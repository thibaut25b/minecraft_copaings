// Police de CC lue dans le jar de CC: Tweaked (atlas term_font.png) et PNG, partagés par l'aperçu et l'émulateur.
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

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

/** Masques 6x9 des 256 codes : ceux de la police, ou à défaut seulement les pseudo-pixels. */
function tableDesMasques(police) {
  const taille = LARGEUR_CASE * HAUTEUR_CASE;
  return Array.from({ length: 256 }, (_, code) => {
    if (police) return police.masques.subarray(code * taille, (code + 1) * taille);
    return code >= 128 && code <= 159 ? masquePseudoPixel(code) : new Uint8Array(taille);
  });
}

/** URI data: de l'atlas pour une page HTML, ou null sans police. */
function uriPolice(police) {
  return police ? `data:image/png;base64,${police.png.toString('base64')}` : null;
}

/** Code navigateur du rendu des cases, à insérer dans une page après la constante POLICE. */
const RENDU_CASES = fs.readFileSync(path.join(__dirname, 'rendu_cases.js'), 'utf8');

module.exports = { LARGEUR_CASE, HAUTEUR_CASE, encoderPng, chargerPolice, tableDesMasques, uriPolice, RENDU_CASES };
