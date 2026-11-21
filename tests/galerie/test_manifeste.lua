-- Le manifeste de la galerie liste tout fichier du projet et tout module commun requis, chemins calqués sur le dépôt.

colors = require("faux.couleurs")

local verif = require("verif")
local manifeste = require("galerie.manifeste")

local PREFIXE = "projets/galerie/"

local function listes_depot()
  local liste = {}
  for _, fichier in ipairs(manifeste.fichiers) do liste[fichier.depot] = true end
  return liste
end

-- Modules requis par le point d'entrée : il tourne dans un bac à sable dont `require` note les noms et renvoie
-- des modules vides ; sans écran, il s'arrête de lui-même sur « aucun écran utilisable ».
local function requis_par_le_point_d_entree()
  local requis = {}
  local vide = setmetatable({}, { __index = function() return function() return {} end end })
  local bac = {
    package = { path = "" }, print = function() end, ipairs = ipairs, pcall = pcall, error = error, type = type,
    tostring = tostring,
    require = function(nom)
      requis[#requis + 1] = nom
      if nom == "galerie.ecrans" then return {} end
      return vide
    end,
  }
  local fonction = assert(loadfile(PREFIXE .. "principal.lua", "t", bac))
  local ok, message = pcall(fonction)
  verif.egal(ok, false)
  verif.vrai(tostring(message):find("aucun écran utilisable", 1, true), tostring(message))
  return requis
end

return {
  tout_fichier_du_projet_sauf_le_manifeste_est_liste = function()
    local listes = listes_depot()
    for _, chemin in ipairs(FICHIERS_DU_DEPOT) do
      if chemin:sub(1, #PREFIXE) == PREFIXE and chemin ~= PREFIXE .. "manifeste.lua" then
        verif.vrai(listes[chemin], chemin .. " n'est pas listé dans le manifeste")
      end
    end
  end,

  tout_fichier_liste_existe_et_compile = function()
    local presents = {}
    for _, chemin in ipairs(FICHIERS_DU_DEPOT) do presents[chemin] = true end
    for _, fichier in ipairs(manifeste.fichiers) do
      verif.vrai(presents[fichier.depot], fichier.depot .. " absent du dépôt")
      local fonction, message = loadfile(fichier.depot)
      verif.vrai(fonction, tostring(message))
    end
  end,

  tout_module_commun_requis_par_les_ecrans_et_le_point_d_entree_est_liste = function()
    local listes = listes_depot()
    for _, nom in ipairs(require("galerie.ecrans")) do require("galerie.ecrans." .. nom) end
    local modules = {}
    for nom in pairs(package.loaded) do modules[#modules + 1] = nom end
    for _, nom in ipairs(requis_par_le_point_d_entree()) do modules[#modules + 1] = nom end
    for _, nom in ipairs(modules) do
      if nom:sub(1, 7) == "commun." then
        local chemin = nom:gsub("%.", "/") .. ".lua"
        verif.vrai(listes[chemin], chemin .. " est requis mais pas listé")
      end
    end
  end,

  point_d_entree_est_installe_et_la_config_ne_l_est_pas = function()
    local ordinateur = {}
    for _, fichier in ipairs(manifeste.fichiers) do ordinateur[fichier.ordinateur] = true end
    verif.vrai(ordinateur[manifeste.entree], "entrée absente de la liste")
    verif.egal(ordinateur[manifeste.config], nil)
    verif.egal(manifeste.entree, "galerie/principal.lua")
    verif.egal(manifeste.config, "galerie.cfg")
  end,

  chemins_ordinateur_suivent_la_disposition_du_depot = function()
    for _, fichier in ipairs(manifeste.fichiers) do
      local attendu = fichier.depot:gsub("^projets/", "")
      verif.egal(fichier.ordinateur, attendu)
    end
  end,
}
