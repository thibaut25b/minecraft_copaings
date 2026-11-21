-- Réseau cinétique montré : jauge de stress et chiffres, rangée compacte, courbe du stress.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local regulation = require("usine.regulation")
local base = require("usine.vues.base")

local R = theme.ROLES

local reseau = {}

local ILLISIBLE = "stress illisible"
local LARGEUR_CHIFFRES = 18 -- « Capacité » et « 16 384 su » côte à côte
local ANNEAU_MIN = 10 -- en dessous, pas d'anneau : la charge devient une ligne des chiffres

--- Réseau montré : { reseau (config), mesure, ratio, delestees } ; `etat.reseau` est son indice (1 si hors liste).
function reseau.montre(etat)
  local indice = etat.reseau
  if type(indice) ~= "number" or not etat.reseaux[indice] then indice = 1 end
  local choisi = etat.reseaux[indice]
  if not choisi then return { indice = 1, delestees = 0 } end
  local mesure = etat.mesures[choisi.nom] or {}
  local delestees = 0
  for _, ligne in ipairs(etat.lignes) do
    local memoire = etat.memoire[ligne.nom]
    if ligne.reseau == choisi.nom and memoire and memoire.delestee then delestees = delestees + 1 end
  end
  return { indice = indice, reseau = choisi, mesure = mesure, ratio = regulation.charge(mesure),
    delestees = delestees }
end

--- Annotation du panneau : nom du réseau, et sa place s'il y en a plusieurs (« Nord 1/2 »).
function reseau.annotation(etat, montre)
  if not montre.reseau then return "aucun réseau" end
  if #etat.reseaux > 1 then return montre.reseau.nom .. " " .. montre.indice .. "/" .. #etat.reseaux end
  return montre.reseau.nom
end

local function texte_ratio(montre)
  local mesure = montre.mesure or {}
  if montre.ratio == math.huge then return "SURCHARGE" end
  if montre.ratio then return base.pourcent(montre.ratio) end
  if type(mesure.capacite) == "number" then return "à l'arrêt" end
  return ILLISIBLE
end

local function su(valeur)
  if type(valeur) ~= "number" then return "?" end
  return panneaux.milliers(valeur) .. " su"
end

--- Jauge et chiffres du réseau montré dans `zone` (intérieur du panneau).
function reseau.dessiner_jauge(cible, zone, etat, montre)
  local mesure = montre.mesure or {}
  local couleur = base.couleur_stress(montre.ratio, etat.seuils)
  local largeur_anneau = math.min(math.floor(1.5 * zone.hauteur) + 1, zone.largeur - LARGEUR_CHIFFRES - 2)
  local x = zone.x
  if largeur_anneau >= ANNEAU_MIN then
    local remplissage = montre.ratio and math.min(1, montre.ratio) or 0
    local libelle = montre.ratio and montre.ratio ~= math.huge and "stress" or nil
    panneaux.jauge(cible, { x = zone.x, y = zone.y, largeur = largeur_anneau, hauteur = zone.hauteur }, remplissage,
      couleur, texte_ratio(montre), libelle)
    x = zone.x + largeur_anneau + 2
  end
  local largeur = zone.x + zone.largeur - x
  local marge = "?"
  if type(mesure.stress) == "number" and type(mesure.capacite) == "number" then
    marge = su(mesure.capacite - mesure.stress)
  end
  local vitesse = type(mesure.vitesse) == "number" and math.floor(mesure.vitesse + 0.5) .. " rpm" or "-"
  local paires = {
    { "Utilisé", su(mesure.stress) },
    { "Capacité", su(mesure.capacite) },
    { "Marge", marge, couleur },
    { "Vitesse", vitesse },
    { "Délestées", tostring(montre.delestees), montre.delestees > 0 and R.alerte or R.texte },
  }
  if x == zone.x then table.insert(paires, 1, { "Charge", texte_ratio(montre), couleur }) end
  panneaux.paires(cible, { x = x, y = zone.y, largeur = largeur, hauteur = zone.hauteur }, paires)
end

--- Rangée compacte en `y` sur `largeur` cases : nom, charge, barre, stress / capacité.
function reseau.dessiner_rangee(cible, x, y, largeur, etat, montre)
  local nom = montre.reseau and montre.reseau.nom or "aucun réseau"
  local couleur = base.couleur_stress(montre.ratio, etat.seuils)
  local mesure = montre.mesure or {}
  local ecrit = dessin.ecrire(cible, x, y, dessin.tronquer(nom, 14), R.texte, R.fond)
  ecrit = ecrit + 1 + dessin.ecrire(cible, x + ecrit + 1, y, texte_ratio(montre), couleur, R.fond)
  local droite = su(mesure.stress) .. " / " .. su(mesure.capacite)
  if montre.delestees > 0 then droite = montre.delestees .. " délestée(s)  " .. droite end
  local place = largeur - ecrit - 2
  if panneaux.longueur(droite) > place - 6 then droite = "" end
  local barre = place - panneaux.longueur(droite) - (droite ~= "" and 1 or 0)
  if montre.ratio and barre >= 4 then
    panneaux.barre_fine(cible, x + ecrit + 1, y, barre, montre.ratio, couleur, R.bordure, R.fond)
  end
  if droite ~= "" then
    dessin.ecrire(cible, x + largeur - panneaux.longueur(droite), y, droite, R.discret, R.fond)
  end
end

--- Courbe du stress du réseau montré dans `zone`, repère rouge à la capacité.
function reseau.dessiner_courbe(cible, zone, etat, montre)
  local valeurs = montre.reseau and etat.courbes[montre.reseau.nom] or {}
  if #valeurs < 2 then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Courbe en cours de remplissage", zone.largeur), R.discret,
      R.surface)
    return
  end
  local capacite = type(montre.mesure.capacite) == "number" and montre.mesure.capacite or 0
  local haut = capacite
  for _, valeur in ipairs(valeurs) do haut = math.max(haut, valeur) end
  haut = math.max(1, haut * 1.15)
  local duree = math.floor((#valeurs - 1) * etat.periode + 0.5)
  panneaux.courbe(cible, zone, valeurs, {
    couleur = R.accent, remplissage = colors.blue, min = 0, max = haut,
    graduations = { { capacite, base.court(capacite) }, { capacite / 2, base.court(capacite / 2) }, { 0, "0" } },
    repere = capacite > 0 and { valeur = capacite, couleur = R.mauvais } or nil,
    abscisses = { "-" .. duree .. " s", "maintenant" },
  })
end

return reseau
