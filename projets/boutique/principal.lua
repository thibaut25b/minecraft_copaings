-- Point d'entrée de la boutique : réassort et prix des comptoirs, comptes des ventes et tableau de bord, en trois boucles.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local depot = require("commun.depot")
local journal = require("commun.journal")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local defauts = require("boutique.reglages")
local offres = require("boutique.offres")
local passe = require("boutique.passe")
local ventes = require("boutique.ventes")
local vues = require("boutique.vues")

local CHEMIN_CONFIG = "/boutique.cfg"
local CHEMIN_JOURNAL = "/boutique.log"
local CHEMIN_VENTES = "/boutique.ventes"
local TAILLE_JOURNAL = 50000
local EVENEMENT_AFFICHAGE = "boutique_affichage"
local EVENEMENT_PASSE = "boutique_passe"
local EVENEMENT_VENTE = "boutique_vente"

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
local trace = journal.ouvrir(CHEMIN_JOURNAL, TAILLE_JOURNAL)

-- Les erreurs sont rangées par origine : une boucle remplace les siennes sans effacer celles des autres.
local ORIGINES = { "config", "comptoirs", "prix", "tampon", "reseau", "ventes", "ecran", "interne" }
local erreurs = {}
for _, origine in ipairs(ORIGINES) do erreurs[origine] = {} end
local function signaler_config(message) erreurs.config[#erreurs.config + 1] = "Config : " .. message end
if erreur_config then signaler_config(erreur_config) end
if type(reglages.articles) ~= "table" then
  signaler_config("articles doit être une table, ignorée")
  reglages.articles = {}
end
local theme_connu = false
for _, nom in ipairs(theme.NOMS) do theme_connu = theme_connu or nom == reglages.theme end
if not theme_connu then
  signaler_config("thème inconnu " .. tostring(reglages.theme) .. ", nuit utilisé")
  reglages.theme = "nuit"
end
if type(reglages.tampon) ~= "string" or reglages.tampon == "" then
  signaler_config("tampon vide : mets le nom réseau du coffre tampon dans " .. CHEMIN_CONFIG)
  reglages.tampon = ""
end

local depot_ventes = depot.fichier(CHEMIN_VENTES)
local lu, avis_ventes = depot_ventes.lire()
if lu == false then erreurs.ventes = { "Ventes : " .. tostring(avis_ventes) } end
local etat = {
  heure = "", articles = {}, ventes = ventes.charger(lu), erreurs = {}, pagination = {}, comptoirs = 0,
}
local memoire = { en_route = {}, refus = {} }
local attente = {} -- ventes reçues, pas encore lues
local internes = {}
local deja_journalisees = {}
local identifiant = os.getComputerID()

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

-- Exécute une étape sans laisser mourir sa coroutine : l'erreur inattendue s'affiche et se journalise.
local function proteger(nom, etape, ...)
  local ok, message = pcall(etape, ...)
  internes[nom] = (not ok) and ("Erreur (" .. nom .. ") : " .. tostring(message)) or nil
  erreurs.interne = {}
  for _, texte in pairs(internes) do erreurs.interne[#erreurs.interne + 1] = texte end
end

-- Tous les comptoirs visibles, avec leur nom réseau.
local function comptoirs_visibles()
  local liste = {}
  for _, trader in ipairs({ peripheral.find(peripheriques.TYPES.comptoir) }) do
    local ok, nom = pcall(peripheral.getName, trader)
    liste[#liste + 1] = { nom = ok and tostring(nom) or ("comptoir " .. (#liste + 1)), trader = trader }
  end
  return liste
end

local function stock_ticker()
  if reglages.stock_ticker == "" then return peripheriques.trouver(peripheriques.TYPES.stock_ticker) end
  return peripheriques.par_nom(reglages.stock_ticker)
end

local function passer()
  local comptoirs = comptoirs_visibles()
  local ticker = stock_ticker()
  local resultat = passe.executer({ comptoirs = comptoirs, tampon = reglages.tampon, ticker = ticker,
    reglages = reglages, memoire = memoire, maintenant = os.clock(), id = identifiant, trace = trace })
  etat.articles, etat.comptoirs = resultat.articles, #comptoirs
  for origine, messages in pairs(resultat.erreurs) do erreurs[origine] = messages end
  if reglages.tampon == "" then erreurs.tampon = {} end
  if not ticker then
    erreurs.reseau = { "Pas de Stock Ticker " .. (reglages.stock_ticker ~= "" and "« " .. reglages.stock_ticker
      .. " » " or "") .. ": réassort par le tampon seulement" }
  end
end

-- Lit les objets d'une vente reçue : l'offre de l'événement, sinon getTrade(indice + 1) (indice 0-based).
local function objets_de(recue)
  local objets = offres.objets_vendus(recue.trade)
  if objets then return objets end
  if type(recue.indice) == "number" then
    local ok, trade = peripheriques.appel(recue.trader, "getTrade", recue.indice + 1)
    if ok then objets = offres.objets_vendus(trade) end
  end
  return objets or {}
end

local function traiter_vente(recue)
  local joueur = type(recue.joueur) == "table" and type(recue.joueur.Name) == "string" and recue.joueur.Name or "?"
  local texte_paye = type(recue.paye) == "table" and type(recue.paye.text) == "string" and recue.paye.text or nil
  local vente = { joueur = joueur, objets = objets_de(recue), montant = ventes.montant(recue.paye),
    texte = texte_paye, heure = textutils.formatTime(os.time(), true) }
  ventes.enregistrer(etat.ventes, vente, reglages.ventes_gardees)
  local premier = vente.objets[1]
  trace.info(("Vente : %s achète %s pour %d crédits"):format(joueur,
    premier and (premier.quantite .. " x " .. premier.objet) or "?", vente.montant))
  local ok, message = depot_ventes.ecrire(etat.ventes)
  erreurs.ventes = ok and {} or { "Ventes non enregistrées : " .. tostring(message) }
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
  etat.erreurs = rassembler_erreurs()
  journaliser_erreurs()
  local cible = cible_affichage()
  theme.appliquer(cible, reglages.theme)
  local ok, message = pcall(vues.dessiner, cible, etat)
  if not ok then trace.erreur("Affichage : " .. tostring(message)) end
end

-- Passe à chaque période, ou plus tôt quand une vente la demande.
local function boucle_passe()
  while true do
    proteger("passe", passer)
    os.queueEvent(EVENEMENT_AFFICHAGE)
    local minuteur = os.startTimer(reglages.periode)
    while true do
      local evenement, parametre = os.pullEvent()
      if evenement == EVENEMENT_PASSE or (evenement == "timer" and parametre == minuteur) then break end
    end
  end
end

-- Les ventes sont lues ici et non dans la boucle des événements : lire une offre attend le serveur, et une
-- coroutine qui attend perd les événements qui arrivent pendant ce temps.
local function boucle_ventes()
  while true do
    if #attente > 0 then
      while #attente > 0 do proteger("ventes", traiter_vente, table.remove(attente, 1)) end
      os.queueEvent(EVENEMENT_AFFICHAGE)
    end
    os.pullEvent()
  end
end

local REDESSINER = { [EVENEMENT_AFFICHAGE] = true, monitor_resize = true, term_resize = true }

local function reagir(evenement, a, b, c, d, e)
  if evenement == "lc_trade" then
    attente[#attente + 1] = { trader = a, indice = b, trade = c, joueur = d, paye = e }
    os.queueEvent(EVENEMENT_VENTE)
    os.queueEvent(EVENEMENT_PASSE)
    return
  end
  if evenement == "monitor_touch" or evenement == "mouse_click" then
    local cible, sur_moniteur = cible_affichage()
    if (evenement == "monitor_touch") == sur_moniteur then
      local action = vues.action_touchee(cible, etat, b, c)
      if action then etat.pagination.articles = action.page end
      afficher()
    end
  elseif REDESSINER[evenement] then
    afficher()
  end
end

local function boucle_evenements()
  proteger("affichage", afficher)
  while true do
    proteger("affichage", reagir, os.pullEvent())
  end
end

-- À l'arrêt (Ctrl+T compris), le terminal et le moniteur retrouvent la palette d'origine de CC.
local function restaurer_palettes()
  theme.restaurer(term.current())
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if moniteur then pcall(theme.restaurer, moniteur) end
end

trace.info("Démarrage de la boutique")
local ok, message = pcall(parallel.waitForAny, boucle_passe, boucle_ventes, boucle_evenements)
restaurer_palettes()
if not ok then error(message, 0) end
