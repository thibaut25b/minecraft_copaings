-- Conversion de texte pour l'affichage CC : les sources sont en UTF-8, CC affiche un octet par caractère.

local texte = {}

--- Texte UTF-8 vers le jeu de caractères de CC (Latin-1 pour U+0080 à U+00FF, "?" au-delà).
function texte.vers_cc(valeur)
  return (tostring(valeur or ""):gsub("[\194-\244][\128-\191]+", function(sequence)
    local tete, suite = sequence:byte(1, 2)
    if #sequence == 2 and tete <= 195 then return string.char((tete - 194) * 64 + suite) end
    return "?"
  end))
end

return texte
