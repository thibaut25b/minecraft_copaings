-- Blackjack : valeur des mains, règlement, banque, sabot, tours complets contre une vraie caisse, retour simulé.

local verif = require("verif")
local blackjack = require("casino.jeux.blackjack")
local caisse = require("casino.caisse")
local session = require("casino.session")
local defauts = require("casino.reglages")

local function main(...)
  local cartes = {}
  for i, rang in ipairs({ ... }) do cartes[i] = { rang = rang, couleur = "pique" } end
  return cartes
end

local function copie(source)
  local resultat = {}
  for cle, valeur in pairs(source) do resultat[cle] = valeur end
  return resultat
end

-- Session au blackjack, mise 10, sabot fixé : `ordre` est la suite des rangs distribués (joueur, banque, joueur,
-- banque, puis les cartes tirées).
local function table_de_jeu(ordre, solde)
  local d = { contenu = { solde = solde or 500 } }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat) d.contenu = etat; return true end
  local c = caisse.ouvrir(d, { depart = 500, recharge = 500 })
  local ctx = { caisse = c, maintenant = 0, inactivite = 90, hasard = function() return 1 end }
  local etat = session.nouvelle(defauts, c.solde())
  session.agir(etat, { type = "ouvrir", jeu = "blackjack" }, ctx)
  etat.blackjack.sabot = { cartes = main((table.unpack or unpack)(ordre)), position = 1 }
  local t = { etat = etat, ctx = ctx, depot = d, caisse = c }
  function t.agir(genre) session.agir(etat, { type = genre }, ctx) end
  function t.attendre(secondes)
    ctx.maintenant = ctx.maintenant + secondes
    session.avancer(etat, ctx)
  end
  return t
end

-- Graine fixe : générateur de Park et Miller, entier de 1 à n.
local function hasard_graine(graine)
  local x = graine
  return function(n)
    x = (48271 * x) % 2147483647
    return x % n + 1
  end
end

-- Stratégie de base simple, sans partage : doubler sur 9 à 11 favorables, tirer jusqu'à 17 dur ou 19 souple.
local function strategie(joueur, visible)
  local total, souple = blackjack.valeur(joueur)
  local banque = visible.rang == 1 and 11 or math.min(10, visible.rang)
  if #joueur == 2 and not souple and (total == 11 or (total == 10 and banque <= 9)
    or (total == 9 and banque >= 3 and banque <= 6)) then
    return "doubler"
  end
  if souple then return (total >= 19 or (total == 18 and banque <= 8)) and "rester" or "tirer" end
  if total >= 17 or (total >= 13 and banque <= 6) or (total == 12 and banque >= 4 and banque <= 6) then
    return "rester"
  end
  return "tirer"
end

-- Taux de retour (rendu / misé) sur `mains` mains jouées avec la stratégie, sabot de 6 jeux, mise de 2.
local function simuler(mains, graine)
  local hasard = hasard_graine(graine)
  local sabot = blackjack.sabot(6, hasard)
  local mise_totale, rendu = 0, 0
  for _ = 1, mains do
    if blackjack.a_remelanger(sabot) then sabot = blackjack.sabot(6, hasard) end
    local joueur, banque = {}, {}
    for i = 1, 4 do table.insert(i % 2 == 1 and joueur or banque, blackjack.tirer(sabot)) end
    local mise = 2
    if not blackjack.naturel(joueur) and not blackjack.naturel(banque) then
      while blackjack.valeur(joueur) < 21 do
        local choix = strategie(joueur, banque[1])
        if choix == "rester" then break end
        joueur[#joueur + 1] = blackjack.tirer(sabot)
        if choix == "doubler" then
          mise = 4
          break
        end
      end
      if blackjack.valeur(joueur) <= 21 then
        for _ = 1, #blackjack.tirage_banque(banque, sabot) do banque[#banque + 1] = blackjack.tirer(sabot) end
      end
    end
    mise_totale = mise_totale + mise
    rendu = rendu + blackjack.regler(joueur, banque, mise)
  end
  return rendu / mise_totale
end

return {
  valeur_as_a_1_ou_11_mains_souples_et_dures = function()
    verif.egal({ blackjack.valeur(main(1, 6)) }, { 17, true })
    verif.egal({ blackjack.valeur(main(1, 6, 10)) }, { 17, false })
    verif.egal({ blackjack.valeur(main(1, 1)) }, { 12, true })
    verif.egal({ blackjack.valeur(main(1, 1, 9)) }, { 21, true })
    verif.egal({ blackjack.valeur(main(13, 12, 5)) }, { 25, false })
    verif.egal({ blackjack.valeur(main(11, 1)) }, { 21, true })
  end,

  naturel_seulement_avec_deux_cartes = function()
    verif.vrai(blackjack.naturel(main(1, 13)))
    verif.vrai(not blackjack.naturel(main(7, 7, 7)))
    verif.vrai(not blackjack.naturel(main(10, 9)))
  end,

  reglement_de_chaque_issue = function()
    verif.egal({ blackjack.regler(main(1, 12), main(10, 9), 10) }, { 25, "blackjack" })
    verif.egal({ blackjack.regler(main(1, 12), main(1, 13), 10) }, { 10, "egalite" })
    verif.egal({ blackjack.regler(main(10, 9), main(1, 13), 10) }, { 0, "banque_blackjack" })
    verif.egal({ blackjack.regler(main(7, 7, 7), main(1, 13), 10) }, { 0, "banque_blackjack" })
    verif.egal({ blackjack.regler(main(10, 6, 9), main(10, 6, 9), 10) }, { 0, "depasse" })
    verif.egal({ blackjack.regler(main(10, 8), main(10, 6, 9), 10) }, { 20, "banque_depasse" })
    verif.egal({ blackjack.regler(main(10, 9), main(10, 8), 10) }, { 20, "gagne" })
    verif.egal({ blackjack.regler(main(10, 7), main(10, 8), 10) }, { 0, "perdu" })
    verif.egal({ blackjack.regler(main(10, 8), main(9, 9), 10) }, { 10, "egalite" })
    verif.egal({ blackjack.regler(main(7, 7, 7), main(10, 10), 10) }, { 20, "gagne" })
  end,

  blackjack_paie_3_pour_2_arrondi_en_dessous = function()
    verif.egal((blackjack.regler(main(1, 10), main(10, 9), 3)), 7)
  end,

  banque_tire_jusqu_a_17_et_reste_sur_17_souple = function()
    local sabot = { cartes = main(5, 2, 10, 4), position = 1 }
    verif.egal(#blackjack.tirage_banque(main(1, 6), sabot), 0)
    verif.egal(#blackjack.tirage_banque(main(10, 6), sabot), 1)
    verif.egal(#blackjack.tirage_banque(main(2, 3), sabot), 3)
    verif.egal(sabot.position, 1, "l'aperçu de la banque ne consomme pas le sabot")
  end,

  sabot_complet_et_remelange_sous_le_quart = function()
    local sabot = blackjack.sabot(6, hasard_graine(7))
    verif.egal(#sabot.cartes, 312)
    local as = 0
    for _, carte in ipairs(sabot.cartes) do
      if carte.rang == 1 then as = as + 1 end
    end
    verif.egal(as, 24)
    verif.vrai(not blackjack.a_remelanger(sabot))
    sabot.position = 312 - 78 + 1
    verif.vrai(not blackjack.a_remelanger(sabot))
    sabot.position = sabot.position + 1
    verif.vrai(blackjack.a_remelanger(sabot))
  end,

  retour_simule_strategie_simple_entre_96_et_102_pour_cent = function()
    -- Mise paire (le 3 pour 2 tombe juste). 3 x 100 000 mains donnent 98,9 à 99,3 % ; ici 10 000 mains à graine
    -- fixe, écart type d'environ 1,1 point : fourchette large.
    local retour = simuler(10000, 12345)
    verif.vrai(retour >= 0.96 and retour <= 1.02, tostring(retour))
  end,

  main_restee_gagnante_reglee_et_gain_prevu_ecrit_a_la_donne = function()
    local t = table_de_jeu({ 10, 10, 9, 7 })
    t.agir("jouer")
    verif.egal(t.depot.contenu, { solde = 490, en_cours = { mise = 10, gain = 20 } })
    verif.egal(t.etat.blackjack.phase, "anime")
    t.attendre(2)
    verif.egal(t.etat.blackjack.phase, "joueur")
    t.agir("rester")
    t.attendre(2)
    verif.egal(t.etat.blackjack.issue, "gagne")
    verif.egal(t.depot.contenu, { solde = 510 })
  end,

  blackjack_naturel_regle_sans_action = function()
    local t = table_de_jeu({ 1, 9, 13, 7 })
    t.agir("jouer")
    t.attendre(3)
    verif.egal(t.etat.blackjack.issue, "blackjack")
    verif.egal(t.etat.solde, 515)
  end,

  blackjack_de_la_banque_et_des_deux = function()
    local t = table_de_jeu({ 10, 1, 9, 13 })
    t.agir("jouer")
    t.attendre(3)
    verif.egal(t.etat.blackjack.issue, "banque_blackjack")
    verif.egal(t.etat.solde, 490)
    local u = table_de_jeu({ 1, 1, 12, 13 })
    u.agir("jouer")
    u.attendre(3)
    verif.egal(u.etat.blackjack.issue, "egalite")
    verif.egal(u.etat.solde, 500)
  end,

  tirer_puis_depasser_perd_et_le_gain_prevu_tombe_a_zero = function()
    local t = table_de_jeu({ 10, 10, 6, 7, 9 })
    t.agir("jouer")
    t.attendre(2)
    t.agir("tirer")
    verif.egal(t.depot.contenu.en_cours, { mise = 10, gain = 0 })
    t.attendre(2)
    verif.egal(t.etat.blackjack.issue, "depasse")
    verif.egal(t.etat.solde, 490)
  end,

  doubler_engage_une_seconde_mise_et_une_seule_carte = function()
    local t = table_de_jeu({ 5, 10, 6, 7, 10, 4 })
    t.agir("jouer")
    t.attendre(2)
    t.agir("doubler")
    verif.egal(t.depot.contenu, { solde = 480, en_cours = { mise = 20, gain = 40 } })
    t.attendre(3)
    verif.egal(#t.etat.blackjack.joueur, 3)
    verif.egal(t.etat.blackjack.issue, "gagne")
    verif.egal(t.etat.solde, 520)
  end,

  doubler_sans_assez_de_jetons_refuse_proprement = function()
    local t = table_de_jeu({ 5, 10, 6, 7, 10 }, 15)
    t.agir("jouer")
    t.attendre(2)
    t.agir("doubler")
    verif.egal(t.etat.blackjack.phase, "joueur")
    verif.egal(#t.etat.blackjack.joueur, 2)
    verif.egal(t.depot.contenu, { solde = 5, en_cours = { mise = 10, gain = 0 } })
    verif.vrai(t.etat.message.texte:find("Solde insuffisant"), t.etat.message.texte)
  end,

  main_interrompue_reglee_comme_si_le_joueur_restait = function()
    local t = table_de_jeu({ 10, 10, 2, 7, 6, 10 })
    t.agir("jouer")
    t.attendre(2)
    t.agir("tirer")
    -- 18 contre 17 : en restant maintenant le joueur gagne ; le redémarrage le règle ainsi.
    local apres, reprise = caisse.ouvrir({ lire = function() return t.depot.contenu end,
      ecrire = function() return true end }, { depart = 500, recharge = 500 })
    verif.egal(reprise, { mise = 10, gain = 20 })
    verif.egal(apres.solde(), 510)
  end,

  double_interrompu_garde_les_deux_mises_et_leur_gain = function()
    local t = table_de_jeu({ 5, 10, 6, 7, 2, 4 })
    t.agir("jouer")
    t.attendre(2)
    t.agir("doubler")
    local apres = caisse.ouvrir({ lire = function() return t.depot.contenu end, ecrire = function() return true end },
      { depart = 500, recharge = 500 })
    -- 13 contre 17 puis 4 : la banque reste à 21, les 20 jetons sont perdus.
    verif.egal(apres.solde(), 480)
  end,

  inactif_pendant_la_main_le_joueur_reste = function()
    local t = table_de_jeu({ 10, 10, 9, 7 })
    t.agir("jouer")
    t.attendre(2)
    t.attendre(95)
    t.attendre(3)
    verif.egal(t.etat.blackjack.phase, "fini")
    verif.egal(t.etat.solde, 510)
  end,

  sabot_presque_vide_remelange_avant_la_donne = function()
    local t = table_de_jeu({ 10, 10, 9, 7, 1, 1, 1, 1 })
    t.etat.blackjack.sabot.position = 8
    t.agir("jouer")
    verif.egal(#t.etat.blackjack.sabot.cartes, 52 * defauts.jeux_blackjack)
    verif.egal(t.etat.blackjack.sabot.position, 5)
    verif.vrai(t.etat.message.texte:find("remélangé"), t.etat.message.texte)
  end,

  mise_de_depart_au_palier_sous_mise_defaut = function()
    local reglages = copie(defauts)
    reglages.mise_defaut = 30
    verif.egal(session.nouvelle(reglages, 100).mise, 20)
    reglages.mise_defaut, reglages.mise_min = 1, 5
    verif.egal(session.nouvelle(reglages, 100).mise, 5)
    verif.egal(session.nouvelle(defauts, 100).mise, 10)
  end,
}
