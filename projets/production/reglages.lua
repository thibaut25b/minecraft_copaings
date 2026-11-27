-- Réglages par défaut du suivi de production. Les valeurs du monde se changent dans `/production.cfg`, jamais ici.

return {
  periode = 2,               -- secondes entre deux mesures
  echelle_texte = 0.5,       -- taille du texte du moniteur (0.5 à 5)
  theme = "nuit",            -- palette du tableau de bord : "nuit" ou "ambre"
  unite = "min",             -- unité de débit affichée au départ : "s", "min" ou "h"
  duree_historique = 3600,   -- secondes de mesures gardées en mémoire
  duree_graphe = 600,        -- secondes couvertes par l'histogramme (au plus duree_historique)
  pont = "",                 -- nom réseau du ME Bridge ("" : le premier trouvé)
  coffre = "",               -- côté ou nom réseau du coffre modèle ("" : pas de coffre ; jamais deviné)
  -- Objets suivis, avant ceux du coffre modèle : { objet = "minecraft:iron_ingot", nom = "" }.
  -- nom = "" : le nom affiché lu dans l'AE, à défaut l'identifiant de l'objet.
  objets = {},
}
