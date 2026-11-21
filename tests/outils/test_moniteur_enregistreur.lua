-- Le moniteur enregistreur se comporte comme un term CC et exporte l'image sans abîmer les octets 128 à 255.

local verif = require("verif")
local moniteur = require("outils.moniteur_enregistreur")

local CHIFFRES_DE_PALETTE = 96

--- Ligne `numero` (à partir de 1) de l'export : octets, couleurs de texte, couleurs de fond (chaînes hexa).
local function ligne_exportee(cible, largeur, numero)
  local export = cible.exporter()
  local debut = CHIFFRES_DE_PALETTE + (numero - 1) * 4 * largeur
  return export:sub(debut + 1, debut + 2 * largeur),
    export:sub(debut + 2 * largeur + 1, debut + 3 * largeur),
    export:sub(debut + 3 * largeur + 1, debut + 4 * largeur)
end

return {
  write_coupe_aux_bords_et_avance_le_curseur = function()
    local cible = moniteur.creer(4, 2)
    cible.setCursorPos(3, 1)
    cible.write("abcd")
    verif.egal((ligne_exportee(cible, 4, 1)), "20206162")
    verif.egal({ cible.getCursorPos() }, { 7, 1 })
  end,

  write_hors_de_la_grille_est_ignore_sans_erreur = function()
    local cible = moniteur.creer(3, 1)
    cible.setCursorPos(1, 5)
    cible.write("zz")
    cible.setCursorPos(-1, 1)
    cible.write("abcde")
    verif.egal((ligne_exportee(cible, 3, 1)), "636465")
  end,

  blit_pose_texte_et_couleurs_et_coupe_aux_bords = function()
    local cible = moniteur.creer(3, 1)
    cible.setCursorPos(2, 1)
    cible.blit("xy", "e1", "0f")
    local octets, couleurs_texte, couleurs_fond = ligne_exportee(cible, 3, 1)
    verif.egal(octets, "207879")
    verif.egal(couleurs_texte, "0e1")
    verif.egal(couleurs_fond, "f0f")
  end,

  blit_coupe_a_droite = function()
    local cible = moniteur.creer(2, 1)
    cible.setCursorPos(2, 1)
    cible.blit("xyz", "000", "fff")
    verif.egal((ligne_exportee(cible, 2, 1)), "2078")
  end,

  blit_de_longueurs_differentes_leve_une_erreur = function()
    local cible = moniteur.creer(3, 1)
    verif.vrai(not pcall(cible.blit, "ab", "0", "0f"))
  end,

  couleurs_courantes_se_lisent_et_s_appliquent_a_write = function()
    local cible = moniteur.creer(2, 1)
    cible.setTextColour(16384)
    cible.setBackgroundColor(8)
    verif.egal({ cible.getTextColor(), cible.getBackgroundColor() }, { 16384, 8 })
    cible.write("a")
    local _, couleurs_texte, couleurs_fond = ligne_exportee(cible, 2, 1)
    verif.egal(couleurs_texte, "e0")
    verif.egal(couleurs_fond, "3f")
  end,

  couleur_invalide_leve_une_erreur = function()
    local cible = moniteur.creer(2, 1)
    verif.vrai(not pcall(cible.setTextColor, 3))
  end,

  palette_par_defaut_est_celle_de_cc = function()
    local cible = moniteur.creer(1, 1)
    local r, v, b = cible.getPaletteColour(2)
    verif.egal({ math.floor(r * 255 + 0.5), math.floor(v * 255 + 0.5), math.floor(b * 255 + 0.5) }, { 0xF2, 0xB2, 0x33 })
    verif.egal(cible.exporter():sub(1, 12), "f0f0f0f2b233")
  end,

  palette_accepte_les_formes_rvb_et_hexa = function()
    local cible = moniteur.creer(1, 1)
    cible.setPaletteColour(1, 1, 0, 0.5)
    local r, v, b = cible.getPaletteColour(1)
    verif.egal({ r, v, b }, { 1, 0, 0.5 })
    cible.setPaletteColor(2, 0x336699)
    verif.egal(cible.exporter():sub(1, 12), "ff0080336699")
  end,

  palette_hors_bornes_leve_une_erreur = function()
    local cible = moniteur.creer(1, 1)
    verif.vrai(not pcall(cible.setPaletteColour, 1, 2, 0, 0))
    verif.vrai(not pcall(cible.setPaletteColour, 1, 0x1000000))
  end,

  export_preserve_les_caracteres_128_a_255_en_ascii_pur = function()
    local cible = moniteur.creer(3, 1)
    cible.write(string.char(128, 159, 255))
    verif.vrai(not cible.exporter():find("[^%w]"))
    verif.egal((ligne_exportee(cible, 3, 1)), "809fff")
  end,

  clear_remplit_avec_le_fond_courant = function()
    local cible = moniteur.creer(2, 2)
    cible.write("ab")
    cible.setBackgroundColor(2)
    cible.clear()
    local octets, _, couleurs_fond = ligne_exportee(cible, 2, 1)
    verif.egal(octets, "2020")
    verif.egal(couleurs_fond, "11")
  end,

  clear_line_n_efface_que_la_ligne_du_curseur = function()
    local cible = moniteur.creer(2, 2)
    cible.write("ab")
    cible.setCursorPos(1, 2)
    cible.write("cd")
    cible.clearLine()
    verif.egal((ligne_exportee(cible, 2, 1)), "6162")
    verif.egal((ligne_exportee(cible, 2, 2)), "2020")
  end,

  get_size_renvoie_la_taille_demandee = function()
    verif.egal({ moniteur.creer(7, 5).getSize() }, { 7, 5 })
  end,
}
