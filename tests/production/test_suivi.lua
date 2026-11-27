-- Liste suivie : config puis coffre modèle sans doublon, et oubli des objets retirés.

local verif = require("verif")
local suivi = require("production.suivi")

local FER = { objet = "minecraft:iron_ingot", nom = "Fer" }

return {
  sans_coffre_la_liste_est_celle_de_la_config = function()
    verif.egal(suivi.fusionner({ FER }, nil), { FER })
    verif.egal(suivi.fusionner({}, {}), {})
  end,

  les_items_du_coffre_suivent_la_config_dans_l_ordre_des_emplacements = function()
    local liste = suivi.fusionner({ FER }, {
      [9] = { name = "a:neuvieme", count = 1 }, [2] = { name = "a:deuxieme", count = 1 },
      [5] = { name = "a:cinquieme", count = 1 },
    })
    verif.egal(liste, { FER, { objet = "a:deuxieme", nom = "" }, { objet = "a:cinquieme", nom = "" },
      { objet = "a:neuvieme", nom = "" } })
  end,

  un_id_deja_dans_la_config_n_est_pas_repete_et_garde_son_nom = function()
    local liste = suivi.fusionner({ FER }, { [1] = { name = "minecraft:iron_ingot", count = 3 } })
    verif.egal(liste, { FER })
  end,

  plusieurs_piles_du_meme_id_font_un_seul_objet = function()
    local liste = suivi.fusionner({}, { [1] = { name = "a:b", count = 64 }, [2] = { name = "a:b", count = 10 },
      [3] = { name = "a:c", count = 1 } })
    verif.egal(liste, { { objet = "a:b", nom = "" }, { objet = "a:c", nom = "" } })
  end,

  les_piles_illisibles_sont_ignorees = function()
    local liste = suivi.fusionner({}, { [1] = "texte", [2] = { count = 1 }, [3] = { name = "", count = 1 },
      x = { name = "a:x", count = 1 }, [4] = { name = "a:b", count = 1 } })
    verif.egal(liste, { { objet = "a:b", nom = "" } })
  end,

  la_liste_de_la_config_n_est_pas_modifiee = function()
    local config = { FER }
    suivi.fusionner(config, { [1] = { name = "a:b", count = 1 } })
    verif.egal(config, { FER })
  end,

  oublier_retire_les_objets_qui_ne_sont_plus_suivis = function()
    local series = { ["a:b"] = { 1 }, ["a:c"] = { 2 } }
    suivi.oublier(series, { { objet = "a:c", nom = "" } })
    verif.egal(series, { ["a:c"] = { 2 } })
  end,
}
