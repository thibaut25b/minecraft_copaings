-- Les briques de panneaux répartissent exactement, ne débordent pas et dessinent les tuiles et barres empilées.

colors = require("faux.couleurs")

local verif = require("verif")
local panneaux = require("commun.panneaux")
local moniteur = require("faux.moniteur")

local function somme(liste)
  local total = 0
  for _, valeur in ipairs(liste) do total = total + valeur end
  return total
end

return {
  decouper_donne_des_longueurs_dont_la_somme_est_exacte = function()
    verif.egal(panneaux.decouper(10, { 1, 1, 1 }), { 4, 3, 3 })
    verif.egal(somme(panneaux.decouper(37, { 8, 1, 2, 2, 2, 1 })), 37)
  end,

  decouper_a_l_echelle_d_un_total_laisse_le_reste_vide = function()
    verif.egal(panneaux.decouper(20, { 5, 5 }, 20), { 5, 5 })
    verif.egal(panneaux.decouper(10, { 0, 0 }, 0), { 0, 0 })
  end,

  une_petite_valeur_garde_au_moins_une_case = function()
    local tailles = panneaux.decouper(10, { 1000, 1 })
    verif.egal(tailles[2], 1)
    verif.egal(somme(tailles), 10)
  end,

  barre_empilee_ne_deborde_pas_et_garde_ses_couleurs = function()
    local m = moniteur.nouveau(12, 2)
    panneaux.barre_empilee(m, { x = 1, y = 1, largeur = 12, hauteur = 1 }, { { 6, colors.lime }, { 3, colors.red } },
      12)
    verif.egal(m.debordements, 0)
    verif.egal(m.pixel(1, 1), colors.lime)
    verif.egal(m.pixel(13, 1), colors.red)
    verif.egal(m.pixel(23, 1), colors.brown, "le reste du total en vide")
    verif.egal(m.pixel(1, 3), colors.gray, "la dernière rangée de pixels reste au fond")
  end,

  tuile_porte_titre_valeur_et_note_sans_deborder = function()
    local m = moniteur.nouveau(30, 6)
    panneaux.tuile(m, 1, 1, 30, 5, "Logés", "20/23", "3 sans maison", 20 / 23, colors.yellow)
    verif.egal(m.debordements, 0)
    verif.vrai(m.chercher("Log\233s"))
    local x, y = m.chercher("20/23")
    verif.egal(m.couleur_texte(x, y), colors.yellow)
    verif.vrai(m.chercher("3 sans maison"))
  end,

  interieur_du_panneau_est_celui_que_rend_le_dessin = function()
    local m = moniteur.nouveau(20, 10)
    verif.egal(panneaux.panneau(m, 2, 3, 15, 6, "Titre"), panneaux.interieur(2, 3, 15, 6))
  end,
}
