// Émulateur navigateur : écrit apercu/jouer-<projet>.html, page autonome où le vrai programme du projet tourne
// sur un moniteur tactile émulé (Fengari, fichiers du manifeste, police de CC tout embarqués).
// Usage : `npm run jouer -- <projet>` ; CC_JAR remplace le jar de CC: Tweaked.
'use strict';

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const { chargerPolice, uriPolice, RENDU_CASES } = require('./police');

const RACINE = path.resolve(__dirname, '..');
const DOSSIER_SORTIE = path.join(RACINE, 'apercu');
const FENGARI_WEB = path.join(RACINE, 'node_modules', 'fengari-web', 'dist', 'fengari-web.js');
const MODULES_LUA = {
  'outils.moniteur_enregistreur': 'outils/moniteur_enregistreur.lua',
  'outils.emulateur.bibliotheques': 'outils/emulateur/bibliotheques.lua',
  'outils.emulateur.disque': 'outils/emulateur/disque.lua',
  'outils.emulateur.peripheriques': 'outils/emulateur/peripheriques.lua',
  'outils.emulateur.ordinateur': 'outils/emulateur/ordinateur.lua',
};

// Lit le manifeste comme install.lua (environnement vide) ; renvoie une ligne « entree » puis une par fichier.
const LECTEUR_MANIFESTE = String.raw`
local source = ...
local fonction, erreur = load(source, "manifeste", "t", {})
if not fonction then error(erreur, 0) end
local manifeste = fonction()
if type(manifeste) ~= "table" or type(manifeste.entree) ~= "string" or type(manifeste.fichiers) ~= "table" then
  error("manifeste illisible", 0)
end
local lignes = { manifeste.entree }
for _, fichier in ipairs(manifeste.fichiers) do lignes[#lignes + 1] = fichier.depot .. "\t" .. fichier.ordinateur end
return table.concat(lignes, "\n")
`;

function lireManifeste(projet) {
  const chemin = path.join(RACINE, 'projets', projet, 'manifeste.lua');
  if (!/^[\w-]+$/.test(projet) || !fs.existsSync(chemin)) throw new Error(`Projet sans manifeste : ${projet}`);
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lauxlib.luaL_loadstring(L, to_luastring(LECTEUR_MANIFESTE));
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(chemin, 'utf8')));
  if (lua.lua_pcall(L, 1, 1, 0) !== lua.LUA_OK) throw new Error(`${chemin} : ${to_jsstring(lua.lua_tostring(L, -1))}`);
  const [entree, ...fichiers] = to_jsstring(lua.lua_tostring(L, -1)).split('\n');
  return { entree: `/${entree}`, fichiers: fichiers.map((ligne) => ligne.split('\t')) };
}

function main() {
  const projet = process.argv[2];
  if (!projet) throw new Error('Usage : npm run jouer -- <projet>');
  const manifeste = lireManifeste(projet);
  const fichiers = {};
  for (const [depot, ordinateur] of manifeste.fichiers) {
    fichiers[`/${ordinateur}`] = fs.readFileSync(path.join(RACINE, depot)).toString('base64');
  }
  const modules = {};
  for (const [nom, chemin] of Object.entries(MODULES_LUA)) modules[nom] = fs.readFileSync(path.join(RACINE, chemin), 'utf8');
  const donnees = JSON.stringify({ nom: projet, entree: manifeste.entree, genere: new Date().toISOString(), fichiers, modules }).replace(/</g, '\\u003c');
  const page = fs.readFileSync(path.join(__dirname, 'emulateur', 'page.html'), 'utf8')
    .replace(/__TITRE__/g, () => `Jouer : ${projet}`)
    .replace('__FENGARI__', () => fs.readFileSync(FENGARI_WEB, 'utf8'))
    .replace('__POLICE__', () => JSON.stringify(uriPolice(chargerPolice())))
    .replace('__PROJET__', () => donnees)
    .replace('__RENDU_CASES__', () => RENDU_CASES)
    .replace('__HOTE__', () => fs.readFileSync(path.join(__dirname, 'emulateur', 'hote.js'), 'utf8'));
  fs.mkdirSync(DOSSIER_SORTIE, { recursive: true });
  const sortie = path.join(DOSSIER_SORTIE, `jouer-${projet}.html`);
  fs.writeFileSync(sortie, page);
  console.log(`apercu/jouer-${projet}.html écrit (${manifeste.fichiers.length} fichiers, ${Math.round(page.length / 1024)} Kio)`);
}

main();
