-- Le journal est horodaté et borné : au plus le fichier courant et un seul `.ancien`.

local verif = require("verif")
local systeme = require("faux.systeme")
local journal = require("commun.journal")

return {
  chaque_message_est_une_ligne_horodatee = function()
    local etat = systeme.installer()
    local j = journal.ouvrir("/j.log", 1000)
    j.info("demarrage")
    j.erreur("pont absent")
    verif.egal(etat.disque["j.log"],
      "2026-01-02 03:04:05 INFO demarrage\n2026-01-02 03:04:05 ERREUR pont absent\n")
  end,

  fichier_trop_gros_est_tourne_en_ancien = function()
    local etat = systeme.installer()
    local j = journal.ouvrir("/j.log", 60)
    j.info("premier")
    j.info("second")
    verif.egal(etat.disque["j.log.ancien"], "2026-01-02 03:04:05 INFO premier\n")
    verif.egal(etat.disque["j.log"], "2026-01-02 03:04:05 INFO second\n")
  end,

  un_seul_ancien_est_garde = function()
    local etat = systeme.installer()
    local j = journal.ouvrir("/j.log", 40)
    j.info("un")
    j.info("deux")
    j.info("trois")
    verif.egal(etat.disque["j.log.ancien"], "2026-01-02 03:04:05 INFO deux\n")
    verif.egal(etat.disque["j.log"], "2026-01-02 03:04:05 INFO trois\n")
    verif.egal(etat.disque["j.log.ancien.ancien"], nil)
  end,

  sans_depassement_aucune_rotation = function()
    local etat = systeme.installer()
    local j = journal.ouvrir("/j.log", 1000)
    j.info("un")
    j.info("deux")
    verif.egal(etat.disque["j.log.ancien"], nil)
  end,
}
