-- Instantanés : clé name|nbt, normalisation des items du pont, détection de coupure.

local verif = require("verif")
local inventaire = require("production.inventaire")

local COMB = "productivebees:configurable_honeycomb"

-- Instantané de `types` clés « k:1| » à « k:N| », chacune à `quantite`.
local function reseau(types, quantite)
  local instantane = {}
  for i = 1, types do instantane["k:" .. i .. "|"] = quantite end
  return instantane
end

return {
  la_cle_est_le_nom_puis_le_nbt_et_vide_sans_composants = function()
    verif.egal(inventaire.cle("a:b", "f00"), "a:b|f00")
    verif.egal(inventaire.cle("a:b", nil), "a:b|")
    verif.egal(inventaire.cle("a:b", ""), "a:b|")
  end,

  decouper_rend_l_id_et_le_nbt_nil_sans_composants = function()
    verif.egal({ inventaire.decouper("a:b|f00") }, { "a:b", "f00" })
    verif.egal({ inventaire.decouper("a:b|") }, { "a:b" })
  end,

  deux_items_de_meme_name_et_nbt_differents_restent_separes = function()
    local instantane = inventaire.normaliser({ { name = COMB, count = 5, nbt = "abeille1" },
      { name = COMB, count = 7, nbt = "abeille2" }, { name = COMB, count = 1 } })
    verif.egal(instantane, { [COMB .. "|abeille1"] = 5, [COMB .. "|abeille2"] = 7, [COMB .. "|"] = 1 })
  end,

  les_crochets_du_nom_affiche_du_pont_sont_retires = function()
    local _, noms = inventaire.normaliser({ { name = "a:fer", count = 1, displayName = "[Iron Ingot]" },
      { name = "a:or", count = 1, displayName = "Gold" }, { name = "a:x", count = 1, displayName = "[]" } })
    verif.egal(noms, { ["a:fer|"] = "Iron Ingot", ["a:or|"] = "Gold" })
  end,

  les_items_illisibles_sont_ignores = function()
    local instantane = inventaire.normaliser({ "texte", { count = 1 }, { name = "", count = 1 },
      { name = "a:b", count = "beaucoup" }, { name = "a:c", count = 1, nbt = 4 }, { name = "a:d", count = 3 } })
    verif.egal(instantane, { ["a:d|"] = 3 })
  end,

  une_cle_repetee_additionne_ses_quantites = function()
    verif.egal(inventaire.normaliser({ { name = "a:b", count = 2 }, { name = "a:b", count = 3 } }), { ["a:b|"] = 5 })
  end,

  sans_reference_rien_n_est_une_coupure = function()
    verif.egal(inventaire.coupure(nil, {}, 0.2), false)
    verif.egal(inventaire.coupure({}, { ["a|"] = 1 }, 0.2), false)
  end,

  une_reference_de_moins_de_20_types_n_est_jamais_coupee = function()
    local petite = reseau(inventaire.TYPES_MINI_COUPURE - 1, 10)
    verif.egal(inventaire.coupure(petite, {}, 0.2), false)
    verif.egal(inventaire.coupure({ ["a|"] = 10, ["b|"] = 10 }, { ["a|"] = 10 }, 0.2), false)
    verif.egal(inventaire.coupure(reseau(inventaire.TYPES_MINI_COUPURE, 10), {}, 0.2), true)
  end,

  un_instantane_vide_apres_un_plein_est_une_coupure = function()
    verif.egal(inventaire.coupure(reseau(20, 10), {}, 0.2), true)
  end,

  trop_de_types_disparus_d_un_coup_est_une_coupure = function()
    local reference = reseau(20, 1)
    local reste = reseau(16, 1)
    verif.egal(inventaire.coupure(reference, reste, 0.2), false)
    reste["k:16|"] = nil
    verif.egal(inventaire.coupure(reference, reste, 0.2), true)
  end,

  trop_de_types_apparus_d_un_coup_est_une_coupure = function()
    local reference = reseau(20, 1)
    local avec = reseau(25, 1)
    verif.egal(inventaire.coupure(reference, avec, 0.2), true)
    avec["k:25|"] = nil
    verif.egal(inventaire.coupure(reference, avec, 0.2), false)
  end,

  une_chute_du_total_au_dela_du_seuil_est_une_coupure = function()
    local reference = reseau(20, 100)
    local apres = reseau(20, 100)
    for i = 1, 4 do apres["k:" .. i .. "|"] = 1 end
    verif.egal(inventaire.coupure(reference, apres, 0.2), false)
    apres["k:5|"] = 1
    verif.egal(inventaire.coupure(reference, apres, 0.2), true)
  end,
}
