-- Diagnostic à lancer à la main (/usine/diag) : lit capteurs, stock et relais configurés, sans jamais rien poser.

package.path = "/?.lua;" .. package.path
local peripheriques = require("commun.peripheriques")
local logistique = require("commun.logistique")
local vers_cc = require("commun.texte").vers_cc

local FICHIER = "/usine-diag.txt"
local CONFIG = "/usine.cfg"
local ECHANTILLON = 10

local T = peripheriques.TYPES
local lignes, rapport = {}, { visibles = peripheriques.visibles(), jauges = {}, relais = {} }

local function noter(texte) lignes[#lignes + 1] = texte end

local function lire(objet, methode, ...)
  local ok, valeur = peripheriques.appel(objet, methode, ...)
  if ok then return valeur end
  return "erreur : " .. tostring(valeur)
end

-- Noms visibles dont le type principal est `type_voulu`.
local function noms_du_type(type_voulu)
  local noms = {}
  for _, nom in ipairs(peripheral.getNames()) do
    if peripheral.getType(nom) == type_voulu then noms[#noms + 1] = nom end
  end
  table.sort(noms)
  return noms
end

noter(#rapport.visibles .. " périphériques visibles")
for _, visible in ipairs(rapport.visibles) do noter("  " .. visible) end

local JAUGES = {
  { type = T.stressometre, lectures = { "getStress", "getStressCapacity" } },
  { type = T.speedometre, lectures = { "getSpeed" } },
}
for _, jauge in ipairs(JAUGES) do
  for _, nom in ipairs(noms_du_type(jauge.type)) do
    local objet = peripheriques.par_nom(nom)
    local valeurs = {}
    for _, methode in ipairs(jauge.lectures) do
      valeurs[#valeurs + 1] = methode .. " = " .. tostring(lire(objet, methode))
    end
    rapport.jauges[nom] = valeurs
    noter(nom .. " : " .. table.concat(valeurs, ", "))
  end
end

local tickers = noms_du_type(T.stock_ticker)
if #tickers == 0 then noter("Stock Ticker : aucun") end
for _, nom in ipairs(tickers) do
  local stock, message = logistique.stock(peripheriques.par_nom(nom))
  if not stock then
    noter(nom .. " : " .. tostring(message))
  else
    local objets = {}
    for objet in pairs(stock) do objets[#objets + 1] = objet end
    table.sort(objets)
    local echantillon = {}
    for i = 1, math.min(ECHANTILLON, #objets) do echantillon[objets[i]] = stock[objets[i]] end
    rapport.stock = { total = #objets, echantillon = echantillon }
    noter(nom .. " : " .. #objets .. " objets différents")
    for i = 1, math.min(ECHANTILLON, #objets) do noter("  " .. objets[i] .. " = " .. stock[objets[i]]) end
  end
end

-- Relais des lignes de /usine.cfg, relu sans le créer : getOutput seulement.
local lus = {}
if fs.exists(CONFIG) then
  local fichier = fs.open(CONFIG, "r")
  if fichier then
    lus = textutils.unserialize(fichier.readAll() or "") or {}
    fichier.close()
  end
end
for _, ligne in ipairs(type(lus.lignes) == "table" and lus.lignes or {}) do
  if type(ligne) == "table" and type(ligne.relais) == "string" and type(ligne.cote) == "string" then
    local relais = peripheriques.par_nom(ligne.relais)
    local constat
    if not relais then
      constat = "introuvable"
    elseif type(relais.setOutput) ~= "function" then
      constat = "pas un relais redstone de ComputerCraft"
    else
      constat = "getOutput = " .. tostring(lire(relais, "getOutput", ligne.cote))
    end
    rapport.relais[#rapport.relais + 1] = { ligne = ligne.nom, relais = ligne.relais, cote = ligne.cote,
      constat = constat }
    noter("Ligne " .. tostring(ligne.nom) .. " : " .. ligne.relais .. " " .. ligne.cote .. " : " .. constat)
  end
end

for _, texte in ipairs(lignes) do print(vers_cc(texte)) end
local fichier = fs.open(FICHIER, "w")
if fichier then
  fichier.write(textutils.serialize(rapport))
  fichier.close()
  print(vers_cc("Détail : " .. FICHIER))
else
  print(vers_cc("Écriture impossible : " .. FICHIER))
end
