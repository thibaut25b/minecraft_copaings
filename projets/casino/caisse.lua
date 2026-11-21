-- Caisse du casino : la seule interface des jeux vers le solde (jetons fictifs ou crédits en vraie monnaie).
-- Règle de reprise : un tour est écrit en une fois avec sa mise et le gain qu'il donne si le joueur ne touche plus à
-- rien ; un tour resté en suspens (arrêt en plein tour) est réglé à ce gain à la réouverture.

local texte = require("commun.texte")
local monnaie = require("casino.monnaie")

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
--- `regles` = { depart, recharge (0 : pas de recharge), unite (« jeton », « crédit »), couverture (facultatif) }.
--- `couverture()` renvoie la valeur de la réserve qui garantit les gains (nil si elle est illisible) : avec elle,
--- une mise n'est acceptée que si la réserve couvre le solde plus l'exposition du tour (voir `monnaie.couvre`).
--- Renvoie la caisse, le tour repris ({ mise, gain }) ou nil, et un message si l'état n'a pas pu être relu ou écrit.
---
--- La caisse : solde() ; miser(montant, gain_prevu, exposition) -> true ou false, raison ; regler(gain) ;
--- modifier(supplement, gain_prevu) ; recharger() -> true, montant ou false, raison ; crediter(montant) ;
--- retirer(montant) ; en_cours() -> booléen. Les écritures renvoient true, ou false et la raison.
function caisse.ouvrir(depot, regles)
  local etat, avis_lecture = depot.lire()
  local reprise, probleme
  local unite = regles.unite or "jeton"
  local function enregistrer(nouvel)
    etat = nouvel
    local ok, message = depot.ecrire(nouvel)
    if not ok then
      probleme = "Solde non enregistré : " .. tostring(message)
      return false, probleme
    end
    return true
  end

  if not lisible(etat) then
    if etat ~= nil then probleme = avis_lecture or "Solde illisible : solde de départ rendu" end
    enregistrer({ solde = regles.depart })
  end
  if etat.en_cours then
    reprise = etat.en_cours
    enregistrer({ solde = etat.solde + reprise.gain })
  end

  -- Écrit `nouvel` ; si l'écriture échoue, l'état en mémoire reste l'ancien.
  local function changer(nouvel)
    local ancien = etat
    local ok, raison = enregistrer(nouvel)
    if not ok then etat = ancien end
    return ok, raison
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

  --- Retire `montant` du solde et ouvre un tour qui vaut `gain_prevu` si le joueur ne fait plus rien. Avec une
  --- couverture, `exposition` (gain net maximal du tour) doit être couverte par la réserve.
  function objet.miser(montant, gain_prevu, exposition)
    if not entier(gain_prevu, 0) then error("gain prévu invalide : " .. tostring(gain_prevu), 2) end
    if regles.couverture and not entier(exposition, 0) then error("exposition invalide : " .. tostring(exposition), 2) end
    if etat.en_cours then return false, "Un tour est déjà en cours." end
    if not entier(montant, 1) then return false, "Mise invalide : " .. tostring(montant) end
    if montant > etat.solde then
      return false, "Solde insuffisant : " .. texte.quantite(etat.solde, unite) .. "."
    end
    if regles.couverture and not monnaie.couvre(regles.couverture(), etat.solde, exposition) then
      return false, "Réserve du casino insuffisante."
    end
    return changer({ solde = etat.solde - montant, en_cours = { mise = montant, gain = gain_prevu } })
  end

  --- Verse `gain` (mise comprise, 0 pour une perte) et ferme le tour. Une écriture ratée garde le tour en suspens
  --- dans le fichier : il sera réglé au gain prévu à la réouverture.
  function objet.regler(gain)
    if not etat.en_cours then error("aucun tour à régler", 2) end
    if not entier(gain, 0) then error("gain invalide : " .. tostring(gain), 2) end
    return enregistrer({ solde = etat.solde + gain })
  end

  --- Pendant un tour : retire `supplement` de plus (0 ou plus) et remplace le gain prévu, en une seule écriture.
  function objet.modifier(supplement, gain_prevu)
    if not etat.en_cours then error("aucun tour à modifier", 2) end
    if not entier(supplement, 0) or not entier(gain_prevu, 0) then
      error("modification invalide : " .. tostring(supplement) .. ", " .. tostring(gain_prevu), 2)
    end
    if supplement > etat.solde then
      return false, "Solde insuffisant pour doubler : " .. texte.quantite(etat.solde, unite) .. "."
    end
    return changer({ solde = etat.solde - supplement,
      en_cours = { mise = etat.en_cours.mise + supplement, gain = gain_prevu } })
  end

  --- Ajoute `montant` crédits déposés (pièces déjà rangées dans la réserve) ; un tour en cours reste ouvert.
  function objet.crediter(montant)
    if not entier(montant, 0) then error("crédit invalide : " .. tostring(montant), 2) end
    return changer({ solde = etat.solde + montant, en_cours = etat.en_cours })
  end

  --- Retire `montant` crédits avant de les verser en pièces, hors tour en cours.
  function objet.retirer(montant)
    if not entier(montant, 0) then error("retrait invalide : " .. tostring(montant), 2) end
    if etat.en_cours then return false, "Termine d'abord le tour en cours." end
    if montant > etat.solde then return false, "Solde insuffisant." end
    return changer({ solde = etat.solde - montant })
  end

  --- Ajoute les jetons gratuits de la démo, hors tour en cours.
  function objet.recharger()
    if not regles.recharge or regles.recharge <= 0 then return false, "Pas de recharge avec la vraie monnaie." end
    if etat.en_cours then return false, "Termine d'abord le tour en cours." end
    local ok, raison = changer({ solde = etat.solde + regles.recharge })
    if not ok then return false, raison end
    return true, regles.recharge
  end

  return objet, reprise, probleme
end

return caisse
