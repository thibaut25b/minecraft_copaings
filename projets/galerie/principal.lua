-- Point d'entrée de la galerie : anime les écrans sur le moniteur (ou le terminal) ; toucher : suivant, Q : quitter.

package.path = "/?.lua;" .. package.path

local config = require("commun.config")
local dessin = require("commun.dessin")
local peripheriques = require("commun.peripheriques")
local theme = require("commun.theme")
local vers_cc = require("commun.texte").vers_cc
local defauts = require("galerie.reglages")
local noms = require("galerie.ecrans")

local CHEMIN_CONFIG = "/galerie.cfg"
local DUREE_MESSAGE = 3

local reglages, erreur_config = config.charger(CHEMIN_CONFIG, defauts)
if erreur_config then print(vers_cc("Config : " .. erreur_config)) end

-- Écrans chargés ; un fichier fautif est annoncé puis ignoré.
local ecrans = {}
for _, nom in ipairs(noms) do
  local ok, ecran = pcall(require, "galerie.ecrans." .. nom)
  if ok and type(ecran) == "table" and type(ecran.dessiner) == "function" then
    ecrans[#ecrans + 1] = ecran
  else
    print(vers_cc("Écran " .. nom .. " ignoré : " .. tostring(ok and "forme invalide" or ecran)))
  end
end
if #ecrans == 0 then error("aucun écran utilisable", 0) end

-- Sans moniteur, la galerie se dessine sur le terminal de l'ordinateur.
local function cible_affichage()
  local moniteur = peripheriques.trouver(peripheriques.TYPES.moniteur)
  if not moniteur then return term.current() end
  peripheriques.appel(moniteur, "setTextScale", reglages.echelle_texte)
  return moniteur
end

local function annoncer(cible, message)
  print(vers_cc(message))
  if cible == term.current() then return end
  pcall(function()
    dessin.effacer(cible)
    dessin.ecrire(cible, 1, 1, dessin.tronquer(message, (cible.getSize())), colors.red)
  end)
end

local function jouer()
  local indice, t = 1, 0
  local cible = cible_affichage()
  local fin_ecran = os.clock() + reglages.duree_ecran
  local reprise = 0
  local minuteur = os.startTimer(reglages.periode_image)

  local function suivant()
    indice, t = indice % #ecrans + 1, 0
    fin_ecran = os.clock() + reglages.duree_ecran
  end

  while true do
    local evenement, parametre = os.pullEventRaw()
    if evenement == "terminate" or (evenement == "key" and parametre == keys.q) then
      return cible
    elseif evenement == "monitor_touch" or evenement == "mouse_click" then
      suivant()
    elseif evenement == "timer" and parametre == minuteur then
      cible = cible_affichage()
      if os.clock() >= reprise then
        local ecran = ecrans[indice]
        local ok, message = pcall(ecran.dessiner, cible, t % ecran.images)
        t = t + 1
        if not ok then
          annoncer(cible, "Écran " .. ecran.nom .. " sauté : " .. tostring(message))
          reprise = os.clock() + DUREE_MESSAGE
          suivant()
        elseif os.clock() >= fin_ecran then
          suivant()
        end
      end
      minuteur = os.startTimer(reglages.periode_image)
    end
  end
end

-- En quittant, le moniteur et le terminal retrouvent la palette d'origine.
for _, cible in ipairs({ jouer(), term.current() }) do
  pcall(theme.restaurer, cible)
  pcall(dessin.effacer, cible)
end
print(vers_cc("Galerie arrêtée."))
