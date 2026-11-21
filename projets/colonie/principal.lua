-- Point d'entrée de la colonie : fourniture des requêtes, tableau de bord et alarme de raid, en trois boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("colonie.reglages")
local lecture = require("colonie.lecture")
local fourniture = require("colonie.fourniture")
local chantiers = require("colonie.chantiers")
local historique = require("colonie.historique")
local vues = require("colonie.vues")

local CHEMIN_CONFIG = "/colonie.cfg"
local CHEMIN_JOURNAL = "/colonie.log"
local CHEMIN_HISTORIQUE = "/colonie.hist"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "colonie_affichage"

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)

-- Les erreurs sont rangées par origine : une boucle remplace les siennes sans effacer celles des autres.
local ORIGINES = { "config", "bascule", "colonie", "passe", "alarme", "ecran", "historique", "interne" }
local erreurs = { config = erreur_config and { "Config : " .. erreur_config } or {} }
for _, origine in ipairs(ORIGINES) do erreurs[origine] = erreurs[origine] or {} end
if type(reglages.livraison_chantiers) ~= "table" then
  erreurs.config[#erreurs.config + 1] = "Config : livraison_chantiers doit être une table, ignorée"
  reglages.livraison_chantiers = {}
end
local function theme_connu(nom)
  for _, connu in ipairs(theme.NOMS) do
    if connu == nom then return true end
  end
  return false
end
if not theme_connu(reglages.theme) then
  erreurs.config[#erreurs.config + 1] = "Config : thème inconnu " .. tostring(reglages.theme) .. ", nuit utilisé"
  reglages.theme = "nuit"
end

-- Historique des courbes : relu au démarrage, vide si le fichier manque ou est illisible.
local function lire_historique()
  if not fs.exists(CHEMIN_HISTORIQUE) then return {} end
  local fichier = fs.open(CHEMIN_HISTORIQUE, "r")
  if not fichier then return {} end
  local texte = fichier.readAll()
  fichier.close()
  return historique.lire(texte, reglages.points_historique)
end

local etat = {
  heure = "", page = "resume", colonie = nil, lignes = {}, prochaine_passe = 0, erreurs = {},
  constructeurs = nil, constructeur = nil, lignes_chantiers = {}, livraison = reglages.livraison_chantiers,
  historique = lire_historique(), pagination = {},
}
local internes = {} -- nom d'étape -> message de sa dernière erreur inattendue
local deja_journalisees = {}
local fournisseur = nil
local echeance_passe = os.clock()

local function rassembler_erreurs()
  local liste = {}
  for _, origine in ipairs(ORIGINES) do
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

-- Exécute une étape d'une boucle sans laisser mourir sa coroutine (une boucle morte arrêterait tout le programme) :
-- l'erreur inattendue s'affiche et se journalise, l'étape sera retentée au tour suivant.
local function proteger(nom, etape, ...)
  local ok, message = pcall(etape, ...)
  internes[nom] = (not ok) and ("Erreur (" .. nom .. ") : " .. tostring(message)) or nil
  erreurs.interne = {}
  for _, texte in pairs(internes) do erreurs.interne[#erreurs.interne + 1] = texte end
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

-- Ajoute une mesure à l'historique quand la période est écoulée, et seulement alors réécrit le fichier.
local function noter_historique()
  local mesure = historique.mesure(etat.colonie, etat.lignes)
  local instant = os.epoch("utc") / 1000
  if not historique.ajouter(etat.historique, mesure, instant, reglages.periode_historique,
    reglages.points_historique) then
    return
  end
  local fichier = fs.open(CHEMIN_HISTORIQUE, "w")
  if not fichier then
    erreurs.historique = { "Historique non enregistré : écriture impossible dans " .. CHEMIN_HISTORIQUE }
    return
  end
  fichier.write(historique.serialiser(etat.historique))
  fichier.close()
  erreurs.historique = {}
end

local function passer()
  local messages = {}
  local integrateur = peripheriques.trouver(peripheriques.TYPES.integrateur)
  local requetes, message = lecture.requetes(integrateur)
  if not requetes then messages[#messages + 1] = "Requêtes : " .. tostring(message) end
  local constructeurs, message_chantiers = lecture.constructeurs(integrateur)
  if not constructeurs then messages[#messages + 1] = "Chantiers : " .. tostring(message_chantiers) end
  etat.constructeurs = constructeurs
  etat.constructeur = chantiers.choisir(constructeurs, etat.constructeur)
  local passe = chantiers.composer(requetes, constructeurs, reglages.livraison_chantiers)

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

  -- Une seule passe pour les requêtes ordinaires et les chantiers : un seul stock, une seule mémoire.
  local lignes
  if fournisseur then
    lignes = fournisseur.passer(passe.a_servir)
  else
    lignes = fourniture.lignes_sans_pont(passe.a_servir)
  end
  for _, ligne in ipairs(lignes) do
    if ligne.statut == "erreur" then
      messages[#messages + 1] = ligne.requete.libelle .. " : " .. ligne.message
    end
  end
  local ordinaires, par_constructeur = chantiers.repartir(lignes)
  if requetes then
    for _, ecartee in ipairs(fourniture.lignes_ignorees(passe.ecartees, "livrée par l'onglet Chantiers")) do
      ordinaires[#ordinaires + 1] = ecartee
    end
    etat.lignes = ordinaires
  end
  etat.lignes_chantiers = par_constructeur
  erreurs.passe = messages
end

-- Sans moniteur, le tableau de bord se dessine sur le terminal de l'ordinateur.
local function cible_affichage()
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if not moniteur then return term.current(), false end
  local ok, message = peripheriques.appel(moniteur, "setTextScale", reglages.echelle_texte)
  erreurs.ecran = ok and {} or { "echelle_texte refusée : " .. tostring(message) }
  return moniteur, true
end

local function afficher()
  etat.heure = textutils.formatTime(os.time(), true)
  etat.prochaine_passe = math.max(0, math.ceil(echeance_passe - os.clock()))
  etat.erreurs = rassembler_erreurs()
  journaliser_erreurs()
  local cible = cible_affichage()
  theme.appliquer(cible, reglages.theme)
  local ok, message = pcall(vues.dessiner, cible, etat)
  if not ok then trace.erreur("Affichage : " .. tostring(message)) end
end

local function boucle_fourniture()
  while true do
    echeance_passe = os.clock() + reglages.periode_fourniture
    proteger("fourniture", passer)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode_fourniture)
  end
end

local function boucle_colonie()
  while true do
    proteger("colonie", lire_colonie)
    proteger("historique", noter_historique)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode_affichage)
  end
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

-- Bascule la livraison automatique d'un constructeur et l'enregistre, sauf si le fichier de config est fautif.
local function basculer_livraison(cle)
  local livraison = reglages.livraison_chantiers
  livraison[cle] = (livraison[cle] ~= true) or nil
  if erreur_config then
    erreurs.bascule = { "Livraison des chantiers non enregistrée : corrige d'abord " .. CHEMIN_CONFIG }
    return
  end
  local ok, message = config.enregistrer(CHEMIN_CONFIG, reglages)
  erreurs.bascule = ok and {} or { "Livraison des chantiers non enregistrée : " .. tostring(message) }
end

-- Un toucher du moniteur (ou un clic sur le terminal quand il sert d'écran) change de page, de constructeur, ou
-- bascule la livraison du constructeur montré.
local function reagir(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  local touche = (evenement == "monitor_touch" and sur_moniteur) or (evenement == "mouse_click" and not sur_moniteur)
  if touche then
    local action = vues.action_touchee(cible, etat, x, y)
    if action and action.type == "page" then etat.page = action.page end
    if action and action.type == "constructeur" then etat.constructeur = action.cle end
    if action and action.type == "livraison" then basculer_livraison(action.cle) end
    if action and action.type == "pagination" then etat.pagination[action.liste] = action.page end
    afficher()
  elseif REDESSINER[evenement] then
    afficher()
  end
end

local function boucle_affichage()
  proteger("affichage", afficher)
  while true do
    local evenement, _, x, y = os.pullEvent()
    proteger("affichage", reagir, evenement, x, y)
  end
end

-- À l'arrêt (Ctrl+T compris), le terminal et le moniteur retrouvent la palette d'origine de CC.
local function restaurer_palettes()
  theme.restaurer(term.current())
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if moniteur then pcall(theme.restaurer, moniteur) end
end

trace.info("Démarrage de la colonie")
local ok, message = pcall(parallel.waitForAny, boucle_fourniture, boucle_colonie, boucle_affichage)
restaurer_palettes()
if not ok then error(message, 0) end
