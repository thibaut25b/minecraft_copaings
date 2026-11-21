-- Primitives de dessin sur une cible au format term de CC (moniteur ou terminal), sans rien de spécifique à un projet.

local texte_cc = require("commun.texte")

local vers_cc, depuis_cc = texte_cc.vers_cc, texte_cc.depuis_cc

local dessin = {}

local MARQUEUR = "~"
local ECART = 1
local LARGEUR_MIN_FLEXIBLE = 3
local LARGEUR_MIN_ONGLET = 3

-- Une cible sans couleur n'accepte que noir, blanc et deux gris.
local function en_monochrome(texte, fond)
  local unies = { [colors.white] = true, [colors.black] = true, [colors.gray] = true, [colors.lightGray] = true }
  if not unies[fond] then fond = colors.white end
  if fond == colors.white then
    texte = colors.black
  elseif not unies[texte] then
    texte = colors.white
  end
  return texte, fond
end

local function appliquer(cible, texte, fond)
  texte = texte or colors.white
  fond = fond or colors.black
  if not cible.isColor() then texte, fond = en_monochrome(texte, fond) end
  cible.setBackgroundColor(fond)
  cible.setTextColor(texte)
end

-- Écrit un texte déjà converti, coupé aux bords de la cible.
local function ecrire_cc(cible, x, y, texte, couleur, fond)
  local largeur, hauteur = cible.getSize()
  if y < 1 or y > hauteur or x > largeur then return 0 end
  if x < 1 then
    texte = texte:sub(2 - x)
    x = 1
  end
  texte = texte:sub(1, largeur - x + 1)
  if texte == "" then return 0 end
  appliquer(cible, couleur, fond)
  cible.setCursorPos(x, y)
  cible.write(texte)
  return #texte
end

local function couper(texte, largeur, marqueur)
  if largeur <= 0 then return "" end
  if #texte <= largeur then return texte end
  if largeur <= #marqueur then return marqueur:sub(1, largeur) end
  return texte:sub(1, largeur - #marqueur) .. marqueur
end

local function ajuster(texte, largeur, alignement)
  texte = couper(texte, largeur, MARQUEUR)
  local reste = largeur - #texte
  if reste <= 0 then return texte end
  if alignement == "droite" then return string.rep(" ", reste) .. texte end
  if alignement == "centre" then
    local gauche = math.floor(reste / 2)
    return string.rep(" ", gauche) .. texte .. string.rep(" ", reste - gauche)
  end
  return texte .. string.rep(" ", reste)
end

--- Efface toute la cible avec la couleur de fond (noir par défaut).
function dessin.effacer(cible, fond)
  appliquer(cible, colors.white, fond)
  cible.clear()
  cible.setCursorPos(1, 1)
end

--- Écrit `texte` en (x, y), coupé aux bords de la cible ; renvoie le nombre de caractères écrits.
function dessin.ecrire(cible, x, y, texte, couleur, fond)
  return ecrire_cc(cible, x, y, vers_cc(texte), couleur, fond)
end

--- Coupe `texte` à `largeur` caractères en finissant par le marqueur (« ~ » par défaut) ; le résultat reste en
--- UTF-8, prêt pour `dessin.ecrire`.
function dessin.tronquer(texte, largeur, marqueur)
  return depuis_cc(couper(vers_cc(texte), largeur, vers_cc(marqueur or MARQUEUR)))
end

--- Texte coupé puis complété d'espaces pour faire exactement `largeur` ; alignement "gauche", "droite" ou "centre".
--- Le résultat reste en UTF-8, prêt pour `dessin.ecrire`.
function dessin.aligner(texte, largeur, alignement)
  return depuis_cc(ajuster(vers_cc(texte), largeur, alignement))
end

--- Barre horizontale de `largeur` cases ; `ratio` borné à 0..1 (nil ou invalide compte pour 0).
function dessin.barre(cible, x, y, largeur, ratio, couleur, fond)
  if type(ratio) ~= "number" or ratio ~= ratio then ratio = 0 end
  ratio = math.max(0, math.min(1, ratio))
  local pleines = math.floor(ratio * largeur + 0.5)
  ecrire_cc(cible, x, y, string.rep(" ", pleines), nil, couleur)
  ecrire_cc(cible, x + pleines, y, string.rep(" ", largeur - pleines), nil, fond or colors.gray)
end

-- Colonnes retenues pour `largeur` cases, avec leur décalage et leur largeur. Les colonnes `facultatif` tombent en
-- premier (de droite à gauche), puis les autres ; la première colonne reste toujours. Une colonne flexible reçoit son
-- `min` puis une part égale du reste.
local function minimum(colonne)
  return colonne.min or LARGEUR_MIN_FLEXIBLE
end

local function repartir(colonnes, largeur)
  local retenues = {}
  for indice, colonne in ipairs(colonnes) do
    retenues[indice] = { colonne = colonne, indice = indice }
  end
  local function tient()
    local total = ECART * (#retenues - 1)
    for _, retenue in ipairs(retenues) do total = total + (retenue.colonne.largeur or minimum(retenue.colonne)) end
    return total <= largeur
  end
  while #retenues > 1 and not tient() do
    local retire = #retenues
    for i = #retenues, 2, -1 do
      if retenues[i].colonne.facultatif then
        retire = i
        break
      end
    end
    table.remove(retenues, retire)
  end
  local fixes, flexibles = ECART * (#retenues - 1), {}
  for _, retenue in ipairs(retenues) do
    if retenue.colonne.largeur then
      retenue.largeur = retenue.colonne.largeur
      fixes = fixes + retenue.largeur
    else
      flexibles[#flexibles + 1] = retenue
    end
  end
  if #flexibles > 0 then
    local reste = largeur - fixes
    for _, retenue in ipairs(flexibles) do reste = reste - minimum(retenue.colonne) end
    reste = math.max(0, reste)
    local base = math.floor(reste / #flexibles)
    for _, retenue in ipairs(flexibles) do retenue.largeur = minimum(retenue.colonne) + base end
    flexibles[1].largeur = flexibles[1].largeur + reste - base * #flexibles
  end
  local decalage = 0
  for _, retenue in ipairs(retenues) do
    retenue.largeur = math.min(retenue.largeur, largeur)
    retenue.decalage = decalage
    decalage = decalage + retenue.largeur + ECART
  end
  return retenues
end

--- Tableau en (x, y) sur `largeur` x `hauteur` : titres puis lignes. `colonnes` = { { titre, largeur (nil : flexible),
--- min (des flexibles), alignement, facultatif } } ; une cellule est un texte ou { texte, couleur, fond } (avec `fond`,
--- c'est une pastille centrée). `options` : fond (du tableau), zebre (fond d'une ligne sur deux). Ce qui ne tient pas
--- en hauteur est remplacé par « + N autres ». Renvoie le nombre de lignes affichées et le nombre de lignes restantes.
function dessin.tableau(cible, x, y, largeur, hauteur, colonnes, lignes, options)
  options = options or {}
  local fond = options.fond
  if hauteur < 1 or largeur < 1 then return 0, #lignes end
  local mises = repartir(colonnes, largeur)
  for _, mise in ipairs(mises) do
    local titre = ajuster(vers_cc(mise.colonne.titre), mise.largeur, mise.colonne.alignement)
    ecrire_cc(cible, x + mise.decalage, y, titre, colors.lightGray, fond)
  end
  local capacite = hauteur - 1
  local affichees = #lignes
  if affichees > capacite then affichees = math.max(0, capacite - 1) end
  for i = 1, affichees do
    local fond_ligne = fond
    if options.zebre and i % 2 == 0 then
      fond_ligne = options.zebre
      ecrire_cc(cible, x, y + i, string.rep(" ", largeur), nil, fond_ligne)
    end
    for _, mise in ipairs(mises) do
      local cellule = lignes[i][mise.indice]
      local texte, couleur, fond_cellule, alignement = cellule, nil, nil, mise.colonne.alignement
      if type(cellule) == "table" then texte, couleur, fond_cellule = cellule.texte, cellule.couleur, cellule.fond end
      if fond_cellule then alignement = "centre" end
      local ajuste = ajuster(vers_cc(texte), mise.largeur, alignement)
      ecrire_cc(cible, x + mise.decalage, y + i, ajuste, couleur, fond_cellule or fond_ligne)
    end
  end
  local restantes = #lignes - affichees
  if restantes > 0 and capacite >= 1 then
    ecrire_cc(cible, x, y + affichees + 1, couper(string.format("+ %d autres", restantes), largeur, MARQUEUR),
      colors.lightGray, fond)
  end
  return affichees, restantes
end

--- Zones cliquables d'une rangée d'onglets `{ nom, libelle }` sur `largeur` cases : liste de { nom, libelle, x1, x2, y }.
--- Les libellés raccourcissent quand la rangée est trop large ; les onglets sans place sont omis.
function dessin.zones_onglets(x, y, largeur, onglets)
  local libelles, largeurs = {}, {}
  local total = ECART * (#onglets - 1)
  for i, onglet in ipairs(onglets) do
    libelles[i] = vers_cc(onglet.libelle)
    largeurs[i] = #libelles[i] + 2
    total = total + largeurs[i]
  end
  while total > largeur do
    local plus = 1
    for i = 2, #largeurs do
      if largeurs[i] > largeurs[plus] then plus = i end
    end
    if largeurs[plus] <= LARGEUR_MIN_ONGLET then break end
    largeurs[plus] = largeurs[plus] - 1
    total = total - 1
  end
  local zones, position = {}, x
  for i, onglet in ipairs(onglets) do
    local fin = math.min(position + largeurs[i] - 1, x + largeur - 1)
    if fin - position + 1 < LARGEUR_MIN_ONGLET then break end
    zones[#zones + 1] = { nom = onglet.nom, libelle = libelles[i], x1 = position, x2 = fin, y = y }
    position = position + largeurs[i] + ECART
  end
  return zones
end

--- Dessine la rangée d'onglets (celui dont le nom est `actif` en clair) et renvoie ses zones cliquables.
function dessin.onglets(cible, x, y, largeur, onglets, actif)
  local zones = dessin.zones_onglets(x, y, largeur, onglets)
  for _, zone in ipairs(zones) do
    local taille = zone.x2 - zone.x1 + 1
    local texte = ajuster(" " .. couper(zone.libelle, taille - 2, MARQUEUR) .. " ", taille, "gauche")
    if zone.nom == actif then
      ecrire_cc(cible, zone.x1, y, texte, colors.black, colors.white)
    else
      ecrire_cc(cible, zone.x1, y, texte, colors.white, colors.gray)
    end
  end
  return zones
end

--- Nom de l'onglet qui contient le point (x, y), ou nil.
function dessin.onglet_sous_point(zones, x, y)
  for _, zone in ipairs(zones) do
    if y == zone.y and x >= zone.x1 and x <= zone.x2 then return zone.nom end
  end
  return nil
end

return dessin
