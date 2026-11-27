-- Validation des réglages de la production : entrée fautive écartée avec son message, valeur hors bornes ramenée au défaut.

local theme = require("commun.theme")
local debit = require("production.debit")

local validation = {}

--- Bornes de `echelle_texte` (échelles acceptées par un moniteur CC).
validation.ECHELLE_MINI, validation.ECHELLE_MAXI = 0.5, 5

--- Plus petite période de mesure acceptée, en secondes.
validation.PERIODE_MINI = 0.5

local function contient(liste, valeur)
  for _, element in ipairs(liste) do
    if element == valeur then return true end
  end
  return false
end

local function nombre(valeur)
  return type(valeur) == "number" and valeur == valeur
end

-- Réglage simple : valeur gardée si `valide`, défaut et message sinon.
local function simple(reglages, defauts, cle, valide, attendu, erreurs)
  if valide(reglages[cle]) then return reglages[cle] end
  erreurs[#erreurs + 1] = "Config : " .. cle .. " doit être " .. attendu .. ", " .. tostring(defauts[cle])
    .. " utilisé"
  return defauts[cle]
end

local function valider_objet(entree, vus)
  if type(entree) ~= "table" then return nil, "n'est pas une table" end
  if type(entree.objet) ~= "string" or entree.objet == "" then return nil, "objet manquant" end
  if vus[entree.objet] then return nil, "déjà suivi" end
  if entree.nom ~= nil and type(entree.nom) ~= "string" then return nil, "nom doit être un texte" end
  return { objet = entree.objet, nom = entree.nom or "" }
end

--- Réglages validés à partir de `reglages` (fichier complété) et `defauts` : { periode, echelle_texte, theme,
--- unite, duree_historique, duree_graphe, pont, objets }, puis la liste des messages d'erreur. `objets` ne garde
--- que les entrées { objet, nom } valides, sans doublon ; `duree_graphe` est ramenée à `duree_historique` si elle
--- la dépasse.
function validation.valider(reglages, defauts)
  local erreurs = {}
  local propre = {}
  propre.periode = simple(reglages, defauts, "periode", function(v)
    return nombre(v) and v >= validation.PERIODE_MINI
  end, "un nombre de secondes >= " .. validation.PERIODE_MINI, erreurs)
  propre.echelle_texte = simple(reglages, defauts, "echelle_texte", function(v)
    return nombre(v) and v >= validation.ECHELLE_MINI and v <= validation.ECHELLE_MAXI
  end, "un nombre de " .. validation.ECHELLE_MINI .. " à " .. validation.ECHELLE_MAXI, erreurs)
  propre.theme = simple(reglages, defauts, "theme", function(v) return contient(theme.NOMS, v) end,
    "un thème connu (" .. table.concat(theme.NOMS, ", ") .. ")", erreurs)
  propre.unite = simple(reglages, defauts, "unite", function(v) return contient(debit.UNITES, v) end,
    "une unité connue (" .. table.concat(debit.UNITES, ", ") .. ")", erreurs)
  propre.duree_historique = simple(reglages, defauts, "duree_historique", function(v)
    return nombre(v) and v > 0
  end, "un nombre de secondes > 0", erreurs)
  propre.duree_graphe = simple(reglages, defauts, "duree_graphe", function(v)
    return nombre(v) and v > 0
  end, "un nombre de secondes > 0", erreurs)
  if propre.duree_graphe > propre.duree_historique then
    erreurs[#erreurs + 1] = "Config : duree_graphe dépasse duree_historique, " .. propre.duree_historique
      .. " utilisé"
    propre.duree_graphe = propre.duree_historique
  end
  propre.pont = simple(reglages, defauts, "pont", function(v) return type(v) == "string" end, "un texte", erreurs)

  propre.objets = {}
  local liste = reglages.objets
  if liste ~= nil and type(liste) ~= "table" then
    erreurs[#erreurs + 1] = "Config : objets doit être une liste, ignorée"
    liste = {}
  end
  local vus = {}
  for i, entree in ipairs(liste or {}) do
    local objet, raison = valider_objet(entree, vus)
    if objet then
      vus[objet.objet] = true
      propre.objets[#propre.objets + 1] = objet
    else
      local nom = type(entree) == "table" and type(entree.objet) == "string" and entree.objet ~= "" and entree.objet
        or "n°" .. i
      erreurs[#erreurs + 1] = "Config : objet " .. nom .. " écarté : " .. raison
    end
  end
  return propre, erreurs
end

return validation
