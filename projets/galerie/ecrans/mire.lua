-- Mire de réglage : couleurs, texte accentué, pseudo-pixels, aplats et un élément animé.

local texte = require("commun.texte")

local NOMS_COULEURS = {
  "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray",
  "lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black",
}
local CHIFFRES = "0123456789abcdef"
local LARGEUR_ECHANTILLON = 6
local COLONNE_GAUCHE = 149 -- 128 + bits 1, 4 et 16 : colonne gauche allumée
local IMAGES = 60
local LARGEUR_MIN, HAUTEUR_MIN = 97, 24

local function ecrire(cible, x, y, valeur, couleur, fond)
  cible.setCursorPos(x, y)
  cible.setTextColor(couleur or colors.white)
  cible.setBackgroundColor(fond or colors.black)
  cible.write(valeur)
end

local function dessiner_couleurs(cible)
  for i, nom in ipairs(NOMS_COULEURS) do
    local colonne = 2 + ((i - 1) % 8) * (LARGEUR_ECHANTILLON + 2)
    local ligne = 4 + math.floor((i - 1) / 8) * 3
    local chiffre = CHIFFRES:sub(i, i)
    cible.setCursorPos(colonne, ligne)
    cible.blit(string.rep(" ", LARGEUR_ECHANTILLON), string.rep("0", LARGEUR_ECHANTILLON), string.rep(chiffre, LARGEUR_ECHANTILLON))
    cible.setCursorPos(colonne, ligne + 1)
    cible.blit(string.rep(" ", LARGEUR_ECHANTILLON), string.rep("0", LARGEUR_ECHANTILLON), string.rep(chiffre, LARGEUR_ECHANTILLON))
    ecrire(cible, colonne, ligne + 2, nom:sub(1, LARGEUR_ECHANTILLON + 1), colors.lightGray)
  end
end

local function dessiner_pseudo_pixels(cible)
  for code = 128, 159 do
    local colonne = 2 + (code - 128) * 3
    cible.setCursorPos(colonne, 15)
    cible.setTextColor(colors.yellow)
    cible.setBackgroundColor(colors.gray)
    cible.write(string.char(code) .. " ")
  end
end

local function dessiner_aplats(cible)
  local deux_couleurs = { colors.red, colors.blue }
  for ligne = 0, 5 do
    for colonne = 0, 19 do
      local damier = (ligne + colonne) % 2 + 1
      cible.setCursorPos(2 + colonne, 19 + ligne)
      cible.setTextColor(deux_couleurs[damier])
      cible.setBackgroundColor(deux_couleurs[3 - damier])
      cible.write(string.char(COLONNE_GAUCHE))
    end
  end
  for ligne = 0, 5 do
    cible.setCursorPos(24, 19 + ligne)
    cible.setBackgroundColor(colors.lime)
    cible.write(string.rep(string.char(128), 10))
    cible.setBackgroundColor(colors.green)
    cible.write(string.rep(" ", 10))
  end
end

local function dessiner_mobile(cible, t)
  local sous_colonnes = 2 * 40
  local position = math.floor((t % IMAGES) * (2 * sous_colonnes - 2) / IMAGES)
  if position >= sous_colonnes then position = 2 * sous_colonnes - 2 - position end
  local colonne = 46 + math.floor(position / 2)
  cible.setBackgroundColor(colors.gray)
  cible.setCursorPos(46, 19)
  cible.write(string.rep(" ", 40))
  cible.setCursorPos(46, 20)
  cible.write(string.rep(" ", 40))
  cible.setCursorPos(colonne, 20)
  if position % 2 == 0 then
    cible.setTextColor(colors.orange)
    cible.write(string.char(COLONNE_GAUCHE))
  else
    cible.setTextColor(colors.gray)
    cible.setBackgroundColor(colors.orange)
    cible.write(string.char(COLONNE_GAUCHE))
  end
  ecrire(cible, 46, 22, "image " .. t % IMAGES, colors.lightGray)
end

return {
  nom = "mire",
  titre = "Mire de réglage",
  images = IMAGES,
  dessiner = function(cible, t)
    cible.setBackgroundColor(colors.black)
    cible.clear()
    local largeur, hauteur = cible.getSize()
    if largeur < LARGEUR_MIN or hauteur < HAUTEUR_MIN then
      local message = string.format("Mire : il faut %dx%d cases", LARGEUR_MIN, HAUTEUR_MIN)
      ecrire(cible, 1, 1, message:sub(1, largeur), colors.white)
      return
    end
    ecrire(cible, 2, 2, texte.vers_cc("Mire de réglage : couleurs, texte, pseudo-pixels"), colors.white)
    dessiner_couleurs(cible)
    ecrire(cible, 2, 11, texte.vers_cc("Voilà l'été : garçon, île, où, ÉCOLE, ñ, ü, ½ ; ABC abc 0123 !?"), colors.cyan)
    ecrire(cible, 2, 13, "Pseudo-pixels 128 a 159", colors.lightGray)
    dessiner_pseudo_pixels(cible)
    ecrire(cible, 2, 17, "Damier et aplats (aucune ligne entre cases)", colors.lightGray)
    dessiner_aplats(cible)
    dessiner_mobile(cible, t)
  end,
}
