-- Classement des objets (logique pure) : lignes triées, totaux et alertes de rupture à partir de l'état de flux.

local inventaire = require("production.inventaire")
local flux = require("production.flux")

local classement = {}

--- Sens de tri : production décroissante, |net| décroissant, consommation décroissante.
classement.SENS = { "prod", "bilan", "conso" }

-- Vrai si l'id de `cle` est exclu : id exact, ou préfixe finissant par « : » (tout un mod).
local function exclu(cle, exclure)
  local id = inventaire.decouper(cle)
  for _, motif in ipairs(exclure) do
    if motif == id or (motif:sub(-1) == ":" and id:sub(1, #motif) == motif) then return true end
  end
  return false
end

-- Clés considérées : toutes celles de l'état, ou celles de la liste suivie `suivis` ({ objet, nbt?, nom }) ; une
-- entrée sans nbt prend toutes les variantes connues de son id (à défaut la variante sans composants).
local function cles_considerees(etat, suivis)
  local cles, vus, noms = {}, {}, {}
  local function prendre(cle, nom)
    if vus[cle] then return end
    vus[cle] = true
    cles[#cles + 1] = cle
    if nom and nom ~= "" then noms[cle] = nom end
  end
  if not suivis then
    for cle in pairs(etat.objets) do prendre(cle) end
    return cles, noms
  end
  local par_id = {}
  for cle in pairs(etat.objets) do
    local id = inventaire.decouper(cle)
    par_id[id] = par_id[id] or {}
    par_id[id][#par_id[id] + 1] = cle
  end
  for _, liste in pairs(par_id) do table.sort(liste) end
  for _, entree in ipairs(suivis) do
    if entree.nbt ~= nil then
      prendre(inventaire.cle(entree.objet, entree.nbt), entree.nom)
    elseif par_id[entree.objet] then
      for _, cle in ipairs(par_id[entree.objet]) do prendre(cle, entree.nom) end
    else
      prendre(inventaire.cle(entree.objet), entree.nom)
    end
  end
  return cles, noms
end

local function avant(a, b, cle_tri)
  if cle_tri(a) ~= cle_tri(b) then return cle_tri(a) > cle_tri(b) end
  if a.nom ~= b.nom then return a.nom < b.nom end
  return a.cle < b.cle
end

local TRIS = {
  prod = function(ligne) return ligne.production end,
  conso = function(ligne) return ligne.consommation end,
  bilan = function(ligne) return math.abs(ligne.net) end,
}

--- Classement à `instant` sur `vue` { fenetre, sens, suivis? (liste suivie ; nil = tout l'état) } avec
--- `reglages` { consommation, exclure, debit_mini (items/min), delai_alerte }. Renvoie { lignes, totaux, alertes } :
--- lignes { cle, nom, stock, production, consommation, net, partiel } (débits en items/s) triées selon le sens,
--- départagées par nom ; `debit_mini` s'applique au critère du tri. Sans liste suivie, une ligne immobile dans le
--- sens (production nulle en "prod", consommation nulle en "conso", les deux en "bilan") n'est pas listée. totaux { production, consommation, actifs,
--- connus } sur les objets non exclus. alertes { cle, nom, stock, net, avant_rupture } : net négatif et
--- stock / |net| < `delai_alerte`, triées par `avant_rupture`. `consommation = false` : sens "prod", ni
--- consommation ni net dans les lignes et les totaux, aucune alerte.
function classement.classer(etat, instant, vue, reglages)
  local avec_conso = reglages.consommation
  local sens = avec_conso and vue.sens or "prod"
  local cles, noms_suivis = cles_considerees(etat, vue.suivis)
  local lignes, alertes = {}, {}
  local totaux = { production = 0, consommation = avec_conso and 0 or nil, actifs = 0, connus = 0 }
  for _, cle in ipairs(cles) do
    if not exclu(cle, reglages.exclure) then
      local objet = etat.objets[cle]
      local production, consommation, net, partiel = flux.debits(etat, cle, vue.fenetre, instant)
      local ligne = {
        cle = cle, nom = noms_suivis[cle] or (objet and objet.nom) or inventaire.decouper(cle),
        stock = objet and objet.stock or 0, production = production, consommation = consommation, net = net,
        partiel = partiel,
      }
      totaux.connus = totaux.connus + 1
      totaux.production = totaux.production + production
      if production > 0 or (avec_conso and consommation > 0) then totaux.actifs = totaux.actifs + 1 end
      if avec_conso then
        totaux.consommation = totaux.consommation + consommation
        if net < 0 and ligne.stock / -net < reglages.delai_alerte then
          alertes[#alertes + 1] = { cle = cle, nom = ligne.nom, stock = ligne.stock, net = net,
            avant_rupture = ligne.stock / -net }
        end
      end
      local bouge = (sens ~= "conso" and production > 0) or (sens ~= "prod" and consommation > 0)
      if (vue.suivis or bouge) and TRIS[sens](ligne) * 60 >= reglages.debit_mini then lignes[#lignes + 1] = ligne end
    end
  end
  table.sort(lignes, function(a, b) return avant(a, b, TRIS[sens]) end)
  if not avec_conso then
    for _, ligne in ipairs(lignes) do ligne.consommation, ligne.net = nil, nil end
  end
  table.sort(alertes, function(a, b)
    if a.avant_rupture ~= b.avant_rupture then return a.avant_rupture < b.avant_rupture end
    if a.nom ~= b.nom then return a.nom < b.nom end
    return a.cle < b.cle
  end)
  return { lignes = lignes, totaux = totaux, alertes = alertes }
end

--- Contenu de l'écran à `instant` pour `vue` { fenetre, sens, onglet, suivis (liste suivie), tout } :
--- comme `classer`, totaux et alertes sur le périmètre lu (tout l'état si `tout`, sinon la liste suivie), lignes
--- de l'onglet (la liste suivie seule sur l'onglet "suivis").
function classement.ecran(etat, instant, vue, reglages)
  local perimetre = not vue.tout and vue.suivis or nil
  local resultat = classement.classer(etat, instant,
    { fenetre = vue.fenetre, sens = vue.sens, suivis = perimetre }, reglages)
  if vue.onglet == "suivis" and vue.tout then
    resultat.lignes = classement.classer(etat, instant,
      { fenetre = vue.fenetre, sens = vue.sens, suivis = vue.suivis }, reglages).lignes
  end
  return resultat
end

return classement
