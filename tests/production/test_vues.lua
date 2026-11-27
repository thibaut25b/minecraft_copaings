-- Vues de la production : ce qui est à l'écran à chaque gabarit, et l'action de chaque toucher.

colors = require("faux.couleurs")

local verif = require("verif")
local vues = require("production.vues")
local moniteur = require("faux.moniteur")
local exemple = require("outils.apercus.production.exemple")
local vers_cc = require("commun.texte").vers_cc

local TAILLES = { { 100, 38 }, { 72, 26 }, { 51, 19 }, { 39, 19 }, { 164, 81 }, { 26, 12 }, { 20, 8 } }

local function dessiner(largeur, hauteur, options)
  local m = moniteur.nouveau(largeur, hauteur)
  local etat = exemple.etat(options)
  vues.dessiner(m, etat)
  return m, etat
end

local function present(m, motif)
  verif.vrai(m.chercher(vers_cc(motif)), "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
end

local function toucher(m, etat, motif)
  local x, y = m.chercher(vers_cc(motif))
  verif.vrai(x, "introuvable à l'écran : " .. motif .. "\n" .. m.texte())
  return vues.action_touchee(m, etat, x, y)
end

return {
  aucune_taille_ne_deborde_ni_ne_leve = function()
    for _, taille in ipairs(TAILLES) do
      for _, options in ipairs({ {}, { vide = true }, { objets_en_plus = 20 }, { erreurs = { "a", "b", "c", "d" } } }) do
        local m = dessiner(taille[1], taille[2], options)
        verif.egal(m.debordements, 0, taille[1] .. "x" .. taille[2])
      end
    end
  end,

  riche_montre_bandeau_liste_detail_et_histogramme = function()
    local m = dessiner(100, 38)
    for _, motif in ipairs({ "Production", "14:32", "/s", "/min", "/h", "Objets suivis", "Iron Ingot", "Détail",
      "Débit 10 s", "Débit 1 h", "Depuis le début", "Reset", "Débit par tranche", "production", "consommation",
      "max ", "-10 min", "maintenant" }) do
      present(m, motif)
    end
  end,

  l_unite_active_est_en_evidence = function()
    local m = dessiner(100, 38, { unite = "h" })
    local xh, y = m.chercher("/h")
    local xs = m.chercher("/s")
    verif.egal(m.couleur_fond(xh, y), colors.white)
    verif.vrai(m.couleur_fond(xs, y) ~= colors.white)
  end,

  un_debit_positif_est_vert_et_un_debit_negatif_rouge_dans_la_liste = function()
    local etat = exemple.etat()
    etat.series["minecraft:iron_ingot"] = { { t = 0, n = 0 }, { t = 60, n = 600 } }
    etat.series["minecraft:redstone"] = { { t = 0, n = 600 }, { t = 60, n = 0 } }
    local m = moniteur.nouveau(100, 38)
    vues.dessiner(m, etat)
    local x, y = m.chercher("+600")
    verif.egal(m.couleur_texte(x, y), colors.lime)
    x, y = m.chercher("-600")
    verif.egal(m.couleur_texte(x, y), colors.red)
  end,

  un_debit_partiel_est_precede_d_un_tilde = function()
    local etat = exemple.etat()
    etat.series["minecraft:iron_ingot"] = { { t = 0, n = 0 }, { t = 20, n = 40 } }
    local m = moniteur.nouveau(100, 38)
    vues.dessiner(m, etat)
    present(m, "~+120")
  end,

  l_objet_choisi_est_detaille_et_a_defaut_le_premier = function()
    local m = dessiner(100, 38, { selection = "minecraft:diamond" })
    local _, y = m.chercher("Reset")
    verif.vrai(m.ligne(y):find("Diamond", 1, true), m.ligne(y))
    m = dessiner(100, 38, { selection = "absent" })
    _, y = m.chercher("Reset")
    verif.vrai(m.ligne(y):find("Iron Ingot", 1, true), m.ligne(y))
  end,

  histogramme_colore_la_production_et_la_consommation_differemment = function()
    local etat = exemple.etat({ selection = "minecraft:iron_ingot" })
    local serie = {}
    for t = 0, 600, 2 do serie[#serie + 1] = { t = t, n = t < 300 and t * 5 or 1500 - (t - 300) * 5 } end
    etat.series["minecraft:iron_ingot"] = serie
    local m = moniteur.nouveau(100, 38)
    vues.dessiner(m, etat)
    local vert, rouge = false, false
    for x = 1, 200 do
      for y = 60, 114 do
        local _, couleur = pcall(m.pixel, x, y)
        if couleur == colors.lime then vert = true end
        if couleur == colors.red then rouge = true end
      end
    end
    verif.vrai(vert and rouge, "production en vert et consommation en rouge")
  end,

  toucher_un_bouton_d_unite_la_choisit_sur_chaque_gabarit = function()
    for _, taille in ipairs({ { 100, 38 }, { 51, 19 }, { 26, 12 } }) do
      local m, etat = dessiner(taille[1], taille[2])
      verif.egal(toucher(m, etat, "/h"), { type = "unite", unite = "h" }, taille[1] .. "x" .. taille[2])
      verif.egal(toucher(m, etat, "/s"), { type = "unite", unite = "s" })
    end
  end,

  toucher_une_ligne_choisit_son_objet_et_reset_demande_la_remise_a_zero = function()
    for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
      local m, etat = dessiner(taille[1], taille[2])
      verif.egal(toucher(m, etat, "Gold Ingot"), { type = "selection", objet = "minecraft:gold_ingot" })
      verif.egal(toucher(m, etat, "Reset"), { type = "reset", objet = "minecraft:iron_ingot" })
    end
  end,

  liste_qui_deborde_est_paginee_et_la_commande_touchable = function()
    local m, etat = dessiner(51, 19, { objets_en_plus = 6 })
    present(m, "1 / 3")
    local x, y = m.chercher("1 / 3")
    verif.egal(vues.action_touchee(m, etat, x + 6, y), { type = "pagination", liste = "objets", page = 2 })
    m = dessiner(51, 19, { objets_en_plus = 6, pagination = { objets = 2 } })
    present(m, "2 / 3")
  end,

  erreurs_et_absence_d_objet_sont_affichees = function()
    local m = dessiner(100, 38, { erreurs = { "ME Bridge absent" }, vide = true })
    present(m, "! ME Bridge absent")
    present(m, "Aucun objet suivi")
    present(m, "Coffre modèle")
    present(m, "/production.cfg")
  end,

  sans_objet_le_message_des_deux_methodes_tient_aussi_en_compact = function()
    local m = dessiner(51, 19, { vide = true })
    present(m, "Coffre modèle")
    present(m, "/production.cfg")
  end,
}
