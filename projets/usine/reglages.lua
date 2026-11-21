-- Réglages par défaut de l'usine. Les valeurs du monde se changent dans `/usine.cfg`, jamais ici.

return {
  periode = 5,               -- secondes entre deux passes de régulation
  echelle_texte = 0.5,       -- taille du texte du moniteur (0.5 à 5)
  theme = "nuit",            -- palette du tableau de bord : "nuit" ou "ambre"
  points_historique = 120,   -- mesures de stress gardées en mémoire pour la courbe
  stock_ticker = "",         -- nom réseau du Stock Ticker ("" : le premier trouvé)
  -- Réseaux cinétiques : { nom = "Nord", stressometre = "Create_Stressometer_0", speedometre = "" (aucun) }.
  -- Liste vide : le premier stressomètre et le premier speedomètre trouvés forment le réseau « Principal ».
  reseaux = {},
  -- Lignes de production : { nom = "Presse", produit = "create:iron_sheet", mini = 500, maxi = 2000,
  --   relais = "redstone_relay_0", cote = "back", signal_coupe = true, reseau = "", priorite = 1 }.
  -- signal_coupe = true : sortie active = ligne arrêtée (embrayage) ; false : sortie active = ligne en marche.
  -- reseau = "" : le premier réseau. priorite : 1 = la plus importante, délestée en dernier.
  lignes = {},
  -- Stocks surveillés en plus des produits des lignes : { nom = "Rails", objet = "create:track", seuil = 200 }.
  stocks = {},
  seuil_delestage = 0.95,    -- stress / capacité à partir duquel une ligne de plus est coupée à chaque passe
  seuil_reprise = 0.80,      -- stress / capacité en dessous duquel une ligne délestée repart à chaque passe
}
