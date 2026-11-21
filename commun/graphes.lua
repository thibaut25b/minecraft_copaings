-- Graphiques dessinés dans une toile de pseudo-pixels (commun.pixels), chacun dans son cadre ou son disque.

local graphes = {}

local atan2 = math.atan2 or math.atan
local DEUX_PI = 2 * math.pi

local function arrondi(nombre)
  return math.floor(nombre + 0.5)
end

-- Cadre { x, y, largeur, hauteur } en entiers.
local function lire_cadre(cadre)
  return math.floor(cadre.x), math.floor(cadre.y), math.floor(cadre.largeur), math.floor(cadre.hauteur)
end

-- Bornes de l'échelle : celles des options, sinon les extrêmes des valeurs (avec 0 si `inclure_zero`).
local function bornes(valeurs, options, inclure_zero)
  local bas, haut = math.huge, -math.huge
  for _, valeur in ipairs(valeurs) do
    bas, haut = math.min(bas, valeur), math.max(haut, valeur)
  end
  if inclure_zero then bas, haut = math.min(bas, 0), math.max(haut, 0) end
  return options.min or bas, options.max or haut
end

-- Position de `valeur` dans l'échelle, bornée à 0..1 ; nil si l'échelle est vide (min >= max).
local function fraction(valeur, bas, haut)
  if haut <= bas then return nil end
  return math.max(0, math.min(1, (valeur - bas) / (haut - bas)))
end

local function ratio_borne(ratio)
  if type(ratio) ~= "number" or ratio ~= ratio then return 0 end
  return math.max(0, math.min(1, ratio))
end

-- Part du tour, de 0 (haut) à 1 (haut de nouveau), dans le sens horaire, du pixel à (dx, dy) du centre.
local function fraction_horaire(dx, dy)
  if dx == 0 and dy == 0 then return 0 end
  local angle = atan2(dx, -dy)
  if angle < 0 then angle = angle + DEUX_PI end
  return angle / DEUX_PI
end

-- Appelle visiteur(x, y, distance2, fraction_horaire) pour chaque pixel du disque (centre compris) qui est dans la toile.
local function parcourir_disque(toile, cx, cy, rayon, visiteur)
  local largeur, hauteur = toile.taille()
  local limite = rayon * rayon + rayon
  for dy = math.max(-rayon, 1 - cy), math.min(rayon, hauteur - cy) do
    for dx = math.max(-rayon, 1 - cx), math.min(rayon, largeur - cx) do
      local distance2 = dx * dx + dy * dy
      if distance2 <= limite then visiteur(cx + dx, cy + dy, distance2, fraction_horaire(dx, dy)) end
    end
  end
end

--- Courbe des `valeurs` (liste, éventuellement vide) sur toute la largeur du cadre ; `remplissage` colore sous la
--- courbe ; échelle `min`..`max` (par défaut les extrêmes) ; des valeurs égales donnent une ligne à mi-hauteur.
function graphes.courbe(toile, cadre, valeurs, options)
  local x, y, largeur, hauteur = lire_cadre(cadre)
  local nombre = #valeurs
  if nombre == 0 or largeur < 1 or hauteur < 1 then return end
  local bas, haut = bornes(valeurs, options, false)
  local pied = y + hauteur - 1
  local hauteurs = {}
  for colonne = 0, largeur - 1 do
    local t = largeur > 1 and colonne * (nombre - 1) / (largeur - 1) or 0
    local indice = math.floor(t)
    local depart = valeurs[indice + 1]
    local valeur = depart + (valeurs[math.min(indice + 2, nombre)] - depart) * (t - indice)
    hauteurs[colonne] = pied - arrondi((fraction(valeur, bas, haut) or 0.5) * (hauteur - 1))
  end
  if options.remplissage then
    for colonne = 0, largeur - 1 do toile.ligne(x + colonne, hauteurs[colonne], x + colonne, pied, options.remplissage) end
  end
  for colonne = 0, largeur - 1 do
    local suivante = math.min(colonne + 1, largeur - 1)
    toile.ligne(x + colonne, hauteurs[colonne], x + suivante, hauteurs[suivante], options.couleur)
  end
end

--- Histogramme des `valeurs` (liste, éventuellement vide), une barre par valeur ; l'échelle inclut 0 par défaut et
--- les barres partent du bas du cadre ; `ecart` pixels entre barres (1 par défaut), nul si le cadre est trop étroit.
function graphes.histogramme(toile, cadre, valeurs, options)
  local x, y, largeur, hauteur = lire_cadre(cadre)
  local nombre = #valeurs
  if nombre == 0 or largeur < 1 or hauteur < 1 then return end
  local bas, haut = bornes(valeurs, options, true)
  local ecart = math.max(0, math.floor(options.ecart or 1))
  local epaisseur = math.floor((largeur - ecart * (nombre - 1)) / nombre)
  if epaisseur < 1 then epaisseur, ecart = math.max(1, math.floor(largeur / nombre)), 0 end
  for i = 1, nombre do
    local gauche = x + (i - 1) * (epaisseur + ecart)
    local droite = math.min(gauche + epaisseur - 1, x + largeur - 1)
    local part = fraction(valeurs[i], bas, haut) or 0
    if gauche <= droite and part > 0 then
      local taille = math.max(1, arrondi(part * hauteur))
      toile.rectangle(gauche, y + hauteur - taille, droite - gauche + 1, taille, options.couleur, true)
    end
  end
end

--- Jauge circulaire : anneau de `epaisseur` pixels, rempli en `couleur` depuis le haut dans le sens horaire sur
--- `ratio` (borné à 0..1, nil compte pour 0) du tour ; le reste en `couleur_fond` si elle est donnée.
function graphes.anneau(toile, cx, cy, rayon, epaisseur, ratio, couleur, couleur_fond)
  cx, cy, rayon, epaisseur = arrondi(cx), arrondi(cy), arrondi(rayon), arrondi(epaisseur)
  ratio = ratio_borne(ratio)
  local interne = rayon - epaisseur
  local limite_interne = interne > 0 and interne * interne + interne or -1
  parcourir_disque(toile, cx, cy, rayon, function(x, y, distance2, part)
    if distance2 <= limite_interne then return end
    if part < ratio then
      toile.point(x, y, couleur)
    elseif couleur_fond then
      toile.point(x, y, couleur_fond)
    end
  end)
end

--- Camembert plein : `parts` = { { valeur, couleur } }, une part par valeur positive, depuis le haut dans le sens horaire.
function graphes.secteurs(toile, cx, cy, rayon, parts)
  local total = 0
  for _, part in ipairs(parts) do total = total + math.max(0, part[1]) end
  if total <= 0 then return end
  local fins, cumul = {}, 0
  for i, part in ipairs(parts) do
    cumul = cumul + math.max(0, part[1])
    fins[i] = cumul / total
  end
  parcourir_disque(toile, arrondi(cx), arrondi(cy), arrondi(rayon), function(x, y, _, fraction_tour)
    for i = 1, #fins do
      if fraction_tour < fins[i] then
        toile.point(x, y, parts[i][2])
        return
      end
    end
  end)
end

return graphes
