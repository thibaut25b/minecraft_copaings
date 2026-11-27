-- Vues de la production : ce qui est à l'écran à chaque taille, l'action de chaque toucher, la courbe et son échelle.

colors = require("faux.couleurs")

local verif = require("verif")
local vues = require("production.vues")
local flux = require("production.flux")
local courbe = require("production.vues.courbe")
local moniteur = require("faux.moniteur")
local exemple = require("outils.apercus.production.exemple")
local vers_cc = require("commun.texte").vers_cc

local TAILLES = { { 164, 81 }, { 100, 38 }, { 72, 26 }, { 51, 19 }, { 39, 19 }, { 26, 12 }, { 20, 8 } }
local FER = "minecraft:iron_ingot|"

local function dessiner(largeur, hauteur, options)
  local m = moniteur.nouveau(largeur, hauteur)
  local etat = exemple.etat(options)
  vues.dessiner(m, etat)
  return m, etat
end

local function present(m, motif)
  verif.vrai(m.chercher(vers_cc(motif)), "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
end

local function absent(m, motif)
  verif.egal(m.chercher(vers_cc(motif)), nil, "présent à l'écran : " .. motif .. "\n" .. m.texte())
end

local function toucher(m, etat, motif)
  local x, y = m.chercher(vers_cc(motif))
  verif.vrai(x, "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
  return vues.action_touchee(m, etat, x, y)
end

-- Couleurs de pixels trouvées dans le rectangle de cases (x1, y1)..(x2, y2).
local function couleurs(m, x1, y1, x2, y2)
  local vues_couleurs = {}
  for y = (y1 - 1) * 3 + 1, y2 * 3 do
    for x = (x1 - 1) * 2 + 1, x2 * 2 do
      local ok, couleur = pcall(m.pixel, x, y)
      if ok then vues_couleurs[couleur] = true end
    end
  end
  return vues_couleurs
end

return {
  aucune_taille_ne_deborde_ni_ne_leve = function()
    local cas = { {}, { vide = true }, { objets_en_plus = 20 }, { erreurs = { "a", "b", "c", "d" } },
      { onglet = "alertes" }, { consommation = false }, { phase = "attente" }, { sens = "bilan" }, { fenetre = 3600 } }
    for _, taille in ipairs(TAILLES) do
      for _, options in ipairs(cas) do
        local m = dessiner(taille[1], taille[2], options)
        verif.egal(m.debordements, 0, taille[1] .. "x" .. taille[2])
      end
    end
  end,

  riche_montre_bandeau_commandes_tuiles_liste_detail_et_courbe = function()
    local m = dessiner(100, 38)
    for _, motif in ipairs({ "Production", "14:32", "2 alertes", "Tout", "Suivis", "Alertes", "/s", "/min", "/h",
      "1 min", "10 min", "1 h", "Prod", "Bilan", "Conso", "Production totale", "Consommation totale", "Types actifs",
      "Tout le réseau", "Iron Ingot", "Détail", "Stock", "Reset", "Débit", "max ", "-10 min", "-5 min", "maintenant",
      "Prochaine mesure dans 4 s" }) do
      present(m, motif)
    end
  end,

  aucune_phrase_d_aide_a_l_ecran = function()
    local m = dessiner(164, 81)
    absent(m, "toucher")
    absent(m, "moyenne sur")
    absent(m, "par barre")
  end,

  les_onglets_suivent_les_reglages = function()
    local function noms(options)
      local liste = {}
      for i, onglet in ipairs(vues.onglets(options)) do liste[i] = onglet.nom end
      return liste
    end
    verif.egal(noms({ tout = true, suivis = true, consommation = true }), { "tout", "suivis", "alertes" })
    verif.egal(noms({ tout = true, suivis = false, consommation = false }), { "tout" })
    verif.egal(noms({ tout = false, suivis = false, consommation = true }), { "suivis", "alertes" })
  end,

  un_seul_onglet_ne_dessine_aucune_rangee_d_onglets = function()
    local m = dessiner(100, 38, { tout = false, consommation = false })
    absent(m, "Suivis")
    absent(m, "Alertes")
    present(m, "Objets suivis")
  end,

  sans_consommation_ni_sens_ni_conso_ni_alertes = function()
    local m = dessiner(100, 38, { consommation = false })
    for _, motif in ipairs({ "Bilan", "Conso", "Alertes", "alerte", "Consommation totale" }) do absent(m, motif) end
    present(m, "Production totale")
  end,

  la_valeur_active_de_chaque_commande_est_en_evidence = function()
    local m = dessiner(100, 38, { unite = "h", fenetre = 60, sens = "conso" })
    for _, paire in ipairs({ { "/h", "/s" }, { "1 min", "10 min" }, { "Conso", "Bilan" } }) do
      local xa, ya = m.chercher(paire[1])
      local xb, yb = m.chercher(paire[2])
      verif.egal(m.couleur_fond(xa, ya), colors.white, paire[1])
      verif.vrai(m.couleur_fond(xb, yb) ~= colors.white, paire[2])
    end
  end,

  petit_ecran_garde_l_unite_et_fait_defiler_le_reste_d_un_bouton = function()
    local m, etat = dessiner(26, 12)
    for _, motif in ipairs({ "/s", "/min", "/h", "10 min", "Prod" }) do present(m, motif) end
    absent(m, "Bilan")
    verif.egal(toucher(m, etat, "/h"), { type = "unite", unite = "h" })
    verif.egal(toucher(m, etat, "10 min"), { type = "fenetre", fenetre = 3600 })
    verif.egal(toucher(m, etat, " Prod "), { type = "sens", sens = "bilan" })
    verif.egal(toucher(m, etat, "Tout"), { type = "onglet", onglet = "suivis" })
  end,

  toucher_un_onglet_ou_une_commande_la_choisit = function()
    local m, etat = dessiner(100, 38)
    verif.egal(toucher(m, etat, "Alertes"), { type = "onglet", onglet = "alertes" })
    verif.egal(toucher(m, etat, "1 h"), { type = "fenetre", fenetre = 3600 })
    verif.egal(toucher(m, etat, "Bilan"), { type = "sens", sens = "bilan" })
  end,

  la_production_est_en_bon_et_la_consommation_en_mauvais = function()
    local m = dessiner(100, 38, { sens = "bilan" })
    local _, y = m.chercher("Iron Ingot")
    local ligne = m.ligne(y)
    local xp, xc = ligne:find("+", 1, true), ligne:find(" -", 1, true) + 1
    verif.egal(m.couleur_texte(xp, y), colors.lime)
    verif.egal(m.couleur_texte(xc, y), colors.red)
  end,

  bilan_montre_prod_conso_et_net_si_la_place_le_permet_sinon_net = function()
    local m = dessiner(100, 38, { sens = "bilan" })
    local _, y = m.chercher("# Objet")
    for _, motif in ipairs({ "Prod", "Conso", "Net" }) do verif.vrai(m.ligne(y):find(motif, 1, true), m.ligne(y)) end
    m = dessiner(39, 19, { sens = "bilan" })
    _, y = m.chercher("Iron Ingot")
    local _, signes = m.ligne(y):gsub("[%+%-]%d", "")
    verif.egal(signes, 1, m.ligne(y))
  end,

  la_mini_courbe_des_10_minutes_suit_la_largeur = function()
    local m = dessiner(100, 38)
    local _, y = m.chercher("# Objet")
    verif.vrai(m.ligne(y):find("10 min", 1, true), m.ligne(y))
    m = dessiner(164, 81, { sens = "bilan" })
    _, y = m.chercher("# Objet")
    verif.vrai(m.ligne(y):find("Net 10 min", 1, true), m.ligne(y))
  end,

  un_debit_partiel_est_precede_d_un_tilde = function()
    present(dessiner(100, 38, { duree = 300 }), "~+")
  end,

  toucher_une_ligne_choisit_son_objet_et_reset_vise_l_objet_choisi = function()
    for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
      local m, etat = dessiner(taille[1], taille[2], { selection = FER })
      verif.egal(toucher(m, etat, "Osmium Ingot"), { type = "selection", cle = "mekanism:ingot_osmium|" })
      verif.egal(toucher(m, etat, "Reset"), { type = "reset", cle = FER })
    end
  end,

  sans_selection_le_detail_montre_la_premiere_ligne = function()
    local m = dessiner(100, 38)
    local _, y = m.chercher("Reset")
    verif.vrai(m.ligne(y):find("Certus Quartz Crystal", 1, true), m.ligne(y))
  end,

  liste_qui_deborde_est_paginee_et_la_commande_touchable = function()
    local m, etat = dessiner(51, 19, { objets_en_plus = 12 })
    local x, y = m.chercher("1 / ")
    verif.vrai(x, m.texte())
    verif.egal(vues.action_touchee(m, etat, x + 6, y), { type = "pagination", liste = "tout", page = 2 })
    present(dessiner(51, 19, { objets_en_plus = 12, pagination = { tout = 2 } }), "2 / ")
  end,

  le_detail_montre_les_trois_fenetres_et_la_conso_seulement_si_activee = function()
    local m = dessiner(100, 38, { selection = FER })
    local _, y = m.chercher("/min ")
    for _, motif in ipairs({ "1 min", "10 min", "1 h" }) do verif.vrai(m.ligne(y):find(motif, 1, true), m.ligne(y)) end
    present(m, "Départ")
    verif.vrai(m.ligne(y + 2):find("Conso", 1, true), m.ligne(y + 2))
    m = dessiner(100, 38, { selection = FER, consommation = false })
    _, y = m.chercher("/min ")
    verif.egal(m.ligne(y + 2):find("Conso", 1, true), nil)
  end,

  la_vue_alertes_donne_le_temps_avant_rupture = function()
    local m = dessiner(100, 38, { onglet = "alertes" })
    present(m, "Alertes de rupture")
    present(m, "Rupture")
    local _, y = m.chercher("Copper Ingot")
    verif.vrai(m.ligne(y):find("%d+ min"), m.ligne(y))
  end,

  la_courbe_trace_la_production_en_bon_et_la_consommation_en_mauvais = function()
    local m = dessiner(100, 38, { selection = FER })
    local _, haut = m.chercher("max ")
    local _, bas = m.chercher("maintenant")
    local trouvees = couleurs(m, 56, haut + 1, 99, bas - 1)
    verif.vrai(trouvees[colors.lime] and trouvees[colors.red], "production et consommation tracées")
    m = dessiner(100, 38, { selection = FER, consommation = false })
    trouvees = couleurs(m, 56, haut + 1, 99, bas - 1)
    verif.vrai(trouvees[colors.lime] and not trouvees[colors.red], "production seule")
  end,

  un_pic_isole_est_plafonne_marque_et_son_vrai_maximum_affiche = function()
    local etat = exemple.etat({ selection = exemple.PIC })
    local prepare = courbe.preparer(etat, exemple.PIC, 120)
    verif.vrai(prepare.plafond < prepare.maximum / 3, "le pic ne fixe pas l'échelle")
    verif.vrai(next(prepare.plafonnes) ~= nil)
    local m = moniteur.nouveau(100, 38)
    vues.dessiner(m, etat)
    local x, y = m.chercher(vers_cc("max " .. require("production.vues.base").texte_absolu(prepare.maximum, "min")))
    verif.vrai(x, m.texte())
    verif.egal(m.couleur_texte(x, y), colors.yellow)
  end,

  la_courbe_vient_des_cases_de_flux_et_reste_stable_d_une_mesure_a_l_autre = function()
    local etat = exemple.etat()
    local avant = courbe.preparer(etat, FER, 120)
    flux.noter(etat.flux, etat.flux.base, exemple.INSTANT + 10, { seuil_coupure = 0.2, delai_aller_retour = 0 })
    etat.instant = exemple.INSTANT + 10
    local apres = courbe.preparer(etat, FER, 120)
    for k = 1, #avant.production - 1 do
      verif.egal(apres.production[k], avant.production[k + 1], "point " .. k)
      verif.egal(apres.consommation[k], avant.consommation[k + 1], "point " .. k)
    end
  end,

  une_case_sans_donnee_n_est_pas_un_zero = function()
    local etat = exemple.etat({ duree = 300 })
    local prepare = courbe.preparer(etat, FER, 120)
    verif.egal(prepare.production[1], false)
    verif.vrai(type(prepare.production[#prepare.production]) == "number")
  end,

  les_graduations_sont_rondes_et_reduites_sur_petite_hauteur = function()
    verif.egal(courbe.graduations(700, 8), { 200, 400, 600 })
    verif.egal(courbe.graduations(100, 8), { 50, 100 })
    verif.egal(courbe.graduations(0.37, 8), { 0.1, 0.2, 0.3 })
    verif.egal(courbe.graduations(7, 3), { 5 })
    verif.egal(courbe.graduations(7, 1), {})
    verif.egal(courbe.graduations(0, 8), {})
  end,

  les_reperes_du_temps_vont_par_5_min_ou_par_15_min = function()
    verif.egal(courbe.reperes(600), { { 600, "-10 min" }, { 300, "-5 min" }, { 0, "maintenant" } })
    verif.egal(courbe.reperes(3600), { { 3600, "-60 min" }, { 2700, "-45 min" }, { 1800, "-30 min" },
      { 900, "-15 min" }, { 0, "maintenant" } })
  end,

  la_courbe_d_une_heure_a_ses_reperes_par_15_min = function()
    local m = dessiner(164, 81, { fenetre = 3600 })
    present(m, "-60 min")
    present(m, "-30 min")
  end,

  messages_d_etat_courts_sans_donnee_ou_sans_objet = function()
    present(dessiner(100, 38, { phase = "attente" }), "Première mesure dans 4 s.")
    present(dessiner(26, 12, { phase = "base" }), "Base prise")
    present(dessiner(72, 26, { vide = true }), "Aucun objet suivi.")
  end,

  erreurs_et_coupure_sont_affichees = function()
    local m = dessiner(100, 38, { erreurs = { "ME Bridge absent", "Lecture ignorée : réseau AE incomplet" } })
    present(m, "! ME Bridge absent")
    present(m, "! Lecture ignorée : réseau AE incomplet")
  end,

  les_tuiles_ne_paraissent_que_sur_un_grand_ecran = function()
    present(dessiner(100, 38), "Types actifs")
    absent(dessiner(72, 26), "Types actifs")
  end,

  la_vue_tout_cache_les_objets_immobiles_et_suivis_les_garde = function()
    absent(dessiner(164, 81), "Cobblestone")
    local m = dessiner(164, 81, { onglet = "suivis" })
    present(m, "Allthemodium Comb")
  end,

  les_reperes_de_temps_sont_centres_sauf_le_premier_et_maintenant = function()
    local places = courbe.placer_reperes(3600, 60)
    verif.egal(#places, 5)
    verif.egal(places[1].debut, places[1].colonne)
    for i = 2, 4 do
      verif.egal(places[i].debut + math.floor(#places[i].texte / 2), places[i].colonne, places[i].texte)
    end
    verif.egal(places[5].debut + #places[5].texte, 60)
  end,

  des_reperes_qui_se_touchent_sont_retires_un_sur_deux = function()
    local places = courbe.placer_reperes(3600, 34)
    local textes = {}
    for i, place in ipairs(places) do
      textes[i] = place.texte
      if i > 1 then verif.vrai(places[i - 1].debut + #places[i - 1].texte < place.debut, place.texte) end
    end
    verif.egal(textes, { "-60 min", "-30 min", "maintenant" })
    verif.egal(#courbe.placer_reperes(600, 10), 1)
  end,

  les_graduations_sont_un_pointille_serre_sur_toute_la_largeur = function()
    local m = dessiner(100, 38, { selection = FER })
    local _, haut = m.chercher("max ")
    local plus = 0
    for py = haut * 3 + 1, 37 * 3 do
      local brun = 0
      for px = 112, 198 do
        local ok, couleur = pcall(m.pixel, px, py)
        if ok and couleur == colors.lightGray then brun = brun + 1 end
      end
      plus = math.max(plus, brun)
    end
    verif.vrai(plus >= 30, "pixels de graduation sur une rangée : " .. plus)
  end,

  deux_cases_separent_les_groupes_de_commandes = function()
    local m = dessiner(100, 38)
    local x, y = m.chercher("/h")
    verif.egal(m.couleur_fond(x + 3, y), colors.black)
    verif.egal(m.couleur_fond(x + 4, y), colors.black)
    verif.vrai(m.couleur_fond(x + 5, y) ~= colors.black)
  end,
}
