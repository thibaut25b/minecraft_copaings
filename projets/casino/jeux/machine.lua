-- Machine à sous à trois rouleaux : bande des rouleaux, table de gains et tirage, sans rien afficher.

local machine = {}

--- Bande commune aux trois rouleaux : un arrêt par case, la fréquence d'un symbole est son nombre d'arrêts.
machine.BANDE = {
  "cerise", "citron", "orange", "prune", "cerise", "bar", "citron", "orange", "cloche", "cerise",
  "prune", "citron", "sept", "orange", "cerise", "bar", "prune", "citron", "orange", "cloche",
}

--- Nom affiché de chaque symbole, au singulier et au pluriel.
machine.NOMS = {
  sept = { "7", "7" }, bar = { "BAR", "BAR" }, cloche = { "cloche", "cloches" }, prune = { "prune", "prunes" },
  orange = { "orange", "oranges" }, citron = { "citron", "citrons" }, cerise = { "cerise", "cerises" },
}

--- Table de gains, lue dans l'ordre : une ligne paie si la ligne du milieu porte exactement `nombre` fois `symbole`.
--- `multiplicateur` donne le gain total, mise comprise (x1 : mise rendue).
machine.TABLE = {
  { symbole = "sept", nombre = 3, multiplicateur = 100 },
  { symbole = "bar", nombre = 3, multiplicateur = 50 },
  { symbole = "cloche", nombre = 3, multiplicateur = 25 },
  { symbole = "prune", nombre = 3, multiplicateur = 10 },
  { symbole = "orange", nombre = 3, multiplicateur = 6 },
  { symbole = "citron", nombre = 3, multiplicateur = 4 },
  { symbole = "cerise", nombre = 3, multiplicateur = 10 },
  { symbole = "cerise", nombre = 2, multiplicateur = 3 },
  { symbole = "cerise", nombre = 1, multiplicateur = 1 },
}

local NOMBRES = { "Une", "Deux", "Trois" }

--- Tire les trois arrêts (indices dans la bande) avec `hasard(n)`, entier uniforme de 1 à n.
function machine.tirer(hasard)
  local taille = #machine.BANDE
  return { hasard(taille), hasard(taille), hasard(taille) }
end

--- Ligne de la table qui paie pour ces arrêts, ou nil.
function machine.combinaison(arrets)
  for _, ligne in ipairs(machine.TABLE) do
    local compte = 0
    for _, arret in ipairs(arrets) do
      if machine.BANDE[arret] == ligne.symbole then compte = compte + 1 end
    end
    if compte == ligne.nombre then return ligne end
  end
  return nil
end

--- Libellé d'une ligne de la table : « Trois cloches », « Une cerise ».
function machine.libelle(ligne)
  local noms = machine.NOMS[ligne.symbole]
  return NOMBRES[ligne.nombre] .. " " .. (ligne.nombre > 1 and noms[2] or noms[1])
end

--- Gain total (mise comprise) pour ces arrêts et cette mise.
function machine.gain(arrets, mise)
  local ligne = machine.combinaison(arrets)
  return ligne and mise * ligne.multiplicateur or 0
end

--- Taux de retour au joueur exact : moyenne du multiplicateur sur toutes les combinaisons d'arrêts.
function machine.retour()
  local taille, somme = #machine.BANDE, 0
  for a = 1, taille do
    for b = 1, taille do
      for c = 1, taille do somme = somme + machine.gain({ a, b, c }, 1) end
    end
  end
  return somme / taille ^ 3
end

--- Règles affichables : intro, entrées de la table ({ texte, symbole }), pied.
function machine.regles()
  local entrees = {}
  for i, ligne in ipairs(machine.TABLE) do
    entrees[i] = { texte = machine.libelle(ligne) .. " : x" .. ligne.multiplicateur, symbole = ligne.symbole }
  end
  return {
    intro = { "Aligne les symboles sur la ligne du milieu.", "Les cerises paient où qu'elles soient." },
    entrees = entrees,
    pied = { "Gain = mise x multiplicateur, mise comprise.",
      (string.format("Retour au joueur : %.1f %% (calcul exact).", 100 * machine.retour()):gsub("%.", ",", 1)) },
  }
end

return machine
