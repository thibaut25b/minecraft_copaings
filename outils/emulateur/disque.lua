-- Disque émulé de CC : fichiers en mémoire derrière l'API `fs`, changements exportables pour les garder entre deux visites.

local disque = {}

local MODES = { r = "lecture", rb = "lecture", w = "ecriture", wb = "ecriture", a = "ajout", ab = "ajout" }
local ESPACE = 1000000

--- Forme canonique d'un chemin comme `fs.combine` : sans « / » au bord, « . » et « .. » résolus. Erreur si on sort de la racine.
function disque.normaliser(chemin)
  local parties = {}
  for partie in tostring(chemin):gsub("\\", "/"):gmatch("[^/]+") do
    if partie == ".." then
      if #parties == 0 then error("/" .. tostring(chemin) .. ": Invalid Path", 3) end
      parties[#parties] = nil
    elseif partie ~= "." then
      parties[#parties + 1] = partie
    end
  end
  return table.concat(parties, "/")
end

local function parent(chemin)
  return chemin:match("^(.*)/[^/]*$") or ""
end

--- Crée un disque contenant `fichiers` (chemin -> contenu). Renvoie l'objet disque, dont `disque.fs` est l'API de CC.
function disque.creer(fichiers)
  local contenus, dossiers, modifies = {}, {}, {}
  local change = false
  local fs = {}
  local objet = { fs = fs }

  local function marquer(chemin)
    modifies[chemin] = true
    change = true
  end

  local function creer_dossier(chemin, noter)
    while chemin ~= "" and not dossiers[chemin] do
      dossiers[chemin] = true
      if noter then marquer(chemin) end
      chemin = parent(chemin)
    end
  end

  local function poser(chemin, contenu, noter)
    creer_dossier(parent(chemin), noter)
    contenus[chemin] = contenu
    if noter then marquer(chemin) end
  end

  local function est_dossier(chemin) return chemin == "" or dossiers[chemin] == true end
  local function existe(chemin) return contenus[chemin] ~= nil or est_dossier(chemin) end

  -- Chemins du sous-arbre `chemin` (lui compris) : fichiers puis dossiers.
  local function sous_arbre(chemin)
    local liste = {}
    for _, table_ in ipairs({ contenus, dossiers }) do
      for cle in pairs(table_) do
        if cle == chemin or cle:sub(1, #chemin + 1) == chemin .. "/" then liste[#liste + 1] = cle end
      end
    end
    return liste
  end

  local function supprimer(chemin)
    for _, cle in ipairs(sous_arbre(chemin)) do
      contenus[cle], dossiers[cle] = nil, nil
      marquer(cle)
    end
  end

  local function copier(source, destination)
    if not existe(source) then error("/" .. source .. ": No such file", 3) end
    if existe(destination) then error("/" .. destination .. ": File exists", 3) end
    if destination == source or destination:sub(1, #source + 1) == source .. "/" then
      error("/" .. destination .. ": Can't copy a directory inside itself", 3)
    end
    for _, cle in ipairs(sous_arbre(source)) do
      local cible = destination .. cle:sub(#source + 1)
      if contenus[cle] then poser(cible, contenus[cle], true) else creer_dossier(cible, true) end
    end
  end

  for chemin, contenu in pairs(fichiers or {}) do poser(disque.normaliser(chemin), contenu, false) end

  function fs.combine(...)
    return disque.normaliser(table.concat({ ... }, "/"))
  end
  function fs.exists(chemin) return existe(disque.normaliser(chemin)) end
  function fs.isDir(chemin) return est_dossier(disque.normaliser(chemin)) end
  function fs.isReadOnly() return false end
  function fs.getName(chemin)
    local nom = disque.normaliser(chemin):match("[^/]*$")
    return nom == "" and "root" or nom
  end
  function fs.getDir(chemin)
    local normal = disque.normaliser(chemin)
    return normal == "" and ".." or parent(normal)
  end
  function fs.getDrive(chemin)
    return existe(disque.normaliser(chemin)) and "hdd" or nil
  end
  function fs.getFreeSpace() return ESPACE end
  function fs.getCapacity() return ESPACE end

  function fs.getSize(chemin)
    local normal = disque.normaliser(chemin)
    if contenus[normal] then return #contenus[normal] end
    if est_dossier(normal) then return 0 end
    error("/" .. normal .. ": No such file", 2)
  end

  function fs.attributes(chemin)
    local normal = disque.normaliser(chemin)
    if not existe(normal) then error("/" .. normal .. ": No such file", 2) end
    return { size = contenus[normal] and #contenus[normal] or 0, isDir = est_dossier(normal), isReadOnly = false,
      created = 0, modified = 0, modification = 0 }
  end

  function fs.list(chemin)
    local normal = disque.normaliser(chemin)
    if not est_dossier(normal) then error("/" .. normal .. ": Not a directory", 2) end
    local noms = {}
    for _, table_ in ipairs({ contenus, dossiers }) do
      for cle in pairs(table_) do
        if cle ~= "" and parent(cle) == normal then noms[#noms + 1] = cle:match("[^/]*$") end
      end
    end
    table.sort(noms)
    return noms
  end

  function fs.makeDir(chemin)
    local normal = disque.normaliser(chemin)
    if contenus[normal] then error("/" .. normal .. ": File exists", 2) end
    creer_dossier(normal, true)
  end

  function fs.delete(chemin)
    supprimer(disque.normaliser(chemin))
  end

  function fs.copy(source, destination)
    copier(disque.normaliser(source), disque.normaliser(destination))
  end

  function fs.move(source, destination)
    local depart = disque.normaliser(source)
    copier(depart, disque.normaliser(destination))
    supprimer(depart)
  end

  --- Ouvre un fichier : modes r, w, a (et rb, wb, ab). Renvoie un objet fichier, ou `nil, message`.
  function fs.open(chemin, mode)
    local normal = disque.normaliser(chemin)
    local genre = MODES[mode]
    if not genre then error("Unsupported mode", 2) end
    local binaire = mode:sub(2, 2) == "b"
    local ouvert = true
    local fichier = {}
    local function verifier()
      if not ouvert then error("attempt to use a closed file", 3) end
    end
    function fichier.close()
      verifier()
      if fichier.flush then fichier.flush() end
      ouvert = false
    end

    if genre == "lecture" then
      local contenu = contenus[normal]
      if not contenu then return nil, "/" .. normal .. ": No such file" end
      local position = 1
      function fichier.readAll()
        verifier()
        local reste = contenu:sub(position)
        position = #contenu + 1
        return reste
      end
      function fichier.readLine(avec_fin)
        verifier()
        if position > #contenu then return nil end
        local fin = contenu:find("\n", position, true) or #contenu
        local ligne = contenu:sub(position, fin)
        position = fin + 1
        if avec_fin then return ligne end
        return (ligne:gsub("\r?\n$", ""))
      end
      function fichier.read(nombre)
        verifier()
        if position > #contenu then return nil end
        if binaire and nombre == nil then
          position = position + 1
          return contenu:byte(position - 1)
        end
        local morceau = contenu:sub(position, position + (nombre or 1) - 1)
        position = position + #morceau
        return morceau
      end
      return fichier
    end

    if est_dossier(normal) then return nil, "/" .. normal .. ": Cannot write to directory" end
    if genre == "ecriture" or not contenus[normal] then poser(normal, "", true) end
    local tampon = {}
    function fichier.write(valeur)
      verifier()
      tampon[#tampon + 1] = (binaire and type(valeur) == "number") and string.char(valeur) or tostring(valeur)
    end
    function fichier.writeLine(valeur)
      verifier()
      tampon[#tampon + 1] = tostring(valeur) .. "\n"
    end
    function fichier.flush()
      verifier()
      if #tampon == 0 then return end
      poser(normal, (contenus[normal] or "") .. table.concat(tampon), true)
      tampon = {}
    end
    return fichier
  end

  --- Changements depuis la création en source Lua (`return { [chemin] = contenu | true (dossier) | false }`),
  --- ou nil si rien n'a changé depuis le dernier export.
  function objet.exporter()
    if not change then return nil end
    change = false
    local lignes = { "return {" }
    local chemins = {}
    for chemin in pairs(modifies) do chemins[#chemins + 1] = chemin end
    table.sort(chemins)
    for _, chemin in ipairs(chemins) do
      local valeur = contenus[chemin] and string.format("%q", contenus[chemin]) or tostring(dossiers[chemin] == true)
      lignes[#lignes + 1] = "[" .. string.format("%q", chemin) .. "] = " .. valeur .. ","
    end
    lignes[#lignes + 1] = "}"
    return table.concat(lignes, "\n")
  end

  --- Réapplique un export ; un texte illisible est ignoré. Renvoie true si l'export a été appliqué.
  function objet.importer(texte)
    local chargeur = load(texte, "=disque", "t", {})
    local ok, changements = false, nil
    if chargeur then ok, changements = pcall(chargeur) end
    if not ok or type(changements) ~= "table" then return false end
    local chemins = {}
    for chemin in pairs(changements) do chemins[#chemins + 1] = chemin end
    table.sort(chemins)
    for _, chemin in ipairs(chemins) do
      local valeur = changements[chemin]
      if type(valeur) == "string" then
        poser(chemin, valeur, true)
      elseif valeur == true then
        creer_dossier(chemin, true)
      else
        contenus[chemin], dossiers[chemin] = nil, nil
        marquer(chemin)
      end
    end
    change = false
    return true
  end

  --- Texte de diagnostic : chaque fichier écrit par le programme, sa taille et ses `lignes_max` dernières lignes.
  function objet.resumer(lignes_max)
    local chemins, morceaux = {}, {}
    for chemin in pairs(modifies) do
      if contenus[chemin] then chemins[#chemins + 1] = chemin end
    end
    table.sort(chemins)
    for _, chemin in ipairs(chemins) do
      local lignes = {}
      for ligne in (contenus[chemin] .. "\n"):gmatch("(.-)\r?\n") do lignes[#lignes + 1] = ligne end
      if lignes[#lignes] == "" then lignes[#lignes] = nil end
      morceaux[#morceaux + 1] = "== " .. chemin .. " (" .. #contenus[chemin] .. " octets, " .. #lignes .. " lignes)"
      for i = math.max(1, #lignes - lignes_max + 1), #lignes do morceaux[#morceaux + 1] = lignes[i] end
    end
    return table.concat(morceaux, "\n")
  end

  return objet
end

return disque
