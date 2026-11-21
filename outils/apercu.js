// Aperçu hors jeu : joue chaque écran d'une collection (galerie, colonie) dans Fengari sur un moniteur enregistreur,
// puis écrit apercu/<collection>.html et un PNG par écran (première image, échelle 2).
// Usage : `npm run apercu` (toutes), `npm run apercu -- colonie` (une seule) ; CC_JAR remplace le jar de CC: Tweaked.
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const RACINE = path.resolve(__dirname, '..');
const DOSSIER_SORTIE = path.join(RACINE, 'apercu');
const ECHELLE_PNG = 2;

// Collections : `liste` renvoie des noms d'écrans de `dossier` ou des écrans tout faits ; PNG dans apercu/`png`/.
const COLLECTIONS = [
  { nom: 'galerie', titre: 'Galerie ComputerCraft', liste: 'projets/galerie/ecrans.lua', dossier: 'projets/galerie/ecrans/', png: '' },
  { nom: 'colonie', titre: 'Tableau de bord de la colonie', liste: 'outils/apercus/colonie/ecrans.lua', dossier: '', png: 'colonie' },
];

// Géométrie de la police de CC : cases de 6x9 pixels, une case de l'atlas fait 8x11 (marge de 1 pixel), 16 colonnes.
const LARGEUR_CASE = 6;
const HAUTEUR_CASE = 9;
const PAS_ATLAS_X = 8;
const PAS_ATLAS_Y = 11;
const LARGEUR_ATLAS = 16 * PAS_ATLAS_X;
const HAUTEUR_ATLAS = 16 * PAS_ATLAS_Y;
const ENTREE_POLICE = 'assets/computercraft/textures/gui/term_font.png';
const JAR_DEFAUT = path.join(
  process.env.APPDATA || '', 'PrismLauncher', 'instances', 'All the Mods 10 - ATM10', 'minecraft', 'mods',
  'cc-tweaked-1.21.1-forge-1.120.2.jar',
);

// ---------------------------------------------------------------------------------------------------- PNG

const TABLE_CRC = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(octets) {
  let c = 0xffffffff;
  for (const octet of octets) c = TABLE_CRC[(c ^ octet) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function morceauPng(type, donnees) {
  const tete = Buffer.alloc(8);
  tete.writeUInt32BE(donnees.length, 0);
  tete.write(type, 4, 'latin1');
  const queue = Buffer.alloc(4);
  queue.writeUInt32BE(crc32(Buffer.concat([tete.subarray(4), donnees])), 0);
  return Buffer.concat([tete, donnees, queue]);
}

/** Encode des pixels 8 bits (`canaux` = 3 pour RVB, 4 pour RVBA) en PNG. */
function encoderPng(largeur, hauteur, canaux, pixels) {
  const ligne = largeur * canaux;
  const brut = Buffer.alloc((ligne + 1) * hauteur);
  for (let y = 0; y < hauteur; y++) {
    pixels.copy(brut, y * (ligne + 1) + 1, y * ligne, (y + 1) * ligne);
  }
  const entete = Buffer.alloc(13);
  entete.writeUInt32BE(largeur, 0);
  entete.writeUInt32BE(hauteur, 4);
  entete[8] = 8;
  entete[9] = canaux === 4 ? 6 : 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    morceauPng('IHDR', entete),
    morceauPng('IDAT', zlib.deflateSync(brut)),
    morceauPng('IEND', Buffer.alloc(0)),
  ]);
}

/** Décode un PNG (profondeur 1 à 8 bits, types gris, RVB, palette, gris-alpha, RVBA) en { largeur, hauteur, rvba }. */
function decoderPng(octets) {
  let largeur = 0;
  let hauteur = 0;
  let profondeur = 0;
  let type = 0;
  let palette = Buffer.alloc(0);
  let transparence = Buffer.alloc(0);
  const donnees = [];
  for (let p = 8; p < octets.length;) {
    const taille = octets.readUInt32BE(p);
    const nom = octets.toString('latin1', p + 4, p + 8);
    const corps = octets.subarray(p + 8, p + 8 + taille);
    if (nom === 'IHDR') {
      largeur = corps.readUInt32BE(0);
      hauteur = corps.readUInt32BE(4);
      profondeur = corps[8];
      type = corps[9];
    } else if (nom === 'PLTE') palette = corps;
    else if (nom === 'tRNS') transparence = corps;
    else if (nom === 'IDAT') donnees.push(corps);
    p += 12 + taille;
  }
  const canaux = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type];
  if (!canaux || profondeur > 8) throw new Error(`PNG non géré (type ${type}, profondeur ${profondeur})`);
  const bitsPixel = canaux * profondeur;
  const ligne = Math.ceil((largeur * bitsPixel) / 8);
  const pas = Math.max(1, bitsPixel >> 3);
  const brut = zlib.inflateSync(Buffer.concat(donnees));
  const lignes = Buffer.alloc(ligne * hauteur);
  for (let y = 0; y < hauteur; y++) {
    const filtre = brut[y * (ligne + 1)];
    for (let i = 0; i < ligne; i++) {
      const x = brut[y * (ligne + 1) + 1 + i];
      const a = i >= pas ? lignes[y * ligne + i - pas] : 0;
      const b = y > 0 ? lignes[(y - 1) * ligne + i] : 0;
      const c = i >= pas && y > 0 ? lignes[(y - 1) * ligne + i - pas] : 0;
      const pa = Math.abs(b - c);
      const pb = Math.abs(a - c);
      const pc = Math.abs(a + b - 2 * c);
      const paeth = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      const predit = [0, a, b, (a + b) >> 1, paeth][filtre];
      if (predit === undefined) throw new Error(`Filtre PNG inconnu : ${filtre}`);
      lignes[y * ligne + i] = (x + predit) & 0xff;
    }
  }
  const echantillon = (y, n) => {
    if (profondeur === 8) return lignes[y * ligne + n];
    const bit = n * profondeur;
    return (lignes[y * ligne + (bit >> 3)] >> (8 - profondeur - (bit & 7))) & ((1 << profondeur) - 1);
  };
  const maximum = (1 << profondeur) - 1;
  const rvba = Buffer.alloc(largeur * hauteur * 4);
  for (let y = 0; y < hauteur; y++) {
    for (let x = 0; x < largeur; x++) {
      const sortie = (y * largeur + x) * 4;
      const e = (n) => echantillon(y, x * canaux + n);
      let pixel;
      if (type === 3) {
        const i = e(0);
        pixel = [palette[i * 3], palette[i * 3 + 1], palette[i * 3 + 2], i < transparence.length ? transparence[i] : 255];
      } else if (type === 0 || type === 4) {
        const g = Math.round((e(0) * 255) / maximum);
        pixel = [g, g, g, type === 4 ? e(1) : 255];
      } else {
        pixel = [e(0), e(1), e(2), type === 6 ? e(3) : 255];
      }
      rvba.set(pixel, sortie);
    }
  }
  return { largeur, hauteur, rvba };
}

// ----------------------------------------------------------------------------------------------- Police de CC

/** Lit une entrée d'une archive zip (méthodes 0 et 8) ; renvoie un Buffer ou null si absente. */
function lireEntreeZip(chemin, entree) {
  const d = fs.readFileSync(chemin);
  let fin = d.length - 22;
  while (fin >= 0 && d.readUInt32LE(fin) !== 0x06054b50) fin--;
  if (fin < 0) throw new Error('Archive zip invalide');
  const nombre = d.readUInt16LE(fin + 10);
  let p = d.readUInt32LE(fin + 16);
  for (let k = 0; k < nombre; k++) {
    const methode = d.readUInt16LE(p + 10);
    const tailleCompressee = d.readUInt32LE(p + 20);
    const longueurNom = d.readUInt16LE(p + 28);
    const longueurExtra = d.readUInt16LE(p + 30);
    const longueurCommentaire = d.readUInt16LE(p + 32);
    const local = d.readUInt32LE(p + 42);
    if (d.toString('utf8', p + 46, p + 46 + longueurNom) === entree) {
      const debut = local + 30 + d.readUInt16LE(local + 26) + d.readUInt16LE(local + 28);
      const compresse = d.subarray(debut, debut + tailleCompressee);
      return methode === 0 ? compresse : zlib.inflateRawSync(compresse);
    }
    p += 46 + longueurNom + longueurExtra + longueurCommentaire;
  }
  return null;
}

/** Charge la police : { masques, png } ou null (avertissement) si le jar est introuvable. */
function chargerPolice() {
  const jar = process.env.CC_JAR || JAR_DEFAUT;
  try {
    const atlas = lireEntreeZip(jar, ENTREE_POLICE);
    if (!atlas) throw new Error(`entrée ${ENTREE_POLICE} absente`);
    const image = decoderPng(atlas);
    const masques = new Uint8Array(256 * LARGEUR_CASE * HAUTEUR_CASE);
    const sortie = Buffer.alloc(LARGEUR_ATLAS * HAUTEUR_ATLAS * 4);
    for (let y = 0; y < HAUTEUR_ATLAS; y++) {
      for (let x = 0; x < LARGEUR_ATLAS; x++) {
        const i = (y * image.largeur + x) * 4;
        if (image.rvba[i + 3] < 128 || image.rvba[i] < 128) continue;
        sortie.fill(255, (y * LARGEUR_ATLAS + x) * 4, (y * LARGEUR_ATLAS + x) * 4 + 4);
        const code = Math.floor(y / PAS_ATLAS_Y) * 16 + Math.floor(x / PAS_ATLAS_X);
        const px = (x % PAS_ATLAS_X) - 1;
        const py = (y % PAS_ATLAS_Y) - 1;
        if (px >= 0 && px < LARGEUR_CASE && py >= 0 && py < HAUTEUR_CASE) {
          masques[code * LARGEUR_CASE * HAUTEUR_CASE + py * LARGEUR_CASE + px] = 1;
        }
      }
    }
    return { masques, png: encoderPng(LARGEUR_ATLAS, HAUTEUR_ATLAS, 4, sortie) };
  } catch (erreur) {
    console.warn(`AVERTISSEMENT police de CC introuvable (${jar} : ${erreur.message}).`);
    console.warn('  Repli : texte absent des PNG, police monospace du navigateur dans le HTML.');
    return null;
  }
}

/** Masque 6x9 d'un pseudo-pixel (codes 128 à 159), rectangles exacts : le sous-pixel bas droit n'a pas de bit. */
function masquePseudoPixel(code) {
  const masque = new Uint8Array(LARGEUR_CASE * HAUTEUR_CASE);
  for (let y = 0; y < HAUTEUR_CASE; y++) {
    for (let x = 0; x < LARGEUR_CASE; x++) {
      const bit = Math.floor(y / 3) * 2 + Math.floor(x / 3);
      masque[y * LARGEUR_CASE + x] = bit < 5 && ((code - 128) >> bit) & 1 ? 1 : 0;
    }
  }
  return masque;
}

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

/** Masques 6x9 des 256 codes : ceux de la police, ou à défaut seulement les pseudo-pixels. */
function tableDesMasques(police) {
  const taille = LARGEUR_CASE * HAUTEUR_CASE;
  return Array.from({ length: 256 }, (_, code) => {
    if (police) return police.masques.subarray(code * taille, (code + 1) * taille);
    return code >= 128 && code <= 159 ? masquePseudoPixel(code) : new Uint8Array(taille);
  });
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
const L = 6, H = 9, PAS_X = 8, PAS_Y = 11;

function alerte(texte) {
  const div = document.createElement("div");
  div.className = "alerte";
  div.textContent = texte;
  return div;
}

const atlas = new Image();
const teintes = new Map();

function teinte(couleur) {
  let canvas = teintes.get(couleur);
  if (!canvas) {
    if (teintes.size > 400) teintes.clear();
    canvas = document.createElement("canvas");
    canvas.width = atlas.width;
    canvas.height = atlas.height;
    const ctx = canvas.getContext("2d");
    ctx.drawImage(atlas, 0, 0);
    ctx.globalCompositeOperation = "source-in";
    ctx.fillStyle = couleur;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    teintes.set(couleur, canvas);
  }
  return canvas;
}

function pseudoPixel(ctx, code, x, y, couleur) {
  ctx.fillStyle = couleur;
  for (let bit = 0; bit < 5; bit++) {
    if ((code - 128) >> bit & 1) ctx.fillRect(x + (bit % 2) * 3, y + Math.floor(bit / 2) * 3, 3, 3);
  }
}

function dessiner(ecran, n) {
  const s = ecran.images[n], ctx = ecran.ctx, l = ecran.largeur;
  const palette = [];
  for (let i = 0; i < 16; i++) palette.push("#" + s.substr(i * 6, 6));
  for (let cy = 0; cy < ecran.hauteur; cy++) {
    const debut = 96 + cy * 4 * l;
    for (let cx = 0; cx < l; cx++) {
      ctx.fillStyle = palette[parseInt(s[debut + 3 * l + cx], 16)];
      ctx.fillRect(cx * L, cy * H, L, H);
    }
    for (let cx = 0; cx < l; cx++) {
      const code = parseInt(s.substr(debut + cx * 2, 2), 16);
      if (code === 32) continue;
      const couleur = palette[parseInt(s[debut + 2 * l + cx], 16)];
      if (POLICE) {
        ctx.drawImage(teinte(couleur), 1 + (code % 16) * PAS_X, 1 + Math.floor(code / 16) * PAS_Y, L, H, cx * L, cy * H, L, H);
      } else if (code >= 128 && code <= 159) {
        pseudoPixel(ctx, code, cx * L, cy * H, couleur);
      } else {
        ctx.fillStyle = couleur;
        ctx.fillText(String.fromCharCode(code), cx * L, cy * H);
      }
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
      ecran.ctx.font = "9px monospace";
      ecran.ctx.textBaseline = "top";
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

if (POLICE) {
  atlas.onload = construire;
  atlas.src = POLICE;
} else {
  const message = "Police de CC introuvable : repli sur la police monospace du navigateur, rendu approximatif.";
  console.warn(message);
  document.getElementById("avertissements").append(alerte(message));
  construire();
}
</script>
</body>
</html>
`;

function ecrireHtml(collection, ecrans, police) {
  const donnees = JSON.stringify(ecrans).replace(/</g, '\\u003c');
  const uri = police ? `data:image/png;base64,${police.png.toString('base64')}` : null;
  const page = PAGE_HTML.replace(/__TITRE__/g, () => collection.titre).replace('__DONNEES__', () => donnees)
    .replace('__POLICE__', () => JSON.stringify(uri));
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
