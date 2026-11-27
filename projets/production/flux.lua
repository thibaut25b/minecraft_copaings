-- Flux des objets (logique pure) : production et consommation par objet, rangées en cases alignées sur le temps absolu.

local inventaire = require("production.inventaire")

local flux = {}

--- Unités de débit, dans l'ordre de rotation de l'affichage.
flux.UNITES = { "s", "min", "h" }

--- Libellé affiché de chaque unité.
flux.LIBELLES = { s = "/s", min = "/min", h = "/h" }

local SECONDES = { s = 1, min = 60, h = 3600 }

--- Fenêtres de débit lisibles, en secondes.
flux.FENETRES = { 60, 600, 3600 }

--- Part minimale de la fenêtre que l'historique doit couvrir pour que le débit ne soit pas dit partiel.
flux.COUVERTURE_MINI = 0.95

--- Grilles de cases : `largeur` en secondes, `nombre` de cases gardées (10 s sur 10 min, 1 min sur 1 h).
flux.FINES = { nom = "fines", largeur = 10, nombre = 60 }
flux.LARGES = { nom = "larges", largeur = 60, nombre = 60 }
local GRILLES = { flux.FINES, flux.LARGES }

--- Une hausse ou une baisse est anormale au-delà de ce multiple de son rythme habituel.
flux.SEUIL_ANORMAL = 3

--- Poids d'une mesure dans les rythmes habituels (moyennes exponentielles par mesure, en items/s).
flux.POIDS_RYTHME = 0.2

--- Mesures d'historique sous lesquelles un objet n'annule aucun aller-retour.
flux.HISTORIQUE_MINI = 6

--- Écart relatif toléré entre l'excédent d'une hausse et la baisse qu'elle rembourse.
flux.TOLERANCE_RETOUR = 0.2

--- Lectures en coupure d'affilée au bout desquelles l'instantané devient le nouvel état du réseau.
flux.COUPURES_ACCEPTEES = 6

--- Convertit un débit en items/s vers l'unité `unite` ("s", "min" ou "h"). Unité inconnue : erreur.
function flux.convertir(debit_par_seconde, unite)
  local facteur = SECONDES[unite]
  if not facteur then error("unité inconnue : " .. tostring(unite), 2) end
  return debit_par_seconde * facteur
end

--- État vide : { objets = { [cle] = objet }, base, reference, coupures, debut, instant } (voir `noter`).
function flux.nouveau()
  return { objets = {}, base = nil, reference = nil, coupures = 0, debut = nil, instant = nil }
end

-- Indice de la case qui contient `instant` (une borne appartient à la case qui la précède).
local function derniere_case(instant, largeur)
  return math.ceil(instant / largeur) - 1
end

local function grille_vide()
  return { cases = {}, premier = nil, nombre = 0 }
end

local function creer(etat, cle, debut, depart_t, depart_n)
  local objet = {
    stock = depart_n, depart = { t = depart_t, n = depart_n }, debut = debut, mesures = 0, hausses = 0, baisses = 0,
    attente = {},
    fines = grille_vide(), larges = grille_vide(),
  }
  etat.objets[cle] = objet
  return objet
end

local function ajouter(grille, indice, champ, quantite)
  local case = grille.cases[indice]
  if not case then
    case = { production = 0, consommation = 0 }
    grille.cases[indice] = case
    grille.nombre = grille.nombre + 1
    if grille.premier == nil or indice < grille.premier then grille.premier = indice end
  end
  case[champ] = case[champ] + quantite
end

-- Retire de `grille` les cases d'indice inférieur à `limite`.
local function purger(grille, limite)
  if grille.premier == nil or grille.premier >= limite then return end
  for indice = grille.premier, limite - 1 do
    if grille.nombre == 0 then break end
    if grille.cases[indice] then
      grille.cases[indice] = nil
      grille.nombre = grille.nombre - 1
    end
  end
  grille.premier = grille.nombre > 0 and limite or nil
end

local function premiere_gardee(spec, instant)
  return derniere_case(instant, spec.largeur) - spec.nombre + 1
end

-- Répartit `quantite` (champ "production" ou "consommation") sur les cases traversées par [t0, t1], au prorata
-- du temps ; la part antérieure aux cases gardées à `instant` est perdue.
local function ranger(objet, t0, t1, champ, quantite, instant)
  for _, spec in ipairs(GRILLES) do
    local largeur, grille = spec.largeur, objet[spec.nom]
    local limite = premiere_gardee(spec, instant)
    if t1 <= t0 then
      local indice = derniere_case(t1, largeur)
      if indice >= limite then ajouter(grille, indice, champ, quantite) end
    else
      local a = math.max(t0, limite * largeur)
      for indice = math.floor(a / largeur), derniere_case(t1, largeur) do
        local recouvre = math.min(t1, (indice + 1) * largeur) - math.max(a, indice * largeur)
        if recouvre > 0 then ajouter(grille, indice, champ, quantite * recouvre / (t1 - t0)) end
      end
    end
  end
end

-- Vrai si `quantite` items en `duree` s dépassent nettement le `rythme` habituel (items/s) ; rythme nul : tout
-- mouvement non nul est anormal.
local function anormale(quantite, rythme, duree)
  return quantite > 0 and quantite > flux.SEUIL_ANORMAL * rythme * duree
end

-- Retire de l'attente et renvoie la baisse que rembourse `exces` : la plus proche en taille, à
-- `TOLERANCE_RETOUR` près ; nil sinon. Sa part dans le rythme des baisses en est retirée.
local function apparier(objet, exces)
  local choisie, ecart_choisi
  for i, baisse in ipairs(objet.attente) do
    local ecart = math.abs(exces - baisse.n)
    if ecart <= flux.TOLERANCE_RETOUR * baisse.n and (ecart_choisi == nil or ecart < ecart_choisi) then
      choisie, ecart_choisi = i, ecart
    end
  end
  if not choisie then return nil end
  local baisse = table.remove(objet.attente, choisie)
  objet.baisses = math.max(0, objet.baisses - baisse.part)
  return baisse
end

-- Applique au `objet` la nouvelle quantité `quantite` mesurée à `t1` (mesure précédente à `t0`, `t1 > t0`). Une
-- baisse anormale attend `delai` s d'être remboursée par une hausse anormale d'excédent voisin ; sinon elle devient
-- une consommation datée de la baisse. Une part annulée n'entre dans aucun rythme.
local function evoluer(objet, quantite, t0, t1, delai)
  local variation, duree = quantite - objet.stock, t1 - t0
  objet.stock = quantite
  local annulable = delai > 0 and objet.mesures >= flux.HISTORIQUE_MINI
  local hausse, baisse, en_attente = 0, 0, false
  if variation > 0 then
    local rendue = nil
    if annulable and anormale(variation, objet.hausses, duree) then
      rendue = apparier(objet, variation - objet.hausses * duree)
    end
    local reste = variation - (rendue and rendue.n or 0)
    if reste > 0 then
      hausse = reste
      ranger(objet, t0, t1, "production", reste, t1)
    elseif reste < 0 then
      ranger(objet, t0, t1, "consommation", -reste, t1)
    end
  elseif variation < 0 then
    baisse = -variation
    en_attente = annulable and anormale(baisse, objet.baisses, duree)
    if not en_attente then ranger(objet, t0, t1, "consommation", baisse, t1) end
  end
  local poids = math.max(1 / (objet.mesures + 1), flux.POIDS_RYTHME)
  objet.hausses = objet.hausses + (hausse / duree - objet.hausses) * poids
  objet.baisses = objet.baisses + (baisse / duree - objet.baisses) * poids
  for _, autre in ipairs(objet.attente) do autre.part = autre.part * (1 - poids) end
  if en_attente then
    objet.attente[#objet.attente + 1] = { t0 = t0, t1 = t1, n = baisse, part = poids * baisse / duree }
  end
  objet.mesures = objet.mesures + 1
  while objet.attente[1] and t1 - objet.attente[1].t1 >= delai do
    local expiree = table.remove(objet.attente, 1)
    ranger(objet, expiree.t0, expiree.t1, "consommation", expiree.n, t1)
  end
  for _, spec in ipairs(GRILLES) do purger(objet[spec.nom], premiere_gardee(spec, t1)) end
end

-- Instantané pris comme base : stocks recalés sans variation (le départ suit le saut), absents à 0, baisses en
-- attente abandonnées.
local function prendre_base(etat, instantane, instant)
  local premier = etat.debut == nil
  for cle, quantite in pairs(instantane) do
    local objet = etat.objets[cle]
    if objet then
      objet.depart.n = objet.depart.n + quantite - objet.stock
      objet.stock, objet.attente = quantite, {}
    else
      creer(etat, cle, instant, instant, quantite)
    end
  end
  if not premier then
    for cle, objet in pairs(etat.objets) do
      if instantane[cle] == nil then
        objet.depart.n = objet.depart.n - objet.stock
        objet.stock, objet.attente = 0, {}
      end
    end
  end
  etat.debut = etat.debut or instant
  etat.base, etat.instant = instantane, instant
end

--- Note l'instantané `instantane` ({ [cle] = quantité }, lecture réussie) mesuré à `instant` (secondes), avec
--- `reglages` { seuil_coupure, delai_aller_retour }. Renvoie "coupure" (rien n'est noté : la dernière lecture
--- valide reste la référence et la base), "base" (aucun débit : premier instantané, après `rebaser`, horloge qui
--- recule ou n'avance pas, ou `COUPURES_ACCEPTEES` coupures d'affilée prises comme nouvel état du réseau) ou
--- "mesure" (variations depuis la dernière lecture valide). Une clé absente vaut 0 ; un objet à 0 sans case ni
--- baisse en attente est retiré.
function flux.noter(etat, instantane, instant, reglages)
  if inventaire.coupure(etat.reference, instantane, reglages.seuil_coupure) then
    etat.coupures = etat.coupures + 1
    if etat.coupures < flux.COUPURES_ACCEPTEES then return "coupure" end
    etat.base = nil
  end
  etat.coupures, etat.reference = 0, instantane
  if etat.base == nil or instant <= etat.instant then
    prendre_base(etat, instantane, instant)
    return "base"
  end
  local t0, delai = etat.instant, reglages.delai_aller_retour
  for cle, quantite in pairs(instantane) do
    local objet = etat.objets[cle] or creer(etat, cle, etat.debut, t0, 0)
    evoluer(objet, quantite, t0, instant, delai)
  end
  for cle, objet in pairs(etat.objets) do
    if instantane[cle] == nil then
      evoluer(objet, 0, t0, instant, delai)
      if objet.fines.nombre == 0 and objet.larges.nombre == 0 and not objet.attente[1] then
        etat.objets[cle] = nil
      end
    end
  end
  etat.base, etat.instant = instantane, instant
  return "mesure"
end

--- Le prochain instantané noté servira de base (sans débit ni détection de coupure) : à appeler quand l'ensemble
--- des ids lus change.
function flux.rebaser(etat)
  etat.base, etat.reference = nil, nil
end

--- Donne aux objets connus les noms de `noms` ({ [cle] = nom affiché }).
function flux.nommer(etat, noms)
  for cle, nom in pairs(noms) do
    if etat.objets[cle] then etat.objets[cle].nom = nom end
  end
end

-- Grille qui sert une durée : fines jusqu'à leur portée, larges au-delà.
local function grille_pour(duree)
  if duree <= flux.FINES.largeur * flux.FINES.nombre then return flux.FINES end
  return flux.LARGES
end

--- Débits moyens de `cle` sur les `fenetre` secondes qui finissent à `instant` : production/s, consommation/s,
--- net/s, puis `partiel` (historique plus court que 95 % de la fenêtre). Objet inconnu : 0, 0, 0, true.
function flux.debits(etat, cle, fenetre, instant)
  local objet = etat.objets[cle]
  if not objet then return 0, 0, 0, true end
  local spec = grille_pour(fenetre)
  local largeur, cases = spec.largeur, objet[spec.nom].cases
  local derniere = derniere_case(instant, largeur)
  local premiere = derniere - math.ceil(fenetre / largeur) + 1
  local couvert = instant - math.max(premiere * largeur, objet.debut)
  if couvert <= 0 then return 0, 0, 0, true end
  local production, consommation = 0, 0
  for indice = premiere, derniere do
    local case = cases[indice]
    if case then production, consommation = production + case.production, consommation + case.consommation end
  end
  local partiel = instant - objet.debut < fenetre * flux.COUVERTURE_MINI
  return production / couvert, consommation / couvert, (production - consommation) / couvert, partiel
end

--- Barres de `cle` couvrant `duree` secondes jusqu'à `instant`, de la plus ancienne à la plus récente : une par
--- case (10 s jusqu'à 600 s, 1 min au-delà), { production, consommation } en items/s et `vide` (case entièrement
--- avant l'historique). Les cases sont alignées sur le temps absolu : stables d'une mesure à l'autre.
function flux.barres(etat, cle, duree, instant)
  local objet = etat.objets[cle]
  local spec = grille_pour(duree)
  local largeur = spec.largeur
  local nombre = math.ceil(duree / largeur)
  local derniere = derniere_case(instant, largeur)
  local barres = {}
  for k = 1, nombre do
    local indice = derniere - nombre + k
    local case = objet and objet[spec.nom].cases[indice]
    barres[k] = {
      production = case and case.production / largeur or 0,
      consommation = case and case.consommation / largeur or 0,
      vide = objet == nil or (indice + 1) * largeur <= objet.debut,
    }
  end
  return barres
end

--- Variation du stock de `cle` et durée écoulée depuis son départ (premier instantané ou dernier reset), à la
--- dernière mesure. nil si l'objet est inconnu ou sans durée.
function flux.depuis_depart(etat, cle)
  local objet = etat.objets[cle]
  if not objet or etat.instant == nil or etat.instant <= objet.depart.t then return nil end
  return objet.stock - objet.depart.n, etat.instant - objet.depart.t
end

--- Remet à zéro le suivi de `cle` à la dernière mesure : cases et baisses en attente vidées, départ et début de
--- l'historique recalés. Objet inconnu : rien.
function flux.reinitialiser(etat, cle)
  local objet = etat.objets[cle]
  if not objet then return end
  objet.fines, objet.larges, objet.attente = grille_vide(), grille_vide(), {}
  objet.depart = { t = etat.instant, n = objet.stock }
  objet.debut = etat.instant
end

return flux
