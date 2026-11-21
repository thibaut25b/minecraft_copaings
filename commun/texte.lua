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

--- Texte au jeu de caractères de CC vers UTF-8 : réciproque exacte de `vers_cc`, pour reconvertir sans perte.
function texte.depuis_cc(octets)
  return (octets:gsub("[\128-\255]", function(octet)
    local code = octet:byte()
    return string.char(192 + math.floor(code / 64), 128 + code % 64)
  end))
end

--- Nombre entier arrondi avec une espace entre les milliers : 12480 donne « 12 480 ».
function texte.milliers(nombre)
  local chiffres = tostring(math.floor(math.abs(nombre) + 0.5))
  local groupes = chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (nombre < 0 and "-" or "") .. groupes
end

--- Quantité accordée : `texte.quantite(1, "jeton")` donne « 1 jeton », 1250 donne « 1 250 jetons » (pluriel dès 2).
function texte.quantite(nombre, nom)
  return texte.milliers(nombre) .. " " .. nom .. (math.abs(nombre) >= 2 and "s" or "")
end

return texte
