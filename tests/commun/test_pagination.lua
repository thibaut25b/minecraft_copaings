-- La pagination découpe sans perdre de ligne, retombe à la page 1 hors bornes et donne des boutons d'au moins 3 cases.

colors = require("faux.couleurs")

local verif = require("verif")
local pagination = require("commun.pagination")
local moniteur = require("faux.moniteur")

return {
  liste_qui_tient_n_a_pas_de_commande = function()
    verif.egal(pagination.decouper(5, 5, 3), { page = 1, nombre = 1, debut = 1, fin = 5, commande = false })
    verif.egal(pagination.decouper(0, 5, nil), { page = 1, nombre = 1, debut = 1, fin = 0, commande = false })
  end,

  liste_qui_deborde_reserve_une_rangee_a_la_commande = function()
    verif.egal(pagination.decouper(10, 5, 1), { page = 1, nombre = 3, debut = 1, fin = 4, commande = true })
    verif.egal(pagination.decouper(10, 5, 3), { page = 3, nombre = 3, debut = 9, fin = 10, commande = true })
  end,

  toutes_les_lignes_sont_sur_une_page_et_une_seule = function()
    local vues = {}
    local nombre = pagination.decouper(23, 6, 1).nombre
    for page = 1, nombre do
      local decoupe = pagination.decouper(23, 6, page)
      for i = decoupe.debut, decoupe.fin do
        verif.egal(vues[i], nil, "ligne " .. i .. " vue deux fois")
        vues[i] = true
      end
    end
    for i = 1, 23 do verif.vrai(vues[i], "ligne " .. i .. " jamais vue") end
  end,

  page_hors_bornes_ou_absente_retombe_a_un = function()
    for _, demandee in ipairs({ 0, -2, 4, 99, "2", nil }) do
      verif.egal(pagination.decouper(10, 5, demandee).page, 1, tostring(demandee))
    end
  end,

  sans_place_pour_une_commande_on_montre_ce_qui_tient = function()
    verif.egal(pagination.decouper(10, 1, 2), { page = 1, nombre = 1, debut = 1, fin = 1, commande = false })
    verif.egal(pagination.decouper(10, 0, 1).fin, 0)
  end,

  commande_calee_a_droite_avec_des_boutons_qui_bouclent = function()
    local commande = pagination.commande(1, 9, 40, pagination.decouper(10, 5, 1))
    verif.egal(commande.suivant, { x1 = 36, x2 = 40, y = 9, page = 2 })
    verif.egal(commande.precedent.page, 3, "avant la première page vient la dernière")
    verif.egal(commande.texte, "1 / 3")
    verif.egal(pagination.commande(1, 9, 40, pagination.decouper(10, 5, 3)).suivant.page, 1)
  end,

  commande_etroite_garde_des_boutons_de_trois_cases_ou_disparait = function()
    local commande = pagination.commande(1, 1, 13, pagination.decouper(10, 5, 1))
    verif.egal(commande.suivant.x2 - commande.suivant.x1 + 1, 3)
    verif.egal(pagination.commande(1, 1, 12, pagination.decouper(10, 5, 1)), nil)
    verif.egal(pagination.commande(1, 1, 40, pagination.decouper(3, 5, 1)), nil)
  end,

  commande_dessinee_tient_dans_sa_rangee = function()
    local m = moniteur.nouveau(20, 2)
    local commande = pagination.commande(1, 2, 20, pagination.decouper(30, 5, 2))
    pagination.dessiner(m, commande, colors.black)
    verif.egal(m.debordements, 0)
    verif.vrai(m.ligne(2):find("2 / 8", 1, true))
    verif.egal(m.couleur_fond(commande.suivant.x1, 2), colors.lightBlue)
  end,
}
