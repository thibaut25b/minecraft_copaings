-- Comptes des ventes : cumul par article, recette totale et dernières ventes, dans une table persistable.

local ventes = {}

local function nombre(valeur)
  return type(valeur) == "number" and valeur == valeur and valeur >= 0
end

--- Vrai si `etat` a la forme des comptes : { recette, articles = { [objet] = { ventes, vendus, recette } },
--- dernieres = { ... } }.
function ventes.lisible(etat)
  if type(etat) ~= "table" or not nombre(etat.recette) then return false end
  if type(etat.articles) ~= "table" or type(etat.dernieres) ~= "table" then return false end
  for _, article in pairs(etat.articles) do
    if type(article) ~= "table" or not nombre(article.ventes) or not nombre(article.vendus)
      or not nombre(article.recette) then
      return false
    end
  end
  return true
end

--- Comptes relus (`lu`), ou des comptes vides si `lu` n'a pas la bonne forme.
function ventes.charger(lu)
  if ventes.lisible(lu) then return lu end
  return { recette = 0, articles = {}, dernieres = {} }
end

--- Montant d'un prix payé (table monnaie de LC) : son `numeric`, 0 s'il est illisible.
function ventes.montant(paye)
  if type(paye) == "table" and nombre(paye.numeric) then return paye.numeric end
  return 0
end

--- Ajoute `vente` = { joueur, objets = { { objet, quantite } }, montant, texte, heure } aux comptes : chaque objet
--- compte une vente, la recette va au premier ; `gardees` dernières ventes conservées, la plus récente en tête.
function ventes.enregistrer(etat, vente, gardees)
  etat.recette = etat.recette + vente.montant
  for i, vendu in ipairs(vente.objets) do
    local article = etat.articles[vendu.objet] or { ventes = 0, vendus = 0, recette = 0 }
    article.ventes = article.ventes + 1
    article.vendus = article.vendus + vendu.quantite
    if i == 1 then article.recette = article.recette + vente.montant end
    etat.articles[vendu.objet] = article
  end
  local premier = vente.objets[1] or { objet = "?", quantite = 0 }
  table.insert(etat.dernieres, 1, { joueur = vente.joueur, objet = premier.objet, quantite = premier.quantite,
    montant = vente.montant, texte = vente.texte, heure = vente.heure })
  while #etat.dernieres > gardees do table.remove(etat.dernieres) end
  return etat
end

return ventes
