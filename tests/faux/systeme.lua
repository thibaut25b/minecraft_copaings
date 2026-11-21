-- Faux globaux système de CC (fs en mémoire, textutils, os.epoch, os.date, http), à installer explicitement par le test.

local systeme = {}

local function serialiser(valeur)
  if type(valeur) == "string" then return string.format("%q", valeur) end
  if type(valeur) ~= "table" then return tostring(valeur) end
  local cles = {}
  for cle in pairs(valeur) do cles[#cles + 1] = cle end
  table.sort(cles, function(a, b) return tostring(a) < tostring(b) end)
  local morceaux = {}
  for _, cle in ipairs(cles) do
    morceaux[#morceaux + 1] = "[" .. serialiser(cle) .. "]=" .. serialiser(valeur[cle])
  end
  return "{" .. table.concat(morceaux, ",") .. "}"
end

local function deserialiser(texte)
  if type(texte) ~= "string" then return nil end
  local fonction = load("return " .. texte, "unserialize", "t", {})
  if not fonction then return nil end
  local ok, valeur = pcall(fonction)
  if ok then return valeur end
  return nil
end

local function normaliser(chemin)
  return (chemin:gsub("^/+", ""):gsub("/+$", ""))
end

--- Installe les faux globaux et renvoie l'état observable :
-- `disque` (chemin sans « / » initial -> contenu), `dossiers`, `ecritures` (chemins écrits, déplacés ou supprimés),
-- `urls` (url -> contenu servi), `panne_sur` (texte : toute url qui le contient échoue), `epoch` (ms), `date` (texte).
function systeme.installer()
  local etat = {
    disque = {}, dossiers = {}, ecritures = {}, urls = {}, panne_sur = nil,
    epoch = 0, date = "2026-01-02 03:04:05",
  }

  local function noter(chemin) etat.ecritures[#etat.ecritures + 1] = chemin end

  fs = {
    exists = function(chemin)
      local p = normaliser(chemin)
      return etat.disque[p] ~= nil or etat.dossiers[p] == true
    end,
    getSize = function(chemin)
      local contenu = etat.disque[normaliser(chemin)]
      if not contenu then error("No such file", 2) end
      return #contenu
    end,
    getDir = function(chemin)
      return (normaliser(chemin):match("^(.*)/[^/]*$") or "")
    end,
    makeDir = function(chemin)
      noter(normaliser(chemin))
      etat.dossiers[normaliser(chemin)] = true
    end,
    delete = function(chemin)
      noter(normaliser(chemin))
      etat.disque[normaliser(chemin)] = nil
    end,
    move = function(source, destination)
      local de, vers = normaliser(source), normaliser(destination)
      if etat.disque[de] == nil then error("No such file", 2) end
      if etat.disque[vers] ~= nil then error("File exists", 2) end
      noter(de)
      noter(vers)
      etat.disque[vers] = etat.disque[de]
      etat.disque[de] = nil
    end,
    open = function(chemin, mode)
      local p = normaliser(chemin)
      if mode == "r" then
        local contenu = etat.disque[p]
        if contenu == nil then return nil, "No such file" end
        return {
          readAll = function() return contenu end,
          close = function() end,
        }
      end
      if mode == "w" then etat.disque[p] = "" end
      if mode == "a" and etat.disque[p] == nil then etat.disque[p] = "" end
      noter(p)
      local function ecrire(texte) etat.disque[p] = etat.disque[p] .. texte end
      return {
        write = function(texte) ecrire(tostring(texte)) end,
        writeLine = function(texte) ecrire(tostring(texte) .. "\n") end,
        close = function() end,
      }
    end,
  }

  textutils = { serialize = serialiser, unserialize = deserialiser }

  os.epoch = function() return etat.epoch end
  os.date = function() return etat.date end

  http = {
    get = function(url)
      if etat.panne_sur and url:find(etat.panne_sur, 1, true) then return nil, "panne simulée" end
      local contenu = etat.urls[url]
      if contenu == nil then return nil, "Not Found" end
      return {
        readAll = function() return contenu end,
        close = function() end,
        getResponseCode = function() return 200 end,
      }
    end,
  }

  return etat
end

return systeme
