-- Diagnostic à lancer à la main (/production/diag [texte]) : état du pont, coffre modèle, objets configurés, recherche d'identifiants.

package.path = "/?.lua;" .. package.path
local peripheriques = require("commun.peripheriques")
local lecture = require("production.lecture")
local suivi = require("production.suivi")
local vers_cc = require("commun.texte").vers_cc

local FICHIER = "/production-diag.txt"
local CONFIG = "/production.cfg"
local MAX_AFFICHES = 30

local lignes, rapport = {}, { visibles = peripheriques.visibles(), objets = {}, trouves = {}, coffre = {} }
local recherche = ({ ... })[1]

local function noter(texte) lignes[#lignes + 1] = texte end

local function lire(objet, methode, ...)
  local ok, valeur = peripheriques.appel(objet, methode, ...)
  if ok then return valeur end
  return "erreur : " .. tostring(valeur)
end

-- Config relue sans la créer.
local lus = {}
if fs.exists(CONFIG) then
  local fichier = fs.open(CONFIG, "r")
  if fichier then
    lus = textutils.unserialize(fichier.readAll() or "") or {}
    fichier.close()
  end
end

noter(#rapport.visibles .. " périphériques visibles")
for _, visible in ipairs(rapport.visibles) do noter("  " .. visible) end

local pont
if type(lus.pont) == "string" and lus.pont ~= "" then
  pont = peripheriques.par_nom(lus.pont)
else
  pont = peripheriques.trouver(peripheriques.TYPES.pont_me)
end

if not pont then
  noter("ME Bridge : introuvable")
else
  rapport.pont = { isConnected = lire(pont, "isConnected"), isOnline = lire(pont, "isOnline") }
  noter("ME Bridge : isConnected = " .. tostring(rapport.pont.isConnected) .. ", isOnline = "
    .. tostring(rapport.pont.isOnline))
end

local configures = {}
for _, entree in ipairs(type(lus.objets) == "table" and lus.objets or {}) do
  if type(entree) == "table" and type(entree.objet) == "string" then
    configures[#configures + 1] = { objet = entree.objet, nom = type(entree.nom) == "string" and entree.nom or "" }
  end
end

local contenu
if type(lus.coffre) ~= "string" or lus.coffre == "" then
  noter("Coffre modèle : non configuré (réglage coffre)")
else
  local message
  contenu, message = lecture.lire_coffre(peripheriques.par_nom(lus.coffre), lus.coffre)
  rapport.coffre = { nom = lus.coffre, contenu = contenu, erreur = message }
  if message then
    noter("Erreur : " .. message)
  else
    noter("Coffre modèle " .. lus.coffre .. " :")
    local modeles = suivi.fusionner({}, contenu)
    for _, entree in ipairs(modeles) do noter("  " .. entree.objet) end
    if #modeles == 0 then noter("  vide") end
  end
end

local objets = suivi.fusionner(configures, contenu)
local quantites, noms, erreurs = lecture.lire(pont, objets)
for _, entree in ipairs(objets) do
  local quantite = quantites[entree.objet]
  rapport.objets[entree.objet] = { quantite = quantite, nom = noms[entree.objet] }
  noter(entree.objet .. " = " .. tostring(quantite == nil and "illisible" or quantite)
    .. (noms[entree.objet] and " (" .. noms[entree.objet] .. ")" or ""))
end
for _, message in ipairs(erreurs) do noter("Erreur : " .. message) end

if recherche and pont then
  local motif = recherche:lower()
  local items = lire(pont, "getItems")
  if type(items) ~= "table" then
    noter("getItems : " .. tostring(items))
  else
    for _, item in ipairs(items) do
      local id, nom = tostring(item.name), tostring(item.displayName)
      if id:lower():find(motif, 1, true) or nom:lower():find(motif, 1, true) then
        rapport.trouves[#rapport.trouves + 1] = { id = id, nom = nom, quantite = item.count }
      end
    end
    noter(#rapport.trouves .. " item(s) contenant « " .. recherche .. " »")
    for i = 1, math.min(MAX_AFFICHES, #rapport.trouves) do
      local trouve = rapport.trouves[i]
      noter("  " .. trouve.id .. " | " .. trouve.nom .. " | " .. tostring(trouve.quantite))
    end
    if #rapport.trouves > MAX_AFFICHES then
      noter("  ... " .. #rapport.trouves - MAX_AFFICHES .. " de plus dans " .. FICHIER)
    end
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
