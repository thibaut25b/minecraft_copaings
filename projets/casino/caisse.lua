-- Caisse du casino : la seule interface des jeux vers les jetons. Cette version tient des jetons fictifs.
-- Règle de reprise : un tour est écrit en une fois avec sa mise et le gain qu'il donne si le joueur ne touche plus à
-- rien ; un tour resté en suspens (arrêt en plein tour) est réglé à ce gain à la réouverture.

local caisse = {}

local function entier(valeur, minimum)
  return type(valeur) == "number" and valeur == math.floor(valeur) and valeur >= minimum
end

local function lisible(etat)
  if type(etat) ~= "table" or not entier(etat.solde, 0) then return false end
  if etat.en_cours == nil then return true end
  return type(etat.en_cours) == "table" and entier(etat.en_cours.mise, 1) and entier(etat.en_cours.gain, 0)
end

--- Ouvre la caisse sur `depot` ({ lire() -> table ou nil, ecrire(table) -> true ou false, message }) avec
--- `regles` = { depart, recharge }. Renvoie la caisse, le tour repris ({ mise, gain }) ou nil, et un message si
--- l'état n'a pas pu être relu ou écrit.
---
--- La caisse : solde() ; miser(montant, gain_prevu) -> true ou false, raison ; regler(gain) -> true ou false,
--- raison ; recharger() -> true, montant ou false, raison ; en_cours() -> booléen.
function caisse.ouvrir(depot, regles)
  local etat = depot.lire()
  local reprise, probleme
  local function enregistrer(nouvel)
    etat = nouvel
    local ok, message = depot.ecrire(nouvel)
    if not ok then
      probleme = "Jetons non enregistrés : " .. tostring(message)
      return false, probleme
    end
    return true
  end

  if not lisible(etat) then
    if etat ~= nil then probleme = "Jetons illisibles : solde de départ rendu" end
    enregistrer({ solde = regles.depart })
  end
  if etat.en_cours then
    reprise = etat.en_cours
    enregistrer({ solde = etat.solde + reprise.gain })
  end

  local objet = {}

  --- Jetons disponibles.
  function objet.solde()
    return etat.solde
  end

  --- Vrai si une mise attend son règlement.
  function objet.en_cours()
    return etat.en_cours ~= nil
  end

  --- Retire `montant` du solde et ouvre un tour qui vaut `gain_prevu` si le joueur ne fait plus rien.
  function objet.miser(montant, gain_prevu)
    if not entier(gain_prevu, 0) then error("gain prévu invalide : " .. tostring(gain_prevu), 2) end
    if etat.en_cours then return false, "Un tour est déjà en cours." end
    if not entier(montant, 1) then return false, "Mise invalide : " .. tostring(montant) end
    if montant > etat.solde then
      return false, "Solde insuffisant : " .. etat.solde .. " jetons. Recharge au hall."
    end
    local ancien = etat
    local ok, raison = enregistrer({ solde = etat.solde - montant, en_cours = { mise = montant, gain = gain_prevu } })
    if not ok then etat = ancien end
    return ok, raison
  end

  --- Verse `gain` (mise comprise, 0 pour une perte) et ferme le tour. Une écriture ratée garde le tour en suspens
  --- dans le fichier : il sera réglé au gain prévu à la réouverture.
  function objet.regler(gain)
    if not etat.en_cours then error("aucun tour à régler", 2) end
    if not entier(gain, 0) then error("gain invalide : " .. tostring(gain), 2) end
    return enregistrer({ solde = etat.solde + gain })
  end

  --- Ajoute les jetons gratuits de la démo, hors tour en cours.
  function objet.recharger()
    if etat.en_cours then return false, "Termine d'abord le tour en cours." end
    local ancien = etat
    local ok, raison = enregistrer({ solde = etat.solde + regles.recharge })
    if not ok then
      etat = ancien
      return false, raison
    end
    return true, regles.recharge
  end

  return objet, reprise, probleme
end

return caisse
