-- Action sur les relais redstone : réaffirme à chaque passe la sortie de chaque ligne.

local peripheriques = require("commun.peripheriques")

local action = {}

--- Niveau de la sortie redstone d'une ligne : `signal_coupe` à l'arrêt, son contraire en marche.
function action.valeur(ligne, marche)
  if marche then return not ligne.signal_coupe end
  return ligne.signal_coupe
end

--- Pose sur le relais de chaque ligne la valeur de sa sortie (`sorties[i].marche`). Renvoie les messages d'erreur,
--- un par ligne en défaut ; les autres lignes sont servies quand même.
function action.appliquer(lignes, sorties)
  local erreurs = {}
  for i, ligne in ipairs(lignes) do
    local prefixe = "Ligne " .. ligne.nom .. " : relais " .. ligne.relais
    local relais = peripheriques.par_nom(ligne.relais)
    if not relais then
      erreurs[#erreurs + 1] = prefixe .. " introuvable"
    elseif type(relais.setOutput) ~= "function" then
      erreurs[#erreurs + 1] = prefixe .. " : pas un relais redstone de ComputerCraft"
    else
      local ok, message = peripheriques.appel(relais, "setOutput", ligne.cote, action.valeur(ligne, sorties[i].marche))
      if not ok then erreurs[#erreurs + 1] = prefixe .. " : " .. tostring(message) end
    end
  end
  return erreurs
end

return action
