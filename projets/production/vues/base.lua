-- Briques des vues de la production : objet choisi, nom, textes et couleurs des débits, durées, zones touchables.

local texte = require("commun.texte")
local theme = require("commun.theme")
local flux = require("production.flux")
local inventaire = require("production.inventaire")

local R = theme.ROLES

local base = {}

--- Libellé de chaque fenêtre de débit (secondes).
base.LIBELLES_FENETRES = { [60] = "1 min", [600] = "10 min", [3600] = "1 h" }

--- Lignes de la vue de l'onglet actif : alertes sur l'onglet "alertes", sinon lignes classées ({} sans classement).
function base.lignes(etat)
  local contenu = etat.classement
  if not contenu then return {} end
  if etat.onglet == "alertes" then return contenu.alertes end
  return contenu.lignes
end

--- Clé de l'objet choisi : `etat.selection` si elle est dans les lignes de la vue, sinon la première ligne, nil sans
--- ligne.
function base.selection(etat)
  local lignes = base.lignes(etat)
  for _, ligne in ipairs(lignes) do
    if ligne.cle == etat.selection then return ligne.cle end
  end
  return lignes[1] and lignes[1].cle or nil
end

--- Nom affiché de `cle` : celui de sa ligne au classement, sinon celui lu dans l'AE, sinon son identifiant.
function base.nom(etat, cle)
  for _, liste in ipairs({ etat.classement and etat.classement.lignes or {}, base.lignes(etat) }) do
    for _, ligne in ipairs(liste) do
      if ligne.cle == cle then return ligne.nom end
    end
  end
  local objet = etat.flux and etat.flux.objets[cle]
  return (objet and objet.nom) or (inventaire.decouper(cle))
end

--- Nombre sans signe à un chiffre après la virgule sous 10, entier au-delà : « 2,5 », « 1 250 », « 0 ».
function base.nombre(valeur)
  local absolu = math.abs(valeur)
  if absolu < 0.05 then return "0" end
  if absolu < 10 then return (string.format("%.1f", absolu):gsub("%.", ",")) end
  return texte.milliers(absolu)
end

--- Débit en items/s converti dans l'unité : « +12,5 », « ~-3 » si `partiel`.
function base.texte_debit(par_seconde, partiel, unite)
  local valeur = flux.convertir(par_seconde, unite)
  local signe = math.abs(valeur) < 0.05 and "" or (valeur < 0 and "-" or "+")
  return (partiel and "~" or "") .. signe .. base.nombre(valeur)
end

--- Débit sans signe ni tilde, avec son unité : « 1 250 /min ».
function base.texte_absolu(par_seconde, unite)
  return base.nombre(flux.convertir(par_seconde, unite)) .. " " .. flux.LIBELLES[unite]
end

--- Rôle de couleur d'un débit signé : bon s'il monte, mauvais s'il baisse, discret à zéro (dans l'unité).
function base.couleur_debit(par_seconde, unite)
  local valeur = flux.convertir(par_seconde, unite)
  if math.abs(valeur) < 0.05 then return R.discret end
  return valeur > 0 and R.bon or R.mauvais
end

--- Durée en secondes lisible : « 45 s », « 12 min », « 3 h », « 3 h 20 min ».
function base.duree(secondes)
  secondes = math.floor(secondes + 0.5)
  if secondes < 60 then return secondes .. " s" end
  local minutes = math.floor(secondes / 60)
  if minutes < 60 then return minutes .. " min" end
  local heures = math.floor(minutes / 60)
  if minutes % 60 == 0 or heures >= 10 then return heures .. " h" end
  return heures .. " h " .. minutes % 60 .. " min"
end

--- Vrai si (x, y) est dans la zone { x1, x2, y1, y2 }.
function base.dedans(zone, x, y)
  return x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2
end

return base
