-- Les primitives de dessin ne débordent jamais de la cible et se comportent aux bornes (ratios, largeurs, hauteurs).

colors = require("faux.couleurs")

local verif = require("verif")
local dessin = require("commun.dessin")
local moniteur = require("faux.moniteur")

local function compter_fond(m, y, largeur, couleur)
  local nombre = 0
  for x = 1, largeur do
    if m.couleur_fond(x, y) == couleur then nombre = nombre + 1 end
  end
  return nombre
end

local COLONNES = {
  { titre = "Nom" },
  { titre = "Qte", largeur = 4, alignement = "droite" },
  { titre = "Note", largeur = 6, facultatif = true },
}

local ONGLETS = { { nom = "a", libelle = "Alpha" }, { nom = "b", libelle = "Beta" } }

return {
  ecrire_place_le_texte_et_sa_couleur = function()
    local m = moniteur.nouveau(10, 2)
    verif.egal(dessin.ecrire(m, 3, 2, "abc", colors.red, colors.blue), 3)
    verif.egal(m.ligne(2), "  abc     ")
    verif.egal(m.couleur_texte(3, 2), colors.red)
    verif.egal(m.couleur_fond(5, 2), colors.blue)
    verif.egal(m.couleur_fond(6, 2), colors.black)
  end,

  ecrire_ne_deborde_jamais_de_la_cible = function()
    local m = moniteur.nouveau(5, 3)
    dessin.ecrire(m, 4, 1, "abcdef")
    dessin.ecrire(m, -1, 2, "abcd")
    dessin.ecrire(m, 1, 0, "haut")
    dessin.ecrire(m, 1, 4, "bas")
    dessin.ecrire(m, 6, 3, "droite")
    verif.egal(m.debordements, 0)
    verif.egal(m.ligne(1), "   ab")
    verif.egal(m.ligne(2), "cd   ")
    verif.egal(m.ligne(3), "     ")
  end,

  ecrire_convertit_les_accents_en_un_seul_caractere_cc = function()
    local m = moniteur.nouveau(4, 1)
    verif.egal(dessin.ecrire(m, 1, 1, "été"), 3)
    verif.egal(m.ligne(1), "\233t\233 ")
  end,

  ecrire_sur_cible_sans_couleur_n_utilise_que_les_gris = function()
    local m = moniteur.nouveau(6, 1, false)
    dessin.ecrire(m, 1, 1, "abc", colors.red, colors.orange)
    verif.egal(m.couleur_fond(1, 1), colors.white)
    verif.egal(m.couleur_texte(1, 1), colors.black)
    dessin.barre(m, 1, 1, 6, 0.5, colors.lime)
    verif.egal(compter_fond(m, 1, 6, colors.white), 3)
  end,

  effacer_remplit_toute_la_cible_avec_le_fond = function()
    local m = moniteur.nouveau(4, 2)
    dessin.ecrire(m, 1, 1, "xxxx", colors.red, colors.blue)
    dessin.effacer(m, colors.gray)
    verif.egal(m.texte(), "    \n    ")
    verif.egal(m.couleur_fond(4, 2), colors.gray)
    verif.egal(m.couleur_fond(1, 1), colors.gray)
  end,

  tronquer_garde_un_texte_qui_tient = function()
    verif.egal(dessin.tronquer("abcde", 5), "abcde")
    verif.egal(dessin.tronquer("abc", 9), "abc")
  end,

  tronquer_finit_par_le_marqueur_et_respecte_la_largeur = function()
    verif.egal(dessin.tronquer("abcdefgh", 5), "abcd~")
    verif.egal(dessin.tronquer("abcdefgh", 5, ".."), "abc..")
    verif.egal(dessin.tronquer("abcdefgh", 1), "~")
    verif.egal(dessin.tronquer("abcdefgh", 0), "")
    verif.egal(dessin.tronquer("abcdefgh", -3), "")
  end,

  tronquer_compte_un_accent_pour_un_caractere = function()
    verif.egal(dessin.tronquer("éééé", 4), "\233\233\233\233")
    verif.egal(dessin.tronquer("ééééé", 4), "\233\233\233~")
  end,

  aligner_donne_toujours_la_largeur_demandee = function()
    verif.egal(dessin.aligner("ab", 5), "ab   ")
    verif.egal(dessin.aligner("ab", 5, "droite"), "   ab")
    verif.egal(dessin.aligner("ab", 5, "centre"), " ab  ")
    verif.egal(dessin.aligner("abcdefgh", 4, "droite"), "abc~")
  end,

  barre_remplit_la_moitie_pour_un_ratio_de_un_demi = function()
    local m = moniteur.nouveau(10, 1)
    dessin.barre(m, 1, 1, 10, 0.5, colors.lime, colors.gray)
    verif.egal(compter_fond(m, 1, 10, colors.lime), 5)
    verif.egal(compter_fond(m, 1, 10, colors.gray), 5)
    verif.egal(m.couleur_fond(5, 1), colors.lime)
    verif.egal(m.couleur_fond(6, 1), colors.gray)
  end,

  barre_ratio_negatif_reste_vide = function()
    local m = moniteur.nouveau(10, 1)
    dessin.barre(m, 1, 1, 10, -2, colors.lime)
    verif.egal(compter_fond(m, 1, 10, colors.lime), 0)
    verif.egal(compter_fond(m, 1, 10, colors.gray), 10)
  end,

  barre_ratio_superieur_a_un_reste_pleine_sans_deborder = function()
    local m = moniteur.nouveau(10, 1)
    dessin.barre(m, 1, 1, 10, 7, colors.lime)
    verif.egal(compter_fond(m, 1, 10, colors.lime), 10)
    verif.egal(m.debordements, 0)
  end,

  barre_ratio_nil_ou_invalide_reste_vide = function()
    local m = moniteur.nouveau(10, 1)
    dessin.barre(m, 1, 1, 10, nil, colors.lime)
    verif.egal(compter_fond(m, 1, 10, colors.lime), 0)
    dessin.barre(m, 1, 1, 10, 0 / 0, colors.lime)
    verif.egal(compter_fond(m, 1, 10, colors.lime), 0)
  end,

  barre_plus_large_que_la_cible_ne_deborde_pas = function()
    local m = moniteur.nouveau(4, 1)
    dessin.barre(m, 3, 1, 10, 1, colors.lime)
    verif.egal(m.debordements, 0)
    verif.egal(compter_fond(m, 1, 4, colors.lime), 2)
  end,

  tableau_affiche_titres_cellules_et_alignement = function()
    local m = moniteur.nouveau(20, 4)
    local affichees, restantes = dessin.tableau(m, 1, 1, 20, 4, COLONNES, {
      { "Pierre", "12" },
      { "Bois", "3" },
    })
    verif.egal({ affichees, restantes }, { 2, 0 })
    verif.egal(m.ligne(1), "Nom       Qte Note  ")
    verif.egal(m.ligne(2), "Pierre     12       ")
    verif.egal(m.ligne(3), "Bois        3       ")
  end,

  tableau_donne_la_couleur_de_chaque_cellule = function()
    local m = moniteur.nouveau(20, 3)
    dessin.tableau(m, 1, 1, 20, 3, COLONNES, { { "Pierre", { texte = "12", couleur = colors.red } } })
    verif.egal(m.couleur_texte(13, 2), colors.red)
    verif.egal(m.couleur_texte(1, 2), colors.white)
  end,

  tableau_etroit_retire_d_abord_les_colonnes_facultatives = function()
    local m = moniteur.nouveau(12, 2)
    dessin.tableau(m, 1, 1, 12, 2, COLONNES, { { "Pierre", "12", "ok" } })
    verif.egal(m.ligne(1), "Nom      Qte")
    verif.egal(m.ligne(2), "Pierre    12")
  end,

  tableau_tronque_une_cellule_trop_longue = function()
    local m = moniteur.nouveau(10, 2)
    dessin.tableau(m, 1, 1, 10, 2, COLONNES, { { "Granite poli", "7" } })
    verif.egal(m.ligne(2), "Gran~    7")
    verif.egal(m.debordements, 0)
  end,

  tableau_qui_deborde_indique_les_lignes_restantes = function()
    local m = moniteur.nouveau(20, 5)
    local lignes = {}
    for i = 1, 10 do lignes[i] = { "ligne" .. i, tostring(i) } end
    local affichees, restantes = dessin.tableau(m, 1, 1, 20, 5, COLONNES, lignes)
    verif.egal({ affichees, restantes }, { 3, 7 })
    verif.vrai(m.ligne(5):find("+ 7 autres", 1, true))
    verif.vrai(m.ligne(4):find("ligne3", 1, true))
  end,

  tableau_sans_place_pour_les_lignes_ne_garde_que_l_indication = function()
    local m = moniteur.nouveau(20, 2)
    local affichees, restantes = dessin.tableau(m, 1, 1, 20, 2, COLONNES, { { "a", "1" }, { "b", "2" }, { "c", "3" } })
    verif.egal({ affichees, restantes }, { 0, 3 })
    verif.vrai(m.ligne(2):find("+ 3 autres", 1, true))
  end,

  tableau_sur_cible_minuscule_ne_deborde_pas = function()
    for _, taille in ipairs({ { 1, 1 }, { 2, 3 }, { 3, 2 }, { 5, 5 } }) do
      local m = moniteur.nouveau(taille[1], taille[2])
      dessin.tableau(m, 1, 1, taille[1], taille[2], COLONNES, { { "Pierre", "12", "ok" }, { "Bois", "3", "ko" } })
      verif.egal(m.debordements, 0, "cible " .. taille[1] .. "x" .. taille[2])
    end
  end,

  tableau_sans_hauteur_ou_sans_largeur_n_ecrit_rien = function()
    local m = moniteur.nouveau(10, 3)
    verif.egal({ dessin.tableau(m, 1, 1, 10, 0, COLONNES, { { "a", "1" } }) }, { 0, 1 })
    verif.egal({ dessin.tableau(m, 1, 1, 0, 3, COLONNES, { { "a", "1" } }) }, { 0, 1 })
    verif.egal(m.texte(), "          \n          \n          ")
  end,

  onglets_renvoient_leurs_zones_cliquables = function()
    local m = moniteur.nouveau(30, 2)
    local zones = dessin.onglets(m, 1, 2, 30, ONGLETS, "a")
    verif.egal(zones, {
      { nom = "a", libelle = "Alpha", x1 = 1, x2 = 7, y = 2 },
      { nom = "b", libelle = "Beta", x1 = 9, x2 = 14, y = 2 },
    })
    verif.egal(m.ligne(2):sub(1, 14), " Alpha   Beta ")
  end,

  onglet_actif_est_en_clair_et_les_autres_en_gris = function()
    local m = moniteur.nouveau(30, 2)
    dessin.onglets(m, 1, 2, 30, ONGLETS, "b")
    verif.egal(m.couleur_fond(2, 2), colors.gray)
    verif.egal(m.couleur_fond(10, 2), colors.white)
    verif.egal(m.couleur_texte(10, 2), colors.black)
  end,

  onglet_sous_point_retrouve_l_onglet_touche = function()
    local zones = dessin.zones_onglets(1, 2, 30, ONGLETS)
    verif.egal(dessin.onglet_sous_point(zones, 1, 2), "a")
    verif.egal(dessin.onglet_sous_point(zones, 7, 2), "a")
    verif.egal(dessin.onglet_sous_point(zones, 9, 2), "b")
    verif.egal(dessin.onglet_sous_point(zones, 14, 2), "b")
  end,

  onglet_sous_point_renvoie_nil_hors_des_onglets = function()
    local zones = dessin.zones_onglets(1, 2, 30, ONGLETS)
    verif.egal(dessin.onglet_sous_point(zones, 8, 2), nil)
    verif.egal(dessin.onglet_sous_point(zones, 15, 2), nil)
    verif.egal(dessin.onglet_sous_point(zones, 3, 1), nil)
    verif.egal(dessin.onglet_sous_point(zones, 3, 3), nil)
  end,

  onglets_raccourcissent_leurs_libelles_quand_la_rangee_est_etroite = function()
    local m = moniteur.nouveau(12, 1)
    local zones = dessin.onglets(m, 1, 1, 12, ONGLETS, "a")
    verif.egal(#zones, 2)
    verif.vrai(zones[2].x2 <= 12)
    verif.egal(m.debordements, 0)
  end,

  onglets_sans_place_sont_omis_sans_deborder = function()
    local m = moniteur.nouveau(5, 1)
    local zones = dessin.onglets(m, 1, 1, 5, ONGLETS, "a")
    verif.egal(#zones, 1)
    verif.vrai(zones[1].x2 <= 5)
    verif.egal(m.debordements, 0)
  end,

  faux_moniteur_compte_les_ecritures_hors_cible_et_gere_blit = function()
    local m = moniteur.nouveau(3, 1)
    m.setCursorPos(2, 1)
    m.write("abc")
    verif.egal(m.debordements, 1)
    m.setCursorPos(1, 1)
    m.blit("xyz", "eee", "000")
    verif.egal(m.ligne(1), "xyz")
    verif.egal(m.couleur_texte(1, 1), colors.red)
    verif.egal(m.couleur_fond(1, 1), colors.white)
  end,
}
