-- Faux moniteur au format term de CC : mémorise caractère et couleurs de chaque cellule, compte les débordements.

local couleurs = require("faux.couleurs")

local HEXA = "0123456789abcdef"
local UNIS = { couleurs.white, couleurs.black, couleurs.gray, couleurs.lightGray }

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
      local t = HEXA:find(texte_hexa:sub(i, i), 1, true)
      local f = HEXA:find(fond_hexa:sub(i, i), 1, true)
      poser(texte:sub(i, i), 2 ^ (t - 1), 2 ^ (f - 1))
    end
  end

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
