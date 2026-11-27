-- Liste suivie : config puis coffre modèle sans doublon, une entrée par variante (id et nbt).

local verif = require("verif")
local suivi = require("production.suivi")

local FER = { objet = "minecraft:iron_ingot", nom = "Fer" }
local COMB = "productivebees:configurable_honeycomb"

return {
  sans_coffre_la_liste_est_celle_de_la_config = function()
    verif.egal(suivi.fusionner({ FER }, nil), { FER })
    verif.egal(suivi.fusionner({}, {}), {})
  end,

  une_entree_de_config_avec_nbt_recoit_sa_cle_et_sans_nbt_suit_toutes_les_variantes = function()
    local liste = suivi.fusionner({ FER, { objet = COMB, nom = "", nbt = "abc" }, { objet = "a:b", nom = "", nbt = "" } })
    verif.egal(liste, { FER, { objet = COMB, nom = "", nbt = "abc", cle = COMB .. "|abc" },
      { objet = "a:b", nom = "", nbt = "", cle = "a:b|" } })
  end,

  les_items_du_coffre_suivent_la_config_dans_l_ordre_des_emplacements = function()
    local liste = suivi.fusionner({ FER }, {
      [9] = { name = "a:neuvieme", count = 1 }, [2] = { name = "a:deuxieme", count = 1 },
      [5] = { name = "a:cinquieme", count = 1 },
    })
    verif.egal(liste, { FER, { objet = "a:deuxieme", nbt = "", nom = "", cle = "a:deuxieme|" },
      { objet = "a:cinquieme", nbt = "", nom = "", cle = "a:cinquieme|" },
      { objet = "a:neuvieme", nbt = "", nom = "", cle = "a:neuvieme|" } })
  end,

  deux_combs_d_especes_differentes_du_coffre_font_deux_entrees = function()
    local liste = suivi.fusionner({}, { [1] = { name = COMB, count = 1, nbt = "abeille1" },
      [2] = { name = COMB, count = 1, nbt = "abeille2" } })
    verif.egal(liste, { { objet = COMB, nbt = "abeille1", nom = "", cle = COMB .. "|abeille1" },
      { objet = COMB, nbt = "abeille2", nom = "", cle = COMB .. "|abeille2" } })
  end,

  un_id_suivi_en_entier_par_la_config_n_est_pas_repete_depuis_le_coffre = function()
    local liste = suivi.fusionner({ FER }, { [1] = { name = "minecraft:iron_ingot", count = 3 },
      [2] = { name = "minecraft:iron_ingot", count = 3, nbt = "x" } })
    verif.egal(liste, { FER })
  end,

  une_variante_deja_dans_la_config_n_est_pas_repetee_mais_une_autre_l_est = function()
    local liste = suivi.fusionner({ { objet = COMB, nom = "Comb", nbt = "a" } },
      { [1] = { name = COMB, count = 1, nbt = "a" }, [2] = { name = COMB, count = 1 } })
    verif.egal(liste, { { objet = COMB, nom = "Comb", nbt = "a", cle = COMB .. "|a" },
      { objet = COMB, nbt = "", nom = "", cle = COMB .. "|" } })
  end,

  plusieurs_piles_de_la_meme_variante_font_un_seul_objet = function()
    local liste = suivi.fusionner({}, { [1] = { name = "a:b", count = 64 }, [2] = { name = "a:b", count = 10 } })
    verif.egal(liste, { { objet = "a:b", nbt = "", nom = "", cle = "a:b|" } })
  end,

  les_piles_illisibles_sont_ignorees = function()
    local liste = suivi.fusionner({}, { [1] = "texte", [2] = { count = 1 }, [3] = { name = "", count = 1 },
      x = { name = "a:x", count = 1 }, [5] = { name = "a:y", count = 1, nbt = 3 }, [4] = { name = "a:b", count = 1 } })
    verif.egal(liste, { { objet = "a:b", nbt = "", nom = "", cle = "a:b|" } })
  end,

  la_liste_de_la_config_n_est_pas_modifiee = function()
    local config = { FER }
    suivi.fusionner(config, { [1] = { name = "a:b", count = 1 } })
    verif.egal(config, { { objet = "minecraft:iron_ingot", nom = "Fer" } })
  end,

  les_ids_a_lire_sont_distincts_dans_l_ordre = function()
    local liste = suivi.fusionner({ FER }, { [1] = { name = COMB, count = 1, nbt = "a" },
      [2] = { name = COMB, count = 1, nbt = "b" }, [3] = { name = "a:b", count = 1 } })
    verif.egal(suivi.ids(liste), { "minecraft:iron_ingot", COMB, "a:b" })
  end,
}
