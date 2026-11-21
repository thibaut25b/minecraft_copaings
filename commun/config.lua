-- Config persistante d'un projet : réglages du fichier complétés par les défauts, fichier jamais écrasé s'il est fautif.

local config = {}

local function copier(valeur)
  if type(valeur) ~= "table" then return valeur end
  local copie = {}
  for cle, contenu in pairs(valeur) do copie[cle] = copier(contenu) end
  return copie
end

--- Écrit `reglages` dans le fichier. Renvoie `true`, ou `false, message` si l'écriture est impossible.
function config.enregistrer(chemin, reglages)
  local fichier = fs.open(chemin, "w")
  if not fichier then return false, "écriture impossible : " .. chemin end
  fichier.write(textutils.serialize(reglages))
  fichier.close()
  return true
end

--- Renvoie les réglages du fichier complétés par `defauts` (clés inconnues des défauts conservées).
-- Fichier absent : il est créé avec les défauts. Fichier illisible : défauts et message en second retour, fichier intact.
function config.charger(chemin, defauts)
  local reglages = copier(defauts)
  if not fs.exists(chemin) then
    local ok, message = config.enregistrer(chemin, defauts)
    if not ok then return reglages, message end
    return reglages
  end
  local fichier = fs.open(chemin, "r")
  if not fichier then return reglages, "lecture impossible : " .. chemin end
  local texte = fichier.readAll() or ""
  fichier.close()
  local lus = textutils.unserialize(texte)
  if type(lus) ~= "table" then return reglages, "fichier illisible : " .. chemin end
  for cle, valeur in pairs(lus) do reglages[cle] = valeur end
  return reglages
end

return config
