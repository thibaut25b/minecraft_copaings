-- Manifeste d'installation de la colonie : `depot` = chemin dans le dépôt, `ordinateur` = chemin sans « / » initial en jeu.

return {
  nom = "colonie",
  entree = "colonie/principal.lua",
  config = "colonie.cfg",
  fichiers = {
    { depot = "commun/texte.lua", ordinateur = "commun/texte.lua" },
    { depot = "commun/dessin.lua", ordinateur = "commun/dessin.lua" },
    { depot = "commun/config.lua", ordinateur = "commun/config.lua" },
    { depot = "commun/journal.lua", ordinateur = "commun/journal.lua" },
    { depot = "commun/peripheriques.lua", ordinateur = "commun/peripheriques.lua" },
    { depot = "projets/colonie/reglages.lua", ordinateur = "colonie/reglages.lua" },
    { depot = "projets/colonie/requetes.lua", ordinateur = "colonie/requetes.lua" },
    { depot = "projets/colonie/chantiers.lua", ordinateur = "colonie/chantiers.lua" },
    { depot = "projets/colonie/fourniture.lua", ordinateur = "colonie/fourniture.lua" },
    { depot = "projets/colonie/lecture.lua", ordinateur = "colonie/lecture.lua" },
    { depot = "projets/colonie/vues.lua", ordinateur = "colonie/vues.lua" },
    { depot = "projets/colonie/diag.lua", ordinateur = "colonie/diag.lua" },
    { depot = "projets/colonie/principal.lua", ordinateur = "colonie/principal.lua" },
  },
}
