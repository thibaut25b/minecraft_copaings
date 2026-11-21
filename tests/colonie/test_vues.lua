-- Le tableau de bord montre ce qui bloque en premier, ne déborde jamais et ne plante pas sur des données absentes.

colors = require("faux.couleurs")

local verif = require("verif")
local vues = require("colonie.vues")
local moniteur = require("faux.moniteur")

local PAGES = { "resume", "requetes", "travaux", "habitants" }

local function ligne_passe(demandeur, statut, livre, quantite, message)
  return {
    requete = { id = demandeur, libelle = "Planches", demandeur = demandeur, quantite = quantite or 16,
      quantite_min = 1, candidats = { "minecraft:oak_planks" }, equipement = false },
    action = { type = "livrer", quantite = 0, raison = "" },
    statut = statut, livre = livre or 0, message = message or "",
  }
end

local function nouvelle_colonie()
  return {
    nom = "Aubepine", style = "medieval", bonheur = 7.4, citoyens = 23, limite = 25, tombes = 0, visiteurs = 2,
    raid = false, chantiers = 1,
    travaux = { { id = 3, batiment = "Builder's Hut", type = "amélioration", niveau = 2, constructeur = "Lea", pris = true } },
    habitants = { { nom = "Lea", metier = "Builder", etat = "Working", sante = 20, sante_max = 20, loge = true,
      employe = true } },
  }
end

local function nouvel_etat(page)
  return { heure = "12:30", page = page or "resume", colonie = nouvelle_colonie(), lignes = {},
    prochaine_passe = 12, erreurs = {} }
end

local function etat_charge(page)
  local etat = nouvel_etat(page)
  etat.colonie.raid = true
  etat.erreurs = { "Pont ME introuvable", "Integrateur muet", "Troisieme", "Quatrieme", "Cinquieme" }
  for i = 1, 30 do
    etat.lignes[i] = ligne_passe("Demandeur numero " .. i, i % 2 == 0 and "manquant" or "livre", i, 40,
      "un message assez long pour ne pas tenir")
    etat.colonie.travaux[i] = { id = i, batiment = "Batiment tres long " .. i, type = "construction", niveau = i,
      constructeur = "Constructeur " .. i, pris = i % 2 == 0 }
    etat.colonie.habitants[i] = { nom = "Habitant " .. i, metier = "Mineur", etat = "Working", sante = i,
      sante_max = 20, loge = i % 3 ~= 0, employe = i % 4 ~= 0 }
  end
  return etat
end

local function dessiner(largeur, hauteur, etat)
  local m = moniteur.nouveau(largeur, hauteur)
  vues.dessiner(m, etat)
  return m
end

local function ordonnee(m, motif)
  local _, y = m.chercher(motif)
  verif.vrai(y, "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
  return y
end

local function couleur_de(m, motif)
  local x, y = m.chercher(motif)
  verif.vrai(x, "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
  return m.couleur_texte(x, y)
end

return {
  aucun_ecrit_hors_de_la_cible_sur_un_moniteur_minuscule_pour_les_quatre_pages = function()
    for _, taille in ipairs({ { 1, 1 }, { 2, 2 }, { 3, 5 }, { 6, 3 }, { 10, 4 }, { 14, 6 } }) do
      for _, page in ipairs(PAGES) do
        local m = dessiner(taille[1], taille[2], etat_charge(page))
        verif.egal(m.debordements, 0, page .. " sur " .. taille[1] .. "x" .. taille[2])
      end
    end
  end,

  aucun_ecrit_hors_de_la_cible_du_petit_au_grand_moniteur = function()
    for _, taille in ipairs({ { 26, 12 }, { 50, 19 }, { 80, 40 }, { 164, 81 } }) do
      for _, page in ipairs(PAGES) do
        local m = dessiner(taille[1], taille[2], etat_charge(page))
        verif.egal(m.debordements, 0, page .. " sur " .. taille[1] .. "x" .. taille[2])
      end
    end
  end,

  titre_porte_le_nom_a_gauche_et_l_heure_a_droite = function()
    local m = dessiner(40, 12, nouvel_etat())
    verif.egal(m.ligne(1):sub(1, 8), "Aubepine")
    verif.egal(m.ligne(1):sub(-5), "12:30")
  end,

  pied_donne_le_compte_a_rebours_de_la_prochaine_passe = function()
    local m = dessiner(40, 12, nouvel_etat())
    verif.vrai(m.ligne(12):find("12 s", 1, true))
  end,

  les_lignes_a_problemes_passent_en_premier_dans_les_requetes = function()
    local etat = nouvel_etat("requetes")
    etat.lignes = {
      ligne_passe("Alice", "livre", 16),
      ligne_passe("Bob", "manquant"),
      ligne_passe("Carl", "partiel", 4),
      ligne_passe("Dan", "erreur", 0, 16, "pont ME"),
      ligne_passe("Eve", "en_fabrication"),
    }
    local m = dessiner(60, 14, etat)
    verif.vrai(ordonnee(m, "Bob") < ordonnee(m, "Dan"), "l'ordre d'origine est conservé entre problèmes")
    verif.vrai(ordonnee(m, "Dan") < ordonnee(m, "Alice"))
    verif.vrai(ordonnee(m, "Dan") < ordonnee(m, "Carl"))
    verif.vrai(ordonnee(m, "Alice") < ordonnee(m, "Carl"), "le reste garde son ordre")
  end,

  les_habitants_sans_logis_ou_sans_emploi_passent_en_premier = function()
    local etat = nouvel_etat("habitants")
    local function habitant(nom, loge, employe)
      return { nom = nom, metier = "Mineur", etat = "Idle", sante = 20, sante_max = 20, loge = loge, employe = employe }
    end
    etat.colonie.habitants = { habitant("Zoe", true, true), habitant("Yan", false, true), habitant("Xia", true, false) }
    local m = dessiner(60, 12, etat)
    verif.vrai(ordonnee(m, "Yan") < ordonnee(m, "Zoe"))
    verif.vrai(ordonnee(m, "Xia") < ordonnee(m, "Zoe"))
    verif.vrai(m.ligne(ordonnee(m, "Yan")):find("logis", 1, true))
    verif.vrai(m.ligne(ordonnee(m, "Xia")):find("emploi", 1, true))
    verif.egal(couleur_de(m, "logis"), colors.orange)
  end,

  les_chantiers_en_attente_de_constructeur_passent_en_premier = function()
    local etat = nouvel_etat("travaux")
    etat.colonie.travaux = {
      { id = 1, batiment = "Ferme", type = "construction", niveau = 1, constructeur = "Lea", pris = true },
      { id = 2, batiment = "Mine", type = "construction", niveau = 1, constructeur = "", pris = false },
    }
    local m = dessiner(60, 12, etat)
    verif.vrai(ordonnee(m, "Mine") < ordonnee(m, "Ferme"))
    verif.egal(couleur_de(m, "en attente"), colors.yellow)
    verif.egal(couleur_de(m, "en cours"), colors.lime)
  end,

  bandeau_de_raid_rouge_quand_la_colonie_est_attaquee = function()
    local etat = nouvel_etat()
    etat.colonie.raid = true
    local m = dessiner(40, 12, etat)
    local y = ordonnee(m, "RAID")
    verif.egal(m.couleur_fond(1, y), colors.red)
    verif.egal(m.couleur_fond(40, y), colors.red)
    verif.egal(m.couleur_texte(math.floor(40 / 2), y), colors.white)
  end,

  pas_de_bandeau_de_raid_quand_la_colonie_est_calme = function()
    local m = dessiner(40, 12, nouvel_etat())
    verif.egal(m.chercher("RAID"), nil)
  end,

  les_erreurs_s_affichent_en_bandeau_sans_masquer_les_onglets = function()
    local etat = nouvel_etat()
    etat.erreurs = { "Pont ME introuvable" }
    local m = dessiner(50, 12, etat)
    verif.vrai(m.ligne(2):find("Habitants", 1, true), "onglets intacts")
    verif.vrai(ordonnee(m, "Pont ME introuvable") > 2)
    verif.egal(couleur_de(m, "Pont ME"), colors.orange)
  end,

  trop_d_erreurs_sont_repliees_en_nombre_restant = function()
    local etat = nouvel_etat()
    etat.erreurs = { "e1", "e2", "e3", "e4", "e5" }
    local m = dessiner(40, 12, etat)
    verif.vrai(m.chercher("e1"))
    verif.egal(m.chercher("e4"), nil)
    verif.vrai(m.chercher("+ 4 autres erreurs"))
  end,

  colonie_nil_ne_plante_pas_et_le_dit_sur_les_pages_qui_en_dependent = function()
    for _, page in ipairs({ "resume", "travaux", "habitants" }) do
      local etat = nouvel_etat(page)
      etat.colonie = nil
      local m = dessiner(40, 12, etat)
      verif.vrai(m.chercher("Colonie illisible"), page)
      verif.egal(m.debordements, 0)
    end
  end,

  colonie_nil_laisse_la_page_requetes_utilisable = function()
    local etat = nouvel_etat("requetes")
    etat.colonie = nil
    etat.lignes = { ligne_passe("Alice", "livre", 16) }
    local m = dessiner(60, 12, etat)
    verif.vrai(m.chercher("Alice"))
    verif.egal(m.chercher("illisible"), nil)
  end,

  liste_vide_affiche_un_message_et_pas_un_tableau = function()
    local m = dessiner(40, 12, nouvel_etat("requetes"))
    verif.vrai(m.chercher("Aucune requ"))
    verif.egal(m.chercher("Statut"), nil)
    local etat = nouvel_etat("travaux")
    etat.colonie.travaux = {}
    verif.vrai(dessiner(40, 12, etat).chercher("Aucun chantier"))
    etat = nouvel_etat("habitants")
    etat.colonie.habitants = {}
    verif.vrai(dessiner(40, 12, etat).chercher("Aucun habitant"))
  end,

  resume_sans_requete_dit_aucune_requete_en_cours = function()
    verif.vrai(dessiner(40, 12, nouvel_etat()).chercher("Aucune requ"))
  end,

  resume_situe_chaque_valeur_avec_une_barre = function()
    local m = dessiner(40, 12, nouvel_etat())
    verif.vrai(m.chercher("7.4/10"))
    verif.vrai(m.chercher("23/25"))
    local y = ordonnee(m, "23/25")
    local barre = 0
    for x = 1, 40 do
      if m.couleur_fond(x, y) == colors.cyan then barre = barre + 1 end
    end
    verif.vrai(barre > 0, "barre de citoyens colorée")
  end,

  bonheur_change_de_couleur_selon_le_niveau = function()
    local etat = nouvel_etat()
    etat.colonie.bonheur = 8.5
    verif.egal(couleur_de(dessiner(40, 12, etat), "8.5/10"), colors.lime)
    etat.colonie.bonheur = 5
    verif.egal(couleur_de(dessiner(40, 12, etat), "5.0/10"), colors.yellow)
    etat.colonie.bonheur = 2
    verif.egal(couleur_de(dessiner(40, 12, etat), "2.0/10"), colors.red)
  end,

  resume_donne_les_requetes_livrees_sur_le_total = function()
    local etat = nouvel_etat()
    etat.lignes = { ligne_passe("A", "livre", 16), ligne_passe("B", "livre", 16), ligne_passe("C", "manquant") }
    local m = dessiner(50, 14, etat)
    verif.vrai(m.chercher("2/3"))
  end,

  un_statut_a_la_meme_couleur_sur_toutes_les_pages = function()
    local etat = nouvel_etat()
    etat.lignes = { ligne_passe("Alice", "manquant"), ligne_passe("Bob", "livre", 16) }
    local resume = dessiner(60, 16, etat)
    etat.page = "requetes"
    local requetes = dessiner(60, 16, etat)
    verif.egal(couleur_de(resume, "manquant"), colors.red)
    verif.egal(couleur_de(requetes, "manquant"), colors.red)
    verif.egal(couleur_de(resume, "1  livr\233"), colors.lime)
    verif.egal(couleur_de(requetes, "livr\233"), colors.lime)
  end,

  statut_inconnu_ne_plante_pas = function()
    local etat = nouvel_etat("requetes")
    etat.lignes = { ligne_passe("Alice", "bizarre") }
    verif.vrai(dessiner(60, 12, etat).chercher("bizarre"))
  end,

  page_inconnue_retombe_sur_le_resume = function()
    local m = dessiner(40, 12, nouvel_etat("nimporte"))
    verif.vrai(m.chercher("Bonheur"))
  end,

  liste_trop_longue_indique_combien_de_lignes_restent = function()
    local etat = nouvel_etat("requetes")
    for i = 1, 30 do etat.lignes[i] = ligne_passe("Demandeur " .. i, "livre", 16) end
    local m = dessiner(60, 12, etat)
    -- corps de 9 lignes : titres, 7 lignes, indication
    verif.vrai(m.chercher("+ 23 autres"))
    verif.vrai(m.chercher("Demandeur 7"))
    verif.egal(m.chercher("Demandeur 8"), nil)
  end,

  l_onglet_touche_donne_la_page = function()
    local m = moniteur.nouveau(80, 24)
    verif.egal(vues.page_touchee(m, 3, 2), "resume")
    verif.egal(vues.page_touchee(m, 15, 2), "requetes")
    verif.egal(vues.page_touchee(m, 25, 2), "travaux")
    verif.egal(vues.page_touchee(m, 35, 2), "habitants")
  end,

  hors_des_onglets_aucune_page_n_est_touchee = function()
    local m = moniteur.nouveau(80, 24)
    verif.egal(vues.page_touchee(m, 9, 2), nil)
    verif.egal(vues.page_touchee(m, 60, 2), nil)
    verif.egal(vues.page_touchee(m, 3, 1), nil)
    verif.egal(vues.page_touchee(m, 3, 10), nil)
  end,

  la_zone_touchee_correspond_aux_onglets_dessines_sur_petit_moniteur = function()
    local m = dessiner(26, 12, nouvel_etat())
    verif.egal(vues.page_touchee(m, 1, 2), "resume")
    verif.egal(vues.page_touchee(m, 26, 2), "habitants")
  end,
}
