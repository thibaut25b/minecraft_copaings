-- Installeur commun : `wget run <base>/install.lua <projet>` télécharge tout en mémoire puis écrit (relancer met à jour).

local DEPOT = "thibaut25b/minecraft_copaings"
local BRANCHE = "main"
local RACINE = "https://raw.githubusercontent.com/" .. DEPOT .. "/"
local BASE = RACINE .. BRANCHE .. "/"

local STARTUP = "/startup.lua"
local STARTUP_ANCIEN = "/startup.ancien.lua"
local USAGE = "Usage : wget run " .. BASE .. "install.lua <projet> [branche]\nExemple : wget run " .. BASE .. "install.lua colonie"
local MESSAGE_HTTP = "http est désactivé sur ce serveur. Demande à l'admin de passer http.enabled à true "
  .. "dans computercraft-server.toml (et d'autoriser raw.githubusercontent.com)."

local installeur = { base = BASE }
local base = BASE -- base des téléchargements de l'installation en cours

-- Même conversion que `commun/texte.lua`, recopiée ici car ce fichier se télécharge seul.
local function vers_cc(valeur)
  return (tostring(valeur):gsub("[\194-\244][\128-\191]+", function(sequence)
    local tete, suite = sequence:byte(1, 2)
    if #sequence == 2 and tete <= 195 then return string.char((tete - 194) * 64 + suite) end
    return "?"
  end))
end

local function afficher(message)
  print(vers_cc(message))
end

local function telecharger(chemin_depot)
  local reponse, message = http.get(base .. chemin_depot)
  if not reponse then return nil, tostring(message or "aucune réponse") end
  local contenu = reponse.readAll()
  reponse.close()
  if not contenu then return nil, "réponse vide" end
  return contenu
end

local function chemin_ordinateur(relatif)
  return "/" .. relatif
end

--- Télécharge et valide `projets/<nom>/manifeste.lua`. Renvoie le manifeste, ou `nil, message` (avec l'usage).
function installeur.lire_manifeste(nom)
  if type(nom) ~= "string" or not nom:match("^[%w_%-]+$") then return nil, USAGE end
  local contenu, message = telecharger("projets/" .. nom .. "/manifeste.lua")
  if not contenu then return nil, "Projet inconnu ou injoignable : " .. nom .. " (" .. message .. ")\n" .. USAGE end
  local fonction = load(contenu, "manifeste", "t", {})
  local ok, manifeste = false, nil
  if fonction then ok, manifeste = pcall(fonction) end
  if not ok or type(manifeste) ~= "table" or type(manifeste.entree) ~= "string"
    or type(manifeste.config) ~= "string" or type(manifeste.fichiers) ~= "table" then
    return nil, "Manifeste illisible pour le projet " .. nom
  end
  for _, fichier in ipairs(manifeste.fichiers) do
    if fichier.ordinateur == manifeste.config then
      return nil, "Manifeste refusé : il liste le fichier de config " .. manifeste.config
    end
  end
  return manifeste
end

--- Télécharge tous les fichiers du manifeste, sans rien écrire. Renvoie `{ { chemin, contenu } ... }` ou `nil, message`.
function installeur.telecharger_tout(manifeste, sortie)
  local liste = {}
  for index, fichier in ipairs(manifeste.fichiers) do
    sortie("(" .. index .. "/" .. #manifeste.fichiers .. ") " .. fichier.depot)
    local contenu, message = telecharger(fichier.depot)
    if not contenu then return nil, "Échec du téléchargement de " .. fichier.depot .. " : " .. message end
    liste[#liste + 1] = { chemin = chemin_ordinateur(fichier.ordinateur), contenu = contenu }
  end
  return liste
end

local function ecrire_fichier(chemin, contenu)
  local dossier = fs.getDir(chemin)
  if dossier ~= "" and not fs.exists(dossier) then fs.makeDir(dossier) end
  local fichier = fs.open(chemin, "w")
  if not fichier then return false, "Écriture impossible : " .. chemin end
  fichier.write(contenu)
  fichier.close()
  return true
end

--- Contenu de `/startup.lua` : lance le point d'entrée du projet.
function installeur.contenu_startup(manifeste)
  return 'shell.run("' .. chemin_ordinateur(manifeste.entree) .. '")\n'
end

--- Écrit `/startup.lua`. Un startup différent déjà présent est gardé sous `/startup.ancien.lua` (dit via `sortie`).
function installeur.ecrire_startup(manifeste, sortie)
  local contenu = installeur.contenu_startup(manifeste)
  if fs.exists(STARTUP) then
    local fichier = fs.open(STARTUP, "r")
    local actuel = fichier and (fichier.readAll() or "") or nil
    if fichier then fichier.close() end
    if actuel ~= contenu then
      if fs.exists(STARTUP_ANCIEN) then fs.delete(STARTUP_ANCIEN) end
      fs.move(STARTUP, STARTUP_ANCIEN)
      sortie("Ton startup existant est gardé sous " .. STARTUP_ANCIEN)
    end
  end
  return ecrire_fichier(STARTUP, contenu)
end

--- Installe ou met à jour le projet `nom`. Renvoie `true`, ou `false, message`. `sortie(texte)` affiche la progression.
-- `branche` (facultatif) installe depuis une autre branche du dépôt, pour essayer une version avant sa fusion.
function installeur.installer(nom, sortie, branche)
  if http == nil then return false, MESSAGE_HTTP end
  base = BASE
  if branche ~= nil then
    if type(branche) ~= "string" or not branche:match("^[%w_%-]+$") then return false, "Branche invalide\n" .. USAGE end
    base = RACINE .. branche .. "/"
    sortie("Branche : " .. branche)
  end
  local manifeste, message = installeur.lire_manifeste(nom)
  if not manifeste then return false, message end
  sortie("Installation de " .. nom)
  local liste, erreur = installeur.telecharger_tout(manifeste, sortie)
  if not liste then return false, erreur end
  for _, fichier in ipairs(liste) do
    local ok, echec = ecrire_fichier(fichier.chemin, fichier.contenu)
    if not ok then return false, echec end
  end
  local ok, echec = installeur.ecrire_startup(manifeste, sortie)
  if not ok then return false, echec end
  sortie("Installé : " .. #liste .. " fichiers.")
  sortie("Lancer : reboot, ou " .. chemin_ordinateur(manifeste.entree))
  sortie("Config : " .. chemin_ordinateur(manifeste.config) .. " (jamais écrasée par l'installation)")
  return true
end

--- Point d'entrée en jeu : `lancer(nom, branche)`.
function installeur.lancer(nom, branche)
  local ok, message = installeur.installer(nom, afficher, branche)
  if not ok then afficher(message) end
end

if shell or select("#", ...) > 0 then installeur.lancer(...) end

return installeur
