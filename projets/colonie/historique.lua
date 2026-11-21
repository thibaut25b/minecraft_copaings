-- Historique borné des mesures de la colonie (bonheur, population, requêtes ouvertes et à problème), en texte.

local statuts = require("colonie.statuts")

local historique = {}

local CHAMPS = { "instant", "bonheur", "population", "limite", "ouvertes", "problemes" }
local NOMBRE = "(%-?[%d%.]+)"
local MOTIF = "^" .. NOMBRE .. string.rep(" " .. NOMBRE, #CHAMPS - 1) .. "$"

--- Mesure de l'instant tirée de la colonie et des lignes de passe ; nil si la colonie est illisible.
function historique.mesure(colonie, lignes)
  if not colonie then return nil end
  local ouvertes, problemes = 0, 0
  for _, ligne in ipairs(lignes) do
    if ligne.statut ~= "livre" then ouvertes = ouvertes + 1 end
    if statuts.de(ligne.statut).action then problemes = problemes + 1 end
  end
  return { bonheur = colonie.bonheur, population = colonie.citoyens, limite = colonie.limite, ouvertes = ouvertes,
    problemes = problemes }
end

--- Ajoute `mesure` à `serie` à `instant` (secondes) si `periode` s'est écoulée depuis le dernier point (ou si
--- l'horloge a reculé), puis garde les `taille` derniers points. Renvoie true si le point est ajouté.
function historique.ajouter(serie, mesure, instant, periode, taille)
  if not mesure then return false end
  local dernier = serie[#serie]
  if dernier and instant >= dernier.instant and instant - dernier.instant < periode then return false end
  local point = { instant = instant }
  for i = 2, #CHAMPS do point[CHAMPS[i]] = mesure[CHAMPS[i]] end
  serie[#serie + 1] = point
  while #serie > taille do table.remove(serie, 1) end
  return true
end

--- Valeurs du champ `champ` de la série, dans l'ordre.
function historique.valeurs(serie, champ)
  local valeurs = {}
  for i, point in ipairs(serie) do valeurs[i] = point[champ] end
  return valeurs
end

--- Durée couverte par la série, en texte court (« 40 s », « 35 min », « 6 h »).
function historique.etendue(serie)
  local secondes = #serie > 1 and serie[#serie].instant - serie[1].instant or 0
  if secondes < 60 then return math.floor(secondes) .. " s" end
  if secondes < 3600 then return math.floor(secondes / 60 + 0.5) .. " min" end
  return math.floor(secondes / 3600 + 0.5) .. " h"
end

--- Texte d'une série : un point par ligne, champs séparés par une espace.
function historique.serialiser(serie)
  local lignes = {}
  for i, point in ipairs(serie) do
    lignes[i] = string.format("%d %.1f %d %d %d %d", math.floor(point.instant), point.bonheur,
      math.floor(point.population), math.floor(point.limite), math.floor(point.ouvertes), math.floor(point.problemes))
  end
  return table.concat(lignes, "\n")
end

--- Série lue dans `texte`, réduite aux `taille` derniers points ; texte absent ou illisible : série vide.
function historique.lire(texte, taille)
  if type(texte) ~= "string" then return {} end
  local serie = {}
  for ligne in texte:gmatch("[^\n]+") do
    local valeurs = { ligne:match(MOTIF) }
    if #valeurs ~= #CHAMPS then return {} end
    local point = {}
    for i, champ in ipairs(CHAMPS) do
      point[champ] = tonumber(valeurs[i])
      if not point[champ] then return {} end
    end
    serie[#serie + 1] = point
  end
  while #serie > taille do table.remove(serie, 1) end
  return serie
end

return historique
