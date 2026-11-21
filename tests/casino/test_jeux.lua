-- Règles de paiement et taux de retour exacts de la machine à sous, de la roulette et du crash.

local verif = require("verif")
local machine = require("casino.jeux.machine")
local roulette = require("casino.jeux.roulette")
local crash = require("casino.jeux.crash")

-- Indice du premier arrêt de la bande qui porte `symbole`.
local function arret(symbole)
  for i, nom in ipairs(machine.BANDE) do
    if nom == symbole then return i end
  end
  error("symbole absent de la bande : " .. symbole)
end

local function hasard_fixe(valeur)
  return function() return valeur end
end

-- Nombre de tirages (sur les TIRAGES équiprobables) qui donnent chaque point du crash, énuméré une seule fois.
local repartition
local function repartition_crash()
  if repartition then return repartition end
  repartition = {}
  for k = 1, crash.TIRAGES do
    local point = crash.point(hasard_fixe(k))
    repartition[point] = (repartition[point] or 0) + 1
  end
  return repartition
end

return {
  machine_trois_7_paient_cent_fois_la_mise = function()
    verif.egal(machine.gain({ arret("sept"), arret("sept"), arret("sept") }, 5), 500)
  end,

  machine_chaque_ligne_de_la_table_paie_son_multiplicateur = function()
    for _, ligne in ipairs(machine.TABLE) do
      local arrets = {}
      for i = 1, 3 do
        arrets[i] = arret(i <= ligne.nombre and ligne.symbole or "citron")
      end
      verif.egal(machine.gain(arrets, 2), 2 * ligne.multiplicateur, machine.libelle(ligne))
    end
  end,

  machine_les_cerises_paient_ou_qu_elles_soient = function()
    local c, p, o = arret("cerise"), arret("prune"), arret("orange")
    verif.egal(machine.gain({ p, c, o }, 10), 10)
    verif.egal(machine.gain({ c, o, c }, 10), 30)
  end,

  machine_sans_combinaison_ne_paie_rien = function()
    verif.egal(machine.gain({ arret("citron"), arret("orange"), arret("prune") }, 10), 0)
    verif.egal(machine.gain({ arret("sept"), arret("sept"), arret("bar") }, 10), 0)
  end,

  machine_retour_exact_95_325_pour_cent_dans_la_fourchette_94_97 = function()
    local retour = machine.retour()
    verif.vrai(math.abs(retour - 0.95325) < 1e-9, tostring(retour))
    verif.vrai(retour >= 0.94 and retour <= 0.97)
  end,

  machine_retour_combinatoire_egal_au_parcours_des_8000_combinaisons = function()
    local taille, somme = #machine.BANDE, 0
    for a = 1, taille do
      for b = 1, taille do
        for c = 1, taille do somme = somme + machine.gain({ a, b, c }, 1) end
      end
    end
    verif.egal(somme, 7626)
    verif.vrai(math.abs(machine.retour() - somme / taille ^ 3) < 1e-12)
  end,

  machine_tirage_prend_un_arret_par_rouleau_dans_la_bande = function()
    local vus = {}
    local arrets = machine.tirer(function(n) vus[#vus + 1] = n; return n end)
    verif.egal(arrets, { #machine.BANDE, #machine.BANDE, #machine.BANDE })
    verif.egal(vus, { 20, 20, 20 })
  end,

  roulette_couleurs_et_roue_europeenne_complete = function()
    verif.egal(#roulette.ROUE, 37)
    local vus, rouges = {}, 0
    for _, numero in ipairs(roulette.ROUE) do
      vus[numero] = true
      if roulette.couleur(numero) == "rouge" then rouges = rouges + 1 end
    end
    for numero = 0, 36 do verif.vrai(vus[numero], "numéro absent : " .. numero) end
    verif.egal(rouges, 18)
    verif.egal(roulette.couleur(0), "vert")
    verif.egal(roulette.couleur(32), "rouge")
    verif.egal(roulette.couleur(15), "noir")
  end,

  roulette_plein_paie_36_fois_le_jeton = function()
    verif.egal(roulette.gain({ n17 = 5 }, 17), 180)
    verif.egal(roulette.gain({ n17 = 5 }, 18), 0)
    verif.egal(roulette.gain({ n0 = 2 }, 0), 72)
  end,

  roulette_chances_simples_douzaines_colonnes = function()
    verif.egal(roulette.gain({ rouge = 10 }, 1), 20)
    verif.egal(roulette.gain({ noir = 10 }, 1), 0)
    verif.egal(roulette.gain({ pair = 10, impair = 10 }, 7), 20)
    verif.egal(roulette.gain({ manque = 4, passe = 4 }, 19), 8)
    verif.egal(roulette.gain({ d2 = 3 }, 24), 9)
    verif.egal(roulette.gain({ c1 = 3, c3 = 3 }, 34), 9)
    verif.egal(roulette.gain({ c3 = 3 }, 36), 9)
  end,

  roulette_le_zero_fait_perdre_toutes_les_autres_cases = function()
    local mises = {}
    for _, cle in ipairs(roulette.EXTERIEURES) do mises[cle] = 1 end
    verif.egal(roulette.gain(mises, 0), 0)
  end,

  roulette_plusieurs_mises_se_cumulent = function()
    verif.egal(roulette.gain({ n17 = 1, rouge = 5, noir = 5, d2 = 2 }, 17), 36 + 0 + 10 + 6)
  end,

  roulette_retour_exact_36_sur_37_pour_chaque_case = function()
    local cles = { "n0", "n17", "n36" }
    for _, cle in ipairs(roulette.EXTERIEURES) do cles[#cles + 1] = cle end
    for _, cle in ipairs(cles) do
      verif.vrai(math.abs(roulette.retour(cle) - 36 / 37) < 1e-12, cle)
    end
    verif.vrai(math.abs(36 / 37 - 0.973) < 0.0005)
  end,

  roulette_case_inconnue_leve_une_erreur = function()
    verif.egal(roulette.case("n37"), nil)
    verif.egal(pcall(roulette.gain, { vert = 1 }, 0), false)
  end,

  roulette_tirage_de_0_a_36 = function()
    verif.egal(roulette.tirer(hasard_fixe(1)), 0)
    verif.egal(roulette.tirer(hasard_fixe(37)), 36)
  end,

  crash_loi_du_point_verifiee_par_enumeration = function()
    -- P(point > m) = floor(0,97 x N / m) / N pour tout m de 1,00 au plafond.
    local compte, au_dessus = repartition_crash(), crash.TIRAGES
    for m = 100, crash.PLAFOND - 1 do
      au_dessus = au_dessus - (compte[m] or 0)
      verif.egal(au_dessus, math.floor(crash.RETOUR * crash.TIRAGES / m), "m = " .. m)
    end
  end,

  crash_explosion_immediate_trois_pour_cent = function()
    verif.egal(repartition_crash()[100], crash.TIRAGES * (100 - crash.RETOUR) / 100)
  end,

  crash_retour_exact_entre_96_et_97_pour_cent_pour_chaque_cible = function()
    -- Toutes les cibles de x1.01 au plafond ; on gagne si le point est au-dessus, ou au plafond s'il y est.
    local compte, au_dessus = repartition_crash(), crash.TIRAGES - repartition_crash()[100]
    for cible = 101, crash.PLAFOND do
      au_dessus = au_dessus - (compte[cible] or 0)
      local gagnants = cible == crash.PLAFOND and compte[cible] or au_dessus
      local retour = gagnants * crash.gain(100, cible) / (100 * crash.TIRAGES)
      verif.vrai(retour >= 0.96 and retour <= 0.97, cible .. " : " .. retour)
      verif.vrai(crash.gagne(cible, cible + 1) and not crash.gagne(cible, cible))
    end
  end,

  crash_multiplicateur_croit_et_plafonne = function()
    verif.egal(crash.multiplicateur(0), 100)
    verif.vrai(crash.multiplicateur(5) > crash.multiplicateur(4))
    verif.egal(crash.multiplicateur(1000), crash.PLAFOND)
    verif.egal(crash.multiplicateur(crash.instant(250) + 1e-6), 250)
    verif.egal(crash.texte(142), "x1.42")
    verif.egal(crash.texte(1005), "x10.05")
  end,

  crash_gain_arrondi_en_dessous_et_sans_geste_perdu_sauf_plafond = function()
    verif.egal(crash.gain(25, 142), 35)
    verif.egal(crash.gain_sans_geste(25, 9999), 0)
    verif.egal(crash.gain_sans_geste(25, crash.PLAFOND), 2500)
  end,

  regles_de_chaque_jeu_tiennent_en_45_caracteres = function()
    local texte = require("commun.texte")
    for _, jeu in ipairs({ machine, roulette, crash }) do
      local r = jeu.regles()
      for _, ligne in ipairs(r.intro) do verif.vrai(#texte.vers_cc(ligne) <= 45, ligne) end
      for _, ligne in ipairs(r.pied) do verif.vrai(#texte.vers_cc(ligne) <= 45, ligne) end
    end
    verif.vrai(machine.regles().pied[2]:find("95,3 %", 1, true), machine.regles().pied[2])
    verif.vrai(roulette.regles().pied[2]:find("97,3 %", 1, true), roulette.regles().pied[2])
  end,
}
