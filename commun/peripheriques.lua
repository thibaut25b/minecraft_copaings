-- Accès aux périphériques : recherche par type et appel protégé (un périphérique peut disparaître à tout instant).

local peripheriques = {}

--- Types CC des périphériques utilisés par les projets.
peripheriques.TYPES = { integrateur = "colony_integrator", pont_me = "me_bridge", moniteur = "monitor" }

--- Renvoie le premier périphérique du type demandé (table de méthodes), ou nil s'il n'y en a pas.
function peripheriques.trouver(type_voulu)
  return (peripheral.find(type_voulu))
end

--- Appelle `objet[methode](...)` sans jamais lever d'erreur.
-- Renvoie `true, résultats...` si l'appel aboutit, `false, message` sinon (objet absent, méthode absente, erreur Lua).
function peripheriques.appel(objet, methode, ...)
  if type(objet) ~= "table" then return false, "périphérique absent" end
  local fonction = objet[methode]
  if type(fonction) ~= "function" then return false, "méthode inconnue : " .. tostring(methode) end
  return pcall(fonction, ...)
end

return peripheriques
