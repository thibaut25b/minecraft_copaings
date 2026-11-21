-- Accès aux périphériques : recherche par type et appel protégé (un périphérique peut disparaître à tout instant).

local peripheriques = {}

--- Types CC des périphériques utilisés par les projets.
peripheriques.TYPES = {
  integrateur = "colony_integrator", pont_me = "me_bridge", moniteur = "monitor", haut_parleur = "speaker",
  stock_ticker = "Create_StockTicker", stressometre = "Create_Stressometer", speedometre = "Create_Speedometer",
  relais = "redstone_relay", comptoir = "lc_trader_item",
}

--- Renvoie le premier périphérique du type demandé (table de méthodes), ou nil s'il n'y en a pas.
function peripheriques.trouver(type_voulu)
  return (peripheral.find(type_voulu))
end

--- Périphérique de nom `nom` (côté ou nom réseau d'un modem), ou nil s'il n'est pas visible.
function peripheriques.par_nom(nom)
  if type(nom) ~= "string" or nom == "" then return nil end
  return peripheral.wrap(nom)
end

--- Noms de tous les périphériques visibles, triés, avec leur type : « minecraft:chest_0 (minecraft:chest) ».
function peripheriques.visibles()
  local liste = {}
  for _, nom in ipairs(peripheral.getNames()) do
    liste[#liste + 1] = nom .. " (" .. tostring(peripheral.getType(nom)) .. ")"
  end
  table.sort(liste)
  return liste
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
