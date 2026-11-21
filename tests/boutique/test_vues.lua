-- Tableau de bord : ce qui est à l'écran (articles, rupture, en route, ventes, erreurs) et la pagination au toucher.

local verif = require("verif")
colors = require("faux.couleurs")
local faux_moniteur = require("faux.moniteur")
local vues = require("boutique.vues")

local function article(objet, nom, comptoir, reserve, en_route)
  return { objet = objet, nom = nom, texte = "12c", comptoir = comptoir, reserve = reserve, usine = 300,
    en_route = en_route or 0 }
end

local function etat(articles, dernieres, erreurs)
  return { heure = "14:32", comptoirs = 1, articles = articles, erreurs = erreurs or {}, pagination = {},
    ventes = { recette = 1874, articles = { ["mod:fer"] = { ventes = 2, vendus = 8, recette = 24 } },
      dernieres = dernieres or {} } }
end

local ARTICLES = { article("mod:fer", "Fer", 0, 64), article("mod:or", "Or", 10, 64, 54) }
local VENTE = { heure = "14:31", joueur = "Alice", objet = "mod:fer", quantite = 4, montant = 12, texte = "1i2c" }

local function dessiner(largeur, hauteur, e)
  local m = faux_moniteur.nouveau(largeur, hauteur)
  vues.dessiner(m, e)
  return m
end

return {
  articles_sont_listes_avec_prix_comptoir_reserve_et_recette_totale = function()
    for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
      local m = dessiner(taille[1], taille[2], etat(ARTICLES, { VENTE }))
      local texte = m.texte()
      verif.vrai(texte:find("Recette 1 874", 1, true), texte)
      verif.vrai(texte:find("12c", 1, true), texte)
      verif.vrai(texte:find("10/64", 1, true), texte)
      verif.egal(m.debordements, 0)
    end
  end,

  article_en_rupture_est_en_rouge = function()
    local m = dessiner(100, 38, etat(ARTICLES))
    local x, y = m.chercher("0/64")
    verif.egal(m.couleur_texte(x, y), colors.red)
    local xn, yn = m.chercher("Fer ")
    verif.egal(m.couleur_texte(xn, yn), colors.red)
  end,

  quantite_en_route_est_affichee = function()
    local m = dessiner(100, 38, etat(ARTICLES))
    local _, y = m.chercher("Or ")
    verif.vrai(m.ligne(y):find("54", 1, true), m.ligne(y))
  end,

  dernieres_ventes_montrent_joueur_article_et_montant = function()
    local m = dessiner(51, 19, etat(ARTICLES, { VENTE }))
    local _, y = m.chercher("Alice")
    verif.vrai(m.ligne(y):find("4 x Fer", 1, true), m.ligne(y))
    verif.vrai(m.ligne(y):find("1i2c", 1, true), m.ligne(y))
  end,

  sans_comptoir_l_ecran_dit_quoi_faire = function()
    local e = etat({})
    e.comptoirs = 0
    verif.vrai(dessiner(51, 19, e).chercher("Aucun comptoir"))
    e.comptoirs = 1
    verif.vrai(dessiner(51, 19, e).chercher("Aucune offre"))
  end,

  erreurs_sont_en_bandeau = function()
    local m = dessiner(51, 19, etat(ARTICLES, {}, { "donne la permission openStorage" }))
    verif.vrai(m.chercher("! donne la permission openStorage"))
  end,

  liste_trop_longue_se_pagine_et_le_toucher_change_de_page = function()
    local articles = {}
    for i = 1, 20 do articles[i] = article("mod:o" .. i, ("Objet %02d"):format(i), 5, 64) end
    local e = etat(articles)
    local m = dessiner(51, 19, e)
    verif.vrai(m.chercher("1 / "), m.texte())
    local x, y = m.chercher(string.char(16))
    verif.egal(vues.action_touchee(m, e, x, y), { type = "pagination", page = 2 })
    e.pagination.articles = 2
    m = dessiner(51, 19, e)
    verif.vrai(m.chercher("2 / "), m.texte())
    verif.egal(vues.action_touchee(m, e, 1, 1), nil)
  end,
}
