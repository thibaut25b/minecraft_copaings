-- Historique du stress de chaque réseau, en mémoire seulement : les dernières mesures pour la courbe.

local historique = {}

--- Ajoute à `courbes[nom]` le stress de chaque réseau lisible de `mesures` ({ [nom] = { stress } }), en gardant au
--- plus `points` valeurs par réseau. Un réseau illisible n'ajoute rien.
function historique.noter(courbes, mesures, points)
  for nom, mesure in pairs(mesures) do
    if type(mesure) == "table" and type(mesure.stress) == "number" then
      local valeurs = courbes[nom] or {}
      valeurs[#valeurs + 1] = mesure.stress
      while #valeurs > points do table.remove(valeurs, 1) end
      courbes[nom] = valeurs
    end
  end
end

return historique
