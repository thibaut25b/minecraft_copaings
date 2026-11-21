-- Statuts d'une ligne de passe : ordre, libellé, rôle de couleur et besoin d'agir du joueur, au seul endroit.

local theme = require("commun.theme")

local R = theme.ROLES

local statuts = {}

--- Statuts connus dans l'ordre d'affichage ; `action` : le joueur doit agir.
statuts.LISTE = {
  { id = "livre", libelle = "livré", couleur = R.bon, action = false },
  { id = "partiel", libelle = "partiel", couleur = R.moyen, action = false },
  { id = "en_fabrication", libelle = "fabrication", couleur = R.info, action = false },
  { id = "manquant", libelle = "manquant", couleur = R.mauvais, action = true },
  { id = "ignore", libelle = "ignoré", couleur = R.discret, action = false },
  { id = "erreur", libelle = "erreur", couleur = R.alerte, action = true },
}

local PAR_ID = {}
for _, statut in ipairs(statuts.LISTE) do PAR_ID[statut.id] = statut end

--- Statut d'identifiant `id` ; un identifiant inconnu donne un statut neutre qui porte son nom.
function statuts.de(id)
  return PAR_ID[id] or { id = id, libelle = tostring(id), couleur = R.texte, action = false }
end

--- Nombre de lignes par identifiant de statut.
function statuts.compter(lignes)
  local nombres = {}
  for _, ligne in ipairs(lignes) do nombres[ligne.statut] = (nombres[ligne.statut] or 0) + 1 end
  return nombres
end

return statuts
