-- Caisse fictive : solde jamais négatif, mise refusée proprement, reprise d'un tour interrompu sans créer ni détruire.

local verif = require("verif")
local caisse = require("casino.caisse")
local depot = require("casino.depot")
local systeme = require("faux.systeme")

local REGLES = { depart = 500, recharge = 200 }

-- Dépôt en mémoire : `contenu` est ce qui serait relu au redémarrage ; `panne` fait échouer l'écriture.
local function depot_memoire(contenu)
  local d = { contenu = contenu, ecritures = 0 }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat)
    if d.panne then return false, "disque plein" end
    d.ecritures = d.ecritures + 1
    d.contenu = { solde = etat.solde, en_cours = etat.en_cours and { mise = etat.en_cours.mise,
      gain = etat.en_cours.gain } }
    return true
  end
  return d
end

return {
  premier_lancement_donne_le_solde_de_depart_et_l_ecrit = function()
    local d = depot_memoire(nil)
    local c, reprise, probleme = caisse.ouvrir(d, REGLES)
    verif.egal(c.solde(), 500)
    verif.egal(reprise, nil)
    verif.egal(probleme, nil)
    verif.egal(d.contenu, { solde = 500 })
  end,

  fichier_illisible_rend_le_depart_et_le_signale = function()
    local c, _, probleme = caisse.ouvrir(depot_memoire(false), REGLES)
    verif.egal(c.solde(), 500)
    verif.vrai(probleme and probleme:find("illisible"), tostring(probleme))
    local negatif = caisse.ouvrir(depot_memoire({ solde = -5 }), REGLES)
    verif.egal(negatif.solde(), 500)
  end,

  miser_retire_la_mise_et_regler_verse_le_gain = function()
    local d = depot_memoire({ solde = 100 })
    local c = caisse.ouvrir(d, REGLES)
    verif.egal(c.miser(30, 90), true)
    verif.egal(c.solde(), 70)
    verif.egal(d.contenu, { solde = 70, en_cours = { mise = 30, gain = 90 } })
    verif.egal(c.regler(90), true)
    verif.egal(c.solde(), 160)
    verif.egal(d.contenu, { solde = 160 })
  end,

  mise_superieure_au_solde_refusee_sans_rien_changer = function()
    local d = depot_memoire({ solde = 20 })
    local c = caisse.ouvrir(d, REGLES)
    local ok, raison = c.miser(21, 0)
    verif.egal(ok, false)
    verif.vrai(raison:find("Solde insuffisant"), raison)
    verif.egal(c.solde(), 20)
    verif.egal(d.ecritures, 0)
  end,

  mise_nulle_negative_ou_fractionnaire_refusee = function()
    local c = caisse.ouvrir(depot_memoire({ solde = 20 }), REGLES)
    for _, montant in ipairs({ 0, -3, 2.5 }) do
      verif.egal(c.miser(montant, 0), false, tostring(montant))
    end
    verif.egal(c.solde(), 20)
  end,

  tout_le_solde_peut_etre_mise_et_le_solde_reste_positif = function()
    local c = caisse.ouvrir(depot_memoire({ solde = 20 }), REGLES)
    verif.egal(c.miser(20, 0), true)
    verif.egal(c.regler(0), true)
    verif.egal(c.solde(), 0)
    verif.egal(c.miser(1, 0), false)
  end,

  une_seule_mise_a_la_fois = function()
    local c = caisse.ouvrir(depot_memoire({ solde = 100 }), REGLES)
    verif.egal(c.miser(10, 0), true)
    verif.egal(c.miser(10, 0), false)
    verif.egal(c.recharger(), false)
    verif.egal(c.solde(), 90)
  end,

  regler_sans_tour_est_une_erreur_de_programme = function()
    local c = caisse.ouvrir(depot_memoire({ solde = 100 }), REGLES)
    verif.egal(pcall(c.regler, 10), false)
  end,

  tour_interrompu_est_regle_au_gain_ecrit_avec_la_mise = function()
    local d = depot_memoire({ solde = 100 })
    local c = caisse.ouvrir(d, REGLES)
    c.miser(10, 50)
    -- Redémarrage en plein tour : seule la copie écrite survit.
    local apres, reprise = caisse.ouvrir(depot_memoire(d.contenu), REGLES)
    verif.egal(reprise, { mise = 10, gain = 50 })
    verif.egal(apres.solde(), 140)
    verif.egal(apres.en_cours(), false)
  end,

  tour_perdant_interrompu_ne_rend_pas_la_mise = function()
    local d = depot_memoire({ solde = 100 })
    caisse.ouvrir(d, REGLES).miser(10, 0)
    local apres = caisse.ouvrir(depot_memoire(d.contenu), REGLES)
    verif.egal(apres.solde(), 90)
  end,

  ecriture_ratee_de_la_mise_refuse_le_tour = function()
    local d = depot_memoire({ solde = 100 })
    local c = caisse.ouvrir(d, REGLES)
    d.panne = true
    local ok, raison = c.miser(10, 0)
    verif.egal(ok, false)
    verif.vrai(raison:find("disque plein"), raison)
    verif.egal(c.solde(), 100)
    verif.egal(c.en_cours(), false)
  end,

  recharger_ajoute_le_montant_des_reglages = function()
    local d = depot_memoire({ solde = 3 })
    local c = caisse.ouvrir(d, REGLES)
    verif.egal({ c.recharger() }, { true, 200 })
    verif.egal(c.solde(), 203)
    verif.egal(d.contenu, { solde = 203 })
  end,

  -- Non-régression : un arrêt en pleine écriture laissait un fichier tronqué, remplacé au démarrage par le solde de
  -- départ. Le fichier illisible est mis de côté, la caisse le signale pour un admin.
  fichier_tronque_mis_de_cote_et_signale = function()
    local disque = systeme.installer()
    disque.epoch = 42
    disque.disque["casino.credits"] = "{ solde = 12"
    local c, _, probleme = caisse.ouvrir(depot.fichier("/casino.credits"), { depart = 0, recharge = 0 })
    verif.egal(c.solde(), 0)
    verif.egal(disque.disque["casino.credits.illisible-42"], "{ solde = 12")
    verif.vrai(probleme:find("admin"), probleme)
  end,

  -- L'écriture passe par un fichier provisoire renommé ; une version provisoire complète seule est relue.
  ecriture_par_fichier_provisoire_puis_renomme = function()
    local disque = systeme.installer()
    local d = depot.fichier("/casino.credits")
    verif.egal(d.ecrire({ solde = 7 }), true)
    verif.egal(d.ecrire({ solde = 8 }), true)
    verif.egal(disque.disque["casino.credits.tmp"], nil)
    verif.egal(d.lire(), { solde = 8 })
    disque.disque["casino.credits"] = nil
    disque.disque["casino.credits.tmp"] = textutils.serialize({ solde = 9 })
    verif.egal(d.lire(), { solde = 9 })
    verif.egal(disque.disque["casino.credits.tmp"], nil)
  end,
}
