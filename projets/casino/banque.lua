-- Banque du casino en vraie monnaie : valeurs des pièces (lc_money), dépôts, encaissements et valeur de la réserve.
-- Seules les pièces bougent, par pushItems entre inventaires vus par l'ordinateur ; chaque mouvement est journalisé.
-- Règle : on ne crédite et on ne débite jamais d'après ce qu'on a vu, seulement d'après la valeur que la réserve a
-- réellement gagnée ou perdue, relue juste avant et juste après chaque mouvement (le casino est seul à la toucher,
-- et un seul mouvement à la fois : relevé et encaissement ne s'entrelacent pas).
-- Dépôt d'un emplacement : réserve relue, pushItems borné au nombre vu, réserve relue, crédit de la différence.
-- Encaissement d'un lot : réserve relue, solde diminué et écrit, pushItems borné, réserve relue, recrédit de ce qui
-- n'est pas sorti. Réserve illisible après un mouvement : rien n'est crédité ni recrédité (la maison garde), le
-- journal dit quoi vérifier.

local peripheriques = require("commun.peripheriques")
local texte = require("commun.texte")
local monnaie = require("casino.monnaie")

local banque = {}

local ROLES = {
  { cle = "depot", titre = "coffre de dépôt" },
  { cle = "sortie", titre = "coffre de sortie" },
  { cle = "reserve", titre = "réserve" },
}

-- Emplacements d'un contenu d'inventaire, dans l'ordre.
local function emplacements(contenu)
  local liste = {}
  for emplacement in pairs(contenu) do liste[#liste + 1] = emplacement end
  table.sort(liste)
  return liste
end

local function titre_de(cle)
  for _, role in ipairs(ROLES) do
    if role.cle == cle then return role.titre end
  end
end

--- Banque sur les réglages (depot, sortie, reserve, pieces, type_monnaie), l'API `lc_money` (nil si le mod manque)
--- et le journal `trace`. Champs lus par l'écran : pret, probleme, reserve (valeur en crédits), valeurs, petite
--- (plus petite pièce présente dans la réserve, en crédits), encaissable (réserve et sortie utilisables). Méthodes : verifier() ; lire_valeurs() -> true ou false,
--- message ; relever(caisse) -> credite, messages ; encaisser(caisse) -> verse, message.
function banque.ouvrir(reglages, api, trace)
  local b = { pret = false, probleme = "Banque pas encore vérifiée", reserve = nil, valeurs = nil }
  local occupe = false
  local annoncees = {}

  local function inventaire(cle)
    return peripheriques.par_nom(reglages[cle])
  end

  local function suspendre(probleme)
    b.pret, b.probleme, b.reserve = false, probleme, nil
    return false
  end

  --- Lit la valeur de chaque pièce par lc_money. Une pièce sans réponse garde sa valeur connue (anomalie
  --- journalisée) : une relecture partielle ne retire jamais de valeur.
  function b.lire_valeurs()
    if type(api) ~= "table" or type(api.readInventoryValues) ~= "function" then
      return false, "API lc_money absente : Lightman's Currency n'est pas chargé"
    end
    local valeurs, decrites, muettes = {}, {}, {}
    for _, piece in ipairs(reglages.pieces) do
      local ok, resultat = pcall(api.readInventoryValues, { { name = piece.id, count = 1 } })
      local entree = ok and type(resultat) == "table" and resultat[reglages.type_monnaie]
      if type(entree) == "table" and type(entree.numeric) == "number" and entree.numeric >= 1 then
        valeurs[piece.id] = math.floor(entree.numeric)
      elseif b.valeurs and b.valeurs[piece.id] then
        valeurs[piece.id] = b.valeurs[piece.id]
        muettes[#muettes + 1] = piece.nom
      end
      if valeurs[piece.id] then decrites[#decrites + 1] = piece.nom .. " = " .. valeurs[piece.id] end
    end
    if #muettes > 0 then
      trace.erreur("lc_money ne donne plus de valeur pour : " .. table.concat(muettes, ", ") .. " ; ancienne gardée")
    end
    if next(valeurs) == nil then
      return false, "lc_money ne donne aucune valeur pour les pièces réglées (type " .. reglages.type_monnaie .. ")"
    end
    local resume = table.concat(decrites, ", ")
    if resume ~= b.resume_valeurs then trace.info("Valeurs des pièces : " .. resume) end
    b.valeurs, b.resume_valeurs = valeurs, resume
    return true
  end

  -- Problème des inventaires `cles` (nil si tout va bien) : API absente, noms en double, réglage vide, introuvable.
  local function controler(cles)
    local manques = {}
    if type(api) ~= "table" then manques[#manques + 1] = "API lc_money absente (Lightman's Currency)" end
    local vus = {}
    for _, role in ipairs(ROLES) do
      local nom = reglages[role.cle]
      if nom ~= "" and vus[nom] then
        manques[#manques + 1] = vus[nom] .. " et " .. role.titre .. " ont le même nom « " .. nom
          .. " » : il faut trois coffres distincts"
      end
      vus[nom] = vus[nom] or role.titre
    end
    for _, cle in ipairs(cles) do
      if reglages[cle] == "" then
        manques[#manques + 1] = "réglage " .. cle .. " vide (" .. titre_de(cle) .. ")"
      elseif not inventaire(cle) then
        manques[#manques + 1] = titre_de(cle) .. " « " .. reglages[cle] .. " » introuvable"
      end
    end
    if #manques == 0 then return nil end
    local visibles = peripheriques.visibles()
    return table.concat(manques, " ; ") .. ". Visibles : " .. (#visibles > 0 and table.concat(visibles, ", ") or "aucun")
  end

  -- Valeur de la réserve relue maintenant (nil si illisible) et son contenu.
  local function lire_reserve()
    local ok, contenu = peripheriques.appel(inventaire("reserve"), "list")
    if not ok or type(contenu) ~= "table" then return nil, contenu end
    return monnaie.valeur(contenu, b.valeurs), contenu
  end

  -- Plus petite pièce présente dans la réserve ; l'absence de la plus petite pièce connue est journalisée une fois.
  local function noter_petite(contenu)
    local petite, plus_petite
    for _, valeur in pairs(b.valeurs) do plus_petite = math.min(plus_petite or valeur, valeur) end
    for identifiant in pairs(monnaie.stock(contenu, b.valeurs)) do
      petite = math.min(petite or b.valeurs[identifiant], b.valeurs[identifiant])
    end
    if petite ~= b.petite and petite and petite > plus_petite then
      trace.erreur("Réserve sans petite monnaie : plus petite pièce " .. petite .. " crédits ; ajoute des petites "
        .. "pièces")
    end
    b.petite = petite
  end

  -- Contrôle les inventaires `cles`, lit les valeurs si besoin puis la réserve ; renvoie son contenu, ou suspend.
  local function ouvrir_reserve(cles)
    local probleme = controler(cles)
    if probleme then return suspendre(probleme) end
    if not b.valeurs then
      local ok, message = b.lire_valeurs()
      if not ok then return suspendre(message) end
    end
    local valeur, contenu = lire_reserve()
    if not valeur then return suspendre("Réserve illisible : " .. tostring(contenu)) end
    b.reserve = valeur
    noter_petite(contenu)
    return contenu
  end

  --- Vérifie les trois inventaires (noms distincts, tous visibles) et relit la réserve ; sinon suspend le jeu avec
  --- le problème exact.
  function b.verifier()
    b.encaissable = controler({ "sortie", "reserve" }) == nil
    if not ouvrir_reserve({ "depot", "sortie", "reserve" }) then return false end
    b.pret, b.probleme = true, nil
    return true
  end

  -- Une pièce vue dans l'emplacement : poussée (au plus le nombre vu), créditée de ce que la réserve a gagné.
  -- Renvoie le crédit, un message éventuel, et false si la réserve est devenue illisible.
  local function deposer(caisse, depot, emplacement, pile)
    local avant = lire_reserve()
    if not avant then return 0, nil, false end
    local pousse, bouge = peripheriques.appel(depot, "pushItems", reglages.reserve, emplacement, pile.count)
    local apres = lire_reserve()
    if not apres then
      trace.erreur(string.format("Dépôt incertain : %d x %s vu, réserve illisible ensuite, rien crédité", pile.count,
        pile.name))
      return 0, nil, false
    end
    local gagne = apres - avant
    trace.info(string.format("Dépôt : %d x %s vu, %s, réserve %+d crédits", pile.count, pile.name,
      pousse and (tostring(bouge) .. " objets poussés") or ("erreur " .. tostring(bouge)), gagne))
    local message = pousse and bouge < pile.count and "Réserve pleine : des pièces restent dans le coffre de dépôt."
      or nil
    if gagne <= 0 then return 0, message, true end
    local ecrit, raison = caisse.crediter(gagne)
    if not ecrit then
      trace.erreur(string.format("Dépôt : %d crédits NON enregistrés (%s), à rembourser", gagne, tostring(raison)))
      return 0, message, true
    end
    trace.info(string.format("Dépôt : +%d crédits, solde %d", gagne, caisse.solde()))
    return gagne, message, true
  end

  --- Range dans la réserve les pièces du coffre de dépôt et crédite ce que la réserve a réellement gagné ; renvoie
  --- l'objet étranger vers la sortie (annoncé une seule fois tant qu'il reste). Renvoie les crédits ajoutés et les
  --- messages pour le joueur.
  function b.relever(caisse)
    local messages, credite = {}, 0
    if not b.pret or occupe then return 0, messages end
    local depot = inventaire("depot")
    local ok, contenu = peripheriques.appel(depot, "list")
    if not ok then
      suspendre("Coffre de dépôt illisible : " .. tostring(contenu))
      return 0, messages
    end
    occupe = true
    local restent = {}
    for _, emplacement in ipairs(emplacements(contenu)) do
      local pile = contenu[emplacement]
      if b.valeurs[pile.name] then
        local gagne, message, lisible = deposer(caisse, depot, emplacement, pile)
        credite = credite + gagne
        if message then messages[#messages + 1] = message end
        if not lisible then break end
      else
        local cle = emplacement .. "|" .. pile.name
        local rendu, nombre = peripheriques.appel(depot, "pushItems", reglages.sortie, emplacement, pile.count)
        local renvoye = rendu and nombre == pile.count
        if renvoye or not annoncees[cle] then
          trace.info(string.format("Dépôt : objet refusé %d x %s, %s", pile.count, pile.name,
            renvoye and "renvoyé au coffre de sortie" or "laissé dans le dépôt"))
          messages[#messages + 1] = "Objet refusé (" .. pile.name .. ") : "
            .. (renvoye and "rendu dans le coffre de sortie." or "reprends-le dans le dépôt.")
        end
        if not renvoye then restent[cle] = true end
      end
    end
    annoncees = restent
    occupe = false
    b.verifier()
    return credite, messages
  end

  -- Un lot de `nombre` pièces de l'emplacement vers la sortie : solde diminué et écrit avant l'envoi, puis recrédit
  -- de ce qui n'est pas sorti de la réserve. Renvoie la valeur sortie et un motif d'arrêt éventuel.
  local function verser(caisse, reserve, emplacement, piece, nombre, valeur)
    local montant = nombre * valeur
    local avant = lire_reserve()
    if not avant then return 0, "Réserve illisible : réessaie plus tard." end
    local retire, raison = caisse.retirer(montant)
    if not retire then return 0, raison end
    trace.info(string.format("Encaissement : -%d crédits (solde %d), envoi de %d x %s", montant, caisse.solde(),
      nombre, piece))
    local pousse, bouge = peripheriques.appel(reserve, "pushItems", reglages.sortie, emplacement, nombre)
    local apres = lire_reserve()
    if not apres then
      trace.erreur(string.format("Encaissement incertain : %d x %s (%s), réserve illisible ensuite, %d crédits non "
        .. "recrédités, à vérifier", nombre, piece, tostring(bouge), montant))
      return 0, "Panne pendant l'encaissement : préviens un admin (journal du casino)."
    end
    local sorti = avant - apres
    trace.info(string.format("Encaissement : %s, réserve -%d crédits",
      pousse and (bouge .. " x " .. piece .. " versées") or ("erreur " .. tostring(bouge)), sorti))
    if sorti < montant then
      caisse.crediter(montant - sorti)
      trace.info(string.format("Encaissement : +%d crédits rendus au solde", montant - sorti))
    elseif sorti > montant then
      trace.erreur(string.format("Encaissement : %d crédits sortis de plus que prévu, à vérifier", sorti - montant))
    end
    if not pousse then return sorti, "Envoi impossible vers le coffre de sortie : " .. tostring(bouge) end
    if sorti < montant then return sorti, "Coffre de sortie plein : vide-le puis touche Encaisser." end
    return sorti
  end

  --- Verse le solde en pièces, des plus grosses aux plus petites que la réserve possède ; n'a besoin que de la
  --- réserve et de la sortie. Renvoie les crédits versés et un message si tout n'a pas pu l'être.
  function b.encaisser(caisse)
    if occupe then return 0, "Opération en cours, réessaie." end
    local contenu = ouvrir_reserve({ "sortie", "reserve" })
    if not contenu then return 0, b.probleme end
    occupe = true
    local reserve = inventaire("reserve")
    local demande = caisse.solde()
    trace.info(string.format("Encaissement demandé : %d crédits", demande))
    local verse, arret = 0, nil
    for _, lot in ipairs((monnaie.rendu(demande, monnaie.stock(contenu, b.valeurs), b.valeurs))) do
      local reste = lot.nombre
      for _, emplacement in ipairs(emplacements(contenu)) do
        local pile = contenu[emplacement]
        if reste == 0 or arret then break end
        if pile.name == lot.piece and pile.count > 0 then
          local nombre = math.min(reste, pile.count)
          local sorti
          sorti, arret = verser(caisse, reserve, emplacement, lot.piece, nombre, b.valeurs[lot.piece])
          verse, reste, pile.count = verse + sorti, reste - nombre, pile.count - nombre
        end
      end
      if arret then break end
    end
    occupe = false
    b.verifier()
    if arret then return verse, arret end
    if verse < demande then
      return verse, "Pas la monnaie exacte : " .. texte.quantite(demande - verse, "crédit")
        .. " restent au solde. Dépose une petite pièce ou rejoue-les."
    end
    return verse
  end

  return b
end

return banque
