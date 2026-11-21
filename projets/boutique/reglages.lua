-- Réglages par défaut de la boutique. Les valeurs du monde se changent dans `/boutique.cfg`, jamais ici.

return {
  periode = 10,            -- secondes entre deux passes de réassort
  echelle_texte = 0.5,     -- taille du texte du moniteur (0.5 à 5)
  theme = "nuit",          -- palette : nuit ou ambre
  stock_ticker = "",       -- nom du Stock Ticker de l'usine ; "" : le premier trouvé
  adresse = "Boutique",    -- adresse Create où un Frogport ou un Packager déballe les colis dans le tampon
  tampon = "",             -- nom réseau du coffre tampon (obligatoire), par exemple "minecraft:chest_0"
  reserve_defaut = 64,     -- quantité visée dans un comptoir pour tout objet qu'il vend
  delai_commande = 120,    -- secondes avant de recommander ce qui n'est pas arrivé
  -- Facultatif, par objet : reserve (quantité visée), prix (en crédits, réglé sur l'offre), nom (libellé affiché).
  -- Exemple : ["minecraft:iron_ingot"] = { reserve = 128, prix = 12, nom = "Lingot de fer" }
  articles = {},
  piece_de_compte = "lightmanscurrency:coin_copper", -- pièce dont 1 exemplaire vaut 1 crédit
  ventes_gardees = 50,     -- nombre de dernières ventes gardées et affichées
}
