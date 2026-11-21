-- Lecture du monde : stock du réseau logistique et jauges de chaque réseau cinétique, sans jamais lever.

local peripheriques = require("commun.peripheriques")
local logistique = require("commun.logistique")

local mesures = {}

-- Capteur nommé, ou le premier du type si `nom` est nil ou "".
local function capteur(nom, type_voulu)
  if nom == nil or nom == "" then return peripheriques.trouver(type_voulu) end
  return peripheriques.par_nom(nom)
end

-- « Stock Ticker x » ou « Stock Ticker » quand le nom est vide.
local function nomme(genre, nom)
  if nom == nil or nom == "" then return genre end
  return genre .. " " .. nom
end

local function nombre(objet, methode)
  local ok, valeur = peripheriques.appel(objet, methode)
  if not ok then return nil, tostring(valeur) end
  if type(valeur) ~= "number" or valeur ~= valeur then return nil, methode .. " illisible" end
  return valeur
end

local function lire_reseau(reseau, erreurs)
  local prefixe = "Réseau " .. reseau.nom .. " : "
  local jauge = capteur(reseau.stressometre, peripheriques.TYPES.stressometre)
  local mesure = {}
  if not jauge then
    erreurs[#erreurs + 1] = prefixe .. nomme("stressomètre", reseau.stressometre) .. " introuvable"
  else
    local stress, message = nombre(jauge, "getStress")
    local capacite, message_capacite = nombre(jauge, "getStressCapacity")
    if stress and capacite then
      mesure.stress, mesure.capacite = stress, capacite
    else
      erreurs[#erreurs + 1] = prefixe .. "stressomètre illisible : " .. tostring(message or message_capacite)
    end
  end
  if reseau.speedometre ~= false then
    local compteur = capteur(reseau.speedometre, peripheriques.TYPES.speedometre)
    if compteur then
      local vitesse, message = nombre(compteur, "getSpeed")
      mesure.vitesse = vitesse
      if not vitesse then erreurs[#erreurs + 1] = prefixe .. "speedomètre illisible : " .. message end
    elseif reseau.speedometre then
      erreurs[#erreurs + 1] = prefixe .. "speedomètre " .. reseau.speedometre .. " introuvable"
    end
  end
  return mesure
end

--- Mesures d'une passe : { stock = { [objet] = quantité } ou nil, reseaux = { [nom] = { stress, capacite, vitesse } } }
--- (champs absents s'ils sont illisibles), puis les messages d'erreur.
function mesures.lire(reglages)
  local erreurs = {}
  local resultat = { reseaux = {} }
  local ticker = capteur(reglages.stock_ticker, peripheriques.TYPES.stock_ticker)
  if not ticker then
    erreurs[#erreurs + 1] = nomme("Stock Ticker", reglages.stock_ticker) .. " introuvable"
  else
    local stock, message = logistique.stock(ticker)
    resultat.stock = stock
    if not stock then erreurs[#erreurs + 1] = "Stock Ticker : " .. tostring(message) end
  end
  for _, reseau in ipairs(reglages.reseaux) do resultat.reseaux[reseau.nom] = lire_reseau(reseau, erreurs) end
  return resultat, erreurs
end

return mesures
