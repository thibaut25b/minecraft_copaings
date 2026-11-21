-- Symboles de la machine à sous peints en pseudo-pixels, à toute taille, autour d'un centre.

local theme = require("commun.theme")

local R = theme.ROLES

local symboles = {}

--- Couleur dominante de chaque symbole (table de gains, règles).
symboles.COULEURS = {
  sept = R.mauvais, bar = R.accent, cloche = R.moyen, prune = R.accent2, orange = R.alerte, citron = R.moyen,
  cerise = R.mauvais,
}

local function ellipse(toile, cx, cy, rx, ry, couleur)
  ry = math.max(0.5, ry)
  for dy = -math.floor(ry), math.floor(ry) do
    local demi = rx * math.sqrt(math.max(0, 1 - (dy / (ry + 0.5)) ^ 2))
    toile.rectangle(cx - demi, cy + dy, 2 * demi + 1, 1, couleur, true)
  end
end

local function trait(toile, x1, y1, x2, y2, epaisseur, couleur)
  for decalage = 0, math.max(0, epaisseur - 1) do toile.ligne(x1 + decalage, y1, x2 + decalage, y2, couleur) end
end

local PEINTRES = {
  sept = function(toile, cx, cy, t)
    local e = math.max(1, math.floor(t * 0.16))
    toile.rectangle(cx - t * 0.32, cy - t * 0.4, t * 0.64, e + 1, R.mauvais, true)
    trait(toile, cx + t * 0.32 - e, cy - t * 0.4 + e, cx - t * 0.1, cy + t * 0.4, e + 1, R.mauvais)
  end,
  bar = function(toile, cx, cy, t)
    local h = math.max(1, math.floor(t * 0.16))
    for i = -1, 1 do
      local y = cy + i * (h + math.max(1, math.floor(t * 0.1))) - h / 2
      toile.rectangle(cx - t * 0.38, y, t * 0.76, h, R.accent, true)
      toile.rectangle(cx - t * 0.3, y, t * 0.6, 1, R.texte, true)
    end
  end,
  cloche = function(toile, cx, cy, t)
    ellipse(toile, cx, cy - t * 0.12, t * 0.24, t * 0.24, R.moyen)
    local haut, bas = math.floor(cy - t * 0.12), math.floor(cy + t * 0.22)
    for y = haut, bas do
      local demi = t * 0.24 + (y - haut) / math.max(1, bas - haut) * t * 0.14
      toile.rectangle(cx - demi, y, 2 * demi + 1, 1, R.moyen, true)
    end
    toile.rectangle(cx - t * 0.42, bas + 1, t * 0.84 + 1, math.max(1, t * 0.06), R.alerte, true)
    ellipse(toile, cx, bas + 1 + t * 0.12, t * 0.08, t * 0.07, R.alerte)
    toile.point(cx, cy - t * 0.42, R.moyen)
  end,
  prune = function(toile, cx, cy, t)
    ellipse(toile, cx, cy + t * 0.05, t * 0.27, t * 0.33, R.accent2)
    toile.point(cx - t * 0.12, cy - t * 0.1, R.texte)
    trait(toile, cx, cy - t * 0.28, cx + t * 0.12, cy - t * 0.44, 1, R.discret)
  end,
  orange = function(toile, cx, cy, t)
    ellipse(toile, cx, cy + t * 0.04, t * 0.34, t * 0.34, R.alerte)
    ellipse(toile, cx + t * 0.1, cy - t * 0.34, t * 0.12, t * 0.05, R.bon)
    toile.point(cx - t * 0.14, cy - t * 0.1, R.moyen)
  end,
  citron = function(toile, cx, cy, t)
    ellipse(toile, cx, cy, t * 0.36, t * 0.25, R.moyen)
    toile.point(cx - t * 0.36 - 1, cy, R.moyen)
    toile.point(cx + t * 0.36 + 1, cy, R.moyen)
    toile.point(cx - t * 0.12, cy - t * 0.1, R.texte)
  end,
  cerise = function(toile, cx, cy, t)
    local r = math.max(1, t * 0.17)
    local sommet_x, sommet_y = cx + t * 0.06, cy - t * 0.38
    trait(toile, cx - t * 0.2, cy + t * 0.1, sommet_x, sommet_y, 1, R.bon)
    trait(toile, cx + t * 0.2, cy + t * 0.16, sommet_x, sommet_y, 1, R.bon)
    ellipse(toile, sommet_x + t * 0.14, sommet_y + 1, t * 0.12, t * 0.05, R.bon)
    ellipse(toile, cx - t * 0.2, cy + t * 0.2, r, r, R.mauvais)
    ellipse(toile, cx + t * 0.2, cy + t * 0.26, r, r, R.mauvais)
    toile.point(cx - t * 0.26, cy + t * 0.14, R.texte)
    toile.point(cx + t * 0.14, cy + t * 0.2, R.texte)
  end,
}

--- Peint le symbole `nom` dans `toile`, centré en (cx, cy), dans un carré d'environ `taille` pixels.
function symboles.peindre(toile, nom, cx, cy, taille)
  local peintre = PEINTRES[nom]
  if not peintre then error("symbole inconnu : " .. tostring(nom), 2) end
  peintre(toile, cx, cy, taille)
end

return symboles
