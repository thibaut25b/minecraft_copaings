-- Le manifeste de la colonie liste tout ce qui s'installe, et tout fichier listé dont la source existe compile.

local verif = require("verif")
local manifeste = require("colonie.manifeste")

-- true : un fichier listé mais pas encore écrit est signalé sans faire échouer. false : il bloque.
local TOLERER_ABSENTS = false

local PREFIXE = "projets/colonie/"

local function dans_le_depot(chemin)
  for _, present in ipairs(FICHIERS_DU_DEPOT) do
    if present == chemin then return true end
  end
  return false
end

local function chemins_listes()
  local liste = {}
  for _, fichier in ipairs(manifeste.fichiers) do liste[fichier.depot] = true end
  return liste
end

return {
  tout_fichier_du_projet_sauf_le_manifeste_est_liste = function()
    local listes = chemins_listes()
    for _, chemin in ipairs(FICHIERS_DU_DEPOT) do
      if chemin:sub(1, #PREFIXE) == PREFIXE and chemin ~= PREFIXE .. "manifeste.lua" then
        verif.vrai(listes[chemin], chemin .. " n'est pas listé dans le manifeste")
      end
    end
  end,

  tout_fichier_liste_existant_compile = function()
    local absents = {}
    for _, fichier in ipairs(manifeste.fichiers) do
      if dans_le_depot(fichier.depot) then
        local fonction, message = loadfile(fichier.depot)
        verif.vrai(fonction, tostring(message))
      else
        absents[#absents + 1] = fichier.depot
      end
    end
    if #absents > 0 then
      print("manifeste : " .. #absents .. " fichier(s) listé(s) pas encore écrit(s) : " .. table.concat(absents, ", "))
      verif.vrai(TOLERER_ABSENTS, "fichiers listés absents : " .. table.concat(absents, ", "))
    end
  end,

  point_d_entree_est_installe_et_la_config_ne_l_est_pas = function()
    local ordinateur = {}
    for _, fichier in ipairs(manifeste.fichiers) do ordinateur[fichier.ordinateur] = true end
    verif.vrai(ordinateur[manifeste.entree], "entrée absente de la liste")
    verif.egal(ordinateur[manifeste.config], nil)
    verif.egal(manifeste.entree, "colonie/principal.lua")
    verif.egal(manifeste.config, "colonie.cfg")
  end,

  chemins_ordinateur_suivent_la_disposition_du_depot = function()
    for _, fichier in ipairs(manifeste.fichiers) do
      local attendu = fichier.depot:gsub("^projets/", "")
      verif.egal(fichier.ordinateur, attendu)
    end
  end,
}
