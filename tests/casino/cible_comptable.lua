-- Cible légère au format term de CC : ne garde pas les cases, compte seulement les caractères écrits hors de la cible
-- (même compte que `faux.moniteur`) et refuse les mêmes couleurs et blit invalides. Pour balayer vite tailles et états.

local cible_comptable = {}

local HEXA = "0123456789abcdef"

local function couleur_valide(couleur)
  for i = 0, 15 do
    if couleur == 2 ^ i then return true end
  end
  return false
end

--- Cible de `largeur` x `hauteur` cases ; champ `debordements` comme `faux.moniteur`.
function cible_comptable.nouvelle(largeur, hauteur)
  local c = { debordements = 0 }
  local x, y = 1, 1

  local function ecrire(nombre)
    for i = 0, nombre - 1 do
      local colonne = x + i
      if colonne < 1 or colonne > largeur or y < 1 or y > hauteur then c.debordements = c.debordements + 1 end
    end
    x = x + nombre
  end

  local function verifier(couleur)
    if not couleur_valide(couleur) then error("couleur invalide : " .. tostring(couleur), 3) end
  end

  function c.getSize() return largeur, hauteur end
  function c.isColor() return true end
  function c.getCursorPos() return x, y end
  function c.setCursorPos(nx, ny) x, y = nx, ny end
  function c.setTextColor(couleur) verifier(couleur) end
  function c.setBackgroundColor(couleur) verifier(couleur) end
  function c.setPaletteColour(couleur) verifier(couleur) end
  function c.clear() end
  function c.write(texte) ecrire(#tostring(texte)) end

  function c.blit(texte, texte_hexa, fond_hexa)
    if #texte ~= #texte_hexa or #texte ~= #fond_hexa then error("blit : longueurs différentes", 2) end
    if (texte_hexa .. fond_hexa):lower():find("[^" .. HEXA .. "]") then error("blit : chiffre hexa invalide", 2) end
    ecrire(#texte)
  end

  return c
end

return cible_comptable
