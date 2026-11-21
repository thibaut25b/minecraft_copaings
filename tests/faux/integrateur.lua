-- Faux Colony Integrator fidèle à docs/peripheriques.md : données de colonie et pannes pilotables.

local integrateur = {}

local HORS_COLONIE = "Here is no colony or you don't have the right permissions"

--- Crée un faux intégrateur et renvoie `integrateur, etat`. Le test pilote `etat` : `en_colonie`, `nom`, `style`,
-- `bonheur`, `nombre`, `limite`, `tombes`, `attaque`, `raid`, `chantiers`, `citoyens`, `visiteurs`, `batiments`,
-- `travaux`, `requetes`, `exceptions` (méthode -> message levé). Il lit `appels` (noms des méthodes appelées).
function integrateur.creer()
  local etat = {
    en_colonie = true, nom = "Valfleuri", style = "medievaloak", bonheur = 7.43, nombre = 2, limite = 25, tombes = 0,
    attaque = false, raid = false, chantiers = 0,
    citoyens = {}, visiteurs = {}, batiments = {}, travaux = {}, requetes = {}, exceptions = {}, appels = {},
  }
  local faux = {}

  local function methode(nom, corps, sans_colonie)
    faux[nom] = function(...)
      etat.appels[#etat.appels + 1] = nom
      if etat.exceptions[nom] then error(etat.exceptions[nom], 0) end
      if not etat.en_colonie and not sans_colonie then error(HORS_COLONIE, 0) end
      return corps(...)
    end
  end

  local function valeur(cle) return function() return etat[cle] end end

  methode("isInColony", function() return etat.en_colonie end, true)
  methode("getColonyName", valeur("nom"))
  methode("getColonyStyle", valeur("style"))
  methode("getHappiness", valeur("bonheur"))
  methode("getCitizenCount", valeur("nombre"))
  methode("getCitizenLimit", valeur("limite"))
  methode("getGraveCount", valeur("tombes"))
  methode("isUnderAttack", valeur("attaque"))
  methode("isUnderRaid", valeur("raid"))
  methode("amountOfConstructionSites", valeur("chantiers"))
  methode("getCitizens", valeur("citoyens"))
  methode("getVisitors", valeur("visiteurs"))
  methode("getBuildings", valeur("batiments"))
  methode("getWorkOrders", valeur("travaux"))
  methode("getRequests", valeur("requetes"))

  return faux, etat
end

return integrateur
