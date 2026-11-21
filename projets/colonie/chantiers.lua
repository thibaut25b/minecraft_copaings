-- Chantiers des constructeurs : manques convertis en requêtes normalisées, composition et répartition d'une passe.

local chantiers = {}

local function actif(livraison, cle)
  return type(livraison) == "table" and livraison[cle] == true
end

--- Clé du constructeur à montrer : `cle` s'il existe encore, sinon le premier, nil s'il n'y en a aucun.
function chantiers.choisir(constructeurs, cle)
  if type(constructeurs) ~= "table" or #constructeurs == 0 then return nil end
  for _, constructeur in ipairs(constructeurs) do
    if constructeur.cle == cle then return cle end
  end
  return constructeurs[1].cle
end

--- Avancement d'un chantier : part du besoin total déjà disponible (0..1), nil sans ressource.
function chantiers.avancement(constructeur)
  local besoin, disponible = 0, 0
  for _, ressource in ipairs(constructeur.ressources) do
    besoin = besoin + ressource.besoin
    disponible = disponible + math.min(ressource.disponible, ressource.besoin)
  end
  if besoin <= 0 then return nil end
  return disponible / besoin
end

-- Identifiant d'une ressource vue comme requête : stable tant que le besoin total ne change pas.
-- `disponible` et `en_livraison` n'y entrent pas : leur hausse (livraison en cours) garde l'identifiant, donc la
-- mémoire de fourniture ; un nouveau besoin total (autre chantier, autre étape) donne une nouvelle requête.
local function identifiant(constructeur, ressource)
  return "chantier:" .. constructeur.cle .. ":" .. ressource.item .. ":" .. ressource.besoin
end

--- Requêtes normalisées des ressources en manque des constructeurs dont `livraison[cle]` vaut true.
-- Chacune porte `chantier` (clé du constructeur) et `item` (ressource d'origine) en plus des champs ordinaires.
function chantiers.requetes(constructeurs, livraison)
  local liste = {}
  for _, constructeur in ipairs(constructeurs or {}) do
    if actif(livraison, constructeur.cle) then
      for _, ressource in ipairs(constructeur.ressources) do
        if ressource.manque > 0 then
          liste[#liste + 1] = {
            id = identifiant(constructeur, ressource),
            libelle = ressource.libelle,
            demandeur = constructeur.nom,
            cible = constructeur.cle,
            quantite = ressource.manque,
            quantite_min = ressource.manque,
            candidats = { ressource.item },
            equipement = false,
            chantier = constructeur.cle,
            item = ressource.item,
          }
        end
      end
    end
  end
  return liste
end

-- Items des chantiers livrés automatiquement, par clé de constructeur.
local function items_livres(constructeurs, livraison)
  local par_cle = {}
  for _, constructeur in ipairs(constructeurs or {}) do
    if actif(livraison, constructeur.cle) then
      local items = {}
      for _, ressource in ipairs(constructeur.ressources) do items[ressource.item] = true end
      par_cle[constructeur.cle] = items
    end
  end
  return par_cle
end

--- Compose une passe : `{ a_servir, ecartees }`. `a_servir` = requêtes ordinaires puis requêtes de chantier.
-- Une requête ordinaire venue d'une hutte livrée automatiquement, pour un item de son chantier, est écartée :
-- le chantier la sert déjà.
function chantiers.composer(ordinaires, constructeurs, livraison)
  local livres = items_livres(constructeurs, livraison)
  local a_servir, ecartees = {}, {}
  for _, requete in ipairs(ordinaires or {}) do
    local items, couverte = livres[requete.cible], false
    for _, nom in ipairs(items and requete.candidats or {}) do couverte = couverte or items[nom] == true end
    if couverte then ecartees[#ecartees + 1] = requete else a_servir[#a_servir + 1] = requete end
  end
  for _, requete in ipairs(chantiers.requetes(constructeurs, livraison)) do a_servir[#a_servir + 1] = requete end
  return { a_servir = a_servir, ecartees = ecartees }
end

--- Sépare les lignes d'une passe : renvoie `ordinaires` (liste) et `par_constructeur[cle][item] = ligne`.
function chantiers.repartir(lignes)
  local ordinaires, par_constructeur = {}, {}
  for _, ligne in ipairs(lignes) do
    local cle = ligne.requete.chantier
    if cle then
      par_constructeur[cle] = par_constructeur[cle] or {}
      par_constructeur[cle][ligne.requete.item] = ligne
    else
      ordinaires[#ordinaires + 1] = ligne
    end
  end
  return ordinaires, par_constructeur
end

return chantiers
