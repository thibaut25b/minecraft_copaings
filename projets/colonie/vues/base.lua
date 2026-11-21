-- Briques des pages du tableau de bord : textes dans une zone, mesures, légendes de statuts et listes paginées.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local pagination = require("commun.pagination")
local theme = require("commun.theme")
local statuts = require("colonie.statuts")

local R = theme.ROLES

local base = {}

local COLONNE_VALEUR = 13
local LARGEUR_VALEUR = 8 -- les barres des mesures s'alignent après une valeur de cette largeur
local LARGEUR_BARRE_MAX = 30
local LARGEUR_BARRE_MIN = 4
local ECART_LEGENDES = 2
local HAUTEUR_TUILE = 5
local HAUTEUR_AEREE = 14 -- compact : une rangée vide sous la synthèse dès cette hauteur de page

base.ILLISIBLE = "Colonie illisible : vérifie l'intégrateur"
base.CONSTRUCTEURS_ILLISIBLES = "Constructeurs illisibles : vérifie l'intégrateur"
base.BONHEUR_BON = 7
base.BONHEUR_MOYEN = 4

--- Rôle de couleur d'une note de bonheur sur 10.
function base.couleur_bonheur(bonheur)
  if bonheur >= base.BONHEUR_BON then return R.bon end
  if bonheur >= base.BONHEUR_MOYEN then return R.moyen end
  return R.mauvais
end

--- Rôle de couleur d'une part (0..1) de ce qui va bien : bon dès 90 %, moyen dès 60 %, mauvais en dessous.
function base.couleur_part(ratio)
  if ratio >= 0.9 then return R.bon end
  if ratio >= 0.6 then return R.moyen end
  return R.mauvais
end

--- Pourcentage arrondi d'un ratio : « 72 % ».
function base.pourcent(ratio)
  return math.floor(100 * ratio + 0.5) .. " %"
end

--- Copie triée : les éléments de rang 0 d'abord, l'ordre d'origine conservé à rang égal.
function base.trier_par_rang(liste, rang)
  local copie = {}
  for i, element in ipairs(liste) do copie[i] = { element = element, rang = rang(element), ordre = i } end
  table.sort(copie, function(a, b)
    if a.rang ~= b.rang then return a.rang < b.rang end
    return a.ordre < b.ordre
  end)
  local resultat = {}
  for i, entree in ipairs(copie) do resultat[i] = entree.element end
  return resultat
end

--- Écrit `texte` à la rangée `n` et à la colonne `x` de `zone` (1 = coin haut gauche), coupé à la zone ; renvoie
--- le nombre de cases écrites.
function base.ecrire(cible, zone, n, x, texte, couleur, fond)
  local disponible = zone.largeur - x + 1
  if n < 1 or n > zone.hauteur or disponible < 1 then return 0 end
  return dessin.ecrire(cible, zone.x + x - 1, zone.y + n - 1, dessin.tronquer(texte, disponible), couleur, fond)
end

-- Lignes de `texte` coupées aux espaces pour tenir sur `largeur` cases.
local function plier(texte, largeur)
  local lignes, courante = {}, ""
  for mot in texte:gmatch("%S+") do
    local essai = courante == "" and mot or courante .. " " .. mot
    if panneaux.longueur(essai) <= largeur or courante == "" then
      courante = essai
    else
      lignes[#lignes + 1] = courante
      courante = mot
    end
  end
  if courante ~= "" then lignes[#lignes + 1] = courante end
  return lignes
end

--- Message plié sur la largeur de `zone`, en haut, ou centré dans la zone si `centrer`.
function base.message(cible, zone, texte, couleur, fond, centrer)
  local lignes = plier(texte, zone.largeur)
  local haut = centrer and math.max(0, math.floor((zone.hauteur - #lignes) / 2)) or 0
  for i, ligne in ipairs(lignes) do
    local x = centrer and math.max(1, math.floor((zone.largeur - panneaux.longueur(ligne)) / 2) + 1) or 1
    base.ecrire(cible, zone, haut + i, x, ligne, couleur, fond)
  end
end

--- Mesure sur une rangée de `zone` : libellé discret, valeur en `couleur`, puis barre pleine à `ratio` (sans barre
--- si `ratio` est nil ou si la place manque).
function base.mesure(cible, zone, n, libelle, valeur, couleur, ratio, couleur_barre, fond)
  if n < 1 or n > zone.hauteur then return end
  base.ecrire(cible, zone, n, 1, dessin.tronquer(libelle, COLONNE_VALEUR - 2), R.discret, fond)
  local ecrit = base.ecrire(cible, zone, n, COLONNE_VALEUR, valeur, couleur, fond)
  local debut = COLONNE_VALEUR + math.max(ecrit, LARGEUR_VALEUR) + 1
  local largeur = math.min(LARGEUR_BARRE_MAX, zone.largeur - debut + 1)
  if ratio and largeur >= LARGEUR_BARRE_MIN then
    dessin.barre(cible, zone.x + debut - 1, zone.y + n - 1, largeur, ratio, couleur_barre or couleur, R.bordure)
  end
end

--- Entrées de légende des statuts présents dans `lignes`, dans l'ordre des statuts : { texte, couleur, nombre }.
function base.legende_statuts(lignes)
  local nombres = statuts.compter(lignes)
  local entrees = {}
  for _, statut in ipairs(statuts.LISTE) do
    if nombres[statut.id] then
      entrees[#entrees + 1] = { nombres[statut.id] .. " " .. statut.libelle, statut.couleur, nombres[statut.id] }
    end
  end
  return entrees
end

-- Position { colonne, rangee } de chaque entrée de légende sur `largeur` cases, et nombre de rangées.
local function placer(largeur, entrees)
  local positions, colonne, rangee = {}, 1, 1
  for i, entree in ipairs(entrees) do
    local taille = (entree[2] and 2 or 0) + panneaux.longueur(entree[1])
    if colonne > 1 and colonne + taille - 1 > largeur then colonne, rangee = 1, rangee + 1 end
    positions[i] = { colonne, rangee }
    colonne = colonne + taille + ECART_LEGENDES
  end
  return positions, #entrees > 0 and rangee or 0
end

--- Nombre de rangées qu'occupent les entrées de légende sur `largeur` cases.
function base.rangees_legende(largeur, entrees)
  local _, rangees = placer(largeur, entrees)
  return rangees
end

--- Légende à partir de la rangée `n` de `zone` : { texte, couleur } (sans couleur : texte seul), carré et texte de
--- la couleur de l'entrée, repliée à la ligne quand elle ne tient pas.
function base.legende(cible, zone, n, entrees, fond)
  local positions = placer(zone.largeur, entrees)
  for i, entree in ipairs(entrees) do
    local colonne, rangee = positions[i][1], n + positions[i][2] - 1
    if rangee >= 1 and rangee <= zone.hauteur then
      if entree[2] then
        panneaux.legende(cible, zone.x + colonne - 1, zone.y + rangee - 1, entree[2],
          dessin.tronquer(entree[1], zone.largeur - colonne - 1), fond, entree[2])
      else
        base.ecrire(cible, zone, rangee, colonne, entree[1], R.texte, fond)
      end
    end
  end
end

--- Cellule de tableau d'un statut : pastille (libellé sur l'aplat de sa couleur) s'il demande d'agir, libellé de sa
--- couleur sinon ; ce qui attend le joueur ressort de loin.
function base.pastille(id)
  local statut = statuts.de(id)
  if statut.action then return { texte = statut.libelle, couleur = R.fond, fond = statut.couleur } end
  return { texte = statut.libelle, couleur = statut.couleur }
end

--- « 1 tombe », « 3 tombes ».
function base.pluriel(nombre, mot)
  return nombre .. " " .. mot .. (nombre > 1 and "s" or "")
end

--- Liste paginée `cle` de `total` lignes dans `zone` (titres compris) : { cle, zone, decoupe, commande, zones },
--- `zones` = boutons touchables de la commande, sur la dernière rangée de la zone.
function base.disposer_liste(zone, cle, total, etat)
  local demandee = type(etat.pagination) == "table" and etat.pagination[cle] or nil
  local decoupe = pagination.decouper(total, zone.hauteur - 1, demandee)
  local commande = pagination.commande(zone.x, zone.y + zone.hauteur - 1, zone.largeur, decoupe)
  local zones = {}
  if commande then
    for _, bouton in ipairs({ commande.precedent, commande.suivant }) do
      zones[#zones + 1] = { x1 = bouton.x1, x2 = bouton.x2, y1 = bouton.y, y2 = bouton.y,
        action = { type = "pagination", liste = cle, page = bouton.page } }
    end
  end
  return { cle = cle, zone = zone, decoupe = decoupe, commande = commande, zones = zones }
end

--- Dessine la page courante de la liste disposée en tableau, puis la commande et le rappel « 8 à 14 sur 30 ».
function base.dessiner_liste(cible, liste, colonnes, rangees, fond, zebre)
  local decoupe, zone = liste.decoupe, liste.zone
  local page = {}
  for i = decoupe.debut, decoupe.fin do page[#page + 1] = rangees[i] end
  local hauteur = decoupe.commande and zone.hauteur - 1 or zone.hauteur
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, hauteur, colonnes, page, { fond = fond, zebre = zebre })
  base.dessiner_commande(cible, liste, #rangees, fond)
end

--- Dessine la commande de pagination de la liste disposée (si elle en a une) et le rappel des lignes montrées.
function base.dessiner_commande(cible, liste, total, fond)
  if not liste.commande then return end
  local decoupe, zone = liste.decoupe, liste.zone
  pagination.dessiner(cible, liste.commande, fond)
  local rappel = decoupe.debut .. " à " .. decoupe.fin .. " sur " .. total
  if panneaux.longueur(rappel) <= liste.commande.x - zone.x - 1 then
    base.ecrire(cible, zone, zone.hauteur, 1, rappel, R.discret, fond)
  end
end

-- Liste de `nombre` poids égaux à 1.
local function uns(nombre)
  local poids = {}
  for i = 1, nombre do poids[i] = 1 end
  return poids
end

--- Géométrie d'une page « synthèse puis liste » : `nombre` mesures en tête (tuiles côte à côte en riche, une rangée
--- chacune en compact), puis la liste paginée `cle` de `total` lignes. Renvoie { zone, tuiles, panneau, liste, zones }.
function base.disposer_synthese(zone, riche, nombre, cle, total, etat)
  local plan = { zone = zone }
  local corps
  if riche then
    local x, largeur = zone.x + 1, zone.largeur - 2
    plan.tuiles = panneaux.repartir(x, largeur, uns(nombre), 1)
    local y = zone.y + HAUTEUR_TUILE + 1
    plan.panneau = { x = x, y = y, largeur = largeur, hauteur = zone.y + zone.hauteur - y }
    corps = panneaux.interieur(x, y, largeur, plan.panneau.hauteur)
  else
    local haut = nombre + (zone.hauteur >= HAUTEUR_AEREE and 1 or 0)
    corps = { x = zone.x, y = zone.y + haut, largeur = zone.largeur, hauteur = math.max(0, zone.hauteur - haut) }
  end
  plan.liste = base.disposer_liste(corps, cle, total, etat)
  plan.zones = plan.liste.zones
  return plan
end

--- Dessine la synthèse : `mesures` = { { titre, valeur, note, ratio, couleur } } en tuiles (riche) ou en rangées.
function base.dessiner_synthese(cible, plan, mesures, riche)
  for i, mesure in ipairs(mesures) do
    if riche then
      local tuile = plan.tuiles[i]
      panneaux.tuile(cible, tuile.debut, plan.zone.y, tuile.taille, HAUTEUR_TUILE, mesure[1], mesure[2], mesure[3],
        mesure[4], mesure[5])
    else
      base.mesure(cible, plan.zone, i, mesure[1], mesure[2], mesure[5], mesure[4], nil, R.fond)
    end
  end
end

--- Zones touchables de plusieurs listes ou plans réunies en une liste.
function base.reunir(...)
  local toutes = {}
  for _, zones in ipairs({ ... }) do
    for _, zone in ipairs(zones) do toutes[#toutes + 1] = zone end
  end
  return toutes
end

return base
