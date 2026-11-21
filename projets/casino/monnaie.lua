-- Calculs de la monnaie réelle, sans rien déplacer : valeur d'un inventaire, rendu en pièces, équivalent affiché,
-- solvabilité. Les valeurs des pièces ({ [identifiant] = valeur en crédits }) sont lues en jeu par ailleurs.

local texte = require("commun.texte")

local monnaie = {}

--- Valeur en crédits d'un contenu d'inventaire ({ [emplacement] = { name, count } }) ; les objets sans valeur
--- comptent pour 0.
function monnaie.valeur(contenu, valeurs)
  local total = 0
  for _, pile in pairs(contenu) do total = total + (valeurs[pile.name] or 0) * pile.count end
  return total
end

--- Nombre de pièces de chaque sorte dans un contenu d'inventaire : { [identifiant] = nombre }.
function monnaie.stock(contenu, valeurs)
  local stock = {}
  for _, pile in pairs(contenu) do
    if valeurs[pile.name] then stock[pile.name] = (stock[pile.name] or 0) + pile.count end
  end
  return stock
end

-- Identifiants des pièces de valeur positive, de la plus grosse à la plus petite (à égalité, par identifiant).
local function par_valeur(valeurs)
  local ordre = {}
  for identifiant, valeur in pairs(valeurs) do
    if valeur > 0 then ordre[#ordre + 1] = identifiant end
  end
  table.sort(ordre, function(a, b)
    if valeurs[a] ~= valeurs[b] then return valeurs[a] > valeurs[b] end
    return a < b
  end)
  return ordre
end

--- Rendu de `montant` crédits avec les pièces de `stock` ({ [identifiant] = nombre }, nil : sans limite), plus
--- grosses d'abord. Renvoie la liste { { piece, nombre } } et le total rendu (au plus `montant`).
function monnaie.rendu(montant, stock, valeurs)
  local lots, reste = {}, montant
  for _, piece in ipairs(par_valeur(valeurs)) do
    local disponible = stock and (stock[piece] or 0) or math.huge
    local nombre = math.min(disponible, math.floor(reste / valeurs[piece]))
    if nombre > 0 then
      lots[#lots + 1] = { piece = piece, nombre = nombre }
      reste = reste - nombre * valeurs[piece]
    end
  end
  return lots, montant - reste
end

--- Équivalent affiché d'un montant : « 1 émeraude 2 or 5 fer » avec les noms de `pieces` ({ { id, nom } }) ; le
--- reste qu'aucune pièce ne rend est ajouté en crédits.
function monnaie.decrire(montant, pieces, valeurs)
  local noms = {}
  for _, piece in ipairs(pieces) do noms[piece.id] = piece.nom end
  local lots, rendu = monnaie.rendu(montant, nil, valeurs)
  local morceaux = {}
  for _, lot in ipairs(lots) do morceaux[#morceaux + 1] = texte.milliers(lot.nombre) .. " " .. noms[lot.piece] end
  if rendu < montant then morceaux[#morceaux + 1] = texte.quantite(montant - rendu, "crédit") end
  if #morceaux == 0 then return "0" end
  return table.concat(morceaux, " ")
end

--- Vrai si la réserve (`reserve` crédits) couvre le solde dans le pire cas d'un tour : solde actuel plus
--- `exposition` (gain net maximal du tour, mises déduites). Réserve inconnue (nil) : jamais couvert.
function monnaie.couvre(reserve, solde, exposition)
  return reserve ~= nil and reserve >= solde + exposition
end

--- Plus grande mise acceptée quand chaque crédit misé peut coûter `exposition_unitaire` crédits nets (0 si aucune).
function monnaie.mise_max(reserve, solde, exposition_unitaire)
  if reserve == nil then return 0 end
  return math.max(0, math.floor((reserve - solde) / exposition_unitaire))
end

return monnaie
