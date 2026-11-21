-- Dépôt d'état : une table gardée dans un fichier de l'ordinateur, écrit sans risque de troncature, relu au
-- démarrage ; un fichier illisible est mis de côté, jamais écrasé.

local depot = {}

local function lire_fichier(chemin)
  local fichier = fs.open(chemin, "r")
  if not fichier then return nil end
  local texte = fichier.readAll() or ""
  fichier.close()
  return textutils.unserialize(texte)
end

--- Dépôt sur le fichier `chemin` : { lire() -> table, nil (absent) ou false et message (illisible, copie gardée),
--- ecrire(table) -> true ou false, message }. L'écriture passe par `chemin .. ".tmp"` puis remplace le fichier
--- (fs.move refuse une cible existante) : un arrêt en pleine écriture laisse toujours une version complète.
function depot.fichier(chemin)
  local provisoire = chemin .. ".tmp"
  return {
    lire = function()
      if not fs.exists(chemin) then
        if not fs.exists(provisoire) then return nil end
        local secours = lire_fichier(provisoire)
        if type(secours) == "table" then
          fs.move(provisoire, chemin)
          return secours
        end
        return nil
      end
      local etat = lire_fichier(chemin)
      if type(etat) == "table" then return etat end
      local copie = chemin .. ".illisible-" .. os.epoch("utc")
      fs.move(chemin, copie)
      return false, "Fichier illisible, copie gardée dans " .. copie .. " : un admin doit regarder."
    end,
    ecrire = function(etat)
      local fichier = fs.open(provisoire, "w")
      if not fichier then return false, "écriture impossible : " .. provisoire end
      fichier.write(textutils.serialize(etat))
      fichier.close()
      if fs.exists(chemin) then fs.delete(chemin) end
      fs.move(provisoire, chemin)
      return true
    end,
  }
end

return depot
