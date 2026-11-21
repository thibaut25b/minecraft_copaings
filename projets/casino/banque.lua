-- Banque du casino en vraie monnaie : valeurs des pièces (lc_money), dépôts, encaissements et valeur de la réserve.
-- Seules les pièces bougent, par pushItems entre inventaires vus par l'ordinateur ; chaque mouvement est journalisé.
-- Dépôt : pièces poussées vers la réserve, puis crédit de ce qui a bougé (coupure entre les deux : la maison garde).
-- Encaissement, lot par lot : solde décrémenté et écrit, puis pièces poussées vers la sortie, puis recrédit de ce qui
-- n'a pas bougé (coupure avant le recrédit, ou envoi en erreur : la maison garde, le journal dit quoi rembourser).

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

--- Banque sur les réglages (depot, sortie, reserve, pieces, type_monnaie), l'API `lc_money` (nil si le mod manque)
--- et le journal `trace`. Champs lus par l'écran : pret, probleme, reserve (valeur en crédits), valeurs.
--- Méthodes : verifier() ; lire_valeurs() -> true ou false, message ; relever(caisse) -> credite, messages ;
--- encaisser(caisse) -> verse, message.
function banque.ouvrir(reglages, api, trace)
  local b = { pret = false, probleme = "Banque pas encore vérifiée", reserve = nil, valeurs = nil }

  local function inventaire(cle)
    return peripheriques.par_nom(reglages[cle])
  end

  local function suspendre(probleme)
    b.pret, b.probleme, b.reserve = false, probleme, nil
    return false
  end

  --- Lit la valeur de chaque pièce de la liste par lc_money ; garde les anciennes valeurs si la lecture échoue.
  function b.lire_valeurs()
    if type(api) ~= "table" or type(api.readInventoryValues) ~= "function" then
      return false, "API lc_money absente : Lightman's Currency n'est pas chargé"
    end
    local valeurs, decrites = {}, {}
    for _, piece in ipairs(reglages.pieces) do
      local ok, resultat = pcall(api.readInventoryValues, { { name = piece.id, count = 1 } })
      if not ok then return false, "lc_money : " .. tostring(resultat) end
      local entree = type(resultat) == "table" and resultat[reglages.type_monnaie]
      if type(entree) == "table" and type(entree.numeric) == "number" and entree.numeric >= 1 then
        valeurs[piece.id] = math.floor(entree.numeric)
        decrites[#decrites + 1] = piece.nom .. " = " .. valeurs[piece.id]
      end
    end
    if next(valeurs) == nil then
      return false, "lc_money ne donne aucune valeur pour les pièces réglées (type " .. reglages.type_monnaie .. ")"
    end
    local resume = table.concat(decrites, ", ")
    if resume ~= b.resume_valeurs then trace.info("Valeurs des pièces : " .. resume) end
    b.valeurs, b.resume_valeurs = valeurs, resume
    return true
  end

  --- Vérifie les trois inventaires et relit la valeur de la réserve ; sinon suspend le jeu avec le problème exact.
  function b.verifier()
    local manques = {}
    if type(api) ~= "table" then manques[#manques + 1] = "API lc_money absente (Lightman's Currency)" end
    for _, role in ipairs(ROLES) do
      local nom = reglages[role.cle]
      if nom == "" then
        manques[#manques + 1] = "réglage " .. role.cle .. " vide (" .. role.titre .. ")"
      elseif not inventaire(role.cle) then
        manques[#manques + 1] = role.titre .. " « " .. nom .. " » introuvable"
      end
    end
    if #manques > 0 then
      local visibles = peripheriques.visibles()
      return suspendre(table.concat(manques, " ; ") .. ". Visibles : "
        .. (#visibles > 0 and table.concat(visibles, ", ") or "aucun"))
    end
    if not b.valeurs then
      local ok, message = b.lire_valeurs()
      if not ok then return suspendre(message) end
    end
    local ok, contenu = peripheriques.appel(inventaire("reserve"), "list")
    if not ok then return suspendre("Réserve illisible : " .. tostring(contenu)) end
    b.pret, b.probleme, b.reserve = true, nil, monnaie.valeur(contenu, b.valeurs)
    return true
  end

  --- Range dans la réserve les pièces du coffre de dépôt et crédite ce qui a réellement bougé ; renvoie l'objet
  --- étranger vers la sortie. Renvoie les crédits ajoutés et la liste des messages pour le joueur.
  function b.relever(caisse)
    local messages, credite = {}, 0
    if not b.pret then return 0, messages end
    local depot = inventaire("depot")
    local ok, contenu = peripheriques.appel(depot, "list")
    if not ok then
      suspendre("Coffre de dépôt illisible : " .. tostring(contenu))
      return 0, messages
    end
    for _, emplacement in ipairs(emplacements(contenu)) do
      local pile = contenu[emplacement]
      local valeur = b.valeurs[pile.name]
      if valeur then
        local pousse, bouge = peripheriques.appel(depot, "pushItems", reglages.reserve, emplacement)
        if not pousse then
          trace.erreur(string.format("Dépôt : %d x %s non rangées (%s), rien crédité", pile.count, pile.name,
            tostring(bouge)))
        elseif bouge > 0 then
          trace.info(string.format("Dépôt : %d x %s rangées dans la réserve", bouge, pile.name))
          local ecrit, raison = caisse.crediter(bouge * valeur)
          if ecrit then
            trace.info(string.format("Dépôt : +%d crédits, solde %d", bouge * valeur, caisse.solde()))
            credite = credite + bouge * valeur
          else
            trace.erreur(string.format("Dépôt : %d crédits NON enregistrés (%s), à rembourser", bouge * valeur,
              tostring(raison)))
          end
        end
        if pousse and bouge < pile.count then
          messages[#messages + 1] = "Réserve pleine : des pièces restent dans le coffre de dépôt."
        end
      else
        local rendu, nombre = peripheriques.appel(depot, "pushItems", reglages.sortie, emplacement)
        local renvoye = rendu and nombre == pile.count
        trace.info(string.format("Dépôt : objet refusé %d x %s, %s", pile.count, pile.name,
          renvoye and "renvoyé au coffre de sortie" or "laissé dans le dépôt"))
        messages[#messages + 1] = "Objet refusé (" .. pile.name .. ") : "
          .. (renvoye and "rendu dans le coffre de sortie." or "reprends-le dans le dépôt.")
      end
    end
    b.verifier()
    return credite, messages
  end

  --- Verse le solde en pièces, des plus grosses aux plus petites que la réserve possède. Renvoie les crédits versés
  --- et un message si tout n'a pas pu l'être (le reste demeure en crédits).
  function b.encaisser(caisse)
    if not b.verifier() then return 0, b.probleme end
    local reserve = inventaire("reserve")
    local ok, contenu = peripheriques.appel(reserve, "list")
    if not ok then return 0, "Réserve illisible : " .. tostring(contenu) end
    local demande = caisse.solde()
    local lots = monnaie.rendu(demande, monnaie.stock(contenu, b.valeurs), b.valeurs)
    trace.info(string.format("Encaissement demandé : %d crédits", demande))
    local verse, sortie_pleine = 0, false
    for _, lot in ipairs(lots) do
      local reste, valeur = lot.nombre, b.valeurs[lot.piece]
      for _, emplacement in ipairs(emplacements(contenu)) do
        local pile = contenu[emplacement]
        if reste == 0 or sortie_pleine then break end
        if pile.name == lot.piece and pile.count > 0 then
          local nombre = math.min(reste, pile.count)
          local retire, raison = caisse.retirer(nombre * valeur)
          if not retire then
            trace.erreur("Encaissement arrêté : " .. tostring(raison))
            b.verifier()
            return verse, raison
          end
          trace.info(string.format("Encaissement : -%d crédits (solde %d), envoi de %d x %s", nombre * valeur,
            caisse.solde(), nombre, lot.piece))
          local pousse, bouge = peripheriques.appel(reserve, "pushItems", reglages.sortie, emplacement, nombre)
          if not pousse then
            trace.erreur(string.format("Encaissement : envoi incertain de %d x %s (%s), %d crédits non recrédités, "
              .. "à vérifier", nombre, lot.piece, tostring(bouge), nombre * valeur))
            b.verifier()
            return verse, "Panne pendant l'encaissement : préviens un admin (journal du casino)."
          end
          trace.info(string.format("Encaissement : %d x %s versées", bouge, lot.piece))
          verse, reste, pile.count = verse + bouge * valeur, reste - bouge, pile.count - bouge
          if bouge < nombre then
            caisse.crediter((nombre - bouge) * valeur)
            trace.info(string.format("Encaissement : +%d crédits rendus au solde (sortie pleine)",
              (nombre - bouge) * valeur))
            sortie_pleine = true
          end
        end
      end
    end
    b.verifier()
    if sortie_pleine then return verse, "Coffre de sortie plein : vide-le puis touche Encaisser." end
    if verse < demande then
      return verse, "Pas la monnaie exacte : " .. texte.quantite(demande - verse, "crédit")
        .. " restent au solde. Dépose une petite pièce ou rejoue-les."
    end
    return verse
  end

  return b
end

return banque
