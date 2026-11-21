-- Toile de pseudo-pixels (2 x 3 par case) rendue sur une cible au format term de CC, une ligne par blit.

local pixels = {}

local BITS = { 1, 2, 4, 8, 16 }
-- Colonne et rangée de chaque sous-pixel : haut gauche, haut droit, milieu gauche, milieu droit, bas gauche, bas droit.
local COLONNE = { 0, 1, 0, 1, 0, 1 }
local RANGEE = { 0, 0, 1, 1, 2, 2 }

local CARACTERES = {}
for bits = 0, 31 do CARACTERES[bits] = string.char(128 + bits) end

local HEXA = {}
for i = 0, 15 do HEXA[2 ^ i] = string.format("%x", i) end

local function exiger(couleur)
  if not HEXA[couleur] then error("couleur invalide : " .. tostring(couleur), 3) end
end

local function arrondi(nombre)
  return math.floor(nombre + 0.5)
end

-- Les deux couleurs les plus présentes d'une case ; à égalité, la première rencontrée dans l'ordre des sous-pixels.
local function deux_plus_presentes(sous)
  local nombres, ordre = {}, {}
  for k = 1, 6 do
    local couleur = sous[k]
    if not nombres[couleur] then
      nombres[couleur] = 0
      ordre[#ordre + 1] = couleur
    end
    nombres[couleur] = nombres[couleur] + 1
  end
  local premiere, seconde
  for _, couleur in ipairs(ordre) do
    if not premiere or nombres[couleur] > nombres[premiere] then
      premiere, seconde = couleur, premiere
    elseif not seconde or nombres[couleur] > nombres[seconde] then
      seconde = couleur
    end
  end
  return { premiere, seconde }
end

-- Couleur gardée du sous-pixel retenu le plus proche (en position) du sous-pixel `k`, à égalité le premier.
local function plus_proche(sous, k, gardees)
  local meilleure, distance
  for j = 1, 6 do
    if sous[j] == gardees[1] or sous[j] == gardees[2] then
      local d = (COLONNE[j] - COLONNE[k]) ^ 2 + (RANGEE[j] - RANGEE[k]) ^ 2
      if not distance or d < distance then meilleure, distance = sous[j], d end
    end
  end
  return meilleure
end

-- Caractère, couleur de texte et couleur de fond d'une case de deux couleurs au plus (sinon nil). Le sous-pixel bas
-- droit n'a pas de bit : sa couleur est le fond, les bits marquent les sous-pixels de l'autre couleur.
local function coder_deux(sous)
  local fond, autre, bits = sous[6], nil, 0
  for k = 1, 5 do
    local couleur = sous[k]
    if couleur ~= fond then
      if autre == nil then
        autre = couleur
      elseif couleur ~= autre then
        return nil
      end
      bits = bits + BITS[k]
    end
  end
  return CARACTERES[bits], autre or fond, fond
end

-- Au-delà de deux couleurs, la case garde les deux plus présentes et les autres sous-pixels prennent la plus proche.
local function coder(sous)
  local caractere, texte, fond = coder_deux(sous)
  if caractere then return caractere, texte, fond end
  local gardees = deux_plus_presentes(sous)
  local reduit = {}
  for k = 1, 6 do
    local couleur = sous[k]
    if couleur == gardees[1] or couleur == gardees[2] then
      reduit[k] = couleur
    else
      reduit[k] = plus_proche(sous, k, gardees)
    end
  end
  return coder_deux(reduit)
end

--- Toile de `largeur_cases` x `hauteur_cases` cases (2 x 3 pixels par case), remplie de `fond` (noir par défaut).
function pixels.creer(largeur_cases, hauteur_cases, fond)
  local largeur, hauteur = largeur_cases * 2, hauteur_cases * 3
  local grille = {}
  local toile = {}

  local function poser(x, y, couleur)
    if x >= 1 and x <= largeur and y >= 1 and y <= hauteur then grille[(y - 1) * largeur + x] = couleur end
  end

  local function remplir(x1, y1, x2, y2, couleur)
    x1, x2 = math.max(x1, 1), math.min(x2, largeur)
    for y = math.max(y1, 1), math.min(y2, hauteur) do
      local base = (y - 1) * largeur
      for x = x1, x2 do grille[base + x] = couleur end
    end
  end

  --- Taille de la toile en pixels : largeur, hauteur.
  function toile.taille()
    return largeur, hauteur
  end

  --- Remplit toute la toile avec `fond` (noir par défaut).
  function toile.effacer(couleur)
    couleur = couleur or colors.black
    exiger(couleur)
    for i = 1, largeur * hauteur do grille[i] = couleur end
  end

  --- Allume le pixel (x, y), à partir de 1 ; hors toile, rien.
  function toile.point(x, y, couleur)
    exiger(couleur)
    poser(arrondi(x), arrondi(y), couleur)
  end

  --- Trace le segment de (x1, y1) à (x2, y2), extrémités comprises.
  function toile.ligne(x1, y1, x2, y2, couleur)
    exiger(couleur)
    x1, y1, x2, y2 = arrondi(x1), arrondi(y1), arrondi(x2), arrondi(y2)
    local dx, dy = math.abs(x2 - x1), -math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local erreur = dx + dy
    while true do
      poser(x1, y1, couleur)
      if x1 == x2 and y1 == y2 then break end
      local double = 2 * erreur
      if double >= dy then
        erreur = erreur + dy
        x1 = x1 + sx
      end
      if double <= dx then
        erreur = erreur + dx
        y1 = y1 + sy
      end
    end
  end

  --- Rectangle de `largeur` x `hauteur` pixels dont le coin haut gauche est (x, y) ; plein ou contour d'un pixel.
  function toile.rectangle(x, y, largeur_rect, hauteur_rect, couleur, plein)
    exiger(couleur)
    x, y, largeur_rect, hauteur_rect = arrondi(x), arrondi(y), arrondi(largeur_rect), arrondi(hauteur_rect)
    if largeur_rect < 1 or hauteur_rect < 1 then return end
    local droite, bas = x + largeur_rect - 1, y + hauteur_rect - 1
    if plein then
      remplir(x, y, droite, bas, couleur)
      return
    end
    remplir(x, y, droite, y, couleur)
    remplir(x, bas, droite, bas, couleur)
    remplir(x, y, x, bas, couleur)
    remplir(droite, y, droite, bas, couleur)
  end

  --- Cercle de centre (cx, cy) et de rayon en pixels ; plein ou contour d'un pixel sans trou.
  function toile.cercle(cx, cy, rayon, couleur, plein)
    exiger(couleur)
    cx, cy, rayon = arrondi(cx), arrondi(cy), arrondi(rayon)
    if rayon < 0 then return end
    if plein then
      for dy = math.max(-rayon, 1 - cy), math.min(rayon, hauteur - cy) do
        local demi = arrondi(math.sqrt(rayon * rayon - dy * dy))
        remplir(cx - demi, cy + dy, cx + demi, cy + dy, couleur)
      end
      return
    end
    for d = -rayon, rayon do
      local demi = arrondi(math.sqrt(rayon * rayon - d * d))
      poser(cx - demi, cy + d, couleur)
      poser(cx + demi, cy + d, couleur)
      poser(cx + d, cy - demi, couleur)
      poser(cx + d, cy + demi, couleur)
    end
  end

  --- Écrit la toile sur la cible dont la case (x_case, y_case) reçoit le coin haut gauche ; coupée aux bords de la cible.
  function toile.rendre(cible, x_case, y_case)
    local largeur_cible, hauteur_cible = cible.getSize()
    local premiere = math.max(1, 2 - x_case)
    local derniere = math.min(largeur_cases, largeur_cible - x_case + 1)
    if premiere > derniere then return end
    local sous, caracteres, textes, fonds = {}, {}, {}, {}
    for rangee = 1, hauteur_cases do
      local y = y_case + rangee - 1
      if y >= 1 and y <= hauteur_cible then
        local haut = (rangee - 1) * 3 * largeur
        local nombre = 0
        for case = premiere, derniere do
          local gauche = haut + (case - 1) * 2 + 1
          sous[1], sous[2] = grille[gauche], grille[gauche + 1]
          sous[3], sous[4] = grille[gauche + largeur], grille[gauche + largeur + 1]
          sous[5], sous[6] = grille[gauche + 2 * largeur], grille[gauche + 2 * largeur + 1]
          local caractere, texte, fond_case = coder(sous)
          nombre = nombre + 1
          caracteres[nombre], textes[nombre], fonds[nombre] = caractere, HEXA[texte], HEXA[fond_case]
        end
        cible.setCursorPos(x_case + premiere - 1, y)
        cible.blit(table.concat(caracteres, "", 1, nombre), table.concat(textes, "", 1, nombre),
          table.concat(fonds, "", 1, nombre))
      end
    end
  end

  toile.effacer(fond)
  return toile
end

return pixels
