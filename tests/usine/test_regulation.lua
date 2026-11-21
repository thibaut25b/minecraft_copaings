-- Régulation pure : hystérésis, stock inconnu, modes forcés, délestage par réseau et mémoire relue.

local verif = require("verif")
local regulation = require("usine.regulation")

local SEUILS = { delestage = 0.95, reprise = 0.80 }

local function ligne(nom, options)
  options = options or {}
  return { nom = nom, produit = "p:" .. nom, mini = options.mini or 100, maxi = options.maxi or 500,
    relais = "r", cote = "back", signal_coupe = true, reseau = options.reseau == nil and "R" or options.reseau or nil,
    priorite = options.priorite or 1 }
end

-- Une passe : `stock` = { [nom de ligne] = quantité } (produit p:nom), `ratio` = charge du réseau R (nil : illisible).
local function passe(lignes, memoire, stock, ratio)
  local quantites
  if stock then
    quantites = {}
    for nom, quantite in pairs(stock) do quantites["p:" .. nom] = quantite end
  end
  local reseaux = {}
  if ratio then reseaux.R = { stress = ratio * 1000, capacite = 1000 } end
  return regulation.passer(lignes, memoire, { stock = quantites, reseaux = reseaux }, SEUILS)
end

local function seule(quantites)
  local lignes = { ligne("A") }
  local memoire = regulation.memoire(lignes, nil)
  local sorties
  for _, quantite in ipairs(quantites) do memoire, sorties = passe(lignes, memoire, { A = quantite }, 0.5) end
  return sorties[1], memoire
end

local function delestees(memoire)
  local noms = {}
  for nom, etat in pairs(memoire) do
    if etat.delestee then noms[#noms + 1] = nom end
  end
  table.sort(noms)
  return noms
end

return {
  premiere_decision_marche_si_stock_sous_maxi = function()
    verif.egal(seule({ 300 }).marche, true)
    verif.egal(seule({ 499 }).marche, true)
  end,

  premiere_decision_arret_si_stock_au_maxi = function()
    local sortie = seule({ 500 })
    verif.egal(sortie.marche, false)
    verif.egal(sortie.raison, "stock plein")
  end,

  ligne_s_arrete_quand_le_stock_atteint_maxi_exactement = function()
    verif.egal(seule({ 300, 499 }).marche, true)
    verif.egal(seule({ 300, 500 }).marche, false)
  end,

  ligne_arretee_garde_l_arret_entre_mini_et_maxi = function()
    local sortie = seule({ 600, 101 })
    verif.egal(sortie.marche, false)
    verif.egal(sortie.raison, "en attente")
  end,

  ligne_repart_quand_le_stock_redescend_a_mini = function()
    local sortie = seule({ 600, 100 })
    verif.egal(sortie.marche, true)
    verif.egal(sortie.raison, "stock bas")
  end,

  ligne_en_marche_garde_la_marche_entre_mini_et_maxi = function()
    local sortie = seule({ 50, 499 })
    verif.egal(sortie.marche, true)
    verif.egal(sortie.raison, "remplit")
  end,

  objet_absent_d_un_stock_connu_compte_zero = function()
    local lignes = { ligne("A") }
    local _, sorties = passe(lignes, regulation.memoire(lignes), { autre = 5 }, 0.5)
    verif.egal(sorties[1].quantite, 0)
    verif.egal(sorties[1].marche, true)
  end,

  stock_inconnu_garde_la_decision_precedente_et_le_signale = function()
    local lignes = { ligne("A") }
    local memoire = passe(lignes, regulation.memoire(lignes), { A = 600 }, 0.5)
    local _, sorties = passe(lignes, memoire, nil, 0.5)
    verif.egal(sorties[1], { marche = false, raison = "stock inconnu" })
    memoire = passe(lignes, regulation.memoire(lignes), { A = 10 }, 0.5)
    _, sorties = passe(lignes, memoire, nil, 0.5)
    verif.egal(sorties[1], { marche = true, raison = "stock inconnu" })
  end,

  stock_inconnu_sans_passe_laisse_la_ligne_a_l_arret = function()
    local lignes = { ligne("A") }
    local _, sorties = passe(lignes, regulation.memoire(lignes), nil, 0.5)
    verif.egal(sorties[1], { marche = false, raison = "stock inconnu" })
  end,

  mode_force_marche_ignore_le_stock_plein = function()
    local lignes = { ligne("A") }
    local memoire = regulation.changer_mode(regulation.memoire(lignes), "A")
    local _, sorties = passe(lignes, memoire, { A = 9999 }, 0.5)
    verif.egal(sorties[1].marche, true)
    verif.egal(sorties[1].raison, "forcée marche")
  end,

  mode_force_arret_ignore_le_stock_bas = function()
    local lignes = { ligne("A") }
    local memoire = regulation.changer_mode(regulation.changer_mode(regulation.memoire(lignes), "A"), "A")
    local _, sorties = passe(lignes, memoire, { A = 0 }, 0.5)
    verif.egal(sorties[1].marche, false)
    verif.egal(sorties[1].raison, "forcée arrêt")
  end,

  modes_tournent_auto_marche_arret_auto = function()
    verif.egal(regulation.mode_suivant("auto"), "marche")
    verif.egal(regulation.mode_suivant("marche"), "arret")
    verif.egal(regulation.mode_suivant("arret"), "auto")
    verif.egal(regulation.mode_suivant("bizarre"), "auto")
  end,

  changer_mode_ne_modifie_pas_la_memoire_d_origine = function()
    local memoire = regulation.memoire({ ligne("A") })
    regulation.changer_mode(memoire, "A")
    verif.egal(memoire.A.mode, "auto")
  end,

  surcharge_deleste_une_seule_ligne_par_passe_la_moins_prioritaire = function()
    local lignes = { ligne("A", { priorite = 1 }), ligne("B", { priorite = 3 }), ligne("C", { priorite = 2 }) }
    local stock = { A = 0, B = 0, C = 0 }
    local memoire, sorties = passe(lignes, regulation.memoire(lignes), stock, 0.96)
    verif.egal(delestees(memoire), { "B" })
    verif.egal(sorties[2], { marche = false, raison = "délestée", quantite = 0 })
    memoire = passe(lignes, memoire, stock, 0.96)
    verif.egal(delestees(memoire), { "B", "C" })
    memoire = passe(lignes, memoire, stock, 0.96)
    verif.egal(delestees(memoire), { "A", "B", "C" })
  end,

  a_priorite_egale_la_derniere_de_la_liste_est_delestee_d_abord = function()
    local lignes = { ligne("A"), ligne("B"), ligne("C") }
    local memoire = passe(lignes, regulation.memoire(lignes), { A = 0, B = 0, C = 0 }, 0.95)
    verif.egal(delestees(memoire), { "C" })
  end,

  capacite_sous_le_stress_deleste = function()
    local lignes = { ligne("A") }
    local memoire = regulation.passer(lignes, regulation.memoire(lignes),
      { stock = { ["p:A"] = 0 }, reseaux = { R = { stress = 10, capacite = 0 } } }, SEUILS)
    verif.egal(delestees(memoire), { "A" })
  end,

  reprise_relache_une_ligne_par_passe_la_plus_prioritaire = function()
    local lignes = { ligne("A", { priorite = 1 }), ligne("B", { priorite = 3 }), ligne("C", { priorite = 2 }) }
    local stock = { A = 0, B = 0, C = 0 }
    local memoire = regulation.memoire(lignes)
    for _ = 1, 3 do memoire = passe(lignes, memoire, stock, 1.2) end
    memoire = passe(lignes, memoire, stock, 0.80)
    verif.egal(delestees(memoire), { "B", "C" })
    memoire = passe(lignes, memoire, stock, 0.5)
    verif.egal(delestees(memoire), { "B" })
  end,

  entre_les_seuils_rien_ne_bouge = function()
    local lignes = { ligne("A"), ligne("B") }
    local stock = { A = 0, B = 0 }
    local memoire = passe(lignes, regulation.memoire(lignes), stock, 0.99)
    memoire = passe(lignes, memoire, stock, 0.9)
    verif.egal(delestees(memoire), { "B" })
  end,

  stress_illisible_ne_deleste_pas_et_garde_les_delestees = function()
    local lignes = { ligne("A"), ligne("B") }
    local stock = { A = 0, B = 0 }
    local memoire = passe(lignes, regulation.memoire(lignes), stock, 0.99)
    memoire = passe(lignes, memoire, stock, nil)
    verif.egal(delestees(memoire), { "B" })
    memoire = regulation.passer(lignes, memoire, { stock = { ["p:A"] = 0, ["p:B"] = 0 },
      reseaux = { R = { stress = 0, capacite = 0 } } }, SEUILS)
    verif.egal(delestees(memoire), { "B" }, "réseau à l'arrêt : comme illisible")
  end,

  ligne_forcee_n_est_jamais_delestee = function()
    local lignes = { ligne("A"), ligne("B") }
    local memoire = regulation.changer_mode(regulation.memoire(lignes), "B")
    local sorties
    memoire, sorties = passe(lignes, memoire, { A = 0, B = 0 }, 1.5)
    verif.egal(delestees(memoire), { "A" })
    verif.egal(sorties[2].marche, true)
    memoire = passe(lignes, memoire, { A = 0, B = 0 }, 1.5)
    verif.egal(delestees(memoire), { "A" })
  end,

  ligne_delestee_puis_forcee_sort_des_delestees = function()
    local lignes = { ligne("A") }
    local memoire = passe(lignes, regulation.memoire(lignes), { A = 0 }, 1.5)
    memoire = regulation.changer_mode(memoire, "A")
    memoire = passe(lignes, memoire, { A = 0 }, 0.9)
    verif.egal(delestees(memoire), {})
  end,

  ligne_arretee_pour_stock_plein_n_est_pas_candidate_au_delestage = function()
    local lignes = { ligne("A"), ligne("B") }
    local memoire = passe(lignes, regulation.memoire(lignes), { A = 0, B = 900 }, 0.99)
    verif.egal(delestees(memoire), { "A" })
  end,

  ligne_delestee_au_stock_plein_sort_des_delestees = function()
    local lignes = { ligne("A") }
    local memoire = passe(lignes, regulation.memoire(lignes), { A = 0 }, 0.99)
    local sorties
    memoire, sorties = passe(lignes, memoire, { A = 900 }, 0.9)
    verif.egal(delestees(memoire), {})
    verif.egal(sorties[1].raison, "stock plein")
  end,

  delestage_reste_dans_son_reseau = function()
    local lignes = { ligne("A", { reseau = "R" }), ligne("B", { reseau = "S" }), ligne("C", { reseau = false }) }
    local memoire = regulation.passer(lignes, regulation.memoire(lignes),
      { stock = { ["p:A"] = 0, ["p:B"] = 0, ["p:C"] = 0 },
        reseaux = { R = { stress = 10, capacite = 100 }, S = { stress = 99, capacite = 100 } } }, SEUILS)
    verif.egal(delestees(memoire), { "B" })
  end,

  memoire_relue_garde_modes_decisions_et_delestees_des_lignes_configurees = function()
    local lignes = { ligne("A"), ligne("B") }
    local lue = { A = { mode = "arret", decision = false, delestee = true }, B = { mode = "n'importe", decision = 3 },
      Z = { mode = "marche" } }
    verif.egal(regulation.memoire(lignes, lue), {
      A = { mode = "arret", decision = false, delestee = true },
      B = { mode = "auto", delestee = false },
    })
    verif.egal(regulation.memoire(lignes, "illisible").A, { mode = "auto", delestee = false })
  end,
}
