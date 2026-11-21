-- L'installeur télécharge tout avant d'écrire, respecte la config et le startup du joueur, et dit quoi faire si ça échoue.

local verif = require("verif")
local systeme = require("faux.systeme")

local installeur = loadfile("install.lua")()
local BASE = installeur.base

local MANIFESTE = [[return {
  nom = "demo", entree = "demo/principal.lua", config = "demo.cfg",
  fichiers = {
    { depot = "commun/a.lua", ordinateur = "commun/a.lua" },
    { depot = "projets/demo/principal.lua", ordinateur = "demo/principal.lua" },
  } }]]

local function preparer(manifeste)
  local etat = systeme.installer()
  etat.urls[BASE .. "projets/demo/manifeste.lua"] = manifeste or MANIFESTE
  etat.urls[BASE .. "commun/a.lua"] = "-- a"
  etat.urls[BASE .. "projets/demo/principal.lua"] = "-- principal"
  return etat
end

local function installer()
  local lignes = {}
  local ok, message = installeur.installer("demo", function(texte) lignes[#lignes + 1] = texte end)
  return ok, message, table.concat(lignes, "\n")
end

return {
  projet_inconnu_donne_l_usage = function()
    systeme.installer()
    local ok, message = installeur.installer("inconnu", function() end)
    verif.egal(ok, false)
    verif.vrai(message:find("Usage", 1, true))
  end,

  argument_manquant_donne_l_usage = function()
    systeme.installer()
    local ok, message = installeur.installer(nil, function() end)
    verif.egal(ok, false)
    verif.vrai(message:find("Usage", 1, true))
  end,

  rien_n_est_ecrit_si_un_telechargement_echoue = function()
    local etat = preparer()
    etat.disque["startup.lua"] = "print('moi')"
    etat.panne_sur = "projets/demo/principal.lua"
    local ok, message = installer()
    verif.egal(ok, false)
    verif.vrai(message:find("principal.lua", 1, true))
    verif.egal(etat.ecritures, {})
    verif.egal(etat.disque, { ["startup.lua"] = "print('moi')" })
  end,

  config_existante_n_est_pas_touchee = function()
    local etat = preparer()
    etat.disque["demo.cfg"] = "{ periode = 99 }"
    verif.egal((installer()), true)
    verif.egal(etat.disque["demo.cfg"], "{ periode = 99 }")
    for _, chemin in ipairs(etat.ecritures) do verif.vrai(chemin ~= "demo.cfg") end
  end,

  manifeste_qui_liste_la_config_est_refuse_sans_rien_ecrire = function()
    local etat = preparer(MANIFESTE:gsub("commun/a.lua\" }", "commun/a.lua\" },\n { depot = \"x.lua\", ordinateur = \"demo.cfg\" }"))
    local ok, message = installer()
    verif.egal(ok, false)
    verif.vrai(message:find("demo.cfg", 1, true))
    verif.egal(etat.ecritures, {})
  end,

  startup_existant_est_sauvegarde_et_dit_a_l_ecran = function()
    local etat = preparer()
    etat.disque["startup.lua"] = "print('moi')"
    local ok, _, ecran = installer()
    verif.egal(ok, true)
    verif.egal(etat.disque["startup.ancien.lua"], "print('moi')")
    verif.egal(etat.disque["startup.lua"], 'shell.run("/demo/principal.lua")\n')
    verif.vrai(ecran:find("startup.ancien.lua", 1, true))
  end,

  relancer_met_a_jour_sans_sauvegarder_son_propre_startup = function()
    local etat = preparer()
    installer()
    etat.urls[BASE .. "commun/a.lua"] = "-- a v2"
    verif.egal((installer()), true)
    verif.egal(etat.disque["commun/a.lua"], "-- a v2")
    verif.egal(etat.disque["startup.ancien.lua"], nil)
  end,

  fichiers_sont_ecrits_a_leur_chemin_d_ordinateur = function()
    local etat = preparer()
    local ok, _, ecran = installer()
    verif.egal(ok, true)
    verif.egal(etat.disque["commun/a.lua"], "-- a")
    verif.egal(etat.disque["demo/principal.lua"], "-- principal")
    verif.vrai(ecran:find("/demo.cfg", 1, true))
    verif.vrai(ecran:find("/demo/principal.lua", 1, true))
  end,

  http_desactive_explique_quoi_demander_a_l_admin = function()
    systeme.installer()
    _G.http = nil
    local ok, message = installeur.installer("demo", function() end)
    verif.egal(ok, false)
    verif.vrai(message:find("http.enabled", 1, true))
    verif.vrai(message:find("computercraft-server.toml", 1, true))
  end,

  nom_de_projet_avec_chemin_est_refuse = function()
    systeme.installer()
    local ok, message = installeur.installer("../x", function() end)
    verif.egal(ok, false)
    verif.vrai(message:find("Usage", 1, true))
  end,
}
