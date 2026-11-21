-- Faux moniteur au format term de CC : mémorise caractère et couleurs de chaque cellule, compte les débordements.

local couleurs = require("faux.couleurs")

local HEXA = "0123456789abcdef"
local UNIS = { couleurs.white, couleurs.black, couleurs.gray, couleurs.lightGray }

local PALETTE_CC = {
  white = 0xF0F0F0, orange = 0xF2B233, magenta = 0xE57FD8, lightBlue = 0x99B2F2,
  yellow = 0xDEDE6C, lime = 0x7FCC19, pink = 0xF2B2CC, gray = 0x4C4C4C,
  lightGray = 0x999999, cyan = 0x4C99B2, purple = 0xB266E5, blue = 0x3366CC,
  brown = 0x7F664C, green = 0x57A64E, red = 0xCC4C4C, black = 0x111111,
}

local moniteur = {}

local function est_unie(couleur)
  for _, valeur in ipairs(UNIS) do
    if valeur == couleur then return true end
  end
  return false
end

local function est_couleur_cc(couleur)
  for i = 0, 15 do
    if couleur == 2 ^ i then return true end
  end
  return false
end

--- Crée un moniteur `largeur` x `hauteur` ; `en_couleur` vaut true par défaut.
function moniteur.nouveau(largeur, hauteur, en_couleur)
  if en_couleur == nil then en_couleur = true end
  local m = { debordements = 0 }
  local cellules = {}
  local curseur_x, curseur_y = 1, 1
  local texte_couleur, fond_couleur = couleurs.white, couleurs.black

  local function remplir(x1, x2, y)
    for x = x1, x2 do
      cellules[y][x] = { caractere = " ", texte = texte_couleur, fond = fond_couleur }
    end
  end

  local function verifier(couleur)
    if not est_couleur_cc(couleur) then error("couleur invalide : " .. tostring(couleur), 3) end
    if not en_couleur and not est_unie(couleur) then error("couleur non gérée : " .. couleur, 3) end
  end

  local function poser(caractere, texte, fond)
    if curseur_x >= 1 and curseur_x <= largeur and curseur_y >= 1 and curseur_y <= hauteur then
      cellules[curseur_y][curseur_x] = { caractere = caractere, texte = texte, fond = fond }
    else
      m.debordements = m.debordements + 1
    end
    curseur_x = curseur_x + 1
  end

  local palette = {}
  for nom, rvb in pairs(PALETTE_CC) do
    palette[couleurs[nom]] = { math.floor(rvb / 65536) / 255, math.floor(rvb / 256) % 256 / 255, rvb % 256 / 255 }
  end

  for y = 1, hauteur do cellules[y] = {} end
  for y = 1, hauteur do remplir(1, largeur, y) end

  function m.getSize() return largeur, hauteur end
  function m.isColor() return en_couleur end
  function m.getCursorPos() return curseur_x, curseur_y end
  function m.setCursorPos(x, y) curseur_x, curseur_y = x, y end
  function m.setTextColor(couleur) verifier(couleur); texte_couleur = couleur end
  function m.setBackgroundColor(couleur) verifier(couleur); fond_couleur = couleur end

  function m.write(texte)
    texte = tostring(texte)
    for i = 1, #texte do poser(texte:sub(i, i), texte_couleur, fond_couleur) end
  end

  function m.blit(texte, texte_hexa, fond_hexa)
    if #texte ~= #texte_hexa or #texte ~= #fond_hexa then error("blit : longueurs différentes", 2) end
    for i = 1, #texte do
      local t = HEXA:find(texte_hexa:sub(i, i):lower(), 1, true)
      local f = HEXA:find(fond_hexa:sub(i, i):lower(), 1, true)
      if not t or not f then error("blit : chiffre hexa invalide", 2) end
      poser(texte:sub(i, i), 2 ^ (t - 1), 2 ^ (f - 1))
    end
  end

  function m.setPaletteColour(couleur, rouge, vert, bleu)
    if not est_couleur_cc(couleur) then error("couleur invalide : " .. tostring(couleur), 2) end
    if vert == nil then
      rouge, vert, bleu = math.floor(rouge / 65536) % 256 / 255, math.floor(rouge / 256) % 256 / 255, rouge % 256 / 255
    end
    palette[couleur] = { rouge, vert, bleu }
  end

  --- Composantes (r, v, b entre 0 et 1) de la couleur dans la palette posée.
  function m.getPaletteColour(couleur)
    if not est_couleur_cc(couleur) then error("couleur invalide : " .. tostring(couleur), 2) end
    return palette[couleur][1], palette[couleur][2], palette[couleur][3]
  end

  m.setPaletteColor, m.getPaletteColor = m.setPaletteColour, m.getPaletteColour

  function m.clear()
    for y = 1, hauteur do remplir(1, largeur, y) end
  end

  function m.clearLine()
    if curseur_y >= 1 and curseur_y <= hauteur then remplir(1, largeur, curseur_y) end
  end

  --- Texte de la ligne `y`, `largeur` caractères.
  function m.ligne(y)
    local morceaux = {}
    for x = 1, largeur do morceaux[x] = cellules[y][x].caractere end
    return table.concat(morceaux)
  end

  --- Tout l'écran, une ligne par rangée.
  function m.texte()
    local lignes = {}
    for y = 1, hauteur do lignes[y] = m.ligne(y) end
    return table.concat(lignes, "\n")
  end

  function m.couleur_texte(x, y) return cellules[y][x].texte end
  function m.couleur_fond(x, y) return cellules[y][x].fond end

  --- Couleur du pseudo-pixel (x, y), à partir de 1 (2 x 3 par case), lue dans les caractères 128 à 159 ; nil hors cible.
  --- Le sous-pixel bas droit n'a pas de bit : c'est toujours la couleur de fond.
  function m.pixel(x, y)
    local case_x, case_y = math.floor((x - 1) / 2) + 1, math.floor((y - 1) / 3) + 1
    if case_x < 1 or case_x > largeur or case_y < 1 or case_y > hauteur then return nil end
    local case = cellules[case_y][case_x]
    local colonne, rangee = (x - 1) % 2, (y - 1) % 3
    local octet = case.caractere:byte() - 128
    if octet < 0 or octet > 31 then error("pixel : la case n'est pas un pseudo-pixel", 2) end
    if colonne == 1 and rangee == 2 then return case.fond end
    local bit = 2 ^ (rangee * 2 + colonne)
    if math.floor(octet / bit) % 2 == 1 then return case.texte end
    return case.fond
  end

  --- Position (x, y) de la première occurrence du motif (texte brut), ou nil.
  function m.chercher(motif)
    for y = 1, hauteur do
      local x = m.ligne(y):find(motif, 1, true)
      if x then return x, y end
    end
    return nil
  end

  return m
end

return moniteur
