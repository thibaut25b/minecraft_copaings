-- Rangées de commandes : onglets de vue, unité, fenêtre, sens ; en place réduite, un bouton qui fait défiler les valeurs.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")

local commandes = {}

local TOUT_REDUIT = { fenetre = true, sens = true, onglet = true }
-- Essais successifs : groupes en entier, puis fenêtre et sens réduits, puis tout réduit, deux cases entre les
-- groupes ; en dernier recours, tout réduit et une seule case.
local ESSAIS = { { {}, 2 }, { { fenetre = true, sens = true }, 2 }, { TOUT_REDUIT, 2 }, { TOUT_REDUIT, 1 } }

-- Largeur d'un groupe en entier (rangée d'onglets) ou réduit (un bouton à la largeur du plus long libellé).
local function largeur(groupe, reduit)
  if reduit then
    local plus = 0
    for _, option in ipairs(groupe.options) do plus = math.max(plus, panneaux.longueur(option.libelle)) end
    return plus + 2
  end
  local zones = dessin.zones_onglets(1, 1, 1000, groupe.options)
  return zones[#zones].x2
end

-- Éléments { groupe, reduit, x, y, largeur } des `groupes` posés à la suite à partir de (x, y) sur `place` cases,
-- séparés de `ecart` cases, et nombre de rangées occupées.
local function ranger(groupes, x, y, place, reduits, ecart)
  local elements, colonne, rangee = {}, x, y
  for _, groupe in ipairs(groupes) do
    local reduit = reduits[groupe.cle] == true
    local taille = math.min(place, largeur(groupe, reduit))
    if colonne > x and colonne + taille - 1 > x + place - 1 then colonne, rangee = x, rangee + 1 end
    elements[#elements + 1] = { groupe = groupe, reduit = reduit, x = colonne, y = rangee, largeur = taille }
    colonne = colonne + taille + ecart
  end
  return elements, #groupes > 0 and rangee - y + 1 or 0
end

--- Géométrie des `groupes` { cle, options { nom, libelle }, actif } à partir de (x, y) sur `place` cases, en
--- `rangees_maxi` rangées si possible, deux cases entre les groupes : tout en onglets, sinon fenêtre et sens
--- réduits à un bouton qui fait défiler, sinon les onglets de vue aussi, sinon une seule case entre les groupes.
--- Renvoie { elements, rangees }.
function commandes.disposer(groupes, x, y, place, rangees_maxi)
  local elements, rangees
  for _, essai in ipairs(ESSAIS) do
    elements, rangees = ranger(groupes, x, y, place, essai[1], essai[2])
    if rangees <= rangees_maxi then break end
  end
  return { elements = elements, rangees = rangees }
end

local function libelle_actif(groupe)
  for _, option in ipairs(groupe.options) do
    if option.nom == groupe.actif then return option end
  end
  return groupe.options[1]
end

--- Dessine les commandes disposées : la valeur active en évidence ; un bouton réduit montre la valeur active.
function commandes.dessiner(cible, plan)
  for _, element in ipairs(plan.elements) do
    local groupe = element.groupe
    if element.reduit then
      local option = libelle_actif(groupe)
      dessin.onglets(cible, element.x, element.y, element.largeur, { option }, option.nom)
    else
      dessin.onglets(cible, element.x, element.y, element.largeur, groupe.options, groupe.actif)
    end
  end
end

--- Action du toucher en (x, y) sur les commandes, ou nil : `{ type = cle, [cle] = valeur }` ; un bouton réduit
--- donne la valeur qui suit l'active.
function commandes.action(plan, x, y)
  for _, element in ipairs(plan.elements) do
    local groupe = element.groupe
    if y == element.y and x >= element.x and x < element.x + element.largeur then
      local valeur
      if element.reduit then
        local options, rang = groupe.options, 1
        for i, option in ipairs(options) do
          if option.nom == groupe.actif then rang = i end
        end
        valeur = options[rang % #options + 1].nom
      else
        valeur = dessin.onglet_sous_point(dessin.zones_onglets(element.x, element.y, element.largeur, groupe.options),
          x, y)
      end
      if valeur ~= nil then return { type = groupe.cle, [groupe.cle] = valeur } end
    end
  end
  return nil
end

return commandes
