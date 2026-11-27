-- Réglages par défaut du suivi de production. Les valeurs du monde se changent dans `/production.cfg`, jamais ici.

return {
  periode = 10,              -- secondes entre deux mesures (2 à 60)
  echelle_texte = 0.5,       -- taille du texte du moniteur (0.5 à 5)
  theme = "nuit",            -- palette du tableau de bord : "nuit" ou "ambre"
  unite = "min",             -- unité de débit affichée au départ : "s", "min" ou "h"
  tout = true,               -- true : tout le réseau ; false : seulement les objets suivis (config et coffre)
  consommation = true,       -- false : aucun chiffre de consommation ni de net, ni alerte
  fenetre = 600,             -- secondes de la fenêtre de débit au départ : 60, 600 ou 3600
  sens = "prod",             -- tri au départ : "prod" (production), "bilan" (|net|) ou "conso" (consommation)
  exclure = {},              -- ids écartés, ou préfixes finissant par « : » (tout un mod) : { "minecraft:dirt", "ae2:" }
  debit_mini = 0,            -- items/min en dessous desquels une ligne est masquée
  seuil_coupure = 0.2,       -- part de types disparus ou apparus, ou de chute du total, qui signale un lecteur déchargé
  delai_aller_retour = 30,   -- secondes pendant lesquelles une baisse peut être remboursée par un retour (0 : jamais)
  delai_alerte = 3600,       -- secondes avant rupture en dessous desquelles un objet est en alerte
  pont = "",                 -- nom réseau du ME Bridge ("" : le premier trouvé)
  coffre = "",               -- côté ou nom réseau du coffre modèle ("" : pas de coffre ; jamais deviné)
  -- Objets suivis, avant ceux du coffre modèle : { objet = "minecraft:iron_ingot", nom = "", nbt = "" }.
  -- nom = "" : le nom affiché lu dans l'AE, à défaut l'identifiant. nbt absent : toutes les variantes de l'id ;
  -- nbt = "" : la variante sans composants ; sinon le champ nbt lu par diag.
  objets = {},
}
