-- Réglages par défaut de la colonie. Les valeurs du monde se changent dans `/colonie.cfg`, jamais ici.

return {
  periode_fourniture = 30,    -- secondes entre deux passes de fourniture
  periode_affichage = 5,      -- secondes entre deux rafraîchissements du moniteur
  cible_export = "@up",       -- où le pont ME livre : "@côté" du pont (@up, @north...) ou nom d'un inventaire du réseau
  fabriquer = true,           -- lancer l'auto-craft AE2 quand le stock ne suffit pas
  ignorer_equipement = true,  -- laisser outils et armures aux colons
  exclusions = {},            -- noms d'items jamais livrés, * remplace n'importe quoi : "minecraft:*_sapling"
  cote_alarme = "",           -- côté de l'ordinateur mis sous redstone pendant un raid ("" : aucun)
  echelle_texte = 0.5,        -- taille du texte du moniteur (0.5 à 5)
}
