-- Faux Colony Integrator fidèle à docs/peripheriques.md : données de colonie et pannes pilotables.

local integrateur = {}

local HORS_COLONIE = "Here is no colony or you don't have the right permissions"

--- Crée un faux intégrateur et renvoie `integrateur, etat`. Le test pilote `etat` : `en_colonie`, `nom`, `style`,
-- `bonheur`, `nombre`, `limite`, `tombes`, `attaque`, `raid`, `chantiers`, `citoyens`, `visiteurs`, `batiments`,
-- `travaux`, `requetes`, `ressources` ("x,y,z" de hutte -> retour de `getBuilderResources`),
-- `pannes_ressources` ("x,y,z" -> message levé pour cette hutte), `exceptions` (méthode -> message levé).
-- Il lit `appels` (noms des méthodes appelées).
function integrateur.creer()
  local etat = {
    en_colonie = true, nom = "Valfleuri", style = "medievaloak", bonheur = 7.43, nombre = 2, limite = 25, tombes = 0,
    attaque = false, raid = false, chantiers = 0,
    citoyens = {}, visiteurs = {}, batiments = {}, travaux = {}, requetes = {}, ressources = {}, pannes_ressources = {},
    exceptions = {}, appels = {},
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

  -- Comme le mod : position obligatoire, `nil` sans hutte de constructeur à cette position.
  methode("getBuilderResources", function(pos)
    if type(pos) ~= "table" or pos.x == nil or pos.y == nil or pos.z == nil then
      error("Table should contains key 'x', 'y' and 'z'", 0)
    end
    local cle = pos.x .. "," .. pos.y .. "," .. pos.z
    if etat.pannes_ressources[cle] then error(etat.pannes_ressources[cle], 0) end
    for _, batiment in ipairs(etat.batiments) do
      local p = batiment.pos
      if batiment.type == "builder" and p.x == pos.x and p.y == pos.y and p.z == pos.z then
        return etat.ressources[cle] or {}
      end
    end
    return nil
  end)

  return faux, etat
end

return integrateur
