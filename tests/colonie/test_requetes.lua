-- Normalisation des requêtes MineColonies et règles de décision de la fourniture.

local verif = require("verif")
local requetes = require("colonie.requetes")

local PLANCHE = "minecraft:oak_planks"
local BOULEAU = "minecraft:birch_planks"

local function regles(modifs)
  local r = { fabriquer = true, ignorer_equipement = true, exclusions = {} }
  for cle, valeur in pairs(modifs or {}) do r[cle] = valeur end
  return r
end

local function requete(modifs)
  local r = { id = "r1", libelle = "16 Oak Planks", demandeur = "", quantite = 16, quantite_min = 8,
              candidats = { PLANCHE, BOULEAU }, equipement = false }
  for cle, valeur in pairs(modifs or {}) do r[cle] = valeur end
  return r
end

local function brute(modifs)
  local r = { id = "tok-1", displayName = "16 Oak Planks", description = "", state = "IN_PROGRESS",
              count = 16, minCount = 4, target = { x = 1, y = 64, z = 2 },
              items = { { name = PLANCHE, count = 16, displayName = "Oak Planks", tags = { ["minecraft:planks"] = true } } } }
  for cle, valeur in pairs(modifs or {}) do r[cle] = valeur end
  return r
end

local BATIMENTS = { { pos = { x = 1, y = 64, z = 2 }, type = "builder", level = 1, displayName = "Builder's Hut" } }

return {
  normaliser_nomme_le_demandeur_d_apres_le_batiment_a_la_position_cible = function()
    local liste = requetes.normaliser({ brute() }, BATIMENTS)
    verif.egal(liste, { {
      id = "tok-1", libelle = "16 Oak Planks", demandeur = "Builder's Hut", quantite = 16, quantite_min = 4,
      candidats = { PLANCHE }, equipement = false,
    } })
  end,

  normaliser_garde_une_cible_chaine_comme_demandeur = function()
    local liste = requetes.normaliser({ brute({ target = "Léa" }) }, BATIMENTS)
    verif.egal(liste[1].demandeur, "Léa")
  end,

  normaliser_laisse_le_demandeur_vide_si_aucun_batiment_a_la_position = function()
    local liste = requetes.normaliser({ brute({ target = { x = 9, y = 9, z = 9 } }) }, BATIMENTS)
    verif.egal(liste[1].demandeur, "")
  end,

  normaliser_garde_une_requete_sans_item_avec_candidats_vides = function()
    local sans_liste = brute({ id = "tok-2" })
    sans_liste.items = nil
    local liste = requetes.normaliser({ brute({ items = {} }), sans_liste }, nil)
    verif.egal(#liste, 2)
    verif.egal(liste[1].candidats, {})
    verif.egal(liste[2].candidats, {})
    verif.egal(liste[2].id, "tok-2")
  end,

  normaliser_dedoublonne_les_candidats_dans_l_ordre = function()
    local items = { { name = BOULEAU }, { name = PLANCHE }, { name = BOULEAU }, { count = 3 } }
    verif.egal(requetes.normaliser({ brute({ items = items }) }, {})[1].candidats, { BOULEAU, PLANCHE })
  end,

  normaliser_borne_quantite_min_a_quantite = function()
    local sans_minimum = brute()
    sans_minimum.minCount = nil
    local r = requetes.normaliser({ brute({ count = 8, minCount = 20 }), sans_minimum }, {})
    verif.egal({ r[1].quantite, r[1].quantite_min, r[2].quantite_min }, { 8, 8, 16 })
  end,

  normaliser_deduit_l_equipement_des_tags_outils_et_armures = function()
    local pioche = { name = "minecraft:iron_pickaxe", tags = { ["c:tools/mining_tool"] = true } }
    local casque = { name = "minecraft:iron_helmet", tags = { ["minecraft:head_armor"] = true } }
    local r = requetes.normaliser({ brute({ items = { pioche } }), brute({ items = { casque } }), brute() }, {})
    verif.egal({ r[1].equipement, r[2].equipement, r[3].equipement }, { true, true, false })
  end,

  decider_ignore_l_equipement_si_le_reglage_le_demande = function()
    local a = requetes.decider(requete({ equipement = true }), { [PLANCHE] = { quantite = 64, fabricable = false } },
      regles(), {})
    verif.egal(a, { type = "ignorer", quantite = 0, raison = "équipement laissé aux colons" })
  end,

  decider_livre_l_equipement_si_le_reglage_le_permet = function()
    local a = requetes.decider(requete({ equipement = true }), { [PLANCHE] = { quantite = 64, fabricable = false } },
      regles({ ignorer_equipement = false }), {})
    verif.egal(a.type, "livrer")
  end,

  decider_ignore_une_requete_dont_tous_les_candidats_sont_exclus = function()
    local a = requetes.decider(requete(), { [PLANCHE] = { quantite = 64, fabricable = true } },
      regles({ exclusions = { "_planks$" } }), {})
    verif.egal(a, { type = "ignorer", quantite = 0, raison = "exclu par les réglages" })
  end,

  decider_saute_un_candidat_exclu_pour_le_suivant = function()
    local stocks = { [PLANCHE] = { quantite = 64, fabricable = false }, [BOULEAU] = { quantite = 64, fabricable = false } }
    local a = requetes.decider(requete(), stocks, regles({ exclusions = { "^minecraft:oak" } }), {})
    verif.egal(a, { type = "livrer", item = BOULEAU, quantite = 16, raison = "" })
  end,

  decider_livre_le_premier_candidat_qui_couvre_le_minimum_au_plus_la_quantite = function()
    local stocks = { [PLANCHE] = { quantite = 5, fabricable = true }, [BOULEAU] = { quantite = 100, fabricable = false } }
    verif.egal(requetes.decider(requete(), stocks, regles(), {}),
      { type = "livrer", item = BOULEAU, quantite = 16, raison = "" })
  end,

  decider_livre_un_stock_entre_minimum_et_quantite_tel_quel = function()
    local a = requetes.decider(requete(), { [PLANCHE] = { quantite = 10, fabricable = true } }, regles(), {})
    verif.egal(a, { type = "livrer", item = PLANCHE, quantite = 10, raison = "" })
  end,

  decider_ne_livre_jamais_zero_meme_si_le_minimum_vaut_zero = function()
    local a = requetes.decider(requete({ quantite_min = 0 }), { [PLANCHE] = { quantite = 0, fabricable = false } },
      regles(), {})
    verif.egal(a.type, "manquant")
  end,

  decider_attend_une_fabrication_deja_en_cours = function()
    local a = requetes.decider(requete(), { [PLANCHE] = { quantite = 2, fabricable = true } }, regles(),
      { [BOULEAU] = true })
    verif.egal(a, { type = "attendre", item = BOULEAU, quantite = 0, raison = "fabrication en cours" })
  end,

  decider_fabrique_ce_qui_manque_pour_atteindre_la_quantite = function()
    local stocks = { [PLANCHE] = { quantite = 3, fabricable = false }, [BOULEAU] = { quantite = 2, fabricable = true } }
    verif.egal(requetes.decider(requete(), stocks, regles(), {}),
      { type = "fabriquer", item = BOULEAU, quantite = 14, raison = "" })
  end,

  decider_ne_fabrique_pas_si_le_reglage_l_interdit = function()
    local a = requetes.decider(requete(), { [PLANCHE] = { quantite = 0, fabricable = true } },
      regles({ fabriquer = false }), {})
    verif.egal(a, { type = "manquant", quantite = 0, raison = "stock insuffisant" })
  end,

  decider_signale_manquant_sans_stock_ni_recette = function()
    local a = requetes.decider(requete(), {}, regles(), {})
    verif.egal(a, { type = "manquant", quantite = 0, raison = "stock insuffisant" })
  end,

  decider_signale_manquant_une_requete_sans_candidat = function()
    local a = requetes.decider(requete({ candidats = {} }), {}, regles(), {})
    verif.egal(a, { type = "manquant", quantite = 0, raison = "aucun item exploitable" })
  end,

  trier_motifs_ecarte_ce_qui_n_est_pas_un_texte = function()
    local motifs, invalides = requetes.trier_motifs({ "minecraft:*_sapling", "", 42 })
    verif.egal(#motifs, 1)
    verif.egal(invalides, { "", "42" })
  end,

  exclusion_avec_etoile_couvre_toute_la_famille_et_rien_d_autre = function()
    local motifs = requetes.trier_motifs({ "minecraft:*_sapling" })
    verif.vrai(("minecraft:oak_sapling"):find(motifs[1]))
    verif.vrai(not ("minecraft:oak_sapling_block"):find(motifs[1]))
    verif.vrai(not ("mod:minecraft:oak_sapling"):find(motifs[1]))
  end,

  -- Non-régression : « a% » ou « x[a » passaient la validation puis levaient à la première requête.
  exclusion_aux_caracteres_speciaux_ne_leve_jamais = function()
    for _, exclusion in ipairs({ "a%", "x[a", "(", "%", "[", "mod:item-1.0+x?", "^$" }) do
      local motifs = requetes.trier_motifs({ exclusion })
      local a = requetes.decider(requete({ candidats = { exclusion, "minecraft:foo" } }),
        { ["minecraft:foo"] = { quantite = 99, fabricable = false } }, regles({ exclusions = motifs }), {})
      verif.egal({ a.type, a.item }, { "livrer", "minecraft:foo" }, "exclusion « " .. exclusion .. " »")
    end
  end,
}
