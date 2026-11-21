-- Session : tours complets de chaque jeu contre une vraie caisse en mémoire, refus propres, retour au hall.

local verif = require("verif")
local caisse = require("casino.caisse")
local session = require("casino.session")
local machine = require("casino.jeux.machine")
local crash = require("casino.jeux.crash")
local defauts = require("casino.reglages")

local function copie(table_source)
  local resultat = {}
  for cle, valeur in pairs(table_source) do resultat[cle] = valeur end
  return resultat
end

-- Session sur une caisse de `solde` jetons ; `tirages` est la suite des valeurs rendues par le hasard.
local function partie(solde, tirages)
  local d = { contenu = { solde = solde } }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat) d.contenu = etat; return true end
  local c = caisse.ouvrir(d, { depart = 500, recharge = 500 })
  local indice = 0
  local ctx = { caisse = c, maintenant = 0, inactivite = 90, hasard = function()
    indice = indice + 1
    return tirages[indice] or 1
  end }
  local reglages = copie(defauts)
  reglages.mise_defaut = 1
  local etat = session.nouvelle(reglages, c.solde())
  local p = { etat = etat, ctx = ctx, caisse = c, depot = d }
  function p.agir(action) session.agir(etat, action, ctx) end
  function p.attendre(secondes)
    ctx.maintenant = ctx.maintenant + secondes
    session.avancer(etat, ctx)
  end
  return p
end

local function arret(symbole)
  for i, nom in ipairs(machine.BANDE) do
    if nom == symbole then return i end
  end
end

return {
  paliers_de_mise_bornes_et_croissants = function()
    verif.egal(session.paliers(1, 100), { 1, 2, 5, 10, 20, 50, 100 })
    verif.egal(session.paliers(3, 40), { 3, 5, 10, 20, 40 })
    verif.egal(session.paliers(7, 7), { 7 })
  end,

  mise_change_par_palier_sans_sortir_des_bornes = function()
    local p = partie(500, {})
    p.agir({ type = "mise", pas = -1 })
    verif.egal(p.etat.mise, 1)
    for _ = 1, 20 do p.agir({ type = "mise", pas = 1 }) end
    verif.egal(p.etat.mise, 100)
  end,

  machine_tour_complet_mise_puis_gain_au_dernier_rouleau = function()
    local sept = arret("sept")
    local p = partie(500, { sept, sept, sept })
    p.agir({ type = "ouvrir", jeu = "machine" })
    p.agir({ type = "mise", pas = 1 })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.solde, 498)
    verif.egal(p.etat.machine.phase, "tourne")
    verif.egal(session.vider_sons(p.etat), { "mise" })
    p.attendre(1.2)
    verif.egal(session.vider_sons(p.etat), { "rouleau" })
    p.attendre(1)
    verif.egal(p.etat.machine.phase, "fini")
    verif.egal(p.etat.solde, 698)
    verif.egal(p.etat.record, 200)
    verif.egal(p.etat.machine.resultat, { mise = 2, gain = 200 })
    verif.egal(session.vider_sons(p.etat), { "rouleau", "rouleau", "gain" })
    verif.egal(p.depot.contenu, { solde = 698 })
  end,

  machine_mise_au_dessus_du_solde_refusee_sans_tour = function()
    local p = partie(1, {})
    p.agir({ type = "ouvrir", jeu = "machine" })
    p.agir({ type = "mise", pas = 1 })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.machine.phase, "attente")
    verif.egal(p.etat.solde, 1)
    verif.vrai(p.etat.message.texte:find("Solde insuffisant"), p.etat.message.texte)
    verif.egal(session.vider_sons(p.etat), { "refus" })
  end,

  pendant_un_tour_ni_hall_ni_mise_ni_second_tour = function()
    local p = partie(500, { 2, 3, 4 })
    p.agir({ type = "ouvrir", jeu = "machine" })
    p.agir({ type = "jouer" })
    p.agir({ type = "hall" })
    p.agir({ type = "mise", pas = 1 })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.ecran, "machine")
    verif.egal(p.etat.mise, 1)
    verif.egal(p.etat.solde, 499)
  end,

  roulette_plusieurs_mises_un_seul_debit_et_gain_cumule = function()
    local p = partie(500, { 18 })
    p.agir({ type = "ouvrir", jeu = "roulette" })
    p.agir({ type = "mise", pas = 3 })
    p.agir({ type = "case", case = "n17" })
    p.agir({ type = "case", case = "rouge" })
    p.agir({ type = "case", case = "d2" })
    verif.egal(p.etat.roulette.mises, { n17 = 10, rouge = 10, d2 = 10 })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.solde, 470)
    p.attendre(session.DUREE_ROULETTE)
    verif.egal(p.etat.roulette.numero, 17)
    verif.egal(p.etat.roulette.phase, "fini")
    verif.egal(p.etat.solde, 470 + 360 + 30)
    verif.egal(p.etat.roulette.historique, { 17 })
    verif.egal(p.etat.roulette.mises, { n17 = 10, rouge = 10, d2 = 10 })
  end,

  roulette_jeton_refuse_au_dela_du_solde_ou_du_maximum_par_case = function()
    local p = partie(15, {})
    p.agir({ type = "ouvrir", jeu = "roulette" })
    p.agir({ type = "mise", pas = 3 })
    p.agir({ type = "case", case = "noir" })
    p.agir({ type = "case", case = "pair" })
    verif.egal(p.etat.roulette.mises, { noir = 10 })
    local q = partie(5000, {})
    q.agir({ type = "mise", pas = 10 })
    q.agir({ type = "case", case = "noir" })
    q.agir({ type = "case", case = "noir" })
    verif.egal(q.etat.roulette.mises, { noir = 100 })
    verif.vrai(q.etat.message.texte:find("maximale"), q.etat.message.texte)
  end,

  roulette_lancer_sans_jeton_refuse = function()
    local p = partie(500, {})
    p.agir({ type = "ouvrir", jeu = "roulette" })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.roulette.phase, "attente")
    verif.egal(p.etat.solde, 500)
  end,

  crash_encaisser_avant_le_point_paie_le_multiplicateur_atteint = function()
    -- k = 6866 donne un point de x3.10.
    local p = partie(500, { 6866 })
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.agir({ type = "mise", pas = 3 })
    p.agir({ type = "jouer" })
    verif.egal(p.etat.crash.point, 310)
    verif.egal(p.depot.contenu.en_cours, { mise = 10, gain = 0 })
    p.ctx.maintenant = crash.instant(200) + 0.001
    p.agir({ type = "encaisser" })
    verif.egal(p.etat.crash.phase, "encaisse")
    verif.egal(p.etat.crash.atteint, 200)
    verif.egal(p.etat.solde, 510)
    verif.egal(p.etat.crash.historique, { 310 })
  end,

  crash_sans_encaisser_explose_au_point = function()
    local p = partie(500, { 6866 })
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.agir({ type = "jouer" })
    p.attendre(crash.instant(310) + 0.01)
    verif.egal(p.etat.crash.phase, "explose")
    verif.egal(p.etat.solde, 499)
    local sons = session.vider_sons(p.etat)
    verif.egal(sons[#sons], "perte")
  end,

  crash_encaisser_apres_le_point_ne_sauve_pas_la_mise = function()
    local p = partie(500, { 6866 })
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.agir({ type = "jouer" })
    p.ctx.maintenant = crash.instant(400)
    p.agir({ type = "encaisser" })
    verif.egal(p.etat.crash.phase, "explose")
    verif.egal(p.etat.solde, 499)
  end,

  crash_point_au_plafond_encaisse_d_office = function()
    local p = partie(500, { crash.TIRAGES })
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.agir({ type = "jouer" })
    verif.egal(p.depot.contenu.en_cours, { mise = 1, gain = 100 })
    p.attendre(crash.instant(crash.PLAFOND) + 0.01)
    verif.egal(p.etat.crash.phase, "encaisse")
    verif.egal(p.etat.solde, 599)
  end,

  recharger_ajoute_les_jetons_et_l_annonce = function()
    local p = partie(0, {})
    p.agir({ type = "recharger" })
    verif.egal(p.etat.solde, 500)
    verif.egal(p.etat.message.ton, "bon")
  end,

  retour_au_hall_apres_inactivite_jamais_pendant_un_tour = function()
    local p = partie(500, { 6866 })
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.attendre(89)
    verif.egal(p.etat.ecran, "crash")
    p.attendre(1)
    verif.egal(p.etat.ecran, "hall")
    p.agir({ type = "ouvrir", jeu = "crash" })
    p.agir({ type = "jouer" })
    p.ctx.maintenant = p.ctx.maintenant + 95
    session.avancer(p.etat, p.ctx)
    verif.egal(p.etat.crash.phase, "explose")
    verif.egal(p.etat.ecran, "crash")
  end,

  anime_pendant_un_tour_et_la_fete_puis_plus_rien = function()
    local sept = arret("sept")
    local p = partie(500, { sept, sept, sept })
    p.agir({ type = "ouvrir", jeu = "machine" })
    verif.egal(session.anime(p.etat, p.ctx.maintenant), false)
    p.agir({ type = "jouer" })
    verif.egal(session.anime(p.etat, p.ctx.maintenant), true)
    p.attendre(3)
    verif.egal(session.anime(p.etat, p.ctx.maintenant), true)
    p.attendre(session.DUREE_FETE)
    verif.egal(session.anime(p.etat, p.ctx.maintenant), false)
    verif.egal(session.echeance(p.etat, 90), p.etat.geste + 90)
  end,

  action_inconnue_leve_une_erreur = function()
    local p = partie(500, {})
    verif.egal(pcall(p.agir, { type = "tricher" }), false)
  end,

  -- Non-régression : un mise_max_monnaie infini, négatif, non entier ou nan donnait des paliers aberrants.
  reglages_numeriques_aberrants_remis_aux_defauts = function()
    for _, valeur in ipairs({ math.huge, -5, 2.5, 0 / 0, 1e12 }) do
      local reglages = copie(defauts)
      -- 2.5 est un volume valable (0 à 3) : il n'est faux que pour les entiers.
      local volume_faux = valeur ~= 2.5
      reglages.mise_max_monnaie, reglages.periode_depot = valeur, valeur
      if volume_faux then reglages.volume = valeur end
      local messages = session.corriger(reglages, defauts, { "nuit" })
      verif.egal(reglages.mise_max_monnaie, defauts.mise_max_monnaie, tostring(valeur))
      verif.egal(reglages.volume, defauts.volume, tostring(valeur))
      verif.vrai(#messages >= (volume_faux and 2 or 1), tostring(valeur))
    end
  end,

  reglages_fautifs_remis_aux_defauts_avec_message = function()
    local reglages = copie(defauts)
    reglages.mise_min, reglages.mise_max, reglages.theme, reglages.volume = 0, "beaucoup", "rose", 9
    local messages = session.corriger(reglages, defauts, { "nuit", "ambre" })
    verif.egal(reglages.mise_min, defauts.mise_min)
    verif.egal(reglages.mise_max, defauts.mise_max)
    verif.egal(reglages.theme, "nuit")
    verif.egal(reglages.volume, defauts.volume)
    verif.egal(#messages, 4)
    local inverses = copie(defauts)
    inverses.mise_min, inverses.mise_max = 50, 10
    session.corriger(inverses, defauts, { "nuit" })
    verif.vrai(inverses.mise_min <= inverses.mise_max)
  end,
}
