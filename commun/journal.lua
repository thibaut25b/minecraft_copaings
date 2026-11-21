-- Journal horodaté d'un projet : une ligne par message, un seul fichier `.ancien` gardé pour borner l'espace disque.

local journal = {}

--- Ouvre le journal `chemin`. Renvoie un objet `info(message)` / `erreur(message)`.
-- Quand une ligne ferait dépasser `taille_max` octets, le fichier devient `chemin .. ".ancien"` (l'ancien est remplacé).
function journal.ouvrir(chemin, taille_max)
  local ancien = chemin .. ".ancien"

  local function ecrire(niveau, message)
    local ligne = os.date("%Y-%m-%d %H:%M:%S") .. " " .. niveau .. " " .. tostring(message)
    if fs.exists(chemin) and fs.getSize(chemin) > 0 and fs.getSize(chemin) + #ligne + 1 > taille_max then
      if fs.exists(ancien) then fs.delete(ancien) end
      fs.move(chemin, ancien)
    end
    local fichier = fs.open(chemin, "a")
    if not fichier then return end
    fichier.writeLine(ligne)
    fichier.close()
  end

  return {
    info = function(message) ecrire("INFO", message) end,
    erreur = function(message) ecrire("ERREUR", message) end,
  }
end

return journal
