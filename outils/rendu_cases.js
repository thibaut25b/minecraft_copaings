// Rendu d'une case de CC sur un canvas avec l'atlas de la police : code inséré tel quel dans les pages de l'aperçu et de l'émulateur.
// Attend la constante POLICE (URI de l'atlas, ou null : repli sur la police monospace du navigateur).
const L = 6, H = 9, PAS_X = 8, PAS_Y = 11;
const atlas = new Image();
const teintes = new Map();

function alerte(texte) {
  const div = document.createElement("div");
  div.className = "alerte";
  div.textContent = texte;
  return div;
}

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

/** Prépare le contexte d'un canvas d'écran pour le repli sans police. */
function preparerContexte(ctx) {
  ctx.font = "9px monospace";
  ctx.textBaseline = "top";
}

/** Dessine la case de coordonnées (cx, cy) comptées depuis 0 : fond puis glyphe `code` (0 à 255). */
function dessinerCase(ctx, cx, cy, code, couleurTexte, couleurFond) {
  ctx.fillStyle = couleurFond;
  ctx.fillRect(cx * L, cy * H, L, H);
  if (code === 32) return;
  if (POLICE) {
    ctx.drawImage(teinte(couleurTexte), 1 + (code % 16) * PAS_X, 1 + Math.floor(code / 16) * PAS_Y, L, H, cx * L, cy * H, L, H);
  } else if (code >= 128 && code <= 159) {
    pseudoPixel(ctx, code, cx * L, cy * H, couleurTexte);
  } else {
    ctx.fillStyle = couleurTexte;
    ctx.fillText(String.fromCharCode(code), cx * L, cy * H);
  }
}

/** Charge l'atlas puis appelle `suite` ; sans police, avertit dans `zone` puis appelle `suite`. */
function chargerPolice(zone, suite) {
  if (POLICE) {
    atlas.onload = suite;
    atlas.src = POLICE;
    return;
  }
  const message = "Police de CC introuvable : repli sur la police monospace du navigateur, rendu approximatif.";
  console.warn(message);
  zone.append(alerte(message));
  suite();
}
