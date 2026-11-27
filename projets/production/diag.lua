-- Diagnostic à la main (/production/diag [tout | texte]) : pont, coffre modèle, clés suivies, chrono, recherche.

package.path = "/?.lua;" .. package.path
local peripheriques = require("commun.peripheriques")
local inventaire = require("production.inventaire")
local lecture = require("production.lecture")
local suivi = require("production.suivi")
local vers_cc = require("commun.texte").vers_cc

local FICHIER = "/production-diag.txt"
local CONFIG = "/production.cfg"
local MAX_AFFICHES = 30

local lignes, rapport = {}, { visibles = peripheriques.visibles(), suivis = {}, trouves = {}, coffre = {} }
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
  if type(entree) == "table" and type(entree.objet) == "string" and entree.objet ~= ""
    and (entree.nbt == nil or type(entree.nbt) == "string") then
    configures[#configures + 1] = { objet = entree.objet, nom = type(entree.nom) == "string" and entree.nom or "",
      nbt = entree.nbt }
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
    for _, entree in ipairs(modeles) do noter("  " .. entree.cle) end
    if #modeles == 0 then noter("  vide") end
  end
end

local suivis = suivi.fusionner(configures, contenu)
noter(#suivis .. " objet(s) suivi(s) (config puis coffre) :")
for _, entree in ipairs(suivis) do
  local cle = entree.cle or (entree.objet .. " (toutes variantes)")
  rapport.suivis[#rapport.suivis + 1] = cle
  noter("  " .. cle)
end

-- Tous les items du réseau, ou nil après avoir noté le message d'échec.
local function lire_tout()
  local items, message = lecture.lire_tout(pont)
  if not items then noter("getItems : " .. tostring(message)) end
  return items
end

if recherche == "tout" then
  local memoire_avant = collectgarbage("count")
  local debut = os.epoch("utc")
  local items = lire_tout()
  local duree = os.epoch("utc") - debut
  if items then
    local instantane = inventaire.normaliser(items)
    local types = 0
    for _ in pairs(instantane) do types = types + 1 end
    local memoire_apres = collectgarbage("count")
    rapport.chrono = { duree_ms = duree, items = #items, types = types, memoire_avant_ko = memoire_avant,
      memoire_apres_ko = memoire_apres }
    noter(string.format("getItems() : %d ms, %d entrées, %d types", duree, #items, types))
    noter(string.format("Mémoire : %d Ko avant, %d Ko après", math.floor(memoire_avant), math.floor(memoire_apres)))
  end
elseif recherche then
  local motif = recherche:lower()
  local items = lire_tout()
  for _, item in ipairs(items or {}) do
    local id, nom = tostring(item.name), tostring(item.displayName)
    if id:lower():find(motif, 1, true) or nom:lower():find(motif, 1, true) then
      rapport.trouves[#rapport.trouves + 1] = { id = id, nbt = item.nbt, nom = nom, quantite = item.count }
    end
  end
  if items then
    noter(#rapport.trouves .. " item(s) contenant « " .. recherche .. " » (id | nbt | nom | quantité)")
    for i = 1, math.min(MAX_AFFICHES, #rapport.trouves) do
      local trouve = rapport.trouves[i]
      noter("  " .. trouve.id .. " | " .. tostring(trouve.nbt or "-") .. " | " .. trouve.nom .. " | "
        .. tostring(trouve.quantite))
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
