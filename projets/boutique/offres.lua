-- Lecture des offres d'un comptoir (Item Trader) en tables simples ; une forme inattendue donne une ligne d'erreur.

local peripheriques = require("commun.peripheriques")

local offres = {}

--- Objets vendus par l'offre `trade` : liste de { objet, quantite } (cases vides ignorées), ou nil et un message.
function offres.objets_vendus(trade)
  local ok, cases = peripheriques.appel(trade, "getSellItems")
  if not ok then return nil, "getSellItems : " .. tostring(cases) end
  if type(cases) ~= "table" then return nil, "getSellItems illisible (" .. type(cases) .. ")" end
  local objets = {}
  for i = 1, 2 do
    local case = cases[i]
    if type(case) == "table" and type(case.name) == "string" and type(case.count) == "number" and case.count > 0 then
      objets[#objets + 1] = { objet = case.name, quantite = case.count }
    end
  end
  return objets
end

--- Prix d'une offre : numeric (nombre ou nil) et text (chaîne ou nil), lus défensivement.
function offres.prix(trade)
  local ok, prix = peripheriques.appel(trade, "getPrice")
  if not ok or type(prix) ~= "table" then return nil, nil end
  return type(prix.numeric) == "number" and prix.numeric or nil, type(prix.text) == "string" and prix.text or nil
end

--- Offres de vente du comptoir `trader` : liste de { indice (1-based), objets, prix, texte, trade }, et la liste des
--- erreurs de lecture. Renvoie nil et un message si getTrades échoue.
function offres.lire(trader)
  local ok, liste = peripheriques.appel(trader, "getTrades")
  if not ok then return nil, "getTrades : " .. tostring(liste) end
  if type(liste) ~= "table" then return nil, "getTrades illisible (" .. type(liste) .. ")" end
  local indices = {}
  for indice in pairs(liste) do
    if type(indice) == "number" then indices[#indices + 1] = indice end
  end
  table.sort(indices)
  local resultat, erreurs = {}, {}
  for _, indice in ipairs(indices) do
    local trade = liste[indice]
    local lu, vente = peripheriques.appel(trade, "isSale")
    if not lu then
      erreurs[#erreurs + 1] = "offre " .. indice .. " : isSale : " .. tostring(vente)
    elseif vente == true then
      local objets, message = offres.objets_vendus(trade)
      if not objets then
        erreurs[#erreurs + 1] = "offre " .. indice .. " : " .. message
      elseif #objets > 0 then
        local numeric, texte = offres.prix(trade)
        resultat[#resultat + 1] = { indice = indice, objets = objets, prix = numeric, texte = texte, trade = trade }
      end
    end
  end
  return resultat, erreurs
end

return offres
