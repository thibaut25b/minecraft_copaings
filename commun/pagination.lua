-- Pagination tactile d'une liste : découpe en pages, commande « < 2 / 5 > » calée à droite et ses zones touchables.

local dessin = require("commun.dessin")
local theme = require("commun.theme")

local R = theme.ROLES

local pagination = {}

local PRECEDENT, SUIVANT = string.char(17), string.char(16) -- flèches gauche et droite de la police de CC
local LARGEURS_BOUTON = { 5, 3 } -- la plus large qui tient ; 3 cases au moins pour un toucher sûr

--- Découpe `total` éléments sur `place` rangées : tout tient, sinon `place - 1` éléments par page et une rangée pour
--- la commande. Une page `demandee` hors de 1..nombre (liste rétrécie, valeur absente) donne la page 1.
--- Renvoie { page, nombre, debut, fin, commande } ; `commande` vaut true s'il y a plusieurs pages.
function pagination.decouper(total, place, demandee)
  if total <= place or place < 2 then
    return { page = 1, nombre = 1, debut = 1, fin = math.min(total, math.max(0, place)), commande = false }
  end
  local capacite = place - 1
  local nombre = math.ceil(total / capacite)
  local page = 1
  if type(demandee) == "number" and demandee >= 1 and demandee <= nombre then page = math.floor(demandee) end
  local debut = (page - 1) * capacite + 1
  return { page = page, nombre = nombre, debut = debut, fin = math.min(total, debut + capacite - 1), commande = true }
end

--- Commande de `decoupe` sur la rangée `y`, calée à droite de x..x+largeur-1 : { x, texte, precedent, suivant }, où
--- precedent et suivant = { x1, x2, y, page } (la première page précède la dernière). Nil sans commande ou sans place.
function pagination.commande(x, y, largeur, decoupe)
  if not decoupe.commande then return nil end
  local texte = decoupe.page .. " / " .. decoupe.nombre
  for _, bouton in ipairs(LARGEURS_BOUTON) do
    local total = 2 * bouton + #texte + 2
    if total <= largeur then
      local debut = x + largeur - total
      local fin = x + largeur - 1
      return {
        x = debut,
        texte = texte,
        precedent = { x1 = debut, x2 = debut + bouton - 1, y = y, page = (decoupe.page - 2) % decoupe.nombre + 1 },
        suivant = { x1 = fin - bouton + 1, x2 = fin, y = y, page = decoupe.page % decoupe.nombre + 1 },
      }
    end
  end
  return nil
end

--- Dessine la commande : deux boutons d'accent et le numéro de page entre eux, sur `fond`.
function pagination.dessiner(cible, commande, fond)
  for _, bouton in ipairs({ { commande.precedent, PRECEDENT }, { commande.suivant, SUIVANT } }) do
    local zone = bouton[1]
    dessin.ecrire(cible, zone.x1, zone.y, dessin.aligner(bouton[2], zone.x2 - zone.x1 + 1, "centre"), R.fond, R.accent)
  end
  local x = commande.precedent.x2 + 2
  dessin.ecrire(cible, x, commande.precedent.y, commande.texte, R.texte, fond)
end

return pagination
