-- Point d'entrée du casino de démo : hall et jeux au toucher, animation par minuterie, jetons fictifs persistés.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local dessin = require("commun.dessin")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("casino.reglages")
local caisse = require("casino.caisse")
local depot = require("casino.depot")
local session = require("casino.session")
local son = require("casino.son")
local vues = require("casino.vues")

local CHEMIN_CONFIG = "/casino.cfg"
local CHEMIN_JETONS = "/casino.jetons"
local CHEMIN_JOURNAL = "/casino.log"
local TAILLE_JOURNAL = 50000

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)
local avis = session.corriger(reglages, defauts, theme.NOMS)
if erreur_config then table.insert(avis, 1, "Config : " .. erreur_config) end

local banque, reprise, erreur_caisse = caisse.ouvrir(depot.fichier(CHEMIN_JETONS),
  { depart = reglages.jetons_depart, recharge = reglages.recharge })
if erreur_caisse then avis[#avis + 1] = erreur_caisse end
if reprise then
  avis[#avis + 1] = string.format("Tour interrompu réglé : mise %d, gain %d.", reprise.mise, reprise.gain)
end

local etat = session.nouvelle(reglages, banque.solde())
local contexte = { caisse = banque, inactivite = reglages.inactivite, maintenant = os.clock(),
  hasard = function(n) return math.random(n) end }
for _, texte in ipairs(avis) do trace.info(texte) end
if #avis > 0 then session.avertir(etat, avis[1], "info", os.clock()) end

local derniere_erreur

-- Une étape qui échoue ne tue pas la boucle : l'erreur s'affiche, se journalise une fois tant qu'elle se répète.
local function proteger(nom, etape, ...)
  local ok, message = pcall(etape, ...)
  if ok then return end
  local texte = "Erreur (" .. nom .. ") : " .. tostring(message)
  if texte ~= derniere_erreur then trace.erreur(texte) end
  derniere_erreur = texte
  session.avertir(etat, texte, "mauvais", os.clock())
end

-- Sans moniteur, le casino se joue sur le terminal de l'ordinateur, à la souris.
local function cible_affichage()
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if not moniteur then return term.current(), false end
  peripheriques.appel(moniteur, "setTextScale", reglages.echelle_texte)
  return moniteur, true
end

local function afficher()
  local cible = cible_affichage()
  theme.appliquer(cible, reglages.theme)
  vues.dessiner(cible, etat, os.clock())
end

local function sonner()
  local sons = session.vider_sons(etat)
  if not reglages.son or #sons == 0 then return end
  local haut_parleur = peripheriques.trouver(peripheriques.TYPES.haut_parleur)
  if not haut_parleur then return end
  for _, nom in ipairs(sons) do
    local ok, message = son.jouer(haut_parleur, nom, reglages.volume)
    if not ok then error("haut-parleur : " .. tostring(message), 0) end
  end
end

local function avancer()
  contexte.maintenant = os.clock()
  session.avancer(etat, contexte)
  proteger("son", sonner)
  afficher()
end

local function toucher(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  if (evenement == "monitor_touch") ~= sur_moniteur then return end
  contexte.maintenant = os.clock()
  local action = vues.action_touchee(cible, etat, x, y)
  if action then session.agir(etat, action, contexte) end
  proteger("son", sonner)
  afficher()
end

-- Une seule minuterie : une image par période pendant une animation, sinon la prochaine échéance, sinon rien.
local minuteur, echeance_minuteur
local function programmer()
  local maintenant = os.clock()
  local voulue
  if session.anime(etat, maintenant) then
    voulue = maintenant + reglages.periode_image
  else
    local echeance = session.echeance(etat, reglages.inactivite)
    if echeance then voulue = math.max(echeance, maintenant + reglages.periode_image) end
  end
  if not voulue or (minuteur and echeance_minuteur <= voulue) then return end
  if minuteur then os.cancelTimer(minuteur) end
  minuteur, echeance_minuteur = os.startTimer(voulue - maintenant), voulue
end

local REDESSINER = { monitor_resize = true, term_resize = true, peripheral = true, peripheral_detach = true }

local function boucle()
  proteger("affichage", afficher)
  proteger("minuterie", programmer)
  while true do
    local evenement, parametre, x, y = os.pullEventRaw()
    if evenement == "terminate" or (evenement == "char" and parametre == "q") then return end
    if evenement == "timer" and parametre == minuteur then
      minuteur = nil
      proteger("animation", avancer)
    elseif evenement == "monitor_touch" or evenement == "mouse_click" then
      proteger("toucher", toucher, evenement, x, y)
    elseif REDESSINER[evenement] then
      proteger("affichage", afficher)
    end
    proteger("minuterie", programmer)
  end
end

trace.info("Démarrage du casino")
boucle()
for _, cible in ipairs({ term.current(), peripheriques.trouver(peripheriques.TYPES.moniteur) }) do
  pcall(theme.restaurer, cible)
  pcall(dessin.effacer, cible)
end
print(require("commun.texte").vers_cc("Casino arrêté."))
