-- Validation des réglages de l'usine : chaque entrée fautive est écartée avec son message, le reste est gardé.

local theme = require("commun.theme")

local validation = {}

--- Côtés d'un relais redstone de CC (docs/create.md, section 6).
validation.COTES = { "bottom", "top", "back", "front", "right", "left" }

--- Nom du réseau formé par défaut quand la liste `reseaux` est vide.
validation.PRINCIPAL = "Principal"

local function texte_plein(valeur)
  return type(valeur) == "string" and valeur ~= ""
end

local function nombre_positif(valeur)
  return type(valeur) == "number" and valeur == valeur and valeur >= 0
end

local function contient(liste, valeur)
  for _, element in ipairs(liste) do
    if element == valeur then return true end
  end
  return false
end

local function liste_ou_vide(reglages, cle, erreurs)
  local valeur = reglages[cle]
  if valeur == nil then return {} end
  if type(valeur) ~= "table" then
    erreurs[#erreurs + 1] = "Config : " .. cle .. " doit être une liste, ignorée"
    return {}
  end
  return valeur
end

local function nom_entree(entree, i)
  if type(entree) == "table" and texte_plein(entree.nom) then return entree.nom end
  return "n°" .. i
end

-- Réglage simple : valeur gardée si `valide`, défaut et message sinon.
local function simple(reglages, defauts, cle, valide, attendu, erreurs)
  if valide(reglages[cle]) then return reglages[cle] end
  erreurs[#erreurs + 1] = "Config : " .. cle .. " doit être " .. attendu .. ", " .. tostring(defauts[cle])
    .. " utilisé"
  return defauts[cle]
end

local function valider_reseau(entree, noms)
  if type(entree) ~= "table" then return nil, "n'est pas une table" end
  if not texte_plein(entree.nom) then return nil, "nom manquant" end
  if noms[entree.nom] then return nil, "nom déjà pris" end
  if not texte_plein(entree.stressometre) then return nil, "stressometre manquant" end
  local vitesse = entree.speedometre
  if vitesse ~= nil and type(vitesse) ~= "string" then return nil, "speedometre doit être un texte" end
  return { nom = entree.nom, stressometre = entree.stressometre,
    speedometre = texte_plein(vitesse) and vitesse or false }
end

local function valider_ligne(entree, noms, sorties, reseaux)
  if type(entree) ~= "table" then return nil, "n'est pas une table" end
  if not texte_plein(entree.nom) then return nil, "nom manquant" end
  if noms[entree.nom] then return nil, "nom déjà pris" end
  if not texte_plein(entree.produit) then return nil, "produit manquant" end
  if not nombre_positif(entree.mini) then return nil, "mini manquant ou négatif" end
  if not nombre_positif(entree.maxi) then return nil, "maxi manquant ou négatif" end
  if entree.mini > entree.maxi then return nil, "mini > maxi" end
  if not texte_plein(entree.relais) then return nil, "relais manquant" end
  if not contient(validation.COTES, entree.cote) then return nil, "côté inconnu : " .. tostring(entree.cote) end
  local sortie = entree.relais .. "/" .. entree.cote
  if sorties[sortie] then return nil, "même sortie que la ligne " .. sorties[sortie] end
  if entree.signal_coupe ~= nil and type(entree.signal_coupe) ~= "boolean" then
    return nil, "signal_coupe doit être true ou false"
  end
  local priorite = entree.priorite == nil and 1 or entree.priorite
  if type(priorite) ~= "number" or priorite < 1 or priorite ~= math.floor(priorite) then
    return nil, "priorite doit être un entier dès 1"
  end
  local reseau = entree.reseau == nil and "" or entree.reseau
  if type(reseau) ~= "string" then return nil, "reseau doit être un texte" end
  local nom_reseau
  if reseau == "" then
    nom_reseau = reseaux[1] and reseaux[1].nom or nil
  else
    for _, connu in ipairs(reseaux) do
      if connu.nom == reseau then nom_reseau = reseau end
    end
    if not nom_reseau then return nil, "réseau inconnu : " .. reseau end
  end
  return {
    nom = entree.nom, produit = entree.produit, mini = entree.mini, maxi = entree.maxi, relais = entree.relais,
    cote = entree.cote, signal_coupe = entree.signal_coupe ~= false, reseau = nom_reseau, priorite = priorite,
  }, sortie
end

local function valider_stock(entree, noms)
  if type(entree) ~= "table" then return nil, "n'est pas une table" end
  if not texte_plein(entree.nom) then return nil, "nom manquant" end
  if not texte_plein(entree.objet) then return nil, "objet manquant" end
  if not nombre_positif(entree.seuil) then return nil, "seuil manquant ou négatif" end
  if noms[entree.nom] then return nil, "nom déjà pris" end
  return { nom = entree.nom, objet = entree.objet, seuil = entree.seuil }
end

-- Garde les entrées valides de `liste` ; `valider(entree)` renvoie l'entrée nettoyée ou nil et la raison.
local function filtrer(liste, genre, valider, erreurs)
  local ecartee = genre == "ligne" and "écartée" or "écarté"
  local gardees = {}
  for i, entree in ipairs(liste) do
    local propre, raison = valider(entree)
    if propre then
      gardees[#gardees + 1] = propre
    else
      erreurs[#erreurs + 1] = "Config : " .. genre .. " " .. nom_entree(entree, i) .. " " .. ecartee .. " : " .. raison
    end
  end
  return gardees
end

--- Réglages validés à partir de `reglages` (fichier complété) et `defauts` : { periode, echelle_texte, theme,
--- points_historique, stock_ticker, seuil_delestage, seuil_reprise, reseaux, lignes, stocks }, puis la liste des
--- messages d'erreur. Réseau sans speedomètre : `speedometre = false` ; réseau par défaut : capteurs à nil (le
--- premier trouvé). Ligne : `reseau` = nom du réseau retenu, nil s'il n'y en a aucun.
function validation.valider(reglages, defauts)
  local erreurs = {}
  local propre = {}
  propre.periode = simple(reglages, defauts, "periode", function(v) return type(v) == "number" and v > 0 end,
    "un nombre de secondes > 0", erreurs)
  propre.echelle_texte = reglages.echelle_texte
  propre.theme = simple(reglages, defauts, "theme", function(v) return contient(theme.NOMS, v) end,
    "un thème connu (" .. table.concat(theme.NOMS, ", ") .. ")", erreurs)
  propre.points_historique = simple(reglages, defauts, "points_historique", function(v)
    return type(v) == "number" and v >= 2 and v == math.floor(v)
  end, "un entier dès 2", erreurs)
  propre.stock_ticker = simple(reglages, defauts, "stock_ticker", function(v) return type(v) == "string" end,
    "un texte", erreurs)
  local function ratio(v) return type(v) == "number" and v > 0 end
  propre.seuil_delestage = simple(reglages, defauts, "seuil_delestage", ratio, "un ratio > 0", erreurs)
  propre.seuil_reprise = simple(reglages, defauts, "seuil_reprise", ratio, "un ratio > 0", erreurs)
  if propre.seuil_reprise >= propre.seuil_delestage then
    erreurs[#erreurs + 1] = "Config : seuil_reprise doit être < seuil_delestage, défauts utilisés"
    propre.seuil_delestage, propre.seuil_reprise = defauts.seuil_delestage, defauts.seuil_reprise
  end

  local reseaux = liste_ou_vide(reglages, "reseaux", erreurs)
  if #reseaux == 0 then
    propre.reseaux = { { nom = validation.PRINCIPAL } }
  else
    local noms = {}
    propre.reseaux = filtrer(reseaux, "réseau", function(entree)
      local reseau, raison = valider_reseau(entree, noms)
      if reseau then noms[reseau.nom] = true end
      return reseau, raison
    end, erreurs)
  end

  local noms, sorties = {}, {}
  propre.lignes = filtrer(liste_ou_vide(reglages, "lignes", erreurs), "ligne", function(entree)
    local ligne, sortie = valider_ligne(entree, noms, sorties, propre.reseaux)
    if ligne then
      noms[ligne.nom] = true
      sorties[sortie] = ligne.nom
    end
    return ligne, sortie
  end, erreurs)

  local noms_stocks = {}
  propre.stocks = filtrer(liste_ou_vide(reglages, "stocks", erreurs), "stock", function(entree)
    local stock, raison = valider_stock(entree, noms_stocks)
    if stock then noms_stocks[stock.nom] = true end
    return stock, raison
  end, erreurs)
  return propre, erreurs
end

return validation
