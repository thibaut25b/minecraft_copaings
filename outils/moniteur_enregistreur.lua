-- Moniteur enregistreur : cible au format `term` de CC qui garde la grille affichée, pour l'aperçu hors jeu.

local moniteur = {}

-- RVB par défaut de CC: Tweaked (tweaked.cc, module colors), dans l'ordre white (indice 0) à black (indice 15).
local PALETTE_DEFAUT = {
  0xF0F0F0, 0xF2B233, 0xE57FD8, 0x99B2F2, 0xDEDE6C, 0x7FCC19, 0xF2B2CC, 0x4C4C4C,
  0x999999, 0x4C99B2, 0xB266E5, 0x3366CC, 0x7F664C, 0x57A64E, 0xCC4C4C, 0x111111,
}

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

local function indice_hexa(caractere)
  local indice = tonumber(caractere, 16)
  if not indice then error("Couleur blit invalide : " .. tostring(caractere), 3) end
  return indice
end

--- Crée un moniteur enregistreur de `largeur` x `hauteur` cases (texte blanc sur fond noir, curseur en 1,1).
function moniteur.creer(largeur, hauteur)
  local cible = {}
  local octets, textes, fonds = {}, {}, {}
  local palette = {}
  local x, y = 1, 1
  local texte_courant, fond_courant = 0, 15
  local echelle = 1

  for i = 1, 16 do
    local rvb = PALETTE_DEFAUT[i]
    palette[i] = { math.floor(rvb / 65536) / 255, math.floor(rvb / 256) % 256 / 255, rvb % 256 / 255 }
  end

  local function remplir_ligne(ligne)
    octets[ligne], textes[ligne], fonds[ligne] = {}, {}, {}
    for colonne = 1, largeur do
      octets[ligne][colonne], textes[ligne][colonne], fonds[ligne][colonne] = 32, texte_courant, fond_courant
    end
  end
  for ligne = 1, hauteur do remplir_ligne(ligne) end

  local function poser(colonne, octet, couleur_texte, couleur_fond)
    if colonne >= 1 and colonne <= largeur and y >= 1 and y <= hauteur then
      octets[y][colonne], textes[y][colonne], fonds[y][colonne] = octet, couleur_texte, couleur_fond
    end
  end

  function cible.getSize() return largeur, hauteur end
  function cible.getCursorPos() return x, y end
  function cible.setCursorPos(colonne, ligne)
    x, y = math.floor(colonne), math.floor(ligne)
  end
  function cible.setCursorBlink() end
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
    for i = 1, #chaine do
      poser(x + i - 1, chaine:byte(i), texte_courant, fond_courant)
    end
    x = x + #chaine
  end

  function cible.blit(chaine, couleurs_texte, couleurs_fond)
    if #chaine ~= #couleurs_texte or #chaine ~= #couleurs_fond then
      error("Les trois arguments de blit doivent avoir la même longueur", 2)
    end
    for i = 1, #chaine do
      poser(x + i - 1, chaine:byte(i), indice_hexa(couleurs_texte:sub(i, i)), indice_hexa(couleurs_fond:sub(i, i)))
    end
    x = x + #chaine
  end

  function cible.clear()
    for ligne = 1, hauteur do remplir_ligne(ligne) end
  end
  function cible.clearLine()
    if y >= 1 and y <= hauteur then remplir_ligne(y) end
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
  end
  function cible.getPaletteColour(couleur)
    local rvb = palette[indice_couleur(couleur) + 1]
    return rvb[1], rvb[2], rvb[3]
  end
  cible.setPaletteColor, cible.getPaletteColor = cible.setPaletteColour, cible.getPaletteColour

  --- Image courante en ASCII : 96 chiffres hexa de palette (16 x RRVVBB), puis pour chaque ligne
  --- les octets du texte (2 chiffres hexa par case), les couleurs de texte puis de fond (1 chiffre par case).
  function cible.exporter()
    local morceaux = {}
    for i = 1, 16 do
      local rvb = palette[i]
      morceaux[#morceaux + 1] = string.format("%02x%02x%02x", arrondi(rvb[1] * 255), arrondi(rvb[2] * 255), arrondi(rvb[3] * 255))
    end
    for ligne = 1, hauteur do
      local hexa, couleurs_texte, couleurs_fond = {}, {}, {}
      for colonne = 1, largeur do
        hexa[colonne] = string.format("%02x", octets[ligne][colonne])
        couleurs_texte[colonne] = string.format("%x", textes[ligne][colonne])
        couleurs_fond[colonne] = string.format("%x", fonds[ligne][colonne])
      end
      morceaux[#morceaux + 1] = table.concat(hexa) .. table.concat(couleurs_texte) .. table.concat(couleurs_fond)
    end
    return table.concat(morceaux)
  end

  return cible
end

return moniteur
