-- Page Résumé, celle qu'on regarde de loin : bonheur, population, requêtes par statut, ce qui attend le joueur,
-- avancement des chantiers et courbes d'historique.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local chantiers = require("colonie.chantiers")
local historique = require("colonie.historique")
local statuts = require("colonie.statuts")
local base = require("colonie.vues.base")

local R = theme.ROLES

local resume = {}

local AUCUNE = "Aucune requête en cours"
local PEU_DE_MESURES = "Courbe dès la deuxième mesure"
local HAUTEUR_AEREE = 14 -- compact : une rangée vide entre les blocs dès cette hauteur de page

local COLONNES_A_TRAITER = {
  { titre = "Statut", largeur = 11 },
  { titre = "Requête", min = 10 },
  { titre = "Livré", largeur = 7, alignement = "droite" },
  { titre = "Demandeur", min = 10, facultatif = true },
}

--- Géométrie de la page : rien n'y est touchable.
function resume.disposer(zone)
  return { zone = zone, zones = {} }
end

local function comptes_habitants(colonie)
  local sans_emploi, sans_logis = 0, 0
  for _, habitant in ipairs(colonie.habitants) do
    if not habitant.employe then sans_emploi = sans_emploi + 1 end
    if not habitant.loge then sans_logis = sans_logis + 1 end
  end
  return sans_emploi, sans_logis
end

local function a_traiter(lignes)
  local liste = {}
  for _, ligne in ipairs(lignes) do
    if statuts.de(ligne.statut).action then liste[#liste + 1] = ligne end
  end
  return liste
end

local function livrees(lignes)
  return statuts.compter(lignes).livre or 0
end

local function serie(etat)
  return type(etat.historique) == "table" and etat.historique or {}
end

-- Écart entre la mesure actuelle et la plus ancienne de l'historique, en texte : « +0.4 en 6 h », nil sans passé.
local function tendance(etat, champ, actuelle, format)
  local points = serie(etat)
  if #points < 2 then return nil end
  return string.format(format, actuelle - points[1][champ]) .. " en " .. historique.etendue(points)
end

-- Constructeurs à montrer : { nom, ratio (nil sans ressource), auto }.
local function etats_chantiers(etat)
  local liste = {}
  for i, constructeur in ipairs(etat.constructeurs) do
    liste[i] = {
      nom = constructeur.nom, ratio = not constructeur.erreur and chantiers.avancement(constructeur) or nil,
      auto = type(etat.livraison) == "table" and etat.livraison[constructeur.cle] == true,
    }
  end
  return liste
end

local function rangees_a_traiter(lignes)
  local rangees = {}
  for i, ligne in ipairs(a_traiter(lignes)) do
    rangees[i] = { base.pastille(ligne.statut), ligne.requete.libelle, ligne.livre .. "/" .. ligne.requete.quantite,
      ligne.requete.demandeur }
  end
  return rangees
end

-- ---------------------------------------------------------------------------------------------- Gabarit riche

local function panneau_bonheur(cible, zone, etat)
  local colonie = etat.colonie
  local note = colonie and tendance(etat, "bonheur", colonie.bonheur, "%+.1f") or "seuil " .. base.BONHEUR_MOYEN
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Bonheur", note)
  if not colonie then return base.message(cible, interieur, base.ILLISIBLE, R.alerte, R.surface, true) end
  local couleur = base.couleur_bonheur(colonie.bonheur)
  panneaux.jauge(cible, interieur, colonie.bonheur / 10, couleur, string.format("%.1f", colonie.bonheur), "sur 10")
end

local function panneau_population(cible, zone, etat)
  local colonie = etat.colonie
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Population",
    colonie and "limite " .. colonie.limite or nil)
  if not colonie then return base.message(cible, interieur, base.ILLISIBLE, R.alerte, R.surface, true) end
  if interieur.hauteur < 2 then return end
  local chiffre = colonie.citoyens .. " / " .. colonie.limite
  local ratio = colonie.limite > 0 and colonie.citoyens / colonie.limite or 0
  local ecrit = base.ecrire(cible, interieur, 1, 1, chiffre, R.texte, R.surface)
  base.ecrire(cible, interieur, 1, ecrit + 2, "colons", R.discret, R.surface)
  panneaux.barre_fine(cible, interieur.x, interieur.y + 1, interieur.largeur, ratio, R.info)
  local sans_emploi, sans_logis = comptes_habitants(colonie)
  panneaux.paires(cible, { x = interieur.x, y = interieur.y + 3, largeur = interieur.largeur,
    hauteur = interieur.hauteur - 3 }, {
    { "Sans emploi", tostring(sans_emploi), sans_emploi > 0 and R.moyen or R.bon },
    { "Sans logis", tostring(sans_logis), sans_logis > 0 and R.moyen or R.bon },
    { "Places libres", tostring(math.max(0, colonie.limite - colonie.citoyens)) },
    { "Visiteurs", tostring(colonie.visiteurs) },
    { "Tombes", tostring(colonie.tombes), colonie.tombes > 0 and R.mauvais or R.texte },
  })
end

local function panneau_statuts(cible, zone, etat)
  local lignes = etat.lignes
  local note = #lignes > 0 and livrees(lignes) .. "/" .. #lignes .. " livrées" or nil
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Requêtes par statut", note)
  if #lignes == 0 then return base.message(cible, interieur, AUCUNE, R.bon, R.surface, true) end
  local parts = {}
  for _, entree in ipairs(base.legende_statuts(lignes)) do
    parts[#parts + 1] = { entree[3], entree[2], (entree[1]:gsub("^%d+ ", "")) }
  end
  panneaux.secteurs(cible, interieur, parts)
end

local function peu_de_mesures(cible, interieur, points)
  if #points >= 2 then return false end
  base.message(cible, interieur, PEU_DE_MESURES, R.discret, R.surface, true)
  return true
end

local function abscisses(points)
  return { "-" .. historique.etendue(points), "maintenant" }
end

local function courbe_bonheur(cible, zone, etat)
  local points = serie(etat)
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Bonheur, évolution",
    "seuil " .. base.BONHEUR_MOYEN)
  if peu_de_mesures(cible, interieur, points) then return end
  panneaux.courbe(cible, interieur, historique.valeurs(points, "bonheur"), {
    couleur = R.accent2, remplissage = R.bordure, min = 0, max = 10,
    graduations = { { 10, "10" }, { 5, "5" }, { 0, "0" } },
    repere = { valeur = base.BONHEUR_MOYEN, couleur = R.moyen }, abscisses = abscisses(points),
  })
end

local function courbe_population(cible, zone, etat)
  local points = serie(etat)
  local limite = #points > 0 and points[#points].limite or 0
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Population, évolution",
    "limite " .. limite)
  if peu_de_mesures(cible, interieur, points) then return end
  local valeurs = historique.valeurs(points, "population")
  local bas = limite
  for _, valeur in ipairs(valeurs) do bas = math.min(bas, valeur) end
  bas = math.max(0, bas - 2)
  local haut = math.max(limite, bas + 1) + 1
  panneaux.courbe(cible, interieur, valeurs, {
    couleur = R.info, remplissage = R.bordure, min = bas, max = haut,
    graduations = { { limite, tostring(limite) }, { bas, tostring(bas) } },
    repere = { valeur = limite, couleur = R.moyen }, abscisses = abscisses(points),
  })
end

-- Requêtes ouvertes en courbe sur l'histogramme des requêtes à problème, même échelle, légende dessous.
local function courbe_requetes(cible, zone, etat)
  local points = serie(etat)
  local note = #points > 0 and points[#points].problemes .. " à problème" or nil
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Requêtes, évolution", note)
  if peu_de_mesures(cible, interieur, points) then return end
  local ouvertes, problemes = historique.valeurs(points, "ouvertes"), historique.valeurs(points, "problemes")
  local haut = 1
  for i = 1, #ouvertes do haut = math.max(haut, ouvertes[i], problemes[i]) end
  local gouttiere = #tostring(haut) + 1
  local trace = { x = interieur.x + gouttiere, y = interieur.y, largeur = interieur.largeur - gouttiere,
    hauteur = interieur.hauteur - 2 }
  if trace.largeur < 2 or trace.hauteur < 1 then return end
  panneaux.toile(cible, trace, R.surface, function(toile, lpx, hpx)
    local cadre = { x = 1, y = 2, largeur = lpx, hauteur = hpx - 2 }
    graphes.histogramme(toile, cadre, problemes, { couleur = R.mauvais, min = 0, max = haut, ecart = 0 })
    graphes.courbe(toile, cadre, ouvertes, { couleur = R.accent, min = 0, max = haut })
  end)
  dessin.ecrire(cible, interieur.x, trace.y, dessin.aligner(tostring(haut), gouttiere - 1, "droite"), R.discret,
    R.surface)
  dessin.ecrire(cible, interieur.x, trace.y + trace.hauteur - 1, dessin.aligner("0", gouttiere - 1, "droite"),
    R.discret, R.surface)
  base.legende(cible, interieur, interieur.hauteur - 1, { { "ouvertes", R.accent }, { "à problème", R.mauvais } },
    R.surface)
end

local function panneau_a_traiter(cible, zone, etat)
  local rangees = rangees_a_traiter(etat.lignes)
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "À traiter par toi",
    #rangees > 0 and #rangees .. " requêtes, détail dans l'onglet Requêtes" or nil)
  if #rangees == 0 then
    return base.message(cible, interieur, "Rien ne t'attend : AE2 suit toutes les requêtes.", R.bon, R.surface, true)
  end
  dessin.tableau(cible, interieur.x, interieur.y, interieur.largeur, interieur.hauteur, COLONNES_A_TRAITER, rangees,
    { fond = R.surface })
end

local function panneau_chantiers(cible, zone, etat)
  local lisibles = type(etat.constructeurs) == "table"
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Chantiers",
    lisibles and #etat.constructeurs .. " constructeurs" or nil)
  if not lisibles then return base.message(cible, interieur, base.CONSTRUCTEURS_ILLISIBLES, R.alerte, R.surface, true) end
  local liste = etats_chantiers(etat)
  if #liste == 0 then return base.message(cible, interieur, "Aucun constructeur", R.discret, R.surface, true) end
  local pas = interieur.hauteur >= 2 * #liste and 2 or 1
  local largeur_nom = math.min(18, math.floor(interieur.largeur * 0.35))
  local largeur_barre = interieur.largeur - largeur_nom - 14
  for i, chantier in ipairs(liste) do
    local n = (i - 1) * pas + 1
    if n > interieur.hauteur then return end
    if n == interieur.hauteur and i < #liste then
      return base.ecrire(cible, interieur, n, 1, "+ " .. (#liste - i + 1) .. " autres", R.discret, R.surface)
    end
    base.ecrire(cible, interieur, n, 1, dessin.tronquer(chantier.nom, largeur_nom), R.texte, R.surface)
    local x = interieur.x + largeur_nom + 1
    if chantier.ratio then
      local couleur = base.couleur_part(chantier.ratio)
      if largeur_barre >= 4 then
        panneaux.barre_fine(cible, x, interieur.y + n - 1, largeur_barre, chantier.ratio, couleur)
      end
      dessin.ecrire(cible, x + largeur_barre + 1, interieur.y + n - 1, dessin.aligner(base.pourcent(chantier.ratio), 5,
        "droite"), couleur, R.surface)
    else
      dessin.ecrire(cible, x, interieur.y + n - 1, dessin.tronquer("sans chantier", largeur_barre + 6), R.discret,
        R.surface)
    end
    if chantier.auto then
      panneaux.pastille(cible, interieur.x + interieur.largeur - 6, interieur.y + n - 1, "auto", R.bon, 6)
    end
  end
end

local function riche(cible, zone, etat)
  local x, largeur = zone.x + 1, zone.largeur - 2
  local rangees = panneaux.repartir(zone.y, zone.hauteur, { 36, 30, 34 }, 1)
  local function cases(colonne, rangee)
    return { x = colonne.debut, y = rangee.debut, largeur = colonne.taille, hauteur = rangee.taille }
  end
  local haut = panneaux.repartir(x, largeur, { 26, 30, 44 }, 1)
  panneau_bonheur(cible, cases(haut[1], rangees[1]), etat)
  panneau_population(cible, cases(haut[2], rangees[1]), etat)
  panneau_statuts(cible, cases(haut[3], rangees[1]), etat)
  local milieu = panneaux.repartir(x, largeur, { 1, 1, 1 }, 1)
  courbe_bonheur(cible, cases(milieu[1], rangees[2]), etat)
  courbe_population(cible, cases(milieu[2], rangees[2]), etat)
  courbe_requetes(cible, cases(milieu[3], rangees[2]), etat)
  local bas = panneaux.repartir(x, largeur, { 56, 44 }, 1)
  panneau_a_traiter(cible, cases(bas[1], rangees[3]), etat)
  panneau_chantiers(cible, cases(bas[2], rangees[3]), etat)
end

-- -------------------------------------------------------------------------------------------- Gabarit compact

-- Chaque bloc écrit à partir de la rangée `n` et renvoie la rangée suivante libre.
local function bloc_colonie(cible, zone, n, etat)
  local colonie = etat.colonie
  if not colonie then
    base.ecrire(cible, zone, n, 1, base.ILLISIBLE, R.alerte, R.fond)
    return n + 1
  end
  local couleur = base.couleur_bonheur(colonie.bonheur)
  base.mesure(cible, zone, n, "Bonheur", string.format("%.1f/10", colonie.bonheur), couleur, colonie.bonheur / 10,
    couleur, R.fond)
  local ratio = colonie.limite > 0 and colonie.citoyens / colonie.limite or 0
  base.mesure(cible, zone, n + 1, "Colons", colonie.citoyens .. "/" .. colonie.limite, R.texte, ratio, R.info, R.fond)
  local sans_emploi, sans_logis = comptes_habitants(colonie)
  local entrees = {
    { sans_emploi .. " sans emploi", sans_emploi > 0 and R.moyen or R.bon },
    { sans_logis .. " sans maison", sans_logis > 0 and R.moyen or R.bon },
    { base.pluriel(colonie.tombes, "tombe"), colonie.tombes > 0 and R.mauvais or R.bon },
  }
  base.legende(cible, zone, n + 2, entrees, R.fond)
  return n + 2 + base.rangees_legende(zone.largeur, entrees)
end

local function bloc_requetes(cible, zone, n, etat)
  local lignes = etat.lignes
  if #lignes == 0 then
    base.ecrire(cible, zone, n, 1, AUCUNE, R.discret, R.fond)
    return n + 1
  end
  local nombre = livrees(lignes)
  base.mesure(cible, zone, n, "Livrées", nombre .. "/" .. #lignes, R.texte, nombre / #lignes, R.bon, R.fond)
  local entrees = base.legende_statuts(lignes)
  base.legende(cible, zone, n + 1, entrees, R.fond)
  return n + 1 + base.rangees_legende(zone.largeur, entrees)
end

local function bloc_a_traiter(cible, zone, n, etat)
  local liste = a_traiter(etat.lignes)
  if #liste == 0 or n > zone.hauteur then return n end
  base.ecrire(cible, zone, n, 1, "À traiter (" .. #liste .. ")", R.texte, R.fond)
  n = n + 1
  for i, ligne in ipairs(liste) do
    if n > zone.hauteur then return n end
    if n == zone.hauteur and i < #liste then
      base.ecrire(cible, zone, n, 1, "+ " .. (#liste - i + 1) .. " autres, onglet Requêtes", R.discret, R.fond)
      return n + 1
    end
    local statut = statuts.de(ligne.statut)
    local ecrit = panneaux.pastille(cible, zone.x, zone.y + n - 1, statut.libelle, statut.couleur, 10)
    base.ecrire(cible, zone, n, ecrit + 2, ligne.requete.libelle .. " (" .. ligne.requete.demandeur .. ")", R.texte,
      R.fond)
    n = n + 1
  end
  return n
end

local function bloc_chantiers(cible, zone, n, etat)
  if type(etat.constructeurs) ~= "table" or #etat.constructeurs == 0 or n > zone.hauteur then return n end
  for _, chantier in ipairs(etats_chantiers(etat)) do
    if n > zone.hauteur then return n end
    local nom = dessin.tronquer(chantier.nom, 11)
    if chantier.ratio then
      base.mesure(cible, zone, n, nom, base.pourcent(chantier.ratio), base.couleur_part(chantier.ratio),
        chantier.ratio, nil, R.fond)
    else
      base.ecrire(cible, zone, n, 1, nom, R.discret, R.fond)
      base.ecrire(cible, zone, n, 13, "sans chantier", R.discret, R.fond)
    end
    n = n + 1
  end
  return n
end

local function compact(cible, zone, etat)
  local ecart = zone.hauteur >= HAUTEUR_AEREE and 1 or 0
  local n = bloc_colonie(cible, zone, 1, etat) + ecart
  n = bloc_requetes(cible, zone, n, etat) + ecart
  n = bloc_a_traiter(cible, zone, n, etat)
  if n > 1 then n = n + ecart end
  bloc_chantiers(cible, zone, n, etat)
end

--- Dessine la page disposée.
function resume.dessiner(cible, plan, etat, est_riche)
  if est_riche then return riche(cible, plan.zone, etat) end
  compact(cible, plan.zone, etat)
end

return resume
