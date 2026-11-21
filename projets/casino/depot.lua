-- Dépôt des jetons fictifs : l'état de la caisse dans un fichier de l'ordinateur, relu au démarrage.

local config = require("commun.config")

local depot = {}

--- Dépôt sur le fichier `chemin` : { lire() -> table ou nil, ecrire(table) -> true ou false, message }.
function depot.fichier(chemin)
  return {
    lire = function()
      if not fs.exists(chemin) then return nil end
      local fichier = fs.open(chemin, "r")
      if not fichier then return nil end
      local texte = fichier.readAll() or ""
      fichier.close()
      return textutils.unserialize(texte) or false
    end,
    ecrire = function(etat)
      return config.enregistrer(chemin, etat)
    end,
  }
end

return depot
