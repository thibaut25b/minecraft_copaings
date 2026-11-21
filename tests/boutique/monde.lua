-- Monde de test de la boutique : réseau de faux coffres, tampon, comptoirs, Stock Ticker facultatif et une passe.

local coffre = require("faux.coffre")
local faux_comptoir = require("faux.comptoir")
local faux_create = require("faux.create")
local defauts = require("boutique.reglages")
local passe = require("boutique.passe")

local monde = {}

monde.TAMPON = "minecraft:chest_0"

--- Monde avec un tampon de contenu `tampon` ({ [emplacement] = { name, count } }), les réglages par défaut
--- complétés de `reglages`, et un Stock Ticker de stock `reseau` ({ [objet] = quantité }) si `reseau` est donné.
function monde.nouveau(tampon, reglages, reseau)
  local m = { reseau = coffre.reseau(), journal = {}, comptoirs = {}, memoire = { en_route = {}, refus = {} } }
  m.tampon = coffre.nouveau(m.reseau, monde.TAMPON, 27, tampon)
  peripheral = { wrap = function(nom) return m.reseau.inventaires[nom] end }
  m.trace = {
    info = function(texte) m.journal[#m.journal + 1] = texte end,
    erreur = function(texte) m.journal[#m.journal + 1] = "ERREUR " .. texte end,
  }
  m.reglages = {}
  for cle, valeur in pairs(defauts) do m.reglages[cle] = valeur end
  m.reglages.tampon = monde.TAMPON
  for cle, valeur in pairs(reglages or {}) do m.reglages[cle] = valeur end
  if reseau then m.ticker = faux_create.ticker(reseau) end

  --- Ajoute le comptoir `nom` (voir faux.comptoir) et le renvoie.
  function m.comptoir(nom, definitions, taille, contenu)
    local c = faux_comptoir.nouveau(m.reseau, nom, definitions, taille, contenu)
    m.comptoirs[#m.comptoirs + 1] = { nom = nom, trader = c }
    return c
  end

  --- Joue une passe à l'instant `maintenant` (0 par défaut) et renvoie son résultat.
  function m.passer(maintenant)
    return passe.executer({ comptoirs = m.comptoirs, tampon = monde.TAMPON, ticker = m.ticker, reglages = m.reglages,
      memoire = m.memoire, maintenant = maintenant or 0, id = 7, trace = m.trace })
  end

  return m
end

--- Vrai si une ligne de `liste` contient `motif` (texte brut).
function monde.contient(liste, motif)
  for _, ligne in ipairs(liste) do
    if tostring(ligne):find(motif, 1, true) then return true end
  end
  return false
end

return monde
