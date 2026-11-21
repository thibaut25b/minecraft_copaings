-- Point d'entrée de la colonie : fourniture des requêtes, tableau de bord et alarme de raid, en trois boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local defauts = require("colonie.reglages")
local lecture = require("colonie.lecture")
local fourniture = require("colonie.fourniture")
local vues = require("colonie.vues")

local CHEMIN_CONFIG = "/colonie.cfg"
local CHEMIN_JOURNAL = "/colonie.log"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "colonie_affichage"

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)

local etat = { heure = "", page = "resume", colonie = nil, lignes = {}, prochaine_passe = 0, erreurs = {} }
-- Les erreurs sont rangées par origine : une boucle remplace les siennes sans effacer celles des autres.
local erreurs = { config = erreur_config and { "Config : " .. erreur_config } or {}, colonie = {}, passe = {}, alarme = {} }
local deja_journalisees = {}
local fournisseur = nil
local echeance_passe = os.clock()

local function rassembler_erreurs()
  local liste = {}
  for _, origine in ipairs({ "config", "colonie", "passe", "alarme" }) do
    for _, message in ipairs(erreurs[origine]) do liste[#liste + 1] = message end
  end
  return liste
end

-- Une erreur qui dure n'est écrite qu'une fois ; elle le sera de nouveau si elle revient après avoir disparu.
local function journaliser_erreurs()
  local presentes = {}
  for _, message in ipairs(rassembler_erreurs()) do
    presentes[message] = true
    if not deja_journalisees[message] then trace.erreur(message) end
  end
  deja_journalisees = presentes
end

local function cote_valide(cote)
  for _, connu in ipairs(redstone.getSides()) do
    if connu == cote then return true end
  end
  return false
end

local function piloter_alarme()
  erreurs.alarme = {}
  local cote = reglages.cote_alarme
  if cote == "" then return end
  if not cote_valide(cote) then
    erreurs.alarme = { "cote_alarme inconnu : " .. tostring(cote) }
    return
  end
  redstone.setOutput(cote, etat.colonie ~= nil and etat.colonie.raid == true)
end

local function lire_colonie()
  local integrateur = peripheriques.trouver(peripheriques.TYPES.integrateur)
  local instantane, message = lecture.lire(integrateur)
  etat.colonie = instantane
  erreurs.colonie = instantane and {} or { "Colonie : " .. tostring(message) }
  piloter_alarme()
end

local function passer()
  local messages = {}
  local integrateur = peripheriques.trouver(peripheriques.TYPES.integrateur)
  local requetes, message = lecture.requetes(integrateur)
  if not requetes then messages[#messages + 1] = "Requêtes : " .. tostring(message) end

  if not fournisseur then
    local pont = peripheriques.trouver(peripheriques.TYPES.pont_me)
    if pont then
      fournisseur = fourniture.creer(pont, reglages)
      for _, avertissement in ipairs(fournisseur.avertissements) do
        erreurs.config[#erreurs.config + 1] = "Config : " .. avertissement
      end
    end
  end
  if not fournisseur then messages[#messages + 1] = "Pont ME introuvable" end

  if requetes and fournisseur then
    etat.lignes = fournisseur.passer(requetes)
    for _, ligne in ipairs(etat.lignes) do
      if ligne.statut == "erreur" then
        messages[#messages + 1] = ligne.requete.libelle .. " : " .. ligne.message
      end
    end
  end
  erreurs.passe = messages
end

-- Sans moniteur, le tableau de bord se dessine sur le terminal de l'ordinateur.
local function cible_affichage()
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if not moniteur then return term.current(), false end
  moniteur.setTextScale(reglages.echelle_texte)
  return moniteur, true
end

local function afficher()
  etat.heure = textutils.formatTime(os.time(), true)
  etat.prochaine_passe = math.max(0, math.ceil(echeance_passe - os.clock()))
  etat.erreurs = rassembler_erreurs()
  journaliser_erreurs()
  local ok, message = pcall(vues.dessiner, (cible_affichage()), etat)
  if not ok then trace.erreur("Affichage : " .. tostring(message)) end
end

local function boucle_fourniture()
  while true do
    echeance_passe = os.clock() + reglages.periode_fourniture
    passer()
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode_fourniture)
  end
end

local function boucle_colonie()
  while true do
    lire_colonie()
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode_affichage)
  end
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

-- Un toucher du moniteur (ou un clic sur le terminal quand il sert d'écran) change de page.
local function boucle_affichage()
  afficher()
  while true do
    local evenement, _, x, y = os.pullEvent()
    local cible, sur_moniteur = cible_affichage()
    local touche = (evenement == "monitor_touch" and sur_moniteur) or (evenement == "mouse_click" and not sur_moniteur)
    if touche then
      etat.page = vues.page_touchee(cible, x, y) or etat.page
      afficher()
    elseif REDESSINER[evenement] then
      afficher()
    end
  end
end

trace.info("Démarrage de la colonie")
parallel.waitForAny(boucle_fourniture, boucle_colonie, boucle_affichage)
