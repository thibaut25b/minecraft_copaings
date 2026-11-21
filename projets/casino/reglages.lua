-- Réglages par défaut du casino. Les valeurs du monde se changent dans `/casino.cfg`, jamais ici.

return {
  mise_min = 1,          -- plus petite mise (jetons)
  mise_max = 100,        -- plus grande mise, par tour ou par case de roulette (jetons)
  jetons_depart = 500,   -- solde au tout premier lancement
  recharge = 500,        -- jetons gratuits ajoutés par « Recharger »
  inactivite = 90,       -- secondes sans toucher avant le retour au hall
  theme = "nuit",        -- palette : nuit ou ambre
  son = true,            -- notes sur le haut-parleur s'il y en a un
  volume = 1,            -- volume des notes (0 à 3)
  echelle_texte = 0.5,   -- taille du texte du moniteur (0.5 à 5)
  periode_image = 0.07,  -- secondes entre deux images pendant une animation
}
