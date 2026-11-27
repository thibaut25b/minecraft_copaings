-- Validation des réglages de la production : entrée fautive écartée avec son message, valeur hors bornes ramenée au défaut.

local theme = require("commun.theme")
local flux = require("production.flux")
local classement = require("production.classement")

local validation = {}

--- Bornes de `echelle_texte` (échelles acceptées par un moniteur CC).
validation.ECHELLE_MINI, validation.ECHELLE_MAXI = 0.5, 5

--- Plus petite période de mesure acceptée, en secondes.
validation.PERIODE_MINI = 2

--- Plus longue période de mesure acceptée, en secondes.
validation.PERIODE_MAXI = 60

--- Plus long délai d'aller-retour accepté : une consommation datée d'avant doit rester dans les cases fines.
validation.DELAI_ALLER_RETOUR_MAXI = 300

local function contient(liste, valeur)
  for _, element in ipairs(liste) do
    if element == valeur then return true end
  end
  return false
end

local function nombre(valeur)
  return type(valeur) == "number" and valeur == valeur
end

local function booleen(valeur)
  return type(valeur) == "boolean"
end

local function texte(valeur)
  return type(valeur) == "string"
end

local function connu(liste)
  return function(valeur) return contient(liste, valeur) end, "une valeur parmi " .. table.concat(liste, ", ")
end

local function entre(mini, maxi, mini_exclu)
  return function(valeur)
    if not nombre(valeur) then return false end
    if mini_exclu and valeur <= mini then return false end
    return valeur >= mini and (maxi == nil or valeur <= maxi)
  end
end

local fenetres = {}
for i, fenetre in ipairs(flux.FENETRES) do fenetres[i] = tostring(fenetre) end

-- Réglages simples : clé, test, description de l'attendu.
local SIMPLES = {
  { "periode", entre(validation.PERIODE_MINI, validation.PERIODE_MAXI),
    "un nombre de secondes de " .. validation.PERIODE_MINI .. " à " .. validation.PERIODE_MAXI },
  { "echelle_texte", entre(validation.ECHELLE_MINI, validation.ECHELLE_MAXI),
    "un nombre de " .. validation.ECHELLE_MINI .. " à " .. validation.ECHELLE_MAXI },
  { "theme", connu(theme.NOMS) },
  { "unite", connu(flux.UNITES) },
  { "tout", booleen, "true ou false" },
  { "consommation", booleen, "true ou false" },
  { "fenetre", function(v) return contient(flux.FENETRES, v) end, "une valeur parmi " .. table.concat(fenetres, ", ") },
  { "sens", connu(classement.SENS) },
  { "debit_mini", entre(0), "un nombre d'items/min >= 0" },
  { "seuil_coupure", entre(0, 1, true), "un nombre > 0 et <= 1" },
  { "delai_aller_retour", entre(0, validation.DELAI_ALLER_RETOUR_MAXI),
    "un nombre de secondes de 0 à " .. validation.DELAI_ALLER_RETOUR_MAXI },
  { "delai_alerte", entre(0, nil, true), "un nombre de secondes > 0" },
  { "pont", texte, "un texte" },
  { "coffre", texte, "un texte" },
}

local function valider_objet(entree, vus)
  if type(entree) ~= "table" then return nil, "n'est pas une table" end
  if type(entree.objet) ~= "string" or entree.objet == "" then return nil, "objet manquant" end
  if entree.nom ~= nil and type(entree.nom) ~= "string" then return nil, "nom doit être un texte" end
  if entree.nbt ~= nil and type(entree.nbt) ~= "string" then return nil, "nbt doit être un texte" end
  local identite = entree.objet .. "|" .. (entree.nbt == nil and "*" or entree.nbt)
  if vus[identite] then return nil, "déjà suivi" end
  vus[identite] = true
  return { objet = entree.objet, nom = entree.nom or "", nbt = entree.nbt }
end

-- Liste de config : entrées gardées par `valider(entree)` (renvoie la valeur propre ou nil et la raison).
local function liste(reglages, cle, quoi, ecarte, valider, nommer, erreurs)
  local propre, brute = {}, reglages[cle]
  if brute ~= nil and type(brute) ~= "table" then
    erreurs[#erreurs + 1] = "Config : " .. cle .. " doit être une liste, ignorée"
    return propre
  end
  for i, entree in ipairs(brute or {}) do
    local valeur, raison = valider(entree)
    if valeur ~= nil then
      propre[#propre + 1] = valeur
    else
      erreurs[#erreurs + 1] = "Config : " .. quoi .. " " .. (nommer(entree) or "n°" .. i) .. " " .. ecarte .. " : " .. raison
    end
  end
  return propre
end

--- Réglages validés à partir de `reglages` (fichier complété) et `defauts` : { periode, echelle_texte, theme,
--- unite, tout, consommation, fenetre, sens, debit_mini, seuil_coupure, delai_aller_retour, delai_alerte, pont,
--- coffre, exclure, objets }, puis la liste des messages d'erreur. `exclure` ne garde que les textes non vides ;
--- `objets` que les entrées { objet, nom, nbt? } valides, sans doublon (même objet et même nbt).
function validation.valider(reglages, defauts)
  local erreurs = {}
  local propre = {}
  for _, simple in ipairs(SIMPLES) do
    local cle, valide, attendu = simple[1], simple[2], simple[3]
    if valide(reglages[cle]) then
      propre[cle] = reglages[cle]
    else
      erreurs[#erreurs + 1] = "Config : " .. cle .. " doit être " .. attendu .. ", " .. tostring(defauts[cle])
        .. " utilisé"
      propre[cle] = defauts[cle]
    end
  end
  propre.exclure = liste(reglages, "exclure", "exclusion", "écartée", function(motif)
    if type(motif) ~= "string" or motif == "" then return nil, "doit être un texte non vide" end
    return motif
  end, function() return nil end, erreurs)
  local vus = {}
  propre.objets = liste(reglages, "objets", "objet", "écarté", function(entree) return valider_objet(entree, vus) end,
    function(entree)
      return type(entree) == "table" and type(entree.objet) == "string" and entree.objet ~= "" and entree.objet or nil
    end, erreurs)
  return propre, erreurs
end

return validation
