-- Chaque écran listé se dessine sans erreur ni débordement de 60x24 à 164x81, et son animation boucle sans saut.

colors = require("faux.couleurs")

local verif = require("verif")
local moniteur = require("faux.moniteur")
local noms = require("galerie.ecrans")

local TAILLES = { { 60, 24 }, { 61, 25 }, { 80, 30 }, { 100, 38 }, { 121, 50 }, { 164, 81 } }

local function charger(nom)
  local ecran = require("galerie.ecrans." .. nom)
  verif.egal(type(ecran.dessiner), "function")
  return ecran
end

local function instants(ecran)
  return { 0, 1, math.floor(ecran.images / 2), ecran.images - 1 }
end

-- Caractère et couleurs de chaque case, pour comparer deux images.
local function empreinte(m)
  local largeur, hauteur = m.getSize()
  local morceaux = { m.texte() }
  for y = 1, hauteur do
    for x = 1, largeur do morceaux[#morceaux + 1] = m.couleur_texte(x, y) .. ":" .. m.couleur_fond(x, y) end
  end
  return table.concat(morceaux, ",")
end

return {
  la_liste_finit_par_la_mire_et_chaque_nom_est_unique = function()
    verif.egal(noms[#noms], "mire")
    local vus = {}
    for _, nom in ipairs(noms) do
      verif.vrai(not vus[nom], "écran listé deux fois : " .. nom)
      vus[nom] = true
    end
  end,

  chaque_ecran_porte_son_nom_et_anime_40_a_60_images = function()
    for _, nom in ipairs(noms) do
      local ecran = charger(nom)
      verif.egal(ecran.nom, nom)
      verif.vrai(ecran.images >= 40 and ecran.images <= 60, nom .. " : " .. tostring(ecran.images) .. " images")
    end
  end,

  chaque_ecran_tient_dans_toutes_les_tailles_sans_deborder = function()
    for _, nom in ipairs(noms) do
      local ecran = charger(nom)
      for _, taille in ipairs(TAILLES) do
        for _, t in ipairs(instants(ecran)) do
          local m = moniteur.nouveau(taille[1], taille[2])
          ecran.dessiner(m, t)
          verif.egal(m.debordements, 0, string.format("%s en %dx%d, image %d", nom, taille[1], taille[2], t))
        end
      end
    end
  end,

  l_image_qui_suit_la_derniere_est_la_premiere = function()
    for _, nom in ipairs(noms) do
      local ecran = charger(nom)
      local debut, tour = moniteur.nouveau(100, 38), moniteur.nouveau(100, 38)
      ecran.dessiner(debut, 0)
      ecran.dessiner(tour, ecran.images)
      verif.vrai(empreinte(debut) == empreinte(tour), nom .. " : saut visible en bout de boucle")
    end
  end,

  les_ecrans_de_demonstration_posent_le_theme_nuit = function()
    for _, nom in ipairs({ "usine", "colonie", "trains", "vitrine" }) do
      local m = moniteur.nouveau(100, 38)
      charger(nom).dessiner(m, 0)
      local r, v, b = m.getPaletteColour(colors.black)
      verif.egal(math.floor(r * 255 + 0.5) * 65536 + math.floor(v * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5),
        0x0B1020, nom)
    end
  end,
}
