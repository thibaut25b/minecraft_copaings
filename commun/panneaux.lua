-- Mise en page de tableaux de bord : grille, panneaux à titre, bandeau, pastilles, graphiques légendés sur toile.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local pixels = require("commun.pixels")
local texte = require("commun.texte")
local theme = require("commun.theme")

local R = theme.ROLES

local panneaux = {}

local MARQUE = string.char(149) -- colonne gauche de la case allumée : liseré vertical fin
local CARRE = string.char(143)  -- deux rangées du haut allumées : petit carré de légende

-- Texte aligné sur `largeur` cases ; rien si la place manque.
local function ecrire(cible, x, y, largeur, valeur, alignement, couleur, fond)
  if largeur < 1 then return end
  dessin.ecrire(cible, x, y, dessin.aligner(valeur, largeur, alignement), couleur, fond)
end

--- Nombre de cases qu'occupe `valeur` une fois converti pour CC.
function panneaux.longueur(valeur)
  return #texte.vers_cc(valeur)
end

--- Nombre entier arrondi avec une espace entre les milliers : 12480 donne « 12 480 ».
function panneaux.milliers(nombre)
  local chiffres = tostring(math.floor(math.abs(nombre) + 0.5))
  local groupes = chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (nombre < 0 and "-" or "") .. groupes
end

--- Découpe `taille` cases à partir de `debut` en morceaux proportionnels à `poids`, séparés de `ecart` cases :
--- liste de { debut, taille } dont les bords tombent sur des cases entières et dont la somme est exacte.
function panneaux.repartir(debut, taille, poids, ecart)
  local total = 0
  for _, poids_morceau in ipairs(poids) do total = total + poids_morceau end
  local utile = taille - ecart * (#poids - 1)
  local morceaux, cumul, precedent = {}, 0, 0
  for i, poids_morceau in ipairs(poids) do
    cumul = cumul + poids_morceau
    local bord = math.floor(utile * cumul / total + 0.5)
    morceaux[i] = { debut = debut + precedent + ecart * (i - 1), taille = bord - precedent }
    precedent = bord
  end
  return morceaux
end

--- Remplit de `couleur` le rectangle de cases (x, y, largeur, hauteur), coupé aux bords de la cible.
function panneaux.rectangle(cible, x, y, largeur, hauteur, couleur)
  if largeur < 1 then return end
  local vide = string.rep(" ", largeur)
  for rangee = y, y + hauteur - 1 do dessin.ecrire(cible, x, rangee, vide, couleur, couleur) end
end

--- Zone intérieure { x, y, largeur, hauteur } du panneau posé en (x, y, largeur, hauteur) : alignée sur le titre,
--- une rangée vide sous le titre, marge d'une case en bas.
function panneaux.interieur(x, y, largeur, hauteur)
  return { x = x + 2, y = y + 2, largeur = largeur - 4, hauteur = hauteur - 3 }
end

--- Panneau sur la surface : liseré d'accent, `titre`, `annotation` discrète à droite si elle tient.
--- Renvoie sa zone intérieure (voir `panneaux.interieur`).
function panneaux.panneau(cible, x, y, largeur, hauteur, titre, annotation)
  panneaux.rectangle(cible, x, y, largeur, hauteur, R.surface)
  dessin.ecrire(cible, x, y, MARQUE, R.accent, R.surface)
  local place = largeur - 3
  local longueur_titre = math.min(panneaux.longueur(titre), place)
  ecrire(cible, x + 2, y, longueur_titre, titre, "gauche", R.texte, R.surface)
  if annotation then
    local longueur_note = panneaux.longueur(annotation)
    if longueur_titre + 2 + longueur_note <= place then
      ecrire(cible, x + largeur - 1 - longueur_note, y, longueur_note, annotation, "gauche", R.discret, R.surface)
    end
  end
  return panneaux.interieur(x, y, largeur, hauteur)
end

--- Tuile de mesure : panneau `titre`, `valeur` en `couleur` suivie de `note` discrète, barre fine à `ratio` dessous
--- (sans barre si `ratio` est nil).
function panneaux.tuile(cible, x, y, largeur, hauteur, titre, valeur, note, ratio, couleur)
  local zone = panneaux.panneau(cible, x, y, largeur, hauteur, titre)
  if zone.hauteur < 1 or zone.largeur < 1 then return end
  local ecrit = dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer(valeur, zone.largeur), couleur, R.surface)
  if note and zone.largeur - ecrit - 1 >= 4 then
    dessin.ecrire(cible, zone.x + ecrit + 1, zone.y, dessin.tronquer(note, zone.largeur - ecrit - 1), R.discret,
      R.surface)
  end
  if ratio and zone.hauteur >= 2 then panneaux.barre_fine(cible, zone.x, zone.y + 1, zone.largeur, ratio, couleur) end
end

--- Bandeau de titre sur la première rangée : `titre`, `sous_titre` discret, puis `segments` { { texte, couleur } }
--- calés à droite (horloge, date) ; ce qui ne tient pas est omis, la droite d'abord.
function panneaux.bandeau(cible, titre, sous_titre, segments)
  local largeur = cible.getSize()
  panneaux.rectangle(cible, 1, 1, largeur, 1, R.surface)
  dessin.ecrire(cible, 1, 1, MARQUE, R.accent, R.surface)
  local fin_gauche = 2 + dessin.ecrire(cible, 3, 1, dessin.tronquer(titre, largeur - 3), R.texte, R.surface)
  if sous_titre then
    local place = largeur - fin_gauche - 3
    if place >= 4 then
      fin_gauche = fin_gauche + 2 + dessin.ecrire(cible, fin_gauche + 3, 1, dessin.tronquer(sous_titre, place),
        R.discret, R.surface)
    end
  end
  local droite = largeur - 1
  for i = #segments, 1, -1 do
    local longueur = panneaux.longueur(segments[i][1])
    if droite - longueur < fin_gauche + 2 then return end
    ecrire(cible, droite - longueur + 1, 1, longueur, segments[i][1], "gauche", segments[i][2], R.surface)
    droite = droite - longueur - 2
  end
end

--- Pastille d'état : `libelle` centré sur un aplat `couleur`, en `encre` (le fond du thème par défaut), sur
--- `largeur` cases (libellé plus deux par défaut). Renvoie la largeur occupée.
function panneaux.pastille(cible, x, y, libelle, couleur, largeur, encre)
  largeur = largeur or panneaux.longueur(libelle) + 2
  ecrire(cible, x, y, largeur, libelle, "centre", encre or R.fond, couleur)
  return largeur
end

--- Petit carré de couleur suivi de `libelle` (en `encre`, le texte du thème par défaut) : entrée de légende ou état
--- discret dans une liste. Renvoie la largeur occupée.
function panneaux.legende(cible, x, y, couleur, libelle, fond, encre)
  dessin.ecrire(cible, x, y, CARRE, couleur, fond or R.surface)
  return 2 + dessin.ecrire(cible, x + 2, y, libelle, encre or R.texte, fond or R.surface)
end

--- Libellés discrets à gauche, valeurs calées à droite : `paires` { { libelle, valeur, couleur } }, centrées en
--- hauteur dans `zone`, une rangée vide entre deux quand la place le permet.
function panneaux.paires(cible, zone, paires, fond)
  fond = fond or R.surface
  local pas = zone.hauteur >= 2 * #paires - 1 and 2 or 1
  local haut = zone.y + math.max(0, math.floor((zone.hauteur - (pas * (#paires - 1) + 1)) / 2))
  for i, paire in ipairs(paires) do
    local y = haut + (i - 1) * pas
    if y >= zone.y + zone.hauteur then return end
    local longueur = math.min(panneaux.longueur(paire[2]), zone.largeur)
    ecrire(cible, zone.x + zone.largeur - longueur, y, longueur, paire[2], "droite", paire[3] or R.texte, fond)
    ecrire(cible, zone.x, y, math.min(panneaux.longueur(paire[1]), zone.largeur - longueur - 1), paire[1], "gauche",
      R.discret, fond)
  end
end

--- Longueurs entières des `valeurs` mises bout à bout sur `longueur`, à l'échelle de `total` (la somme des valeurs
--- au moins) : au plus fort reste, somme exacte, et une valeur non nulle reçoit au moins 1 tant qu'il en reste.
function panneaux.decouper(longueur, valeurs, total)
  local somme = 0
  for _, valeur in ipairs(valeurs) do somme = somme + math.max(0, valeur) end
  total = math.max(total or somme, somme)
  local pleines = total > 0 and math.floor(longueur * somme / total + 0.5) or 0
  local tailles, restes, utilisees = {}, {}, 0
  for i, valeur in ipairs(valeurs) do
    local exacte = total > 0 and longueur * math.max(0, valeur) / total or 0
    tailles[i] = math.floor(exacte)
    restes[i] = exacte > 0 and tailles[i] == 0 and 2 or exacte - tailles[i]
    utilisees = utilisees + tailles[i]
  end
  while utilisees < pleines do
    local meilleure
    for i = 1, #valeurs do
      if restes[i] > 0 and (not meilleure or restes[i] > restes[meilleure]) then meilleure = i end
    end
    if not meilleure then break end
    tailles[meilleure], restes[meilleure], utilisees = tailles[meilleure] + 1, 0, utilisees + 1
  end
  return tailles
end

--- Barre empilée sur `zone` : `parts` { { valeur, couleur } } bout à bout à l'échelle de `total`, en cases entières
--- (voir `panneaux.decouper`), le reste en `vide` (la bordure par défaut), sur `fond` (la surface par défaut). La
--- dernière rangée de pixels reste vide : deux barres l'une sous l'autre ne se touchent pas.
function panneaux.barre_empilee(cible, zone, parts, total, vide, fond)
  local valeurs = {}
  for i, part in ipairs(parts) do valeurs[i] = part[1] end
  local tailles = panneaux.decouper(zone.largeur, valeurs, total)
  panneaux.toile(cible, zone, fond or R.surface, function(toile, lpx, hpx)
    toile.rectangle(1, 1, lpx, hpx - 1, vide or R.bordure, true)
    local x = 1
    for i, taille in ipairs(tailles) do
      if taille > 0 then toile.rectangle(x, 1, 2 * taille, hpx - 1, parts[i][2], true) end
      x = x + 2 * taille
    end
  end)
end

--- Toile de pixels qui couvre `zone` (en cases), remplie de `fond`, passée à `peindre(toile, largeur_px, hauteur_px)`
--- puis rendue sur la cible. Le texte se pose ensuite par-dessus, aux cases données par `panneaux.case`.
function panneaux.toile(cible, zone, fond, peindre)
  if zone.largeur < 1 or zone.hauteur < 1 then return end
  local toile = pixels.creer(zone.largeur, zone.hauteur, fond)
  peindre(toile, toile.taille())
  toile.rendre(cible, zone.x, zone.y)
end

--- Case de la cible qui contient le pixel (px, py) d'une toile posée sur `zone`.
function panneaux.case(zone, px, py)
  return zone.x + math.floor((math.floor(px + 0.5) - 1) / 2), zone.y + math.floor((math.floor(py + 0.5) - 1) / 3)
end

--- Barre fine (un pixel de haut, au milieu de la case) de `largeur` cases, au demi-case près ; `ratio` borné à 0..1.
function panneaux.barre_fine(cible, x, y, largeur, ratio, couleur, couleur_vide, fond)
  panneaux.toile(cible, { x = x, y = y, largeur = largeur, hauteur = 1 }, fond or R.surface, function(toile, lpx)
    if type(ratio) ~= "number" or ratio ~= ratio then ratio = 0 end
    toile.rectangle(1, 2, lpx, 1, couleur_vide or R.bordure, true)
    toile.rectangle(1, 2, math.floor(math.max(0, math.min(1, ratio)) * lpx + 0.5), 1, couleur, true)
  end)
end

-- Rangée de pixel d'une valeur dans un cadre de courbe, comme la place graphes.courbe.
local function rangee_valeur(cadre, valeur, bas, haut)
  local part = haut > bas and math.max(0, math.min(1, (valeur - bas) / (haut - bas))) or 0.5
  return cadre.y + cadre.hauteur - 1 - math.floor(part * (cadre.hauteur - 1) + 0.5)
end

-- Étiquettes d'abscisse réparties sur la dernière rangée de la zone : la première calée à gauche, la dernière à
-- droite ; une étiquette du milieu qui toucherait une voisine est omise.
local function abscisses(cible, x, y, largeur, etiquettes, fond)
  local nombre = #etiquettes
  local positions = {}
  for i, etiquette in ipairs(etiquettes) do
    local longueur = math.min(panneaux.longueur(etiquette), largeur)
    positions[i] = { x, longueur }
    if nombre > 1 then positions[i][1] = x + math.floor((largeur - longueur) * (i - 1) / (nombre - 1) + 0.5) end
  end
  local fin = x - 2
  for i, etiquette in ipairs(etiquettes) do
    local debut, longueur = positions[i][1], positions[i][2]
    local libre = i == 1 or i == nombre or (debut > fin + 1 and debut + longueur < positions[nombre][1] - 1)
    if libre then
      ecrire(cible, debut, y, longueur, etiquette, "gauche", R.discret, fond)
      fin = debut + longueur - 1
    end
  end
end

--- Courbe légendée dans `zone` (cases). `options` : couleur, remplissage, min, max (obligatoires), fond (surface par
--- défaut), graduations { { valeur, texte } } en pointillés avec leur texte à gauche, repere { valeur, couleur } en
--- tirets, abscisses { texte, ... } sur la dernière rangée.
function panneaux.courbe(cible, zone, valeurs, options)
  local fond = options.fond or R.surface
  local graduations = options.graduations or {}
  local gouttiere = 0
  for _, graduation in ipairs(graduations) do
    gouttiere = math.max(gouttiere, panneaux.longueur(graduation[2]) + 1)
  end
  local bas = options.abscisses and 1 or 0
  local trace = { x = zone.x + gouttiere, y = zone.y, largeur = zone.largeur - gouttiere, hauteur = zone.hauteur - bas }
  if trace.largeur < 2 or trace.hauteur < 1 then return end
  local rangees = {}
  panneaux.toile(cible, trace, fond, function(toile, lpx, hpx)
    local cadre = { x = 1, y = 2, largeur = lpx, hauteur = hpx - 2 }
    for i, graduation in ipairs(graduations) do
      rangees[i] = rangee_valeur(cadre, graduation[1], options.min, options.max)
      for px = 1, lpx, 4 do toile.point(px, rangees[i], R.bordure) end
    end
    graphes.courbe(toile, cadre, valeurs, options)
    if options.repere then
      local py = rangee_valeur(cadre, options.repere.valeur, options.min, options.max)
      for px = 1, lpx, 4 do toile.ligne(px, py, px + 1, py, options.repere.couleur) end
    end
  end)
  for i, graduation in ipairs(graduations) do
    local _, y = panneaux.case(trace, 1, rangees[i])
    ecrire(cible, zone.x, y, gouttiere - 1, graduation[2], "droite", R.discret, fond)
  end
  if options.abscisses then
    abscisses(cible, trace.x, zone.y + zone.hauteur - 1, trace.largeur, options.abscisses, fond)
  end
end

--- Histogramme dans `zone` (cases). `options` : couleur, max, ecart, fond, abscisses comme pour la courbe, et
--- `surligne` = indice d'une barre redessinée en `couleur_surligne`.
function panneaux.histogramme(cible, zone, valeurs, options)
  local fond = options.fond or R.surface
  local bas = options.abscisses and 1 or 0
  local trace = { x = zone.x, y = zone.y, largeur = zone.largeur, hauteur = zone.hauteur - bas }
  if trace.largeur < 1 or trace.hauteur < 1 then return end
  panneaux.toile(cible, trace, fond, function(toile, lpx, hpx)
    local cadre = { x = 1, y = 1, largeur = lpx, hauteur = hpx }
    graphes.histogramme(toile, cadre, valeurs, options)
    if options.surligne then
      local seule, haut = {}, 0
      for i = 1, #valeurs do
        seule[i] = i == options.surligne and valeurs[i] or 0
        haut = math.max(haut, valeurs[i])
      end
      graphes.histogramme(toile, cadre, seule, { couleur = options.couleur_surligne, ecart = options.ecart,
        min = options.min, max = options.max or haut })
    end
  end)
  if options.abscisses then
    abscisses(cible, zone.x, zone.y + zone.hauteur - 1, zone.largeur, options.abscisses, fond)
  end
end

--- Jauge circulaire centrée dans `zone` (cases) : anneau rempli à `ratio` en `couleur`, `valeur` au centre et
--- `libelle` discret dessous s'ils tiennent dans le trou.
function panneaux.jauge(cible, zone, ratio, couleur, valeur, libelle, fond)
  fond = fond or R.surface
  local colonne, ligne = math.floor((zone.largeur - 1) / 2), math.floor((zone.hauteur - 1) / 2)
  local cx, cy = 2 * colonne + 2, 3 * ligne + 2
  local rayon = math.min(cx - 1, 2 * zone.largeur - cx, cy - 1, 3 * zone.hauteur - cy)
  if rayon < 3 then return end
  local epaisseur = math.max(2, math.floor(rayon / 4 + 0.5))
  panneaux.toile(cible, zone, fond, function(toile)
    graphes.anneau(toile, cx, cy, rayon, epaisseur, ratio, couleur, R.bordure)
  end)
  local trou = rayon - epaisseur
  local textes = { { valeur, R.texte }, { libelle, R.discret } }
  for decalage, morceau in ipairs(textes) do
    local longueur = morceau[1] and panneaux.longueur(morceau[1]) or 0
    -- Le coin le plus éloigné du texte (demi-largeur, bord bas de sa rangée) doit rester dans le trou.
    local bord = 3 * (decalage - 1) + 1.5
    if longueur > 0 and (longueur + 0.5) ^ 2 + bord * bord <= trou * trou then
      ecrire(cible, zone.x + colonne - math.floor(longueur / 2) + 1, zone.y + ligne + decalage - 1, longueur,
        morceau[1], "gauche", morceau[2], fond)
    end
  end
end

--- Camembert de `parts` { { valeur, couleur, libelle } } à gauche de `zone`, légende avec valeurs et parts à droite.
function panneaux.secteurs(cible, zone, parts, fond)
  fond = fond or R.surface
  local total = 0
  for _, part in ipairs(parts) do total = total + math.max(0, part[1]) end
  local largeur_disque = math.min(math.floor(1.5 * zone.hauteur) + 1, math.floor(zone.largeur * 0.45),
    zone.largeur - 17)
  if largeur_disque < 3 then return end
  panneaux.toile(cible, { x = zone.x, y = zone.y, largeur = largeur_disque, hauteur = zone.hauteur }, fond,
    function(toile, lpx, hpx)
      graphes.secteurs(toile, lpx / 2 + 0.5, hpx / 2 + 0.5, math.floor((math.min(lpx, hpx) - 1) / 2), parts)
    end)
  local x = zone.x + largeur_disque + 1
  local largeur = zone.largeur - largeur_disque - 1
  local pas = zone.hauteur >= 2 * #parts and 2 or 1
  local haut = zone.y + math.floor((zone.hauteur - pas * #parts + pas - 1) / 2)
  for i, part in ipairs(parts) do
    local y = haut + (i - 1) * pas
    if y >= zone.y + zone.hauteur or largeur < 6 then return end
    local pourcent = total > 0 and math.floor(100 * part[1] / total + 0.5) or 0
    local valeur = math.floor(part[1] + 0.5)
    local chiffre = string.format(largeur >= 24 and "%d  %3d %%" or "%3d %%", largeur >= 24 and valeur or pourcent,
      pourcent)
    dessin.ecrire(cible, x, y, CARRE, part[2], fond)
    ecrire(cible, x + 2, y, largeur - 3 - #chiffre, part[3], "gauche", R.texte, fond)
    ecrire(cible, x + largeur - #chiffre, y, #chiffre, chiffre, "gauche", R.discret, fond)
  end
end

return panneaux
