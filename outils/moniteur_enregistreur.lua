-- Moniteur enregistreur : cible au format `term` de CC qui garde la grille affichée, pour l'aperçu et l'émulateur.

local moniteur = {}

-- RVB par défaut de CC: Tweaked (tweaked.cc, module colors), dans l'ordre white (indice 0) à black (indice 15).
local PALETTE_DEFAUT = {
  0xF0F0F0, 0xF2B233, 0xE57FD8, 0x99B2F2, 0xDEDE6C, 0x7FCC19, 0xF2B2CC, 0x4C4C4C,
  0x999999, 0x4C99B2, 0xB266E5, 0x3366CC, 0x7F664C, 0x57A64E, 0xCC4C4C, 0x111111,
}
local HEXA = "0123456789abcdef"
local OCTET_HEXA = {}
for octet = 0, 255 do OCTET_HEXA[string.char(octet)] = string.format("%02x", octet) end

-- Numéros de version communs à tous les moniteurs : une cible neuve ne reprend jamais le numéro d'une autre.
local derniere_version = 0
local function nouvelle_version()
  derniere_version = derniere_version + 1
  return derniere_version
end

local function arrondi(valeur)
  return math.floor(valeur + 0.5)
end

--- Indice 0..15 d'une couleur CC (puissance de 2 de 1 à 32768) ; lève une erreur sinon.
local function indice_couleur(couleur)
  local indice, valeur = 0, 1
  while type(couleur) == "number" and valeur < couleur do
    valeur = valeur * 2
    indice = indice + 1
  end
  if valeur ~= couleur or indice > 15 then
    error("Couleur invalide : " .. tostring(couleur), 3)
  end
  return indice
end

local function hexa_valide(couleurs)
  local invalide = couleurs:lower():match("[^0-9a-f]")
  if invalide then error("Couleur blit invalide : " .. invalide, 3) end
  return couleurs:lower()
end

--- Crée un moniteur enregistreur de `largeur` x `hauteur` cases (texte blanc sur fond noir, curseur en 1,1).
function moniteur.creer(largeur, hauteur)
  local cible = {}
  local textes, couleurs_texte, couleurs_fond = {}, {}, {}
  local palette = {}
  local x, y = 1, 1
  local texte_courant, fond_courant = 0, 15
  local echelle = 1
  local clignote = false
  local version = nouvelle_version()

  for i = 1, 16 do
    local rvb = PALETTE_DEFAUT[i]
    palette[i] = { math.floor(rvb / 65536) / 255, math.floor(rvb / 256) % 256 / 255, rvb % 256 / 255 }
  end

  local function hexa(indice) return HEXA:sub(indice + 1, indice + 1) end

  local function vider_ligne(ligne)
    textes[ligne] = string.rep(" ", largeur)
    couleurs_texte[ligne] = string.rep(hexa(texte_courant), largeur)
    couleurs_fond[ligne] = string.rep(hexa(fond_courant), largeur)
  end
  for ligne = 1, hauteur do vider_ligne(ligne) end

  -- Pose `texte` et ses couleurs (chaînes de même longueur) au curseur, coupés aux bords ; le curseur avance.
  local function poser(texte, avant, fond)
    local debut, n = x, #texte
    x = x + n
    if y < 1 or y > hauteur or debut > largeur or debut + n - 1 < 1 then return end
    local premier = math.max(1, 2 - debut)
    local dernier = math.min(n, largeur - debut + 1)
    local a, b = debut + premier - 1, debut + dernier - 1
    local function inserer(ligne, morceau) return ligne:sub(1, a - 1) .. morceau:sub(premier, dernier) .. ligne:sub(b + 1) end
    textes[y] = inserer(textes[y], texte)
    couleurs_texte[y] = inserer(couleurs_texte[y], avant)
    couleurs_fond[y] = inserer(couleurs_fond[y], fond)
    version = nouvelle_version()
  end

  function cible.getSize() return largeur, hauteur end
  function cible.getCursorPos() return x, y end
  function cible.setCursorPos(colonne, ligne)
    x, y = math.floor(colonne), math.floor(ligne)
  end
  function cible.setCursorBlink(actif)
    clignote = actif == true
    version = nouvelle_version()
  end
  function cible.getCursorBlink() return clignote end
  function cible.isColor() return true end
  cible.isColour = cible.isColor

  function cible.setTextScale(valeur)
    if type(valeur) ~= "number" or valeur < 0.5 or valeur > 5 or valeur * 2 % 1 ~= 0 then
      error("Échelle de texte invalide : " .. tostring(valeur), 2)
    end
    echelle = valeur
  end
  function cible.getTextScale() return echelle end

  function cible.write(valeur)
    local chaine = tostring(valeur)
    poser(chaine, string.rep(hexa(texte_courant), #chaine), string.rep(hexa(fond_courant), #chaine))
  end

  function cible.blit(chaine, avant, fond)
    if type(chaine) ~= "string" or type(avant) ~= "string" or type(fond) ~= "string" then
      error("blit attend trois chaînes", 2)
    end
    if #chaine ~= #avant or #chaine ~= #fond then
      error("Les trois arguments de blit doivent avoir la même longueur", 2)
    end
    poser(chaine, hexa_valide(avant), hexa_valide(fond))
  end

  function cible.clear()
    for ligne = 1, hauteur do vider_ligne(ligne) end
    version = nouvelle_version()
  end
  function cible.clearLine()
    if y >= 1 and y <= hauteur then vider_ligne(y) end
    version = nouvelle_version()
  end

  --- Décale le contenu de `n` lignes vers le haut (vers le bas si `n` est négatif) ; les lignes libérées sont vidées.
  function cible.scroll(n)
    n = math.floor(n)
    local anciens = { textes, couleurs_texte, couleurs_fond }
    textes, couleurs_texte, couleurs_fond = {}, {}, {}
    for ligne = 1, hauteur do
      local source = ligne + n
      if source >= 1 and source <= hauteur then
        textes[ligne], couleurs_texte[ligne], couleurs_fond[ligne] = anciens[1][source], anciens[2][source], anciens[3][source]
      else
        vider_ligne(ligne)
      end
    end
    version = nouvelle_version()
  end

  function cible.setTextColor(couleur) texte_courant = indice_couleur(couleur) end
  function cible.setBackgroundColor(couleur) fond_courant = indice_couleur(couleur) end
  function cible.getTextColor() return 2 ^ texte_courant end
  function cible.getBackgroundColor() return 2 ^ fond_courant end
  cible.setTextColour, cible.setBackgroundColour = cible.setTextColor, cible.setBackgroundColor
  cible.getTextColour, cible.getBackgroundColour = cible.getTextColor, cible.getBackgroundColor

  --- Formes `(couleur, r, v, b)` en 0..1 et `(couleur, 0xRRVVBB)`.
  function cible.setPaletteColour(couleur, r, v, b)
    local indice = indice_couleur(couleur)
    if v == nil then
      if type(r) ~= "number" or r < 0 or r > 0xFFFFFF then error("RVB invalide : " .. tostring(r), 2) end
      r, v, b = math.floor(r / 65536) / 255, math.floor(r / 256) % 256 / 255, math.floor(r) % 256 / 255
    end
    for _, composante in ipairs({ r, v, b }) do
      if type(composante) ~= "number" or composante < 0 or composante > 1 then
        error("Composante hors de 0..1 : " .. tostring(composante), 2)
      end
    end
    palette[indice + 1] = { r, v, b }
    version = nouvelle_version()
  end
  function cible.getPaletteColour(couleur)
    local rvb = palette[indice_couleur(couleur) + 1]
    return rvb[1], rvb[2], rvb[3]
  end
  cible.setPaletteColor, cible.getPaletteColor = cible.setPaletteColour, cible.getPaletteColour

  --- Change la taille en cases ; le contenu est gardé, coupé ou complété par des cases vides.
  function cible.redimensionner(nouvelle_largeur, nouvelle_hauteur)
    local ancienne_largeur = largeur
    largeur, hauteur = nouvelle_largeur, nouvelle_hauteur
    for ligne = 1, hauteur do
      if textes[ligne] and largeur <= ancienne_largeur then
        textes[ligne] = textes[ligne]:sub(1, largeur)
        couleurs_texte[ligne] = couleurs_texte[ligne]:sub(1, largeur)
        couleurs_fond[ligne] = couleurs_fond[ligne]:sub(1, largeur)
      elseif textes[ligne] then
        local ajout = largeur - ancienne_largeur
        textes[ligne] = textes[ligne] .. string.rep(" ", ajout)
        couleurs_texte[ligne] = couleurs_texte[ligne] .. string.rep(hexa(texte_courant), ajout)
        couleurs_fond[ligne] = couleurs_fond[ligne] .. string.rep(hexa(fond_courant), ajout)
      else
        vider_ligne(ligne)
      end
    end
    for ligne = hauteur + 1, #textes do textes[ligne], couleurs_texte[ligne], couleurs_fond[ligne] = nil, nil, nil end
    version = nouvelle_version()
  end

  --- Compteur incrémenté à chaque changement visible : l'émulateur ne redessine que s'il a bougé.
  function cible.version() return version end

  --- Ligne `ligne` : octets du texte, chiffres hexa des couleurs de texte, puis de fond.
  function cible.ligne(ligne) return textes[ligne], couleurs_texte[ligne], couleurs_fond[ligne] end

  --- Palette en 96 chiffres hexa (16 x RRVVBB).
  function cible.palette_hexa()
    local morceaux = {}
    for i = 1, 16 do
      local rvb = palette[i]
      morceaux[i] = string.format("%02x%02x%02x", arrondi(rvb[1] * 255), arrondi(rvb[2] * 255), arrondi(rvb[3] * 255))
    end
    return table.concat(morceaux)
  end

  --- Image courante en ASCII : la palette, puis pour chaque ligne les octets du texte (2 chiffres hexa par case),
  --- les couleurs de texte puis de fond (1 chiffre par case).
  function cible.exporter()
    local morceaux = { cible.palette_hexa() }
    for ligne = 1, hauteur do
      morceaux[#morceaux + 1] = textes[ligne]:gsub(".", OCTET_HEXA) .. couleurs_texte[ligne] .. couleurs_fond[ligne]
    end
    return table.concat(morceaux)
  end

  return cible
end

return moniteur
