-- Les thèmes posent une palette complète, lisible, avec les mêmes rôles aux mêmes emplacements, et se restaurent.

colors = require("faux.couleurs")

local verif = require("verif")
local theme = require("commun.theme")
local moniteur = require("faux.moniteur")

-- RVB d'origine de CC, relevés dans la doc CC: Tweaked (module colors).
local ORIGINE = {
  white = 0xF0F0F0, orange = 0xF2B233, magenta = 0xE57FD8, lightBlue = 0x99B2F2,
  yellow = 0xDEDE6C, lime = 0x7FCC19, pink = 0xF2B2CC, gray = 0x4C4C4C,
  lightGray = 0x999999, cyan = 0x4C99B2, purple = 0xB266E5, blue = 0x3366CC,
  brown = 0x7F664C, green = 0x57A64E, red = 0xCC4C4C, black = 0x111111,
}

local function rvb(m, couleur)
  local r, v, b = m.getPaletteColour(couleur)
  return math.floor(r * 255 + 0.5) * 65536 + math.floor(v * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
end

local function composante(valeur)
  valeur = valeur / 255
  if valeur <= 0.03928 then return valeur / 12.92 end
  return ((valeur + 0.055) / 1.055) ^ 2.4
end

local function luminance(valeur)
  local r, v, b = math.floor(valeur / 65536), math.floor(valeur / 256) % 256, valeur % 256
  return 0.2126 * composante(r) + 0.7152 * composante(v) + 0.0722 * composante(b)
end

local function contraste(a, b)
  local clair, sombre = math.max(luminance(a), luminance(b)), math.min(luminance(a), luminance(b))
  return (clair + 0.05) / (sombre + 0.05)
end

local function couleur_du_role(m, role)
  return rvb(m, theme.ROLES[role])
end

local function avec(nom)
  local m = moniteur.nouveau(4, 2)
  theme.appliquer(m, nom)
  return m
end

return {
  noms_contiennent_au_moins_nuit_et_ambre = function()
    local connus = {}
    for _, nom in ipairs(theme.NOMS) do connus[nom] = true end
    verif.vrai(connus.nuit and connus.ambre)
  end,

  roles_donnent_onze_emplacements_de_couleur_cc_distincts = function()
    local vus, nombre = {}, 0
    for role, couleur in pairs(theme.ROLES) do
      verif.vrai(type(couleur) == "number" and couleur >= 1 and couleur <= 32768, role)
      verif.vrai(not vus[couleur], "emplacement partagé : " .. role)
      vus[couleur] = true
      nombre = nombre + 1
    end
    verif.egal(nombre, 11)
    for _, role in ipairs({ "fond", "surface", "bordure", "texte", "discret", "accent", "accent2", "bon", "moyen",
      "mauvais", "info" }) do
      verif.vrai(theme.ROLES[role], role)
    end
  end,

  appliquer_pose_les_seize_couleurs_de_chaque_theme_differemment_de_l_origine = function()
    for _, nom in ipairs(theme.NOMS) do
      local m = avec(nom)
      local differentes = 0
      for emplacement, valeur in pairs(ORIGINE) do
        if rvb(m, colors[emplacement]) ~= valeur then differentes = differentes + 1 end
      end
      verif.vrai(differentes >= 14, nom)
    end
  end,

  appliquer_un_theme_inconnu_leve_une_erreur_claire = function()
    verif.erreur(function() theme.appliquer(moniteur.nouveau(2, 2), "arc-en-ciel") end, "thème inconnu")
  end,

  appliquer_sur_une_cible_sans_setpalettecolour_est_sans_effet = function()
    local cible = {}
    theme.appliquer(cible, "nuit")
    theme.restaurer(cible)
    verif.egal(cible, {})
  end,

  restaurer_remet_la_palette_d_origine_de_cc = function()
    local m = avec("nuit")
    theme.restaurer(m)
    for emplacement, valeur in pairs(ORIGINE) do
      verif.egal(rvb(m, colors[emplacement]), valeur, emplacement)
    end
  end,

  appliquer_puis_changer_de_theme_remplace_toute_la_palette = function()
    local m = avec("nuit")
    theme.appliquer(m, "ambre")
    local ambre = avec("ambre")
    for emplacement in pairs(ORIGINE) do
      verif.egal(rvb(m, colors[emplacement]), rvb(ambre, colors[emplacement]), emplacement)
    end
  end,

  themes_donnent_des_rvb_differents_au_meme_role = function()
    local nuit, ambre = avec("nuit"), avec("ambre")
    verif.vrai(couleur_du_role(nuit, "fond") ~= couleur_du_role(ambre, "fond"))
    verif.vrai(couleur_du_role(nuit, "accent") ~= couleur_du_role(ambre, "accent"))
  end,

  texte_est_lisible_sur_fond_et_sur_surface_dans_chaque_theme = function()
    for _, nom in ipairs(theme.NOMS) do
      local m = avec(nom)
      verif.vrai(contraste(couleur_du_role(m, "texte"), couleur_du_role(m, "fond")) >= 7, nom .. " texte/fond")
      verif.vrai(contraste(couleur_du_role(m, "texte"), couleur_du_role(m, "surface")) >= 5, nom .. " texte/surface")
      verif.vrai(contraste(couleur_du_role(m, "discret"), couleur_du_role(m, "fond")) >= 4, nom .. " discret/fond")
    end
  end,

  fond_surface_bordure_discret_texte_sont_etages_du_plus_sombre_au_plus_clair = function()
    for _, nom in ipairs(theme.NOMS) do
      local m = avec(nom)
      local etage = { "fond", "surface", "bordure", "discret", "texte" }
      for i = 1, #etage - 1 do
        verif.vrai(luminance(couleur_du_role(m, etage[i])) < luminance(couleur_du_role(m, etage[i + 1])),
          nom .. " " .. etage[i] .. " < " .. etage[i + 1])
      end
    end
  end,

  accents_et_etats_sont_lisibles_sur_le_fond_et_les_etats_sont_distincts = function()
    for _, nom in ipairs(theme.NOMS) do
      local m = avec(nom)
      for _, role in ipairs({ "accent", "accent2", "bon", "moyen", "mauvais", "info" }) do
        verif.vrai(contraste(couleur_du_role(m, role), couleur_du_role(m, "fond")) >= 4.5, nom .. " " .. role)
      end
      local etats = { couleur_du_role(m, "bon"), couleur_du_role(m, "moyen"), couleur_du_role(m, "mauvais") }
      verif.vrai(etats[1] ~= etats[2] and etats[2] ~= etats[3] and etats[1] ~= etats[3], nom)
    end
  end,

  nuit_a_un_fond_tres_sombre_legerement_bleute = function()
    local fond = couleur_du_role(avec("nuit"), "fond")
    local r, v, b = math.floor(fond / 65536), math.floor(fond / 256) % 256, fond % 256
    verif.vrai(r < 32 and v < 32 and b < 48)
    verif.vrai(b > r and b >= v)
  end,

  ambre_ne_garde_que_des_teintes_chaudes_sauf_l_etat_bon = function()
    local m = avec("ambre")
    for _, role in ipairs({ "fond", "surface", "bordure", "discret", "texte", "accent", "accent2", "moyen", "mauvais",
      "info" }) do
      local c = couleur_du_role(m, role)
      local r, v, b = math.floor(c / 65536), math.floor(c / 256) % 256, c % 256
      verif.vrai(r >= v and v >= b, "teinte chaude : " .. role)
    end
  end,
}
