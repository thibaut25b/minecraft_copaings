-- Diagnostic à lancer à la main (/colonie/diag) : constate en vrai les formes renvoyées par les périphériques.

package.path = "/?.lua;" .. package.path
local peripheriques = require("commun.peripheriques")
local vers_cc = require("commun.texte").vers_cc

local FICHIER = "/diag.txt"
local ECHANTILLON = 3
local PROFONDEUR_MAX = 8

-- Lectures sans effet de bord uniquement : jamais d'export, d'import, de craft ni d'annulation.
local CIBLES = {
  { titre = "Colony Integrator", type = peripheriques.TYPES.integrateur,
    lectures = { "getRequests", "getWorkOrders", "getBuildings", "getCitizens", "getVisitors" } },
  { titre = "Pont ME", type = peripheriques.TYPES.pont_me,
    lectures = { "getItems", "getCraftingCPUs", "getCraftingTasks" } },
}

local function est_liste(valeur)
  return type(valeur) == "table" and #valeur > 0
end

-- Les listes sont réduites à `{ total, premiers }` ; les valeurs non sérialisables deviennent du texte.
local function reduire(valeur, profondeur)
  if type(valeur) == "table" then
    if profondeur > PROFONDEUR_MAX then return "<trop profond>" end
    if est_liste(valeur) then
      local premiers = {}
      for i = 1, math.min(#valeur, ECHANTILLON) do premiers[i] = reduire(valeur[i], profondeur + 1) end
      return { total = #valeur, premiers = premiers }
    end
    local copie = {}
    for cle, contenu in pairs(valeur) do copie[tostring(cle)] = reduire(contenu, profondeur + 1) end
    return copie
  end
  if type(valeur) == "string" or type(valeur) == "number" or type(valeur) == "boolean" then return valeur end
  return tostring(valeur)
end

local function noms_des_methodes(objet)
  local noms = {}
  for nom, valeur in pairs(objet) do
    if type(valeur) == "function" then noms[#noms + 1] = nom end
  end
  table.sort(noms)
  return noms
end

local function resume_lecture(ok, valeur)
  if not ok then return "échec" end
  if est_liste(valeur) then return "ok, " .. #valeur .. " éléments" end
  return "ok"
end

local function diagnostiquer(cible)
  local objet = peripheriques.trouver(cible.type)
  if not objet then return { present = false }, { cible.titre .. " : introuvable (" .. cible.type .. ")" } end
  local methodes = noms_des_methodes(objet)
  local rapport = { present = true, methodes = methodes, lectures = {} }
  local lignes = { cible.titre .. " : trouvé, " .. #methodes .. " méthodes" }
  for _, nom in ipairs(cible.lectures) do
    local ok, valeur = peripheriques.appel(objet, nom)
    rapport.lectures[nom] = { ok = ok, valeur = reduire(valeur, 0) }
    lignes[#lignes + 1] = "  " .. nom .. " : " .. resume_lecture(ok, valeur)
  end
  return rapport, lignes
end

local function ecrire_rapport(rapport)
  local fichier = fs.open(FICHIER, "w")
  if not fichier then return false end
  fichier.write(textutils.serialize(rapport))
  fichier.close()
  return true
end

local rapport = {}
for _, cible in ipairs(CIBLES) do
  local partie, lignes = diagnostiquer(cible)
  rapport[cible.type] = partie
  for _, ligne in ipairs(lignes) do print(vers_cc(ligne)) end
end

if ecrire_rapport(rapport) then
  print(vers_cc("Détail : " .. FICHIER))
else
  print(vers_cc("Écriture impossible : " .. FICHIER))
end
