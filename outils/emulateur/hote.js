// Hôte navigateur de l'ordinateur émulé : état Fengari, réveils par minuterie, rendu des écrans, souris, clavier, stockage.
// Attend les constantes POLICE et PROJET, le code de rendu_cases.js et la globale fengari.
const { lua, lauxlib, lualib, to_luastring } = fengari;
const CLE_DISQUE = "cc-jouer:" + PROJET.nom + ":disque";
const CLE_REGLAGES = "cc-jouer:" + PROJET.nom + ":reglages";
const NOM_MONITEUR = "monitor_0";
const BOUTONS = [1, 3, 2];
const CHIFFRES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
const NOMS_TOUCHES = {
  Space: "space", Quote: "apostrophe", Comma: "comma", Minus: "minus", Period: "period", Slash: "slash",
  Semicolon: "semicolon", Equal: "equals", BracketLeft: "leftBracket", Backslash: "backslash",
  BracketRight: "rightBracket", Backquote: "grave", Enter: "enter", Tab: "tab", Backspace: "backspace",
  Insert: "insert", Delete: "delete", ArrowRight: "right", ArrowLeft: "left", ArrowDown: "down", ArrowUp: "up",
  PageUp: "pageUp", PageDown: "pageDown", Home: "home", End: "end", CapsLock: "capsLock", ShiftLeft: "leftShift",
  ShiftRight: "rightShift", ControlLeft: "leftCtrl", ControlRight: "rightCtrl", AltLeft: "leftAlt",
  AltRight: "rightAlt", NumpadEnter: "numPadEnter", NumpadAdd: "numPadAdd", NumpadSubtract: "numPadSubtract",
  NumpadMultiply: "numPadMultiply", NumpadDivide: "numPadDivide", NumpadDecimal: "numPadDecimal",
};

const LIGNES_DIAGNOSTIC = 40; // dernières lignes de chaque fichier reprises dans le diagnostic
const INCIDENTS_DIAGNOSTIC = 10;

const $ = (id) => document.getElementById(id);
const reglages = Object.assign({ taille: "100x38", zoom: "0", branches: {} }, JSON.parse(localStorage.getItem(CLE_REGLAGES) || "{}"));
const enregistrerReglages = () => localStorage.setItem(CLE_REGLAGES, JSON.stringify(reglages));

// ------------------------------------------------------------------------------------------- Octets et Lua

function versLatin1(octets) {
  let texte = "";
  for (let i = 0; i < octets.length; i += 8192) texte += String.fromCharCode.apply(null, octets.subarray(i, i + 8192));
  return texte;
}

function depuisLatin1(texte) {
  const octets = new Uint8Array(texte.length);
  for (let i = 0; i < texte.length; i++) octets[i] = texte.charCodeAt(i) & 255;
  return octets;
}

/** Texte lisible d'octets Lua : UTF-8 s'il est valide, sinon un caractère par octet. */
function lisible(octets) {
  if (!octets) return "";
  try { return new TextDecoder("utf-8", { fatal: true }).decode(octets); } catch (erreur) { return versLatin1(octets); }
}

const LUA = lauxlib.luaL_newstate();
lualib.luaL_openlibs(LUA);

function pousser(valeur) {
  if (valeur === null || valeur === undefined) lua.lua_pushnil(LUA);
  else if (typeof valeur === "number") lua.lua_pushnumber(LUA, valeur);
  else if (typeof valeur === "boolean") lua.lua_pushboolean(LUA, valeur);
  else if (typeof valeur === "string") lua.lua_pushstring(LUA, to_luastring(valeur));
  else if (valeur instanceof Uint8Array) lua.lua_pushstring(LUA, valeur);
  else if (typeof valeur === "function") lua.lua_pushjsfunction(LUA, valeur);
  else {
    lua.lua_newtable(LUA);
    for (const [cle, element] of Object.entries(valeur)) {
      pousser(element);
      lua.lua_setfield(LUA, -2, to_luastring(cle));
    }
  }
}

function lire(indice) {
  switch (lua.lua_type(LUA, indice)) {
    case lua.LUA_TNUMBER: return lua.lua_tonumber(LUA, indice);
    case lua.LUA_TBOOLEAN: return lua.lua_toboolean(LUA, indice);
    case lua.LUA_TSTRING: return lua.lua_tostring(LUA, indice).slice();
    default: return null;
  }
}

/** Appelle ORDI.methode(...) ou ORDI[objet].methode(...) ; renvoie la liste des résultats (chaînes en octets). */
function appeler(objet, methode, ...args) {
  const base = lua.lua_gettop(LUA);
  lua.lua_getglobal(LUA, to_luastring("ORDI"));
  if (objet) lua.lua_getfield(LUA, -1, to_luastring(objet));
  const debut = lua.lua_gettop(LUA);
  lua.lua_getfield(LUA, -1, to_luastring(methode));
  args.forEach(pousser);
  if (lua.lua_pcall(LUA, args.length, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
    const message = lisible(lua.lua_tostring(LUA, -1));
    lua.lua_settop(LUA, base);
    throw new Error(message);
  }
  const resultats = [];
  for (let i = debut + 1; i <= lua.lua_gettop(LUA); i++) resultats.push(lire(i));
  lua.lua_settop(LUA, base);
  return resultats;
}

// ------------------------------------------------------------------------------------------- Son

let audio = null;
function son(Letat) {
  const frequence = lua.lua_tonumber(Letat, 1), volume = lua.lua_tonumber(Letat, 2), duree = lua.lua_tonumber(Letat, 3);
  audio = audio || new AudioContext();
  const oscillateur = audio.createOscillator(), gain = audio.createGain();
  oscillateur.type = "square";
  oscillateur.frequency.value = frequence;
  gain.gain.setValueAtTime(0.15 * volume + 0.0001, audio.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + duree);
  oscillateur.connect(gain).connect(audio.destination);
  oscillateur.start();
  oscillateur.stop(audio.currentTime + duree);
  return 0;
}

// ------------------------------------------------------------------------------------------- Démarrage

function nombre(valeur) {
  return (Letat) => { lua.lua_pushnumber(Letat, valeur()); return 1; };
}

function creerOrdinateur(largeur, hauteur) {
  for (const [nom, source] of Object.entries(PROJET.modules)) {
    lua.lua_getglobal(LUA, to_luastring("package"));
    lua.lua_getfield(LUA, -1, to_luastring("preload"));
    if (lauxlib.luaL_loadbuffer(LUA, to_luastring(source), null, to_luastring("@" + nom)) !== lua.LUA_OK) {
      throw new Error(lisible(lua.lua_tostring(LUA, -1)));
    }
    lua.lua_setfield(LUA, -2, to_luastring(nom));
    lua.lua_settop(LUA, 0);
  }
  const fichiers = {};
  for (const [chemin, base64] of Object.entries(PROJET.fichiers)) fichiers[chemin] = depuisLatin1(atob(base64));
  const amorce = 'local ordinateur = require("outils.emulateur.ordinateur") ORDI = ordinateur.creer(...)';
  lauxlib.luaL_loadstring(LUA, to_luastring(amorce));
  pousser({
    hote: {
      maintenant: nombre(() => performance.now()),
      epoque: nombre(() => Date.now()),
      decalage_local: nombre(() => -new Date().getTimezoneOffset() * 60000),
      son,
    },
    fichiers,
    entree: PROJET.entree,
    moniteur: { nom: NOM_MONITEUR, largeur, hauteur },
  });
  if (lua.lua_pcall(LUA, 1, 0, 0) !== lua.LUA_OK) throw new Error(lisible(lua.lua_tostring(LUA, -1)));
  const sauvegarde = localStorage.getItem(CLE_DISQUE);
  if (sauvegarde) appeler("disque", "importer", depuisLatin1(sauvegarde));
}

// ------------------------------------------------------------------------------------------- Exécution

let reveil = null;

function planifier(delai) {
  if (reveil !== null) clearTimeout(reveil);
  reveil = delai < 0 ? null : setTimeout(tourner, delai);
}

// Incidents de la session (erreurs du programme et de l'émulateur), repris par le bouton Diagnostic.
const incidents = [];

function montrerErreur(titre, details) {
  incidents.push(new Date().toLocaleTimeString() + " " + titre + "\n" + details);
  $("erreurs").replaceChildren(alerte(titre + "\n" + details));
}

/** Texte à coller pour signaler un problème : navigateur, réglages, incidents et fichiers écrits par le programme. */
function diagnostic() {
  let fichiers;
  try {
    fichiers = lisible(appeler("disque", "resumer", LIGNES_DIAGNOSTIC)[0]);
  } catch (erreur) {
    fichiers = "illisibles : " + erreur.message;
  }
  return [
    "Projet : " + PROJET.entree + " (page générée le " + PROJET.genere + ")",
    "Navigateur : " + navigator.userAgent,
    "Taille : " + reglages.taille + ", zoom " + reglages.zoom,
    "État : " + $("etat").textContent,
    "Incidents (" + incidents.length + ") :",
    ...incidents.slice(-INCIDENTS_DIAGNOSTIC),
    "Fichiers écrits par le programme :",
    fichiers || "aucun",
  ].join("\n");
}

function tourner() {
  reveil = null;
  let resultat;
  try {
    resultat = appeler(null, "executer");
  } catch (erreur) {
    $("etat").textContent = PROJET.entree + " : émulateur planté.";
    montrerErreur("Erreur de l'émulateur", erreur.stack || String(erreur));
    return;
  }
  const [octetsEtat, delai, message, trace] = resultat;
  const etat = lisible(octetsEtat);
  const exporte = appeler("disque", "exporter")[0];
  if (exporte) {
    try {
      localStorage.setItem(CLE_DISQUE, versLatin1(exporte));
    } catch (erreur) {
      montrerErreur("Sauvegarde impossible dans ce navigateur", String(erreur));
    }
  }
  const textes = { attente: "Programme en cours.", fini: "Programme terminé.", arrete: "Ordinateur éteint.", erreur: "Programme planté." };
  $("etat").textContent = PROJET.entree + " : " + textes[etat] + (etat === "fini" && message ? " (" + lisible(message) + ")" : "");
  if (etat === "erreur") montrerErreur(lisible(message), lisible(trace));
  if (etat === "attente") planifier(delai);
}

function evenement(...args) {
  appeler(null, "evenement", ...args);
  planifier(0);
}

function relancer() {
  $("erreurs").replaceChildren();
  appeler(null, "demarrer");
  planifier(0);
}

// ------------------------------------------------------------------------------------------- Rendu

const ecrans = {
  moniteur: { canvas: $("moniteur"), version: -1, lignes: [] },
  terminal: { canvas: $("terminal"), version: -1, lignes: [] },
};

function zoom(canvas) {
  const choisi = Number(reglages.zoom);
  if (choisi > 0) return choisi;
  return Math.max(1, Math.min(4, Math.floor((window.innerWidth - 60) / canvas.width)));
}

const hexa = (octet) => (octet <= 57 ? octet - 48 : octet - 87);

function redessiner(nom, ecran) {
  const [largeur, hauteur] = appeler(nom, "getSize");
  const canvas = ecran.canvas;
  if (canvas.width !== largeur * L || canvas.height !== hauteur * H || !ecran.ctx) {
    canvas.width = largeur * L;
    canvas.height = hauteur * H;
    ecran.ctx = canvas.getContext("2d");
    preparerContexte(ecran.ctx);
    ecran.lignes = [];
  }
  const facteur = nom === "terminal" ? Math.min(2, zoom(ecrans.moniteur.canvas)) : zoom(canvas);
  canvas.style.width = canvas.width * facteur + "px";
  canvas.style.height = canvas.height * facteur + "px";
  const palette = versLatin1(appeler(nom, "palette_hexa")[0]);
  if (palette !== ecran.palette) {
    ecran.palette = palette;
    ecran.couleurs = Array.from({ length: 16 }, (_, i) => "#" + palette.substr(i * 6, 6));
    ecran.lignes = [];
  }
  for (let y = 1; y <= hauteur; y++) {
    const [texte, avant, fond] = appeler(nom, "ligne", y);
    const cle = versLatin1(texte) + versLatin1(avant) + versLatin1(fond);
    if (ecran.lignes[y] === cle) continue;
    ecran.lignes[y] = cle;
    for (let x = 0; x < largeur; x++) {
      dessinerCase(ecran.ctx, x, y - 1, texte[x], ecran.couleurs[hexa(avant[x])], ecran.couleurs[hexa(fond[x])]);
    }
  }
}

function peindre() {
  for (const [nom, ecran] of Object.entries(ecrans)) {
    const [version] = appeler(nom, "version");
    if (version !== ecran.version) {
      ecran.version = version;
      redessiner(nom, ecran);
    }
  }
  requestAnimationFrame(peindre);
}

function forcerRendu() {
  for (const ecran of Object.values(ecrans)) ecran.version = -1;
}

// ------------------------------------------------------------------------------------------- Commandes

function appliquerTaille(texte) {
  const [largeur, hauteur] = texte.split("x").map(Number);
  if (!(largeur >= 1 && hauteur >= 1)) return;
  reglages.taille = largeur + "x" + hauteur;
  enregistrerReglages();
  appeler(null, "redimensionner", largeur, hauteur);
  planifier(0);
}

function construireCommandes() {
  const choix = $("taille");
  if (![...choix.options].some((option) => option.value === reglages.taille)) choix.value = "libre";
  else choix.value = reglages.taille;
  [$("largeur").value, $("hauteur").value] = reglages.taille.split("x");
  $("libre").hidden = choix.value !== "libre";
  choix.addEventListener("change", () => {
    $("libre").hidden = choix.value !== "libre";
    if (choix.value !== "libre") appliquerTaille(choix.value);
  });
  $("appliquer").addEventListener("click", () => appliquerTaille($("largeur").value + "x" + $("hauteur").value));
  $("zoom").value = reglages.zoom;
  $("zoom").addEventListener("change", () => { reglages.zoom = $("zoom").value; enregistrerReglages(); forcerRendu(); });
  window.addEventListener("resize", forcerRendu);
  $("arreter").addEventListener("click", () => evenement("terminate"));
  $("relancer").addEventListener("click", relancer);
  $("reinitialiser").addEventListener("click", () => {
    localStorage.removeItem(CLE_DISQUE);
    location.reload();
  });
  $("diagnostiquer").addEventListener("click", () => {
    const zone = $("diagnostic");
    zone.value = diagnostic();
    zone.hidden = false;
    zone.select();
    if (navigator.clipboard) navigator.clipboard.writeText(zone.value).catch(() => {});
  });
  for (const ligne of lisible(appeler(null, "faux_peripheriques")[0]).split("\n").filter(Boolean)) {
    const [nom, type] = ligne.split(" ");
    const case_ = document.createElement("input");
    case_.type = "checkbox";
    case_.checked = reglages.branches[nom] === true;
    appeler(null, "brancher", nom, case_.checked);
    case_.addEventListener("change", () => {
      reglages.branches[nom] = case_.checked;
      enregistrerReglages();
      appeler(null, "brancher", nom, case_.checked);
      planifier(0);
    });
    const etiquette = document.createElement("label");
    etiquette.append(case_, " " + type + " (" + nom + ")");
    $("peripheriques").append(etiquette);
  }
}

function brancherSouris() {
  const moniteur = $("moniteur"), terminal = $("terminal");
  moniteur.addEventListener("mousedown", (e) => {
    appeler(null, "toucher", e.offsetX, e.offsetY, moniteur.clientWidth, moniteur.clientHeight);
    planifier(0);
  });
  for (const [nom, type] of [["mousedown", "mouse_click"], ["mouseup", "mouse_up"]]) {
    terminal.addEventListener(nom, (e) => {
      appeler(null, "souris", type, BOUTONS[e.button] || 1, e.offsetX, e.offsetY, terminal.clientWidth, terminal.clientHeight);
      planifier(0);
    });
  }
  for (const canvas of [moniteur, terminal]) canvas.addEventListener("contextmenu", (e) => e.preventDefault());
}

function nomTouche(code) {
  if (/^Key[A-Z]$/.test(code)) return code[3].toLowerCase();
  if (/^Digit\d$/.test(code)) return CHIFFRES[Number(code[5])];
  if (/^Numpad\d$/.test(code)) return "numPad" + code[6];
  if (/^F\d+$/.test(code)) return code.toLowerCase();
  return NOMS_TOUCHES[code];
}

function brancherClavier() {
  const ignorer = (e) => ["INPUT", "SELECT", "BUTTON"].includes(e.target.tagName);
  document.addEventListener("keydown", (e) => {
    if (ignorer(e)) return;
    const nom = nomTouche(e.code);
    const code = nom && appeler(null, "code_touche", nom)[0];
    if (code !== null && code !== undefined) {
      appeler(null, "evenement", "key", code, e.repeat);
      e.preventDefault();
    }
    const caractere = e.key.length === 1 ? e.key.charCodeAt(0) : -1;
    if (caractere >= 32 && caractere < 256 && !e.ctrlKey && !e.metaKey) appeler(null, "evenement", "char", new Uint8Array([caractere]));
    planifier(0);
  });
  document.addEventListener("keyup", (e) => {
    if (ignorer(e)) return;
    const nom = nomTouche(e.code);
    const code = nom && appeler(null, "code_touche", nom)[0];
    if (code !== null && code !== undefined) evenement("key_up", code);
  });
}

window.addEventListener("error", (e) => montrerErreur("Erreur de l'émulateur", String(e.message)));
window.addEventListener("unhandledrejection", (e) => montrerErreur("Erreur de l'émulateur", String(e.reason)));

chargerPolice($("avertissements"), () => {
  const [largeur, hauteur] = reglages.taille.split("x").map(Number);
  creerOrdinateur(largeur, hauteur);
  construireCommandes();
  brancherSouris();
  brancherClavier();
  appeler(null, "demarrer");
  planifier(0);
  requestAnimationFrame(peindre);
});
