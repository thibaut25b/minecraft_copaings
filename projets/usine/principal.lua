-- Point d'entrée de l'usine : régulation des lignes par relais redstone et tableau de bord tactile, en deux boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local depot = require("commun.depot")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("usine.reglages")
local validation = require("usine.validation")
local regulation = require("usine.regulation")
local mesures = require("usine.mesures")
local action = require("usine.action")
local historique = require("usine.historique")
local vues = require("usine.vues")

local CHEMIN_CONFIG = "/usine.cfg"
local CHEMIN_ETAT = "/usine.etat"
local CHEMIN_JOURNAL = "/usine.log"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "usine_affichage"

local lus, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local reglages, erreurs_validation = validation.valider(lus, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)
local stockage = depot.fichier(CHEMIN_ETAT)

-- Les erreurs sont rangées par origine : une étape remplace les siennes sans effacer celles des autres.
local ORIGINES = { "config", "etat", "mesures", "relais", "ecran", "interne" }
local erreurs = {}
for _, origine in ipairs(ORIGINES) do erreurs[origine] = {} end
if erreur_config then erreurs.config[1] = "Config : " .. erreur_config end
for _, message in ipairs(erreurs_validation) do erreurs.config[#erreurs.config + 1] = message end

local SEUILS = { delestage = reglages.seuil_delestage, reprise = reglages.seuil_reprise }

local function relire_memoire()
  local lue, message = stockage.lire()
  if lue == false then erreurs.etat = { "État : " .. tostring(message) } end
  return regulation.memoire(reglages.lignes, lue)
end

local etat = {
  heure = "", erreurs = {}, prochaine_passe = 0, pagination = {}, reseau = 1,
  lignes = reglages.lignes, reseaux = reglages.reseaux, stocks = reglages.stocks, periode = reglages.periode,
  seuils = SEUILS, memoire = relire_memoire(), sorties = {}, mesures = {}, courbes = {}, stock = nil,
}
local internes = {}
local deja_journalisees = {}
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

-- Exécute une étape sans laisser mourir sa boucle : l'erreur inattendue s'affiche, l'étape sera retentée.
local function proteger(nom, etape, ...)
  local ok, message = pcall(etape, ...)
  internes[nom] = (not ok) and ("Erreur (" .. nom .. ") : " .. tostring(message)) or nil
  erreurs.interne = {}
  for _, texte in pairs(internes) do erreurs.interne[#erreurs.interne + 1] = texte end
end

local function enregistrer(ancienne)
  if textutils.serialize(ancienne) == textutils.serialize(etat.memoire) then return end
  local ok, message = stockage.ecrire(etat.memoire)
  erreurs.etat = ok and {} or { "État non enregistré : " .. tostring(message) }
end

-- Décide avec `lues` à partir de `depart` (la mémoire courante par défaut), pose les relais et enregistre la
-- mémoire si elle diffère de celle d'avant.
local function decider(lues, depart)
  local ancienne = etat.memoire
  etat.memoire, etat.sorties = regulation.passer(reglages.lignes, depart or ancienne, lues, SEUILS)
  erreurs.relais = action.appliquer(reglages.lignes, etat.sorties)
  enregistrer(ancienne)
end

local function passer()
  local lues, messages = mesures.lire(reglages)
  erreurs.mesures = messages
  etat.mesures, etat.stock = lues.reseaux, lues.stock
  historique.noter(etat.courbes, lues.reseaux, reglages.points_historique)
  decider(lues)
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

local function boucle_regulation()
  while true do
    echeance_passe = os.clock() + reglages.periode
    proteger("regulation", passer)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode)
  end
end

-- Le mode touché vaut tout de suite : relais posés sans pas de délestage (stress non relu), mémoire enregistrée.
local function changer_mode(nom)
  decider({ stock = etat.stock, reseaux = {} }, regulation.changer_mode(etat.memoire, nom))
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

local function reagir(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  local touche = (evenement == "monitor_touch" and sur_moniteur) or (evenement == "mouse_click" and not sur_moniteur)
  if touche then
    local choix = vues.action_touchee(cible, etat, x, y)
    if choix and choix.type == "mode" then changer_mode(choix.ligne) end
    if choix and choix.type == "reseau" then etat.reseau = etat.reseau % #reglages.reseaux + 1 end
    if choix and choix.type == "pagination" then etat.pagination[choix.liste] = choix.page end
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

trace.info("Démarrage de l'usine")
local ok, message = pcall(parallel.waitForAny, boucle_regulation, boucle_affichage)
restaurer_palettes()
if not ok then error(message, 0) end
