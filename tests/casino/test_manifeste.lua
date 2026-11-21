-- Le manifeste du casino liste tout fichier du projet et tout module commun requis, chemins calqués sur le dépôt.

local verif = require("verif")
local manifeste = require("casino.manifeste")

local PREFIXE = "projets/casino/"

local function listes_depot()
  local liste = {}
  for _, fichier in ipairs(manifeste.fichiers) do liste[fichier.depot] = true end
  return liste
end

-- Modules requis par un fichier : il tourne dans un bac à sable dont `require` note les noms et renvoie un objet qui
-- accepte tout ; l'exécution s'arrête à la première opération impossible, après les `require` de tête.
local function requis(chemin)
  local noms = {}
  local passe_partout = {}
  setmetatable(passe_partout, {
    __index = function(_, cle) if type(cle) == "string" then return passe_partout end end,
    __call = function() return passe_partout end,
  })
  local bac = setmetatable({ require = function(nom)
    noms[#noms + 1] = nom
    return passe_partout
  end }, { __index = _G })
  pcall(assert(loadfile(chemin, "t", bac)))
  return noms
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

  tout_module_requis_par_un_fichier_liste_est_liste = function()
    local listes = listes_depot()
    for _, fichier in ipairs(manifeste.fichiers) do
      for _, nom in ipairs(requis(fichier.depot)) do
        local chemin = nom:gsub("%.", "/") .. ".lua"
        if nom:sub(1, 7) ~= "commun." then chemin = "projets/" .. chemin end
        verif.vrai(listes[chemin], fichier.depot .. " requiert " .. chemin .. " qui n'est pas listé")
      end
    end
  end,

  point_d_entree_est_installe_et_la_config_ne_l_est_pas = function()
    local ordinateur = {}
    for _, fichier in ipairs(manifeste.fichiers) do ordinateur[fichier.ordinateur] = true end
    verif.vrai(ordinateur[manifeste.entree], "entrée absente de la liste")
    verif.egal(ordinateur[manifeste.config], nil)
    verif.egal(manifeste.entree, "casino/principal.lua")
    verif.egal(manifeste.config, "casino.cfg")
  end,

  chemins_ordinateur_suivent_la_disposition_du_depot = function()
    for _, fichier in ipairs(manifeste.fichiers) do
      verif.egal(fichier.ordinateur, (fichier.depot:gsub("^projets/", "")))
    end
  end,
}
