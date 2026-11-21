-- Vues de l'usine : ce qui est à l'écran à chaque gabarit, et l'action de chaque toucher.

colors = require("faux.couleurs")

local verif = require("verif")
local vues = require("usine.vues")
local moniteur = require("faux.moniteur")
local exemple = require("outils.apercus.usine.exemple")
local vers_cc = require("commun.texte").vers_cc

local TAILLES = { { 100, 38 }, { 72, 26 }, { 51, 19 }, { 39, 19 }, { 164, 81 }, { 26, 12 } }

local function dessiner(largeur, hauteur, options)
  local m = moniteur.nouveau(largeur, hauteur)
  local etat = exemple.etat(options)
  vues.dessiner(m, etat)
  return m, etat
end

local function present(m, motif)
  verif.vrai(m.chercher(vers_cc(motif)), "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
end

-- Toucher le texte `motif` là où il est à l'écran.
local function toucher(m, etat, motif)
  local x, y = m.chercher(vers_cc(motif))
  verif.vrai(x, "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
  return vues.action_touchee(m, etat, x, y)
end

return {
  aucune_taille_ne_deborde_ni_ne_leve = function()
    for _, taille in ipairs(TAILLES) do
      local m = dessiner(taille[1], taille[2])
      verif.egal(m.debordements, 0, taille[1] .. "x" .. taille[2])
    end
  end,

  riche_montre_lignes_raisons_jauge_courbe_et_stocks = function()
    local m = dessiner(100, 38)
    for _, motif in ipairs({ "Lignes de production", "Presse à plaques", "stock plein", "délestée", "forcée arrêt",
      "arrêt", "82 %", "13 435 su", "Stress du réseau", "Stocks", "Lingots de zinc" }) do
      present(m, motif)
    end
  end,

  stock_sous_le_seuil_est_en_rouge = function()
    local m = dessiner(100, 38)
    local x, y = m.chercher("Lingots de zinc")
    verif.egal(m.couleur_texte(x, y), colors.red)
    x, y = m.chercher("Engrenages")
    verif.vrai(m.couleur_texte(x, y) ~= colors.red, "un stock au-dessus du seuil n'est pas rouge")
  end,

  compact_montre_le_stress_et_les_lignes = function()
    local m = dessiner(51, 19)
    present(m, "82 %")
    present(m, "délestée")
    present(m, "stocks")
  end,

  stock_inconnu_est_signale_sur_les_lignes = function()
    local m = dessiner(100, 38, { panne_ticker = true, erreurs = { "Stock Ticker introuvable" } })
    present(m, "stock inconnu")
    present(m, "Stock Ticker introuvable")
  end,

  toucher_une_ligne_demande_son_changement_de_mode = function()
    for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
      local m, etat = dessiner(taille[1], taille[2])
      verif.egal(toucher(m, etat, "Four à b"), { type = "mode", ligne = "Four à briques" })
    end
  end,

  toucher_la_jauge_change_de_reseau_seulement_s_il_y_en_a_plusieurs = function()
    local m, etat = dessiner(100, 38, { deux_reseaux = true })
    present(m, "Nord 1/2")
    verif.egal(toucher(m, etat, "Utilisé"), { type = "reseau" })
    m, etat = dessiner(100, 38)
    verif.egal(toucher(m, etat, "Utilisé"), nil)
  end,

  liste_qui_deborde_est_paginee_et_la_commande_touchable = function()
    local m, etat = dessiner(51, 19, { lignes_en_plus = 4 })
    present(m, "1 / 2")
    local x, y = m.chercher("1 / 2")
    local action = vues.action_touchee(m, etat, x + 6, y)
    verif.egal(action, { type = "pagination", liste = "lignes", page = 2 })
    m = dessiner(51, 19, { lignes_en_plus = 4, pagination = { lignes = 2 } })
    present(m, "Ligne annexe 4")
  end,
}
