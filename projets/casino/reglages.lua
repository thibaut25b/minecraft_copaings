-- Réglages par défaut du casino. Les valeurs du monde se changent dans `/casino.cfg`, jamais ici.

return {
  mise_min = 1,          -- plus petite mise (jetons)
  mise_max = 100,        -- plus grande mise, par tour ou par case de roulette (jetons)
  mise_defaut = 10,      -- mise proposée en ouvrant un jeu (ramenée au palier inférieur)
  jeux_blackjack = 6,    -- jeux de 52 cartes dans le sabot du blackjack
  jetons_depart = 500,  -- solde au tout premier lancement
  recharge = 500,        -- jetons gratuits ajoutés par « Recharger »
  inactivite = 90,       -- secondes sans toucher avant le retour au hall
  theme = "nuit",        -- palette : nuit ou ambre
  son = true,            -- notes sur le haut-parleur s'il y en a un
  volume = 1,            -- volume des notes (0 à 3)
  echelle_texte = 0.5,   -- taille du texte du moniteur (0.5 à 5)
  periode_image = 0.07,  -- secondes entre deux images pendant une animation
  -- Vraie monnaie (Lightman's Currency) : voir le README du projet.
  mode = "demo",         -- demo (jetons fictifs) ou monnaie (pièces réelles, crédits)
  depot = "",            -- nom de périphérique du coffre où le joueur dépose ses pièces
  sortie = "",           -- nom de périphérique du coffre où le casino verse les pièces
  reserve = "",          -- nom de périphérique de la réserve du casino (hors de portée des joueurs)
  pieces = {             -- objets reconnus comme pièces ; leur valeur se lit en jeu
    { id = "lightmanscurrency:coin_copper", nom = "cuivre" },
    { id = "lightmanscurrency:coin_iron", nom = "fer" },
    { id = "lightmanscurrency:coin_gold", nom = "or" },
    { id = "lightmanscurrency:coin_emerald", nom = "émeraude" },
    { id = "lightmanscurrency:coin_diamond", nom = "diamant" },
    { id = "lightmanscurrency:coin_netherite", nom = "netherite" },
  },
  type_monnaie = "lightmanscurrency:coins!main", -- clé de lc_money.readInventoryValues pour ces pièces
  mise_min_monnaie = 1,      -- plus petite mise en crédits (1 crédit = la plus petite pièce)
  mise_max_monnaie = 1000,   -- plus grande mise en crédits
  mise_defaut_monnaie = 10,  -- mise proposée en crédits
  periode_depot = 1,     -- secondes entre deux relevés du coffre de dépôt
  periode_valeurs = 60,  -- secondes entre deux lectures des valeurs des pièces
}
