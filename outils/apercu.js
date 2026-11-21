// Aperçu hors jeu : joue chaque écran d'une collection (galerie, colonie) dans Fengari sur un moniteur enregistreur,
// puis écrit apercu/<collection>.html et un PNG par écran (première image, échelle 2).
// Usage : `npm run apercu` (toutes), `npm run apercu -- colonie` (une seule) ; CC_JAR remplace le jar de CC: Tweaked.
'use strict';

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const { LARGEUR_CASE, HAUTEUR_CASE, encoderPng, chargerPolice, tableDesMasques, uriPolice, RENDU_CASES } = require('./police');

const RACINE = path.resolve(__dirname, '..');
const DOSSIER_SORTIE = path.join(RACINE, 'apercu');
const ECHELLE_PNG = 2;

// Collections : `liste` renvoie des noms d'écrans de `dossier` ou des écrans tout faits ; PNG dans apercu/`png`/.
const COLLECTIONS = [
  { nom: 'galerie', titre: 'Galerie ComputerCraft', liste: 'projets/galerie/ecrans.lua', dossier: 'projets/galerie/ecrans/', png: '' },
  { nom: 'colonie', titre: 'Tableau de bord de la colonie', liste: 'outils/apercus/colonie/ecrans.lua', dossier: '', png: 'colonie' },
];


// ------------------------------------------------------------------------------------------- Écrans via Lua

const PILOTE_LUA = String.raw`
local LISTE, DOSSIER = ...
package.path = "./?.lua;./projets/?.lua"
local moniteur = require("outils.moniteur_enregistreur")

colors = {
  white = 1, orange = 2, magenta = 4, lightBlue = 8, yellow = 16, lime = 32, pink = 64, gray = 128,
  lightGray = 256, cyan = 512, purple = 1024, blue = 2048, brown = 4096, green = 8192, red = 16384, black = 32768,
}
function colors.toBlit(couleur)
  return string.format("%x", math.floor(math.log(couleur) / math.log(2) + 0.5))
end
colours = colors
colours.grey, colours.lightGrey = colors.gray, colors.lightGray

local horloge = 0
os.clock = function() return horloge end
os.epoch = function() return math.floor(horloge * 1000) end
os.time = function() return (6 + horloge / 50) % 24 end

local ECHAPPEMENTS = { ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t" }
local function ligne(...)
  local champs = { ... }
  for i, champ in ipairs(champs) do champs[i] = (tostring(champ):gsub("[\\\n\t]", ECHAPPEMENTS)) end
  return table.concat(champs, "\t")
end

local sortie = {}
local ok_liste, liste = pcall(dofile, LISTE)
if not ok_liste then return table.concat({ ligne("ECRAN", LISTE, LISTE, 0, 0), ligne("ERREUR", "liste", liste) }, "\n") end
for _, entree in ipairs(liste) do
  local nom, ok, ecran = entree, true, entree
  if type(entree) == "table" then nom = tostring(entree.nom) else ok, ecran = pcall(dofile, DOSSIER .. nom .. ".lua") end
  if not ok or type(ecran) ~= "table" or type(ecran.dessiner) ~= "function" or type(ecran.images) ~= "number" then
    sortie[#sortie + 1] = ligne("ECRAN", nom, nom, 0, 0)
    sortie[#sortie + 1] = ligne("ERREUR", "chargement", ok and "l'écran doit renvoyer { images, dessiner }" or ecran)
  else
    local largeur, hauteur = ecran.largeur or 100, ecran.hauteur or 38
    sortie[#sortie + 1] = ligne("ECRAN", nom, ecran.titre or nom, largeur, hauteur)
    local cible = moniteur.creer(largeur, hauteur)
    for t = 0, ecran.images - 1 do
      horloge = t / 10
      local fini, erreur = pcall(ecran.dessiner, cible, t)
      if not fini then
        sortie[#sortie + 1] = ligne("ERREUR", t, erreur)
        break
      end
      sortie[#sortie + 1] = ligne("IMAGE", cible.exporter())
    end
  end
end
return table.concat(sortie, "\n")
`;

function executerEcrans(collection) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  if (lauxlib.luaL_loadstring(L, to_luastring(PILOTE_LUA)) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  lua.lua_pushstring(L, to_luastring(collection.liste));
  lua.lua_pushstring(L, to_luastring(collection.dossier));
  if (lua.lua_pcall(L, 2, 1, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  const defaire = (texte) => texte.replace(/\\([\\nt])/g, (_, c) => ({ '\\': '\\', n: '\n', t: '\t' })[c]);
  const ecrans = [];
  for (const brute of to_jsstring(lua.lua_tostring(L, -1)).split('\n')) {
    const [genre, ...champs] = brute.split('\t').map(defaire);
    if (genre === 'ECRAN') {
      ecrans.push({ nom: champs[0], titre: champs[1], largeur: Number(champs[2]), hauteur: Number(champs[3]), images: [], erreurs: [] });
    } else if (genre === 'IMAGE') ecrans[ecrans.length - 1].images.push(champs[0]);
    else if (genre === 'ERREUR') ecrans[ecrans.length - 1].erreurs.push({ image: champs[0], message: champs[1] });
  }
  return ecrans;
}

// --------------------------------------------------------------------------------------------- Rendu en PNG

/** Rend une image exportée par le moniteur enregistreur en pixels RVB, à l'échelle entière donnée. */
function rendreImage(ecran, exportee, echelle, masques) {
  const palette = Array.from({ length: 16 }, (_, i) => [0, 2, 4].map((k) => parseInt(exportee.substr(i * 6 + k, 2), 16)));
  const largeurPx = ecran.largeur * LARGEUR_CASE * echelle;
  const hauteurPx = ecran.hauteur * HAUTEUR_CASE * echelle;
  const pixels = Buffer.alloc(largeurPx * hauteurPx * 3);
  const l = ecran.largeur;
  for (let cy = 0; cy < ecran.hauteur; cy++) {
    const debut = 96 + cy * 4 * l;
    for (let cx = 0; cx < l; cx++) {
      const code = parseInt(exportee.substr(debut + cx * 2, 2), 16);
      const texte = palette[parseInt(exportee[debut + 2 * l + cx], 16)];
      const fond = palette[parseInt(exportee[debut + 3 * l + cx], 16)];
      for (let py = 0; py < HAUTEUR_CASE * echelle; py++) {
        for (let px = 0; px < LARGEUR_CASE * echelle; px++) {
          const source = Math.floor(py / echelle) * LARGEUR_CASE + Math.floor(px / echelle);
          const couleur = masques[code][source] ? texte : fond;
          const x = cx * LARGEUR_CASE * echelle + px;
          const y = cy * HAUTEUR_CASE * echelle + py;
          pixels.set(couleur, (y * largeurPx + x) * 3);
        }
      }
    }
  }
  return encoderPng(largeurPx, hauteurPx, 3, pixels);
}


// --------------------------------------------------------------------------------------------------- HTML

const PAGE_HTML = String.raw`<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>__TITRE__</title>
<style>
  body { margin: 0; padding: 24px 32px; background: #14161a; color: #c8ccd2; font: 14px/1.4 system-ui, sans-serif; }
  h1 { margin: 0 0 4px; font-size: 20px; font-weight: 600; }
  h2 { margin: 28px 0 8px; font-size: 16px; font-weight: 500; }
  label { margin-left: 12px; }
  canvas { display: block; border: 1px solid #2a2e35; image-rendering: pixelated; cursor: pointer; }
  .legende { margin-top: 4px; color: #7d848f; font-size: 12px; }
  .alerte { margin: 12px 0; padding: 8px 12px; background: #3a2323; border-left: 3px solid #cc4c4c; white-space: pre-wrap; }
</style>
</head>
<body>
<h1>__TITRE__</h1>
<span>Une image toutes les 100 ms, clic sur un écran : pause.</span>
<label>Échelle <select id="echelle"></select></label>
<div id="avertissements"></div>
<main id="galerie"></main>
<script>
"use strict";
const DONNEES = __DONNEES__;
const POLICE = __POLICE__;
__RENDU_CASES__

function dessiner(ecran, n) {
  const s = ecran.images[n], ctx = ecran.ctx, l = ecran.largeur;
  const palette = [];
  for (let i = 0; i < 16; i++) palette.push("#" + s.substr(i * 6, 6));
  for (let cy = 0; cy < ecran.hauteur; cy++) {
    const debut = 96 + cy * 4 * l;
    for (let cx = 0; cx < l; cx++) {
      const code = parseInt(s.substr(debut + cx * 2, 2), 16);
      dessinerCase(ctx, cx, cy, code, palette[parseInt(s[debut + 2 * l + cx], 16)], palette[parseInt(s[debut + 3 * l + cx], 16)]);
    }
  }
}

function legende(ecran) {
  ecran.legende.textContent = "image " + (ecran.n + 1) + "/" + ecran.images.length + (ecran.pause ? " (pause)" : "");
}

function construire() {
  const galerie = document.getElementById("galerie");
  const choix = document.getElementById("echelle");
  for (let e = 1; e <= 5; e++) choix.add(new Option(e + "x", e, e === 2, e === 2));
  for (const ecran of DONNEES) {
    const section = document.createElement("section");
    const titre = document.createElement("h2");
    titre.textContent = ecran.titre;
    section.append(titre);
    for (const erreur of ecran.erreurs) {
      section.append(alerte("Erreur à l'image " + erreur.image + " : " + erreur.message));
    }
    if (ecran.images.length) {
      const canvas = document.createElement("canvas");
      canvas.width = ecran.largeur * L;
      canvas.height = ecran.hauteur * H;
      ecran.ctx = canvas.getContext("2d");
      preparerContexte(ecran.ctx);
      ecran.canvas = canvas;
      ecran.legende = document.createElement("div");
      ecran.legende.className = "legende";
      ecran.n = 0;
      ecran.pause = false;
      canvas.addEventListener("click", () => { ecran.pause = !ecran.pause; legende(ecran); });
      section.append(canvas, ecran.legende);
    }
    galerie.append(section);
  }
  choix.addEventListener("change", mettreAEchelle);
  mettreAEchelle();
  setInterval(() => {
    for (const ecran of DONNEES.filter((e) => e.images.length && !e.pause)) {
      ecran.n = (ecran.n + 1) % ecran.images.length;
      dessiner(ecran, ecran.n);
      legende(ecran);
    }
  }, 100);
  for (const ecran of DONNEES.filter((e) => e.images.length)) { dessiner(ecran, 0); legende(ecran); }
}

function mettreAEchelle() {
  const echelle = Number(document.getElementById("echelle").value);
  for (const ecran of DONNEES.filter((e) => e.canvas)) {
    ecran.canvas.style.width = ecran.canvas.width * echelle + "px";
    ecran.canvas.style.height = ecran.canvas.height * echelle + "px";
  }
}

chargerPolice(document.getElementById("avertissements"), construire);
</script>
</body>
</html>
`;

function ecrireHtml(collection, ecrans, police) {
  const donnees = JSON.stringify(ecrans).replace(/</g, '\\u003c');
  const page = PAGE_HTML.replace(/__TITRE__/g, () => collection.titre).replace('__DONNEES__', () => donnees)
    .replace('__POLICE__', () => JSON.stringify(uriPolice(police)))
    .replace('__RENDU_CASES__', () => RENDU_CASES);
  fs.writeFileSync(path.join(DOSSIER_SORTIE, `${collection.nom}.html`), page);
}

// ------------------------------------------------------------------------------------------------- Principal

function main() {
  process.chdir(RACINE);
  const demandees = process.argv.slice(2);
  const choisies = COLLECTIONS.filter((c) => demandees.length === 0 || demandees.includes(c.nom));
  if (choisies.length === 0) throw new Error(`Collection inconnue : ${demandees.join(', ')}`);
  const police = chargerPolice();
  const masques = tableDesMasques(police);
  let echecs = 0;
  for (const collection of choisies) {
    const dossierPng = path.join(DOSSIER_SORTIE, collection.png);
    fs.mkdirSync(dossierPng, { recursive: true });
    const ecrans = executerEcrans(collection);
    for (const ecran of ecrans) {
      for (const erreur of ecran.erreurs) {
        echecs += 1;
        console.error(`ERREUR écran « ${ecran.nom} », image ${erreur.image} : ${erreur.message}`);
      }
      if (ecran.images.length) {
        fs.writeFileSync(path.join(dossierPng, `${ecran.nom}.png`), rendreImage(ecran, ecran.images[0], ECHELLE_PNG, masques));
      }
    }
    ecrireHtml(collection, ecrans, police);
    console.log(`apercu/${collection.nom}.html écrit (${ecrans.length} écrans)`);
  }
  process.exit(echecs === 0 ? 0 : 1);
}

main();
