-- Régulation des lignes : hystérésis sur le stock, modes forcés et délestage par réseau cinétique, en logique pure.

local regulation = {}

--- Modes d'une ligne, dans l'ordre où le toucher les fait tourner.
regulation.MODES = { "auto", "marche", "arret" }

--- Mode qui suit `mode` dans `regulation.MODES` (le premier après le dernier ou un mode inconnu).
function regulation.mode_suivant(mode)
  for i, connu in ipairs(regulation.MODES) do
    if connu == mode then return regulation.MODES[i % #regulation.MODES + 1] end
  end
  return regulation.MODES[1]
end

local function mode_connu(mode)
  for _, connu in ipairs(regulation.MODES) do
    if connu == mode then return true end
  end
  return false
end

--- Mémoire propre des `lignes` configurées à partir de `lue` (table relue du disque, nil ou n'importe quoi) :
--- { [nom] = { mode, decision (booléen ou nil), delestee (booléen) } }. Ce qui est illisible repart du défaut.
function regulation.memoire(lignes, lue)
  local propre = {}
  for _, ligne in ipairs(lignes) do
    local ancienne = type(lue) == "table" and type(lue[ligne.nom]) == "table" and lue[ligne.nom] or {}
    local decision = nil
    if type(ancienne.decision) == "boolean" then decision = ancienne.decision end
    propre[ligne.nom] = {
      mode = mode_connu(ancienne.mode) and ancienne.mode or "auto",
      decision = decision,
      delestee = ancienne.delestee == true,
    }
  end
  return propre
end

-- Décision du stock seul : arrêt dès `maxi`, marche dès `mini` ou moins, sinon la précédente (marche sans passé).
-- Stock inconnu : la précédente, nil sans passé.
local function hysteresis(ligne, quantite, precedente)
  if quantite == nil then return precedente end
  if quantite >= ligne.maxi then return false end
  if quantite <= ligne.mini then return true end
  if precedente == nil then return true end
  return precedente
end

--- Ratio stress / capacité d'une mesure { stress, capacite } : `math.huge` en surcharge, nil si illisible ou si le
--- réseau est à l'arrêt (capacité nulle).
function regulation.charge(mesure)
  if type(mesure) ~= "table" or type(mesure.stress) ~= "number" or type(mesure.capacite) ~= "number" then return nil end
  if mesure.capacite < mesure.stress then return math.huge end
  if mesure.capacite <= 0 then return nil end
  return mesure.stress / mesure.capacite
end

-- Indice de la ligne à prendre parmi `indices` : la moins prioritaire (plus grand `priorite`, la dernière à égalité)
-- si `moins_prioritaire`, sinon la plus prioritaire (la première à égalité).
local function choisir(lignes, indices, moins_prioritaire)
  local meilleur
  for _, i in ipairs(indices) do
    if not meilleur then
      meilleur = i
    elseif moins_prioritaire and lignes[i].priorite >= lignes[meilleur].priorite then
      meilleur = i
    elseif not moins_prioritaire and lignes[i].priorite < lignes[meilleur].priorite then
      meilleur = i
    end
  end
  return meilleur
end

-- Un pas de délestage sur chaque réseau : une ligne délestée de plus, de moins, ou rien.
local function delester(lignes, memoire, reseaux, seuils)
  local par_reseau = {}
  for i, ligne in ipairs(lignes) do
    if ligne.reseau then
      par_reseau[ligne.reseau] = par_reseau[ligne.reseau] or { candidates = {}, delestees = {} }
      local etat = memoire[ligne.nom]
      if etat.delestee then
        table.insert(par_reseau[ligne.reseau].delestees, i)
      elseif etat.mode == "auto" and etat.decision == true then
        table.insert(par_reseau[ligne.reseau].candidates, i)
      end
    end
  end
  for nom, groupe in pairs(par_reseau) do
    local ratio = regulation.charge(reseaux[nom])
    if ratio and ratio >= seuils.delestage then
      local i = choisir(lignes, groupe.candidates, true)
      if i then memoire[lignes[i].nom].delestee = true end
    elseif ratio and ratio <= seuils.reprise then
      local i = choisir(lignes, groupe.delestees, false)
      if i then memoire[lignes[i].nom].delestee = false end
    end
  end
end

-- Marche et raison affichable d'une ligne une fois tout décidé.
local function sortie(ligne, etat, quantite)
  if etat.mode == "marche" then return true, "forcée marche" end
  if etat.mode == "arret" then return false, "forcée arrêt" end
  if etat.delestee then return false, "délestée" end
  if quantite == nil then return etat.decision == true, "stock inconnu" end
  if etat.decision then return true, quantite <= ligne.mini and "stock bas" or "remplit" end
  return false, quantite >= ligne.maxi and "stock plein" or "en attente"
end

--- Une passe de régulation. `lignes` : validées ; `memoire` : voir `regulation.memoire` ; `mesures` : { stock =
--- { [objet] = quantité } ou nil (inconnu), reseaux = { [nom] = { stress, capacite } } (absent = illisible) } ;
--- `seuils` : { delestage, reprise }. Renvoie la nouvelle mémoire et les sorties { [i] = { marche, raison,
--- quantite } } dans l'ordre des lignes. Un objet absent d'un stock connu compte pour 0.
function regulation.passer(lignes, memoire, mesures, seuils)
  local nouvelle, quantites = {}, {}
  for i, ligne in ipairs(lignes) do
    local etat = memoire[ligne.nom] or { mode = "auto", delestee = false }
    local quantite = mesures.stock and (mesures.stock[ligne.produit] or 0) or nil
    quantites[i] = quantite
    local decision = hysteresis(ligne, quantite, etat.decision)
    -- Une ligne forcée ou arrêtée par son stock n'a plus rien à céder au réseau.
    local delestee = etat.delestee == true and etat.mode == "auto" and decision ~= false
    nouvelle[ligne.nom] = { mode = etat.mode, decision = decision, delestee = delestee }
  end
  delester(lignes, nouvelle, mesures.reseaux or {}, seuils)
  local sorties = {}
  for i, ligne in ipairs(lignes) do
    local marche, raison = sortie(ligne, nouvelle[ligne.nom], quantites[i])
    sorties[i] = { marche = marche, raison = raison, quantite = quantites[i] }
  end
  return nouvelle, sorties
end

--- Mémoire où la ligne `nom` passe au mode suivant (copie, l'originale intacte).
function regulation.changer_mode(memoire, nom)
  local copie = {}
  for cle, etat in pairs(memoire) do
    copie[cle] = { mode = etat.mode, decision = etat.decision, delestee = etat.delestee }
  end
  if copie[nom] then copie[nom].mode = regulation.mode_suivant(copie[nom].mode) end
  return copie
end

return regulation
