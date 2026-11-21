-- Diagnostic à lancer à la main (/boutique/diag) : lectures seules, aucun mouvement ni setPrice ; détail dans
-- /boutique-diag.txt pour constater en jeu les formes de l'API.

package.path = "/?.lua;" .. package.path
local config = require("commun.config")
local peripheriques = require("commun.peripheriques")
local vers_cc = require("commun.texte").vers_cc
local defauts = require("boutique.reglages")

local FICHIER = "/boutique-diag.txt"
local CHEMIN_CONFIG = "/boutique.cfg"
local ECHANTILLON = 10

local reglages = config.charger(CHEMIN_CONFIG, defauts)
local identifiant = "computercraft#" .. os.getComputerID()
local rapport = { ordinateur = identifiant, peripheriques = peripheriques.visibles(), comptoirs = {} }
local lignes = { "Ordinateur : " .. identifiant, "Périphériques visibles : " .. #rapport.peripheriques }
for _, nom in ipairs(rapport.peripheriques) do lignes[#lignes + 1] = "  " .. nom end

-- Retour brut d'un appel protégé : la valeur, ou « erreur : message ».
local function lire(objet, methode, ...)
  local ok, valeur = peripheriques.appel(objet, methode, ...)
  if ok then return valeur end
  return "erreur : " .. tostring(valeur)
end

-- Valeur réduite à ce qui se sérialise : fonctions et objets Lua de LC deviennent du texte.
local function brut(valeur, profondeur)
  if type(valeur) == "function" then return "<fonction>" end
  if type(valeur) ~= "table" then return valeur end
  if (profondeur or 0) > 6 then return "<trop profond>" end
  local copie = {}
  for cle, contenu in pairs(valeur) do
    if type(contenu) ~= "function" then copie[tostring(cle)] = brut(contenu, (profondeur or 0) + 1) end
  end
  return copie
end

for _, trader in ipairs({ peripheral.find(peripheriques.TYPES.comptoir) }) do
  local nom = tostring(peripheral.getName(trader))
  local partie = { nom = nom, proprietaire = lire(trader, "getOwnerName"),
    openStorage = lire(trader, "getMyPermissionLevel", "openStorage"),
    editTrades = lire(trader, "getMyPermissionLevel", "editTrades"), offres = {} }
  lignes[#lignes + 1] = ("Comptoir %s, propriétaire %s, openStorage %s, editTrades %s"):format(nom,
    tostring(partie.proprietaire), tostring(partie.openStorage), tostring(partie.editTrades))
  local trades = lire(trader, "getTrades")
  if type(trades) == "table" then
    for indice, trade in pairs(trades) do
      local offre = { isSale = lire(trade, "isSale"), getSellItems = brut(lire(trade, "getSellItems")),
        getPrice = brut(lire(trade, "getPrice")), getStock = lire(trade, "getStock") }
      partie.offres[tostring(indice)] = offre
      local prix = type(offre.getPrice) == "table" and offre.getPrice.text or offre.getPrice
      lignes[#lignes + 1] = ("  offre %s : vente %s, prix %s, stock %s"):format(tostring(indice),
        tostring(offre.isSale), tostring(prix), tostring(offre.getStock))
    end
  else
    lignes[#lignes + 1] = "  getTrades : " .. tostring(trades)
  end
  local stockage = lire(trader, "getStorage")
  partie.stockage = type(stockage) == "table" and brut(lire(stockage, "list")) or stockage
  lignes[#lignes + 1] = "  stockage : " .. (type(partie.stockage) == "table" and "lisible" or tostring(partie.stockage))
  rapport.comptoirs[#rapport.comptoirs + 1] = partie
end
if #rapport.comptoirs == 0 then lignes[#lignes + 1] = "Aucun comptoir (" .. peripheriques.TYPES.comptoir .. ")" end

local tampon = peripheriques.par_nom(reglages.tampon)
rapport.tampon = tampon and brut(lire(tampon, "list")) or "introuvable"
lignes[#lignes + 1] = "Tampon « " .. tostring(reglages.tampon) .. " » : "
  .. (type(rapport.tampon) == "table" and "lisible" or tostring(rapport.tampon))

local ticker = reglages.stock_ticker == "" and peripheriques.trouver(peripheriques.TYPES.stock_ticker)
  or peripheriques.par_nom(reglages.stock_ticker)
local stock = ticker and lire(ticker, "stock") or "Stock Ticker introuvable"
if type(stock) == "table" then
  local echantillon = {}
  for i = 1, math.min(#stock, ECHANTILLON) do echantillon[i] = brut(stock[i]) end
  rapport.stock = { total = #stock, premiers = echantillon }
  lignes[#lignes + 1] = "Stock du réseau : " .. #stock .. " objets différents"
else
  rapport.stock = stock
  lignes[#lignes + 1] = "Stock du réseau : " .. tostring(stock)
end

for _, ligne in ipairs(lignes) do print(vers_cc(ligne)) end
local fichier = fs.open(FICHIER, "w")
if fichier then
  fichier.write(textutils.serialize(rapport))
  fichier.close()
  print(vers_cc("Détail : " .. FICHIER))
else
  print(vers_cc("Écriture impossible : " .. FICHIER))
end
