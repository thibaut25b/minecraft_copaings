-- Point d'entrée du casino : hall et jeux au toucher, animation par minuterie ; jetons fictifs (démo) ou crédits
-- adossés aux pièces de Lightman's Currency (mode monnaie), solde persisté.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local dessin = require("commun.dessin")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local texte_cc = require("commun.texte")
local theme = require("commun.theme")
local defauts = require("casino.reglages")
local banque_monnaie = require("casino.banque")
local caisse = require("casino.caisse")
local depot = require("casino.depot")
local session = require("casino.session")
local son = require("casino.son")
local vues = require("casino.vues")

local CHEMIN_CONFIG = "/casino.cfg"
local CHEMINS_SOLDE = { demo = "/casino.jetons", monnaie = "/casino.credits" }
local CHEMIN_JOURNAL = "/casino.log"
local TAILLE_JOURNAL = 50000

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)
local avis = session.corriger(reglages, defauts, theme.NOMS)
if erreur_config then table.insert(avis, 1, "Config : " .. erreur_config) end

-- En vraie monnaie : mises en crédits, pas de recharge, gains couverts par la réserve, tout est journalisé.
local reelle = reglages.mode == "monnaie"
local banque
if reelle then
  reglages.mise_min, reglages.mise_max = reglages.mise_min_monnaie, reglages.mise_max_monnaie
  reglages.mise_defaut = reglages.mise_defaut_monnaie
  banque = banque_monnaie.ouvrir(reglages, lc_money, trace)
  banque.verifier()
end
local regles_caisse = { depart = reelle and 0 or reglages.jetons_depart, recharge = reelle and 0 or reglages.recharge,
  unite = reelle and "crédit" or "jeton" }
if reelle then
  regles_caisse.couverture = function() return banque.pret and banque.reserve or nil end
end
local livre, reprise, erreur_caisse = caisse.ouvrir(depot.fichier(CHEMINS_SOLDE[reglages.mode]), regles_caisse)
if erreur_caisse then avis[#avis + 1] = erreur_caisse end
if reprise then
  avis[#avis + 1] = string.format("Tour interrompu réglé : mise %d, gain %d.", reprise.mise, reprise.gain)
end

-- Caisse vue par les jeux : en vraie monnaie, chaque écriture est aussi journalisée.
local function journalisee(c)
  local vue = {}
  for nom, methode in pairs(c) do vue[nom] = methode end
  for _, nom in ipairs({ "miser", "regler", "modifier" }) do
    vue[nom] = function(...)
      local ok, raison = c[nom](...)
      local arguments = {}
      for i, valeur in ipairs({ ... }) do arguments[i] = tostring(valeur) end
      trace.info(string.format("Caisse : %s(%s) %s, solde %d", nom, table.concat(arguments, ", "),
        ok and "fait" or ("refusé : " .. tostring(raison)), c.solde()))
      return ok, raison
    end
  end
  return vue
end
if reelle then livre = journalisee(livre) end

local etat = session.nouvelle(reglages, livre.solde())
local function noter_banque()
  if not reelle then return end
  etat.monnaie = { pret = banque.pret, probleme = banque.probleme, reserve = banque.reserve, valeurs = banque.valeurs,
    pieces = reglages.pieces }
  etat.solde = livre.solde()
end
noter_banque()
local contexte = { caisse = livre, inactivite = reglages.inactivite, maintenant = os.clock(),
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

-- Bouton « Encaisser » du hall : le solde part en pièces vers le coffre de sortie.
local function encaisser()
  if session.en_cours(etat) then return end
  etat.geste = os.clock()
  local verse, message = banque.encaisser(livre)
  noter_banque()
  if message then
    session.avertir(etat, message, verse > 0 and "info" or "mauvais", os.clock())
  elseif verse > 0 then
    session.avertir(etat, texte_cc.quantite(verse, "crédit") .. " versés dans le coffre de sortie.", "bon", os.clock())
  end
end

-- Relevé du coffre de dépôt, à chaque période, et relecture des valeurs des pièces ; redessine si quelque chose change.
local derniere_lecture = os.clock()
local function relever()
  local avant = textutils.serialize({ banque.pret, banque.probleme, banque.reserve, livre.solde() })
  if os.clock() - derniere_lecture >= reglages.periode_valeurs then
    derniere_lecture = os.clock()
    local ok, message = banque.lire_valeurs()
    if not ok then trace.erreur(message) end
  end
  banque.verifier()
  local credite, messages = banque.relever(livre)
  noter_banque()
  if credite > 0 then
    session.avertir(etat, "+" .. texte_cc.quantite(credite, "crédit") .. " déposés.", "bon", os.clock())
  end
  if messages[1] then session.avertir(etat, messages[1], "mauvais", os.clock()) end
  if avant ~= textutils.serialize({ banque.pret, banque.probleme, banque.reserve, livre.solde() }) or messages[1] then
    afficher()
  end
end

local function toucher(evenement, x, y)
  local cible, sur_moniteur = cible_affichage()
  if (evenement == "monitor_touch") ~= sur_moniteur then return end
  contexte.maintenant = os.clock()
  local action = vues.action_touchee(cible, etat, x, y)
  if action and action.type == "encaisser_solde" then
    encaisser()
  elseif action then
    session.agir(etat, action, contexte)
  end
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
  local minuteur_banque = reelle and os.startTimer(reglages.periode_depot)
  while true do
    local evenement, parametre, x, y = os.pullEventRaw()
    if evenement == "terminate" or (evenement == "char" and parametre == "q") then return end
    if reelle and evenement == "timer" and parametre == minuteur_banque then
      proteger("banque", relever)
      minuteur_banque = os.startTimer(reglages.periode_depot)
    elseif evenement == "timer" and parametre == minuteur then
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
print(texte_cc.vers_cc("Casino arrêté."))
