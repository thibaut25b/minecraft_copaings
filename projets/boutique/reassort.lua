-- Réassort des comptoirs : ce qu'il faut tirer du tampon et commander au réseau, et la mémoire des commandes en route.

local reassort = {}

local function reglage_article(reglages, objet)
  local article = type(reglages.articles) == "table" and reglages.articles[objet] or nil
  return type(article) == "table" and article or {}
end

--- Quantité visée dans un comptoir pour `objet` : `articles[objet].reserve`, sinon `reserve_defaut`.
function reassort.reserve(reglages, objet)
  local reserve = reglage_article(reglages, objet).reserve
  if type(reserve) == "number" and reserve >= 0 then return math.floor(reserve) end
  return reglages.reserve_defaut
end

--- Libellé de `objet` : `articles[objet].nom`, sinon l'identifiant sans le mod, « _ » remplacés par des espaces.
function reassort.nom(reglages, objet)
  local nom = reglage_article(reglages, objet).nom
  if type(nom) == "string" and nom ~= "" then return nom end
  return ((objet:match(":(.+)$") or objet):gsub("_", " "))
end

--- Ensemble des objets que vend un comptoir lu ({ offres }).
function reassort.objets(comptoir)
  local vus = {}
  for _, offre in ipairs(comptoir.offres or {}) do
    for _, vendu in ipairs(offre.objets) do vus[vendu.objet] = true end
  end
  return vus
end

local function trier(ensemble)
  local liste = {}
  for cle in pairs(ensemble) do liste[#liste + 1] = cle end
  table.sort(liste)
  return liste
end

local function par_nom(comptoirs)
  local copie = {}
  for i, comptoir in ipairs(comptoirs) do copie[i] = comptoir end
  table.sort(copie, function(a, b) return a.nom < b.nom end)
  return copie
end

--- Nombre total en route pour `objet`.
function reassort.en_route(en_route, objet)
  local total = 0
  for _, commande in ipairs(en_route[objet] or {}) do total = total + commande.nombre end
  return total
end

--- Ajoute une commande de `nombre` objets passée à `maintenant`.
function reassort.ajouter(en_route, objet, nombre, maintenant)
  en_route[objet] = en_route[objet] or {}
  table.insert(en_route[objet], { nombre = nombre, instant = maintenant })
end

--- Retire `nombre` objets tirés du tampon des commandes en route de `objet`, les plus anciennes d'abord.
function reassort.deduire(en_route, objet, nombre)
  local liste = en_route[objet]
  while liste and nombre > 0 and #liste > 0 do
    local pris = math.min(nombre, liste[1].nombre)
    liste[1].nombre = liste[1].nombre - pris
    nombre = nombre - pris
    if liste[1].nombre <= 0 then table.remove(liste, 1) end
  end
  if liste and #liste == 0 then en_route[objet] = nil end
end

--- Copie de `en_route` sans les commandes passées il y a `delai` secondes ou plus.
function reassort.oublier(en_route, maintenant, delai)
  local gardees = {}
  for objet, liste in pairs(en_route) do
    for _, commande in ipairs(liste) do
      if maintenant - commande.instant < delai then reassort.ajouter(gardees, objet, commande.nombre, commande.instant) end
    end
  end
  return gardees
end

--- Plan d'une passe. `entree` = { comptoirs = { { nom, offres, stockage } } (stockage : { [objet] = quantité }, nil
--- si illisible : comptoir ignoré), tampon = { [objet] = quantité }, reseau = { [objet] = quantité } ou nil
--- (inconnu), en_route, reglages }. Renvoie { tirages = { { comptoir, objet, nombre } }, commandes = { { objet,
--- nombre } } }. Le tampon se partage dans l'ordre des noms ; une seule commande par objet couvre tous les manques.
function reassort.planifier(entree)
  local tampon = {}
  for objet, nombre in pairs(entree.tampon or {}) do tampon[objet] = nombre end
  local plan, restes = { tirages = {}, commandes = {} }, {}
  for _, comptoir in ipairs(par_nom(entree.comptoirs)) do
    if comptoir.stockage then
      for _, objet in ipairs(trier(reassort.objets(comptoir))) do
        local manque = reassort.reserve(entree.reglages, objet) - (comptoir.stockage[objet] or 0)
        if manque > 0 then
          local tire = math.min(manque, tampon[objet] or 0)
          if tire > 0 then
            plan.tirages[#plan.tirages + 1] = { comptoir = comptoir.nom, objet = objet, nombre = tire }
            tampon[objet] = tampon[objet] - tire
          end
          restes[objet] = (restes[objet] or 0) + manque - tire
        end
      end
    end
  end
  if not entree.reseau then return plan end
  for _, objet in ipairs(trier(restes)) do
    local voulu = math.min(restes[objet] - reassort.en_route(entree.en_route, objet), entree.reseau[objet] or 0)
    if voulu >= 1 then plan.commandes[#plan.commandes + 1] = { objet = objet, nombre = math.floor(voulu) } end
  end
  return plan
end

--- Lignes du tableau des articles, triées par libellé : { objet, nom, texte (prix affiché), comptoir (quantité, nil
--- si aucun stockage lisible), reserve, usine (nil si inconnu), en_route }.
function reassort.articles(comptoirs, reseau, en_route, reglages)
  local lignes, par_objet = {}, {}
  for _, comptoir in ipairs(par_nom(comptoirs)) do
    for _, offre in ipairs(comptoir.offres or {}) do
      for _, vendu in ipairs(offre.objets) do
        local ligne = par_objet[vendu.objet]
        if not ligne then
          ligne = { objet = vendu.objet, nom = reassort.nom(reglages, vendu.objet), reserve = 0,
            usine = reseau and (reseau[vendu.objet] or 0) or nil, en_route = reassort.en_route(en_route, vendu.objet),
            comptes = {} }
          par_objet[vendu.objet] = ligne
          lignes[#lignes + 1] = ligne
        end
        ligne.texte = ligne.texte or offre.texte
        if not ligne.comptes[comptoir.nom] then
          ligne.comptes[comptoir.nom] = true
          ligne.reserve = ligne.reserve + reassort.reserve(reglages, vendu.objet)
          if comptoir.stockage then ligne.comptoir = (ligne.comptoir or 0) + (comptoir.stockage[vendu.objet] or 0) end
        end
      end
    end
  end
  for _, ligne in ipairs(lignes) do ligne.comptes = nil end
  table.sort(lignes, function(a, b)
    if a.nom ~= b.nom then return a.nom < b.nom end
    return a.objet < b.objet
  end)
  return lignes
end

return reassort
