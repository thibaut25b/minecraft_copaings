-- Faux inventaires au format générique de CC (size, list, getItemDetail, getItemLimit, pushItems, pullItems), reliés
-- par un réseau où chacun est trouvé par son nom ; cible pleine, cible absente et panne simulables.

local coffre = {}

local PILE_DEFAUT = 64

--- Réseau vide : `inventaires` (nom -> faux), `piles` (identifiant d'objet -> taille de pile, 64 par défaut).
function coffre.reseau()
  return { inventaires = {}, piles = {} }
end

local function copie(pile)
  return pile and { name = pile.name, count = pile.count } or nil
end

--- Crée l'inventaire `nom` de `taille` emplacements dans `reseau`, rempli de `contenu` ({ [emplacement] = { name,
--- count } }). Champs de test : `panne` (texte : toute méthode lève ce message), `emplacements` (contenu brut).
function coffre.nouveau(reseau, nom, taille, contenu)
  local c = { nom = nom, emplacements = {} }
  for emplacement, pile in pairs(contenu or {}) do c.emplacements[emplacement] = copie(pile) end
  reseau.inventaires[nom] = c

  local function pile_max(objet)
    return reseau.piles[objet] or PILE_DEFAUT
  end

  local function verifier()
    if c.panne then error(c.panne, 3) end
    if reseau.inventaires[nom] ~= c then error("No peripheral attached", 3) end
  end

  local function emplacement_valide(emplacement, quoi)
    if type(emplacement) ~= "number" or emplacement < 1 or emplacement > taille then
      error(quoi .. " slot out of range", 3)
    end
  end

  -- Range jusqu'à `nombre` objets `objet` dans cet inventaire (un seul emplacement si `vise`) ; renvoie le nombre rangé.
  function c.ranger(objet, nombre, vise)
    local ranges = 0
    local function remplir(emplacement)
      local pile = c.emplacements[emplacement]
      if pile and pile.name ~= objet then return end
      local present = pile and pile.count or 0
      local ajout = math.min(nombre - ranges, pile_max(objet) - present)
      if ajout <= 0 then return end
      c.emplacements[emplacement] = { name = objet, count = present + ajout }
      ranges = ranges + ajout
    end
    if vise then
      remplir(vise)
      return ranges
    end
    for emplacement = 1, taille do
      if c.emplacements[emplacement] then remplir(emplacement) end
    end
    for emplacement = 1, taille do
      if ranges >= nombre then break end
      if not c.emplacements[emplacement] then remplir(emplacement) end
    end
    return ranges
  end

  local function deplacer(source, emplacement, cible, limite, vise)
    local pile = source.emplacements[emplacement]
    if not pile then return 0 end
    local voulu = math.min(pile.count, limite or pile.count)
    local ranges = cible.ranger(pile.name, voulu, vise)
    pile.count = pile.count - ranges
    if pile.count == 0 then source.emplacements[emplacement] = nil end
    return ranges
  end

  local function autre(nom_autre)
    local cible = reseau.inventaires[nom_autre]
    if not cible then error("Target '" .. tostring(nom_autre) .. "' does not exist", 3) end
    if cible.panne then error(cible.panne, 3) end
    return cible
  end

  function c.size()
    verifier()
    return taille
  end

  function c.list()
    verifier()
    local liste = {}
    for emplacement, pile in pairs(c.emplacements) do liste[emplacement] = copie(pile) end
    return liste
  end

  function c.getItemDetail(emplacement)
    verifier()
    emplacement_valide(emplacement, "Slot")
    local pile = c.emplacements[emplacement]
    if not pile then return nil end
    return { name = pile.name, count = pile.count, maxCount = pile_max(pile.name), displayName = pile.name }
  end

  function c.getItemLimit(emplacement)
    verifier()
    emplacement_valide(emplacement, "Slot")
    return PILE_DEFAUT
  end

  function c.pushItems(vers, depuis, limite, vise)
    verifier()
    local cible = autre(vers)
    emplacement_valide(depuis, "From")
    if vise then emplacement_valide(vise, "To") end
    return deplacer(c, depuis, cible, limite, vise)
  end

  function c.pullItems(depuis_nom, depuis, limite, vise)
    verifier()
    local source = autre(depuis_nom)
    if vise then emplacement_valide(vise, "To") end
    return deplacer(source, depuis, c, limite, vise)
  end

  --- Nombre total d'objets `objet` présents (aide de test).
  function c.compter(objet)
    local total = 0
    for _, pile in pairs(c.emplacements) do
      if pile.name == objet then total = total + pile.count end
    end
    return total
  end

  return c
end

return coffre
