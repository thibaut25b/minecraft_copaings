-- Point d'entrée de la production : flux des items d'un réseau AE2 sur un écran tactile, en deux boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("production.reglages")
local validation = require("production.validation")
local inventaire = require("production.inventaire")
local flux = require("production.flux")
local classement = require("production.classement")
local lecture = require("production.lecture")
local suivi = require("production.suivi")
local vues = require("production.vues")

local CHEMIN_CONFIG = "/production.cfg"
local CHEMIN_JOURNAL = "/production.log"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "production_affichage"
local MESSAGE_COUPURE = "Lecture ignorée : réseau AE incomplet"

local lus, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local reglages, erreurs_validation = validation.valider(lus, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)

-- Les erreurs sont rangées par origine : une étape remplace les siennes sans effacer celles des autres.
local ORIGINES = { "config", "coffre", "mesures", "ecran", "interne" }
local erreurs = {}
for _, origine in ipairs(ORIGINES) do erreurs[origine] = {} end
if erreur_config then erreurs.config[1] = "Config : " .. erreur_config end
for _, message in ipairs(erreurs_validation) do erreurs.config[#erreurs.config + 1] = message end

local etat_flux = flux.nouveau()
local liste_suivie = suivi.fusionner(reglages.objets, nil)
local options = { tout = reglages.tout, suivis = #reglages.objets > 0 or reglages.coffre ~= "",
  consommation = reglages.consommation, delai_alerte = reglages.delai_alerte }
local ecran = {
  heure = "", erreurs = {}, prochaine_mesure = 0, pagination = {}, options = options,
  onglet = (vues.onglets(options)[1] or {}).nom, unite = reglages.unite, fenetre = reglages.fenetre,
  sens = reglages.sens, selection = nil, phase = "attente", flux = etat_flux, instant = nil, classement = nil,
}
local internes = {}
local deja_journalisees = {}
local echeance_mesure = os.clock()
local ids_lus = nil

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

-- Liste suivie : la config, puis le coffre modèle relu à chaque mesure ; en panne, son dernier contenu lu.
local function actualiser_suivis()
  erreurs.coffre = {}
  if reglages.coffre ~= "" then
    local contenu, message = lecture.lire_coffre(peripheriques.par_nom(reglages.coffre), reglages.coffre)
    if message then erreurs.coffre[1] = message else contenu_coffre = contenu end
  end
  liste_suivie = suivi.fusionner(reglages.objets, contenu_coffre)
end

-- Classement de l'écran : une fois par mesure ou par action touchée, jamais à chaque dessin.
local function reclasser()
  if not ecran.instant then return end
  ecran.classement = classement.ecran(etat_flux, ecran.instant, { fenetre = ecran.fenetre, sens = ecran.sens,
    onglet = ecran.onglet, suivis = liste_suivie, tout = reglages.tout }, reglages)
end

-- Items à noter : tout le réseau en un appel, ou les ids suivis ; un changement de l'ensemble des ids (pas de leur
-- ordre) refait une base (le stock d'un id nouveau n'est pas une production).
local function lire_items(pont)
  if reglages.tout then return lecture.lire_tout(pont) end
  local ids = suivi.ids(liste_suivie)
  local tries = {}
  for i, id in ipairs(ids) do tries[i] = id end
  table.sort(tries)
  local signature = table.concat(tries, " ")
  if ids_lus ~= nil and signature ~= ids_lus then flux.rebaser(etat_flux) end
  ids_lus = signature
  return lecture.lire_ids(pont, ids)
end

local function mesurer()
  local instant = os.epoch("utc") / 1000
  actualiser_suivis()
  local items, message = lire_items(trouver_pont())
  if not items then
    erreurs.mesures = { message }
    return
  end
  local instantane, noms = inventaire.normaliser(items)
  local statut = flux.noter(etat_flux, instantane, instant, reglages)
  flux.nommer(etat_flux, noms)
  erreurs.mesures = statut == "coupure" and { MESSAGE_COUPURE } or {}
  if statut == "mesure" then ecran.phase = "suivi" end
  if statut == "base" and ecran.phase == "attente" then ecran.phase = "base" end
  ecran.instant = etat_flux.instant
  reclasser()
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
  ecran.heure = textutils.formatTime(os.time(), true)
  ecran.prochaine_mesure = math.max(0, math.ceil(echeance_mesure - os.clock()))
  ecran.erreurs = rassembler_erreurs()
  journaliser_erreurs()
  local cible = cible_affichage()
  theme.appliquer(cible, reglages.theme)
  local ok, message = pcall(vues.dessiner, cible, ecran)
  if not ok then trace.erreur("Affichage : " .. tostring(message)) end
end

-- Flux et classement se mettent à jour d'un bloc, sans rendre la main ; la boucle la rend entre deux mesures.
local function boucle_mesure()
  while true do
    echeance_mesure = os.clock() + reglages.periode
    proteger("mesure", mesurer)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    sleep(reglages.periode)
  end
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

-- Applique l'action touchée ; onglet, fenêtre, sens et Reset refont le classement.
local function appliquer(choix)
  if choix.type == "unite" then ecran.unite = choix.unite end
  if choix.type == "selection" then ecran.selection = choix.cle end
  if choix.type == "pagination" then ecran.pagination[choix.liste] = choix.page end
  if choix.type == "onglet" or choix.type == "fenetre" or choix.type == "sens" then
    ecran[choix.type] = choix[choix.type]
    reclasser()
  end
  if choix.type == "reset" then
    flux.reinitialiser(etat_flux, choix.cle)
    reclasser()
  end
end

local function reagir(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  local touche = (evenement == "monitor_touch" and sur_moniteur) or (evenement == "mouse_click" and not sur_moniteur)
  if touche then
    local choix = vues.action_touchee(cible, ecran, x, y)
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
