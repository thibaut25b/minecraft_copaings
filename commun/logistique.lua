-- Réseau logistique de Create vu par un Stock Ticker : stock par objet et commande d'une livraison.

local peripheriques = require("commun.peripheriques")

local logistique = {}

--- Stock du réseau : { [identifiant] = quantité }, les variantes d'un même objet additionnées. Renvoie nil et un
--- message si le Stock Ticker ne répond pas.
function logistique.stock(ticker)
  local ok, liste = peripheriques.appel(ticker, "stock")
  if not ok then return nil, tostring(liste) end
  if type(liste) ~= "table" then return nil, "stock illisible" end
  local quantites = {}
  for _, objet in pairs(liste) do
    if type(objet) == "table" and type(objet.name) == "string" and type(objet.count) == "number" then
      quantites[objet.name] = (quantites[objet.name] or 0) + objet.count
    end
  end
  return quantites
end

--- Commande au plus `nombre` objets `objet` vers l'adresse `adresse`. Renvoie le nombre mis en commande (0 si le
--- réseau n'en a pas), ou nil et un message. Ce nombre n'est pas une preuve de livraison.
function logistique.commander(ticker, adresse, objet, nombre)
  if type(adresse) ~= "string" or adresse == "" then return nil, "adresse de livraison vide" end
  if type(nombre) ~= "number" or nombre < 1 then return nil, "quantité invalide : " .. tostring(nombre) end
  local ok, demandes = peripheriques.appel(ticker, "requestFiltered", adresse,
    { name = objet, _requestCount = math.floor(nombre) })
  if not ok then return nil, tostring(demandes) end
  if type(demandes) ~= "number" then return nil, "réponse illisible du Stock Ticker" end
  return demandes
end

return logistique
