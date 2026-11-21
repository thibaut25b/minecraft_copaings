-- Manifeste de la galerie : `depot` = chemin dans le dépôt, `ordinateur` = chemin sans « / » initial en jeu.

return {
  nom = "galerie",
  entree = "galerie/principal.lua",
  config = "galerie.cfg",
  fichiers = {
    { depot = "commun/texte.lua", ordinateur = "commun/texte.lua" },
    { depot = "commun/dessin.lua", ordinateur = "commun/dessin.lua" },
    { depot = "commun/config.lua", ordinateur = "commun/config.lua" },
    { depot = "commun/peripheriques.lua", ordinateur = "commun/peripheriques.lua" },
    { depot = "commun/pixels.lua", ordinateur = "commun/pixels.lua" },
    { depot = "commun/graphes.lua", ordinateur = "commun/graphes.lua" },
    { depot = "commun/theme.lua", ordinateur = "commun/theme.lua" },
    { depot = "commun/panneaux.lua", ordinateur = "commun/panneaux.lua" },
    { depot = "projets/galerie/reglages.lua", ordinateur = "galerie/reglages.lua" },
    { depot = "projets/galerie/fictif.lua", ordinateur = "galerie/fictif.lua" },
    { depot = "projets/galerie/planche.lua", ordinateur = "galerie/planche.lua" },
    { depot = "projets/galerie/ecrans.lua", ordinateur = "galerie/ecrans.lua" },
    { depot = "projets/galerie/ecrans/usine.lua", ordinateur = "galerie/ecrans/usine.lua" },
    { depot = "projets/galerie/ecrans/colonie.lua", ordinateur = "galerie/ecrans/colonie.lua" },
    { depot = "projets/galerie/ecrans/trains.lua", ordinateur = "galerie/ecrans/trains.lua" },
    { depot = "projets/galerie/ecrans/vitrine.lua", ordinateur = "galerie/ecrans/vitrine.lua" },
    { depot = "projets/galerie/ecrans/vitrine_ambre.lua", ordinateur = "galerie/ecrans/vitrine_ambre.lua" },
    { depot = "projets/galerie/ecrans/mire.lua", ordinateur = "galerie/ecrans/mire.lua" },
    { depot = "projets/galerie/principal.lua", ordinateur = "galerie/principal.lua" },
  },
}
