-- La toile de pseudo-pixels code chaque case comme CC (caractères 128 à 159), ne sort jamais de la toile ni de la cible.

colors = require("faux.couleurs")

local verif = require("verif")
local pixels = require("commun.pixels")
local moniteur = require("faux.moniteur")

-- Rend la toile 1 case = 1 case sur un moniteur de même taille.
local function rendue(toile, cases_x, cases_y)
  local m = moniteur.nouveau(cases_x, cases_y)
  toile.rendre(m, 1, 1)
  return m
end

local function compter(m, largeur_px, hauteur_px, couleur)
  local nombre = 0
  for y = 1, hauteur_px do
    for x = 1, largeur_px do
      if m.pixel(x, y) == couleur then nombre = nombre + 1 end
    end
  end
  return nombre
end

local function espion(m)
  local espion_m = { blits = 0, longueurs = {} }
  setmetatable(espion_m, { __index = m })
  function espion_m.blit(texte, texte_hexa, fond_hexa)
    espion_m.blits = espion_m.blits + 1
    espion_m.longueurs[#espion_m.longueurs + 1] = { #texte, #texte_hexa, #fond_hexa }
    m.blit(texte, texte_hexa, fond_hexa)
  end
  return espion_m
end

return {
  creer_donne_deux_pixels_en_largeur_et_trois_en_hauteur_par_case = function()
    local largeur, hauteur = pixels.creer(5, 4).taille()
    verif.egal({ largeur, hauteur }, { 10, 12 })
  end,

  case_pleine_d_une_seule_couleur_est_le_caractere_128_dans_cette_couleur = function()
    local toile = pixels.creer(1, 1, colors.red)
    local m = rendue(toile, 1, 1)
    verif.egal(m.ligne(1), "\128")
    verif.egal(m.couleur_texte(1, 1), colors.red)
    verif.egal(m.couleur_fond(1, 1), colors.red)
  end,

  toile_neuve_est_noire_par_defaut_et_effacer_change_le_fond = function()
    local toile = pixels.creer(1, 1)
    toile.point(1, 1, colors.white)
    toile.effacer(colors.blue)
    local m = rendue(toile, 1, 1)
    verif.egal(compter(m, 2, 3, colors.blue), 6)
    verif.egal(compter(rendue(pixels.creer(1, 1), 1, 1), 2, 3, colors.black), 6)
  end,

  haut_gauche_seul_donne_le_bit_1_en_couleur_de_texte = function()
    local toile = pixels.creer(1, 1)
    toile.point(1, 1, colors.white)
    local m = rendue(toile, 1, 1)
    verif.egal(m.ligne(1), "\129")
    verif.egal(m.couleur_texte(1, 1), colors.white)
    verif.egal(m.couleur_fond(1, 1), colors.black)
  end,

  chaque_sous_pixel_a_son_bit = function()
    local attendus = { { 1, 1, 129 }, { 2, 1, 130 }, { 1, 2, 132 }, { 2, 2, 136 }, { 1, 3, 144 } }
    for _, cas in ipairs(attendus) do
      local toile = pixels.creer(1, 1)
      toile.point(cas[1], cas[2], colors.white)
      verif.egal(rendue(toile, 1, 1).ligne(1), string.char(cas[3]), "sous-pixel " .. cas[1] .. "," .. cas[2])
    end
  end,

  bas_droit_allume_inverse_les_bits_et_echange_texte_et_fond = function()
    local toile = pixels.creer(1, 1)
    toile.point(2, 3, colors.white)
    local m = rendue(toile, 1, 1)
    verif.egal(m.ligne(1), "\159")
    verif.egal(m.couleur_texte(1, 1), colors.black)
    verif.egal(m.couleur_fond(1, 1), colors.white)
    verif.egal(m.pixel(2, 3), colors.white)
    verif.egal(compter(m, 2, 3, colors.white), 1)
  end,

  case_a_deux_couleurs_est_rendue_exactement = function()
    local toile = pixels.creer(1, 1, colors.blue)
    toile.point(2, 1, colors.red)
    toile.point(1, 3, colors.red)
    toile.point(2, 3, colors.red)
    local m = rendue(toile, 1, 1)
    verif.egal({ m.pixel(1, 1), m.pixel(2, 1), m.pixel(1, 2), m.pixel(2, 2), m.pixel(1, 3), m.pixel(2, 3) },
      { colors.blue, colors.red, colors.blue, colors.blue, colors.red, colors.red })
  end,

  case_a_plus_de_deux_couleurs_garde_les_deux_plus_presentes = function()
    local toile = pixels.creer(1, 1, colors.red)
    toile.point(2, 2, colors.blue)
    toile.point(1, 3, colors.blue)
    toile.point(2, 3, colors.green)
    local m = rendue(toile, 1, 1)
    verif.egal(compter(m, 2, 3, colors.green), 0)
    verif.egal(compter(m, 2, 3, colors.red), 3)
    verif.egal(compter(m, 2, 3, colors.blue), 3)
  end,

  sous_pixel_en_trop_prend_la_couleur_retenue_la_plus_proche_et_a_egalite_la_premiere = function()
    local toile = pixels.creer(1, 1, colors.red)
    toile.point(1, 1, colors.red)
    toile.point(2, 2, colors.blue)
    toile.point(1, 3, colors.blue)
    toile.point(2, 3, colors.green)
    local m = rendue(toile, 1, 1)
    verif.egal(m.pixel(2, 3), colors.blue)
    toile.point(2, 3, colors.red)
    toile.point(2, 1, colors.green)
    verif.egal(rendue(toile, 1, 1).pixel(2, 1), colors.red)
  end,

  point_hors_toile_est_ignore_sans_erreur = function()
    local toile = pixels.creer(2, 1)
    toile.point(0, 1, colors.red)
    toile.point(5, 1, colors.red)
    toile.point(1, 0, colors.red)
    toile.point(1, 4, colors.red)
    toile.point(-100, 1e6, colors.red)
    verif.egal(compter(rendue(toile, 2, 1), 4, 3, colors.red), 0)
  end,

  couleur_invalide_leve_une_erreur_claire = function()
    local toile = pixels.creer(1, 1)
    verif.erreur(function() toile.point(1, 1, nil) end, "couleur invalide")
    verif.erreur(function() toile.ligne(1, 1, 2, 2, 3) end, "couleur invalide")
    verif.erreur(function() toile.effacer(7) end, "couleur invalide")
  end,

  ligne_inclut_ses_extremites_et_reste_dans_la_toile = function()
    local toile = pixels.creer(5, 3)
    toile.ligne(1, 1, 10, 9, colors.red)
    local m = rendue(toile, 5, 3)
    verif.egal(m.pixel(1, 1), colors.red)
    verif.egal(m.pixel(10, 9), colors.red)
    verif.egal(compter(m, 10, 9, colors.red), 10)
  end,

  ligne_horizontale_et_verticale_ont_une_longueur_exacte = function()
    local toile = pixels.creer(5, 3)
    toile.ligne(3, 4, 8, 4, colors.red)
    toile.ligne(2, 1, 2, 7, colors.blue)
    local m = rendue(toile, 5, 3)
    verif.egal(compter(m, 10, 9, colors.red), 6)
    verif.egal(compter(m, 10, 9, colors.blue), 7)
  end,

  ligne_dans_le_sens_inverse_donne_le_meme_nombre_de_pixels = function()
    local toile = pixels.creer(5, 3)
    toile.ligne(9, 8, 2, 2, colors.red)
    verif.egal(compter(rendue(toile, 5, 3), 10, 9, colors.red), 8)
  end,

  ligne_qui_sort_de_la_toile_est_coupee_sans_erreur = function()
    local toile = pixels.creer(2, 1)
    toile.ligne(-6, -6, 12, 9, colors.red)
    local m = rendue(toile, 2, 1)
    verif.egal(m.debordements, 0)
    verif.vrai(compter(m, 4, 3, colors.red) > 0)
  end,

  rectangle_plein_remplit_exactement_sa_surface = function()
    local toile = pixels.creer(4, 3)
    toile.rectangle(2, 2, 4, 3, colors.red, true)
    local m = rendue(toile, 4, 3)
    verif.egal(compter(m, 8, 9, colors.red), 12)
    verif.egal(m.pixel(2, 2), colors.red)
    verif.egal(m.pixel(5, 4), colors.red)
    verif.egal(m.pixel(6, 4), colors.black)
  end,

  rectangle_contour_laisse_l_interieur_vide = function()
    local toile = pixels.creer(4, 3)
    toile.rectangle(2, 2, 4, 3, colors.red, false)
    local m = rendue(toile, 4, 3)
    verif.egal(compter(m, 8, 9, colors.red), 10)
    verif.egal(m.pixel(3, 3), colors.black)
    verif.egal(m.pixel(2, 2), colors.red)
  end,

  rectangle_partiellement_hors_toile_est_coupe_aux_bords = function()
    local toile = pixels.creer(2, 1)
    toile.rectangle(-2, -2, 5, 5, colors.red, true)
    toile.rectangle(3, 2, 10, 10, colors.blue, true)
    local m = rendue(toile, 2, 1)
    verif.egal(compter(m, 4, 3, colors.red), 4)
    verif.egal(compter(m, 4, 3, colors.blue), 4)
  end,

  rectangle_sans_largeur_ou_sans_hauteur_n_ecrit_rien = function()
    local toile = pixels.creer(2, 1)
    toile.rectangle(1, 1, 0, 3, colors.red, true)
    toile.rectangle(1, 1, 3, -1, colors.red, false)
    verif.egal(compter(rendue(toile, 2, 1), 4, 3, colors.red), 0)
  end,

  cercle_plein_couvre_son_centre_et_ses_quatre_extremites_sans_depasser = function()
    local toile = pixels.creer(6, 4)
    toile.cercle(6, 6, 4, colors.red, true)
    local m = rendue(toile, 6, 4)
    for _, p in ipairs({ { 6, 6 }, { 10, 6 }, { 2, 6 }, { 6, 2 }, { 6, 10 } }) do
      verif.egal(m.pixel(p[1], p[2]), colors.red, "pixel " .. p[1] .. "," .. p[2])
    end
    verif.egal(m.pixel(11, 6), colors.black)
    verif.egal(m.pixel(6, 11), colors.black)
    verif.egal(m.pixel(10, 10), colors.black)
  end,

  cercle_contour_est_creux_et_ferme = function()
    local toile = pixels.creer(6, 4)
    toile.cercle(6, 6, 4, colors.red, false)
    local m = rendue(toile, 6, 4)
    verif.egal(m.pixel(6, 6), colors.black)
    verif.egal(m.pixel(10, 6), colors.red)
    verif.egal(m.pixel(6, 2), colors.red)
    verif.egal(m.pixel(8, 6), colors.black)
  end,

  cercle_de_rayon_zero_est_un_point_et_rayon_negatif_ne_dessine_rien = function()
    local toile = pixels.creer(2, 1)
    toile.cercle(2, 2, 0, colors.red, true)
    toile.cercle(3, 2, -2, colors.blue, true)
    local m = rendue(toile, 2, 1)
    verif.egal(compter(m, 4, 3, colors.red), 1)
    verif.egal(compter(m, 4, 3, colors.blue), 0)
  end,

  cercle_qui_deborde_de_la_toile_est_coupe_sans_erreur = function()
    local toile = pixels.creer(2, 1)
    toile.cercle(1, 1, 30, colors.red, true)
    toile.cercle(-20, 50, 40, colors.blue, false)
    toile.cercle(4, 3, 8, colors.green, false)
    local m = rendue(toile, 2, 1)
    verif.egal(compter(m, 4, 3, colors.red), 12)
    verif.egal(m.debordements, 0)
  end,

  rendre_ecrit_une_ligne_par_blit_avec_trois_chaines_de_meme_longueur = function()
    local m = espion(moniteur.nouveau(10, 6))
    local toile = pixels.creer(4, 3)
    toile.cercle(4, 4, 3, colors.red, true)
    toile.rendre(m, 2, 3)
    verif.egal(m.blits, 3)
    for _, longueurs in ipairs(m.longueurs) do verif.egal(longueurs, { 4, 4, 4 }) end
  end,

  rendre_place_la_toile_a_la_case_demandee = function()
    local toile = pixels.creer(1, 1)
    toile.point(1, 1, colors.white)
    local m = moniteur.nouveau(5, 3)
    toile.rendre(m, 3, 2)
    verif.egal(m.ligne(2), "  \129  ")
    verif.egal(m.ligne(1), "     ")
  end,

  rendre_est_coupe_aux_bords_de_la_cible_sans_deborder = function()
    local toile = pixels.creer(6, 4, colors.red)
    for _, position in ipairs({ { 1, 1 }, { -2, -1 }, { 5, 3 }, { 4, -3 }, { -9, 1 }, { 1, 9 }, { 20, 20 }, { 0, 0 } }) do
      local m = espion(moniteur.nouveau(8, 4))
      toile.rendre(m, position[1], position[2])
      verif.egal(m.debordements, 0, "position " .. position[1] .. "," .. position[2])
    end
  end,

  rendre_coupe_a_gauche_garde_les_bonnes_cases = function()
    local toile = pixels.creer(3, 1)
    toile.point(3, 1, colors.white)
    toile.point(5, 1, colors.white)
    local m = moniteur.nouveau(4, 1)
    toile.rendre(m, -1, 1)
    verif.egal(m.ligne(1), "\129   ")
    verif.egal(m.debordements, 0)
  end,

  rendre_ecrit_les_couleurs_de_chaque_case_par_blit = function()
    local toile = pixels.creer(2, 1, colors.black)
    toile.point(1, 1, colors.lime)
    toile.rectangle(3, 1, 2, 3, colors.blue, true)
    local m = moniteur.nouveau(2, 1)
    toile.rendre(m, 1, 1)
    verif.egal({ m.couleur_texte(1, 1), m.couleur_fond(1, 1) }, { colors.lime, colors.black })
    verif.egal({ m.couleur_texte(2, 1), m.couleur_fond(2, 1) }, { colors.blue, colors.blue })
  end,

  grande_toile_de_164_sur_81_cases_se_rend_ligne_par_ligne = function()
    local toile = pixels.creer(164, 81, colors.black)
    toile.cercle(164, 121, 100, colors.red, true)
    toile.cercle(164, 121, 60, colors.lime, false)
    toile.ligne(1, 1, 328, 243, colors.blue)
    toile.rectangle(10, 10, 80, 60, colors.yellow, false)
    local m = espion(moniteur.nouveau(164, 81))
    toile.rendre(m, 1, 1)
    verif.egal(m.blits, 81)
    verif.egal(m.debordements, 0)
    for _, longueurs in ipairs(m.longueurs) do verif.egal(longueurs, { 164, 164, 164 }) end
  end,
}
