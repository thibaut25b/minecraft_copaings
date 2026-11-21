-- Le tableau de bord montre ce qui bloque en premier, ne déborde jamais et ne plante pas sur des données absentes.

colors = require("faux.couleurs")

local verif = require("verif")
local vues = require("colonie.vues")
local moniteur = require("faux.moniteur")

local PAGES = { "resume", "requetes", "travaux", "chantiers", "habitants" }

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

local function page_touchee(m, etat, x, y)
  local action = vues.action_touchee(m, etat, x, y)
  return action and action.type == "page" and action.page or nil
end

-- Page Chantiers : `nombre` constructeurs (1 par défaut), chacun avec Pierre complète puis Terre en manque.
local function etat_chantiers(options)
  options = options or {}
  local etat = nouvel_etat("chantiers")
  etat.livraison, etat.lignes_chantiers, etat.constructeurs = {}, {}, {}
  if options.illisibles then
    etat.constructeurs = nil
    return etat
  end
  for i = 1, options.nombre or 1 do
    etat.constructeurs[i] = {
      cle = i .. ",64,0", pos = { x = i, y = 64, z = 0 }, nom = "Constructeur " .. i, niveau = i,
      ressources = options.sans_ressources and {} or {
        { item = "minecraft:stone", libelle = "Pierre", besoin = 10, disponible = 10, en_livraison = 0, manque = 0 },
        { item = "minecraft:dirt", libelle = "Terre", besoin = 64, disponible = 8, en_livraison = 0, manque = 56 },
      },
      erreur = options.erreur,
    }
    if options.erreur then etat.constructeurs[i].ressources = {} end
  end
  return etat
end

return {
  aucun_ecrit_hors_de_la_cible_sur_un_moniteur_minuscule_pour_toutes_les_pages = function()
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
    verif.vrai(m.ligne(2):find("Travaux", 1, true), "onglets intacts")
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
    verif.egal(page_touchee(m, nouvel_etat(), 3, 2), "resume")
    verif.egal(page_touchee(m, nouvel_etat(), 15, 2), "requetes")
    verif.egal(page_touchee(m, nouvel_etat(), 25, 2), "travaux")
    verif.egal(page_touchee(m, nouvel_etat(), 35, 2), "chantiers")
    verif.egal(page_touchee(m, nouvel_etat(), 45, 2), "habitants")
  end,

  hors_des_onglets_aucune_page_n_est_touchee = function()
    local m = moniteur.nouveau(80, 24)
    for _, point in ipairs({ { 9, 2 }, { 60, 2 }, { 3, 1 }, { 3, 10 } }) do
      verif.egal(vues.action_touchee(m, nouvel_etat(), point[1], point[2]), nil)
    end
  end,

  la_zone_touchee_correspond_aux_onglets_dessines_sur_petit_moniteur = function()
    local m = dessiner(26, 12, nouvel_etat())
    verif.egal(page_touchee(m, nouvel_etat(), 1, 2), "resume")
    verif.egal(page_touchee(m, nouvel_etat(), 26, 2), "habitants")
  end,

  aucun_ecrit_hors_de_la_cible_sur_la_page_chantiers_dans_tous_les_cas = function()
    local cas = {
      etat_chantiers(),
      etat_chantiers({ nombre = 0 }),
      etat_chantiers({ sans_ressources = true }),
      etat_chantiers({ erreur = "Ressources illisibles : chunk déchargé" }),
      etat_chantiers({ nombre = 40 }),
      etat_chantiers({ illisibles = true }),
    }
    for _, taille in ipairs({ { 1, 1 }, { 6, 3 }, { 14, 6 }, { 26, 12 }, { 50, 19 }, { 164, 81 } }) do
      for i, etat in ipairs(cas) do
        etat.colonie.raid = true
        local m = dessiner(taille[1], taille[2], etat)
        verif.egal(m.debordements, 0, "cas " .. i .. " sur " .. taille[1] .. "x" .. taille[2])
      end
    end
  end,

  chantiers_montrent_un_sous_onglet_par_constructeur_et_le_bouton_du_constructeur_actif = function()
    local etat = etat_chantiers({ nombre = 2 })
    etat.constructeur = "2,64,0"
    local m = dessiner(60, 16, etat)
    local _, y_principal = m.chercher("Chantiers")
    local _, y_lea = m.chercher(" Constructeur 1 ")
    verif.egal({ y_principal, y_lea }, { 2, 3 })
    local x, y = m.chercher(" Constructeur 2 ")
    verif.egal(m.couleur_fond(x, y), colors.white, "le sous-onglet actif est en clair")
    verif.vrai(m.chercher("Constructeur 2 (niveau 2)"), "le titre nomme le constructeur montré")
    local bx, by = m.chercher("Livraison auto : NON")
    verif.egal({ by, m.couleur_fond(bx, by) }, { 4, colors.red })
  end,

  bouton_de_livraison_active_dit_oui_en_vert_et_la_colonne_statut_apparait = function()
    local etat = etat_chantiers()
    etat.livraison["1,64,0"] = true
    etat.lignes_chantiers = { ["1,64,0"] = { ["minecraft:dirt"] = ligne_passe("Lea", "partiel", 8) } }
    local m = dessiner(60, 16, etat)
    local x, y = m.chercher("Livraison auto : OUI")
    verif.egal(m.couleur_fond(x, y), colors.lime)
    verif.vrai(m.chercher("Statut"))
    verif.egal(couleur_de(m, "partiel"), colors.yellow, "même couleur que l'onglet Requêtes")
  end,

  constructeur_desactive_montre_ses_ressources_et_manques_sans_statut = function()
    local m = dessiner(60, 16, etat_chantiers())
    verif.vrai(m.chercher("Terre"))
    verif.vrai(m.chercher("Manque"))
    verif.egal(m.chercher("Statut"), nil)
  end,

  ressources_en_manque_passent_en_premier = function()
    local m = dessiner(60, 16, etat_chantiers())
    verif.vrai(ordonnee(m, "Terre") < ordonnee(m, "Pierre"), "Terre manque, Pierre est complète")
  end,

  chantiers_sans_constructeur_sans_ressource_ou_illisibles_le_disent = function()
    verif.vrai(dessiner(60, 16, etat_chantiers({ nombre = 0 })).chercher("Aucun constructeur"))
    verif.vrai(dessiner(60, 16, etat_chantiers({ sans_ressources = true })).chercher("Aucune ressource"))
    local m = dessiner(60, 16, etat_chantiers({ erreur = "Ressources illisibles : chunk déchargé" }))
    verif.egal(couleur_de(m, "Ressources illisibles"), colors.orange)
    verif.vrai(m.chercher("Livraison auto"), "le bouton reste là")
    verif.vrai(dessiner(60, 16, etat_chantiers({ illisibles = true })).chercher("Constructeurs illisibles"))
  end,

  sur_moniteur_etroit_le_bouton_passe_sous_le_nom = function()
    local m = dessiner(26, 12, etat_chantiers())
    local _, y_nom = m.chercher("Constructeur 1")
    local _, y_bouton = m.chercher("Livraison auto")
    verif.vrai(y_bouton and y_bouton > 4, m.texte())
    verif.vrai(y_nom < y_bouton)
  end,

  trop_de_constructeurs_ajoutent_un_sous_onglet_suivant_et_montrent_l_actif = function()
    local etat = etat_chantiers({ nombre = 40 })
    etat.constructeur = "30,64,0"
    local m = dessiner(60, 16, etat)
    verif.egal(m.ligne(3):sub(1, 3), " > ")
    verif.vrai(m.chercher("Constructeur 30 (niveau 30)"))
    local actif
    for x = 1, 60 do
      if m.couleur_fond(x, 3) == colors.white then actif = actif or x end
    end
    verif.vrai(actif, "le sous-onglet actif est dessiné en clair\n" .. m.texte())
    verif.egal(vues.action_touchee(m, etat, actif, 3), { type = "constructeur", cle = "30,64,0" })
    verif.egal(vues.action_touchee(m, etat, 2, 3), { type = "constructeur", cle = "31,64,0" })
  end,

  toucher_un_sous_onglet_choisit_le_constructeur = function()
    local etat = etat_chantiers({ nombre = 2 })
    local m = dessiner(60, 16, etat)
    local x, y = m.chercher(" Constructeur 2 ")
    verif.egal(vues.action_touchee(m, etat, x + 1, y), { type = "constructeur", cle = "2,64,0" })
  end,

  toucher_le_bouton_bascule_la_livraison_du_constructeur_montre = function()
    for _, largeur in ipairs({ 26, 60 }) do
      local etat = etat_chantiers({ nombre = 2 })
      etat.constructeur = "2,64,0"
      local m = dessiner(largeur, 16, etat)
      local x, y = m.chercher("Livraison auto")
      verif.egal(vues.action_touchee(m, etat, x, y), { type = "livraison", cle = "2,64,0" }, "largeur " .. largeur)
    end
  end,

  hors_page_chantiers_le_bouton_n_est_pas_touchable = function()
    local etat = etat_chantiers()
    local m = dessiner(60, 16, etat)
    local x, y = m.chercher("Livraison auto")
    etat.page = "resume"
    verif.egal(vues.action_touchee(m, etat, x, y), nil)
  end,

  constructeur_actif_disparu_retombe_sur_le_premier = function()
    local etat = etat_chantiers({ nombre = 2 })
    etat.constructeur = "99,64,0"
    verif.vrai(dessiner(60, 16, etat).chercher("Constructeur 1 (niveau 1)"))
  end,
}
