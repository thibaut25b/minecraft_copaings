-- Point d'entrée de la production : débit des items d'un réseau AE2 sur un écran tactile, en deux boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("production.reglages")
local validation = require("production.validation")
local debit = require("production.debit")
local lecture = require("production.lecture")
local suivi = require("production.suivi")
local vues = require("production.vues")

local CHEMIN_CONFIG = "/production.cfg"
local CHEMIN_JOURNAL = "/production.log"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "production_affichage"

local lus, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local reglages, erreurs_validation = validation.valider(lus, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)

-- Les erreurs sont rangées par origine : une étape remplace les siennes sans effacer celles des autres.
local ORIGINES = { "config", "coffre", "mesures", "ecran", "interne" }
local erreurs = {}
for _, origine in ipairs(ORIGINES) do erreurs[origine] = {} end
if erreur_config then erreurs.config[1] = "Config : " .. erreur_config end
for _, message in ipairs(erreurs_validation) do erreurs.config[#erreurs.config + 1] = message end

local etat = {
  heure = "", erreurs = {}, prochaine_mesure = 0, pagination = {}, unite = reglages.unite, selection = nil,
  objets = reglages.objets, noms = {}, quantites = {}, series = {}, departs = {}, periode = reglages.periode,
  duree_graphe = reglages.duree_graphe,
}
local internes = {}
local deja_journalisees = {}
local echeance_mesure = os.clock()

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

-- Le pont nommé dans la config, sinon le premier ME Bridge visible.
local function trouver_pont()
  if reglages.pont ~= "" then return peripheriques.par_nom(reglages.pont) end
  return peripheriques.trouver(peripheriques.TYPES.pont_me)
end

-- Dernier contenu lu du coffre modèle : une panne passagère (chunk déchargé) ne fait rien oublier.
local contenu_coffre = nil

-- Objets suivis : la config, puis le coffre modèle relu à chaque mesure ; en panne, son dernier contenu lu.
local function actualiser_objets()
  erreurs.coffre = {}
  if reglages.coffre ~= "" then
    local contenu, message = lecture.lire_coffre(peripheriques.par_nom(reglages.coffre), reglages.coffre)
    if message then erreurs.coffre[1] = message else contenu_coffre = contenu end
  end
  etat.objets = suivi.fusionner(reglages.objets, contenu_coffre)
  suivi.oublier(etat.series, etat.objets)
  suivi.oublier(etat.departs, etat.objets)
  suivi.oublier(etat.noms, etat.objets)
end

local function mesurer()
  local instant = os.epoch("utc") / 1000
  actualiser_objets()
  local quantites, noms, messages = lecture.lire(trouver_pont(), etat.objets)
  erreurs.mesures = messages
  etat.quantites = quantites
  for objet, nom in pairs(noms) do etat.noms[objet] = nom end
  debit.noter(etat.series, quantites, instant, reglages.duree_historique)
  debit.noter_departs(etat.departs, quantites, instant)
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
  etat.prochaine_mesure = math.max(0, math.ceil(echeance_mesure - os.clock()))
  etat.erreurs = rassembler_erreurs()
  journaliser_erreurs()
  local cible = cible_affichage()
  theme.appliquer(cible, reglages.theme)
  local ok, message = pcall(vues.dessiner, cible, etat)
  if not ok then trace.erreur("Affichage : " .. tostring(message)) end
end

local function boucle_mesure()
  while true do
    echeance_mesure = os.clock() + reglages.periode
    proteger("mesure", mesurer)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode)
  end
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

-- Applique l'action touchée ; le Reset vide la série et le départ de l'objet.
local function appliquer(choix)
  if choix.type == "unite" then etat.unite = choix.unite end
  if choix.type == "selection" then etat.selection = choix.objet end
  if choix.type == "pagination" then etat.pagination[choix.liste] = choix.page end
  if choix.type == "reset" then
    etat.series[choix.objet] = nil
    etat.departs[choix.objet] = nil
  end
end

local function reagir(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  local touche = (evenement == "monitor_touch" and sur_moniteur) or (evenement == "mouse_click" and not sur_moniteur)
  if touche then
    local choix = vues.action_touchee(cible, etat, x, y)
    if choix then appliquer(choix) end
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

trace.info("Démarrage de la production")
local ok, message = pcall(parallel.waitForAny, boucle_mesure, boucle_affichage)
restaurer_palettes()
if not ok then error(message, 0) end
