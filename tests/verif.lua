-- Assertions des tests hors jeu. Chaque fonction lève une erreur lisible en cas d'écart.

local verif = {}

local function decrire(valeur, profondeur)
  profondeur = profondeur or 0
  if type(valeur) ~= "table" or profondeur > 4 then
    return type(valeur) == "string" and string.format("%q", valeur) or tostring(valeur)
  end
  local cles = {}
  for cle in pairs(valeur) do cles[#cles + 1] = cle end
  table.sort(cles, function(a, b) return tostring(a) < tostring(b) end)
  local morceaux = {}
  for _, cle in ipairs(cles) do
    morceaux[#morceaux + 1] = tostring(cle) .. "=" .. decrire(valeur[cle], profondeur + 1)
  end
  return "{" .. table.concat(morceaux, ", ") .. "}"
end

local function identiques(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for cle, valeur in pairs(a) do
    if not identiques(valeur, b[cle]) then return false end
  end
  for cle in pairs(b) do
    if a[cle] == nil then return false end
  end
  return true
end

--- Égalité profonde entre la valeur obtenue et la valeur attendue.
function verif.egal(obtenu, attendu, message)
  if not identiques(obtenu, attendu) then
    error((message or "valeurs différentes") .. "\n  attendu : " .. decrire(attendu) .. "\n  obtenu  : " .. decrire(obtenu), 2)
  end
end

function verif.vrai(condition, message)
  if not condition then error(message or "condition fausse", 2) end
end

--- Vérifie que `fonction` lève une erreur dont le message contient `motif` (texte brut).
function verif.erreur(fonction, motif)
  local ok, err = pcall(fonction)
  if ok then error("une erreur était attendue", 2) end
  if motif and not tostring(err):find(motif, 1, true) then
    error("erreur inattendue : " .. tostring(err), 2)
  end
end

return verif
