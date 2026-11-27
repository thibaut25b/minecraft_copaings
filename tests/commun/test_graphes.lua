-- Les graphiques restent dans leur cadre quelles que soient les valeurs et se comportent aux bornes.

colors = require("faux.couleurs")

local verif = require("verif")
local pixels = require("commun.pixels")
local graphes = require("commun.graphes")
local moniteur = require("faux.moniteur")

local CASES_X, CASES_Y = 20, 10
local LARGEUR, HAUTEUR = CASES_X * 2, CASES_Y * 3

local function nouvelle()
  return pixels.creer(CASES_X, CASES_Y)
end

-- Liste des pixels de la toile ayant la couleur donnée : { x, y }.
local function allumes(toile, couleur)
  local m = moniteur.nouveau(CASES_X, CASES_Y)
  toile.rendre(m, 1, 1)
  local liste = {}
  for y = 1, HAUTEUR do
    for x = 1, LARGEUR do
      if m.pixel(x, y) == couleur then liste[#liste + 1] = { x, y } end
    end
  end
  return liste
end

local function lit(toile, x, y)
  local m = moniteur.nouveau(CASES_X, CASES_Y)
  toile.rendre(m, 1, 1)
  return m.pixel(x, y)
end

local function dans_le_cadre(liste, cadre)
  for _, p in ipairs(liste) do
    if p[1] < cadre.x or p[1] > cadre.x + cadre.largeur - 1 or p[2] < cadre.y or p[2] > cadre.y + cadre.hauteur - 1 then
      return false, p[1] .. "," .. p[2]
    end
  end
  return true
end

local function colonne(liste, x)
  local nombre = 0
  for _, p in ipairs(liste) do
    if p[1] == x then nombre = nombre + 1 end
  end
  return nombre
end

local CADRE = { x = 5, y = 4, largeur = 20, hauteur = 10 }

return {
  courbe_de_liste_vide_ne_dessine_rien_sans_erreur = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, {}, { couleur = colors.red, remplissage = colors.blue })
    verif.egal(#allumes(toile, colors.red), 0)
    verif.egal(#allumes(toile, colors.blue), 0)
  end,

  courbe_d_une_seule_valeur_trace_une_ligne_sur_toute_la_largeur_du_cadre = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, { 7 }, { couleur = colors.red })
    local rouges = allumes(toile, colors.red)
    verif.egal(#rouges, CADRE.largeur)
    verif.vrai(dans_le_cadre(rouges, CADRE))
  end,

  courbe_de_valeurs_toutes_egales_est_une_ligne_a_mi_hauteur = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, { 3, 3, 3, 3 }, { couleur = colors.red })
    local rouges = allumes(toile, colors.red)
    verif.egal(#rouges, CADRE.largeur)
    verif.egal(rouges[1][2], CADRE.y + CADRE.hauteur - 1 - 5)
    verif.vrai(dans_le_cadre(rouges, CADRE))
  end,

  courbe_croissante_va_du_bas_gauche_au_haut_droit_du_cadre = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, { 0, 10 }, { couleur = colors.red })
    verif.egal(lit(toile, CADRE.x, CADRE.y + CADRE.hauteur - 1), colors.red)
    verif.egal(lit(toile, CADRE.x + CADRE.largeur - 1, CADRE.y), colors.red)
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), CADRE))
  end,

  courbe_de_valeurs_negatives_reste_dans_le_cadre = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, { -50, -10, -30, -80, -5 }, { couleur = colors.red, remplissage = colors.blue })
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), CADRE))
    verif.vrai(dans_le_cadre(allumes(toile, colors.blue), CADRE))
    verif.vrai(#allumes(toile, colors.red) >= CADRE.largeur)
  end,

  courbe_avec_valeurs_hors_de_l_echelle_est_bornee_au_cadre = function()
    local toile = nouvelle()
    graphes.courbe(toile, CADRE, { -1000, 1000, 5 }, { couleur = colors.red, min = 0, max = 10 })
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), CADRE))
  end,

  courbe_remplit_sous_la_ligne_et_pas_au_dessus = function()
    local toile = nouvelle()
    -- La ligne est sur la première rangée d'une case : pas de troisième couleur dans la case.
    local cadre = { x = 5, y = 3, largeur = 20, hauteur = 10 }
    graphes.courbe(toile, cadre, { 5, 5 }, { couleur = colors.red, remplissage = colors.blue, min = 0, max = 10 })
    local ligne = cadre.y + cadre.hauteur - 1 - 5
    verif.egal(lit(toile, cadre.x + 3, ligne), colors.red)
    verif.egal(lit(toile, cadre.x + 3, ligne + 1), colors.blue)
    verif.egal(lit(toile, cadre.x + 3, cadre.y + cadre.hauteur - 1), colors.blue)
    verif.egal(lit(toile, cadre.x + 3, ligne - 1), colors.black)
    verif.vrai(dans_le_cadre(allumes(toile, colors.blue), cadre))
  end,

  courbe_dans_un_cadre_degenere_ne_dessine_rien = function()
    local toile = nouvelle()
    graphes.courbe(toile, { x = 5, y = 4, largeur = 0, hauteur = 5 }, { 1, 2 }, { couleur = colors.red })
    graphes.courbe(toile, { x = 5, y = 4, largeur = 5, hauteur = 0 }, { 1, 2 }, { couleur = colors.red })
    graphes.courbe(toile, { x = 5, y = 4, largeur = -3, hauteur = -3 }, { 1, 2 }, { couleur = colors.red })
    verif.egal(#allumes(toile, colors.red), 0)
  end,

  courbe_dans_un_cadre_d_un_pixel_reste_dans_le_cadre = function()
    local toile = nouvelle()
    local cadre = { x = 7, y = 8, largeur = 1, hauteur = 1 }
    graphes.courbe(toile, cadre, { 1, 9, 4 }, { couleur = colors.red })
    verif.egal(#allumes(toile, colors.red), 1)
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), cadre))
  end,

  courbe_dans_un_cadre_qui_depasse_la_toile_ne_sort_pas_de_la_toile = function()
    local toile = nouvelle()
    graphes.courbe(toile, { x = 30, y = 20, largeur = 50, hauteur = 40 }, { 1, 9, 4, 7 }, { couleur = colors.red })
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), { x = 30, y = 20, largeur = 11, hauteur = 11 }))
  end,

  histogramme_donne_a_chaque_barre_une_hauteur_proportionnelle = function()
    local toile = nouvelle()
    local cadre = { x = 3, y = 2, largeur = 11, hauteur = 9 }
    graphes.histogramme(toile, cadre, { 1, 2, 3 }, { couleur = colors.red })
    local rouges = allumes(toile, colors.red)
    verif.egal({ colonne(rouges, 3), colonne(rouges, 7), colonne(rouges, 11) }, { 3, 6, 9 })
    verif.egal(colonne(rouges, 6), 0)
    verif.egal(colonne(rouges, 10), 0)
    verif.vrai(dans_le_cadre(rouges, cadre))
  end,

  courbe_laisse_un_trou_sur_un_point_sans_donnee = function()
    local toile = nouvelle()
    local cadre = { x = 1, y = 1, largeur = LARGEUR, hauteur = HAUTEUR }
    graphes.courbe(toile, cadre, { 1, 1, false, false, 1, 1 }, { couleur = colors.red, min = 0, max = 2 })
    verif.egal(lit(toile, 1, HAUTEUR / 2), colors.red)
    verif.egal(lit(toile, LARGEUR / 2, HAUTEUR / 2), colors.black)
    verif.egal(lit(toile, LARGEUR, HAUTEUR / 2), colors.red)
  end,

  courbe_bornee_au_plafond_reste_dans_le_cadre = function()
    local toile = nouvelle()
    local cadre = { x = 1, y = 1, largeur = LARGEUR, hauteur = HAUTEUR }
    graphes.courbe(toile, cadre, { 1, 50, 1 }, { couleur = colors.red, min = 0, max = 2, remplissage = colors.blue })
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), cadre))
    verif.egal(lit(toile, LARGEUR / 2, 1), colors.red)
  end,

  histogramme_laisse_l_ecart_demande_entre_les_barres = function()
    local toile = nouvelle()
    local cadre = { x = 1, y = 1, largeur = 11, hauteur = 6 }
    graphes.histogramme(toile, cadre, { 4, 4 }, { couleur = colors.red, ecart = 3 })
    local rouges = allumes(toile, colors.red)
    verif.egal({ colonne(rouges, 1), colonne(rouges, 4), colonne(rouges, 5), colonne(rouges, 7), colonne(rouges, 8),
      colonne(rouges, 11) }, { 6, 6, 0, 0, 6, 6 })
  end,

  histogramme_de_liste_vide_ou_de_valeurs_nulles_ne_dessine_rien = function()
    local toile = nouvelle()
    graphes.histogramme(toile, CADRE, {}, { couleur = colors.red })
    graphes.histogramme(toile, CADRE, { 0, 0, 0 }, { couleur = colors.red })
    verif.egal(#allumes(toile, colors.red), 0)
  end,

  histogramme_d_une_seule_valeur_remplit_tout_le_cadre = function()
    local toile = nouvelle()
    graphes.histogramme(toile, CADRE, { 4 }, { couleur = colors.red })
    verif.egal(#allumes(toile, colors.red), CADRE.largeur * CADRE.hauteur)
  end,

  histogramme_de_valeurs_toutes_egales_donne_des_barres_pleines = function()
    local toile = nouvelle()
    graphes.histogramme(toile, CADRE, { 5, 5 }, { couleur = colors.red })
    local rouges = allumes(toile, colors.red)
    verif.egal(colonne(rouges, CADRE.x), CADRE.hauteur)
    verif.vrai(dans_le_cadre(rouges, CADRE))
  end,

  histogramme_de_valeurs_negatives_reste_dans_le_cadre = function()
    local toile = nouvelle()
    graphes.histogramme(toile, CADRE, { -5, -20, 3, -1 }, { couleur = colors.red })
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), CADRE))
    verif.vrai(#allumes(toile, colors.red) > 0)
  end,

  histogramme_avec_plus_de_valeurs_que_de_pixels_reste_dans_le_cadre = function()
    local toile = nouvelle()
    local cadre = { x = 4, y = 3, largeur = 5, hauteur = 6 }
    local valeurs = {}
    for i = 1, 40 do valeurs[i] = i end
    graphes.histogramme(toile, cadre, valeurs, { couleur = colors.red })
    local rouges = allumes(toile, colors.red)
    verif.vrai(#rouges > 0)
    verif.vrai(dans_le_cadre(rouges, cadre))
  end,

  histogramme_tres_petit_valeur_non_nulle_garde_au_moins_un_pixel = function()
    local toile = nouvelle()
    local cadre = { x = 1, y = 1, largeur = 10, hauteur = 10 }
    graphes.histogramme(toile, cadre, { 1, 1000 }, { couleur = colors.red })
    verif.egal(colonne(allumes(toile, colors.red), 1), 1)
  end,

  histogramme_avec_valeur_au_dessus_du_max_est_borne_au_cadre = function()
    local toile = nouvelle()
    graphes.histogramme(toile, CADRE, { 100, -100 }, { couleur = colors.red, min = 0, max = 10 })
    local rouges = allumes(toile, colors.red)
    verif.vrai(dans_le_cadre(rouges, CADRE))
    verif.egal(colonne(rouges, CADRE.x), CADRE.hauteur)
  end,

  anneau_part_du_haut_et_tourne_dans_le_sens_horaire = function()
    local toile = nouvelle()
    graphes.anneau(toile, 20, 20, 10, 8, 0.25, colors.red, colors.blue)
    verif.egal(lit(toile, 21, 12), colors.red)
    verif.egal(lit(toile, 26, 16), colors.red)
    verif.egal(lit(toile, 26, 24), colors.blue)
    verif.egal(lit(toile, 20, 28), colors.blue)
    verif.egal(lit(toile, 14, 20), colors.blue)
  end,

  anneau_a_la_moitie_allume_le_cote_droit_seulement = function()
    local toile = nouvelle()
    graphes.anneau(toile, 20, 20, 10, 3, 0.5, colors.red, colors.blue)
    verif.egal(lit(toile, 29, 20), colors.red)
    verif.egal(lit(toile, 29, 25), colors.red)
    verif.egal(lit(toile, 11, 20), colors.blue)
    verif.egal(lit(toile, 11, 15), colors.blue)
  end,

  anneau_est_creux_selon_son_epaisseur = function()
    local toile = nouvelle()
    graphes.anneau(toile, 20, 20, 10, 3, 1, colors.red)
    verif.egal(lit(toile, 20, 20), colors.black)
    verif.egal(lit(toile, 20, 15), colors.black)
    verif.egal(lit(toile, 29, 20), colors.red)
    verif.egal(lit(toile, 31, 20), colors.black)
  end,

  anneau_ratio_nil_negatif_ou_superieur_a_un_est_borne = function()
    local vide, plein = nouvelle(), nouvelle()
    graphes.anneau(vide, 20, 20, 10, 3, nil, colors.red, colors.blue)
    graphes.anneau(plein, 20, 20, 10, 3, 5, colors.red, colors.blue)
    local negatif = nouvelle()
    graphes.anneau(negatif, 20, 20, 10, 3, -2, colors.red, colors.blue)
    verif.egal(#allumes(vide, colors.red), 0)
    verif.egal(#allumes(negatif, colors.red), 0)
    verif.egal(#allumes(plein, colors.blue), 0)
    verif.vrai(#allumes(plein, colors.red) > 0)
    verif.egal(#allumes(vide, colors.blue), #allumes(plein, colors.red))
  end,

  anneau_ne_depasse_pas_son_rayon = function()
    local toile = nouvelle()
    graphes.anneau(toile, 20, 20, 10, 4, 1, colors.red, colors.blue)
    local cadre = { x = 10, y = 10, largeur = 21, hauteur = 21 }
    verif.vrai(dans_le_cadre(allumes(toile, colors.red), cadre))
    verif.vrai(dans_le_cadre(allumes(toile, colors.blue), cadre))
  end,

  anneau_hors_toile_ou_de_rayon_negatif_ne_deborde_pas = function()
    local toile = nouvelle()
    graphes.anneau(toile, 1, 1, 30, 5, 0.7, colors.red, colors.blue)
    graphes.anneau(toile, -50, 200, 10, 3, 0.5, colors.red)
    graphes.anneau(toile, 20, 20, -4, 3, 0.5, colors.green)
    verif.egal(#allumes(toile, colors.green), 0)
    verif.vrai(#allumes(toile, colors.red) > 0)
  end,

  secteurs_partagent_le_disque_depuis_le_haut_dans_le_sens_horaire = function()
    local toile = nouvelle()
    graphes.secteurs(toile, 20, 20, 10, { { 1, colors.red }, { 1, colors.blue } })
    verif.egal(lit(toile, 25, 20), colors.red)
    verif.egal(lit(toile, 20, 15), colors.red)
    verif.egal(lit(toile, 15, 20), colors.blue)
    verif.egal(lit(toile, 20, 25), colors.blue)
    verif.egal(lit(toile, 20, 20), colors.red)
  end,

  secteurs_proportionnels_aux_valeurs = function()
    local toile = nouvelle()
    graphes.secteurs(toile, 20, 20, 10, { { 3, colors.red }, { 1, colors.blue } })
    verif.egal(lit(toile, 20, 25), colors.red)
    verif.egal(lit(toile, 15, 21), colors.red)
    verif.egal(lit(toile, 17, 15), colors.blue)
    verif.egal(lit(toile, 23, 15), colors.red)
  end,

  secteurs_ignorent_les_valeurs_nulles_ou_negatives = function()
    local toile = nouvelle()
    graphes.secteurs(toile, 20, 20, 10, { { 0, colors.green }, { -5, colors.yellow }, { 2, colors.red } })
    verif.egal(#allumes(toile, colors.green), 0)
    verif.egal(#allumes(toile, colors.yellow), 0)
    verif.egal(lit(toile, 15, 20), colors.red)
    verif.egal(lit(toile, 25, 20), colors.red)
  end,

  secteurs_sans_part_ou_de_total_nul_ne_dessinent_rien = function()
    local toile = nouvelle()
    graphes.secteurs(toile, 20, 20, 10, {})
    graphes.secteurs(toile, 20, 20, 10, { { 0, colors.red } })
    verif.egal(#allumes(toile, colors.red), 0)
  end,

  secteurs_restent_dans_leur_disque_et_dans_la_toile = function()
    local toile = nouvelle()
    graphes.secteurs(toile, 20, 20, 10, { { 1, colors.red }, { 2, colors.blue }, { 3, colors.green } })
    local cadre = { x = 10, y = 10, largeur = 21, hauteur = 21 }
    for _, couleur in ipairs({ colors.red, colors.blue, colors.green }) do
      verif.vrai(dans_le_cadre(allumes(toile, couleur), cadre))
    end
    graphes.secteurs(toile, 1, 1, 50, { { 1, colors.yellow }, { 1, colors.lime } })
    graphes.secteurs(toile, 90, 40, 12, { { 1, colors.pink } })
    verif.egal(#allumes(toile, colors.pink), 0)
  end,
}
