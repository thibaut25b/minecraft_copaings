// Lanceur des tests hors jeu : exécute les fichiers Lua du dépôt dans Fengari (Lua 5.3 en JavaScript).
// Usage : `npm test` (tout) ou `npm test -- colonie` (fichiers de test dont le chemin contient le mot).
'use strict';

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const RACINE = path.resolve(__dirname, '..');
const DOSSIERS_SOURCES = ['commun', 'projets', 'tests'];
const FICHIERS_SOURCES = ['install.lua'];

/** Liste récursive des fichiers `.lua` d'un dossier, en chemins relatifs à la racine (séparateur `/`). */
function fichiersLua(dossier) {
  const absolu = path.join(RACINE, dossier);
  if (!fs.existsSync(absolu)) return [];
  return fs.readdirSync(absolu, { withFileTypes: true }).flatMap((entree) => {
    const relatif = `${dossier}/${entree.name}`;
    if (entree.isDirectory()) return fichiersLua(relatif);
    return entree.name.endsWith('.lua') ? [relatif] : [];
  });
}

function nouvelEtat() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  return L;
}

/** Vérifie qu'un fichier se compile ; renvoie le message d'erreur ou null. */
function erreurDeSyntaxe(fichier) {
  const L = nouvelEtat();
  const statut = lauxlib.luaL_loadfile(L, to_luastring(fichier));
  return statut === lua.LUA_OK ? null : to_jsstring(lua.lua_tostring(L, -1));
}

// Chaque fichier de test tourne dans un état Lua neuf : aucun global ne fuit d'un fichier à l'autre.
const BANC = `
package.path = "./?.lua;./projets/?.lua;./tests/?.lua"
local fichier = ...
local cas = dofile(fichier)
assert(type(cas) == "table", fichier .. " doit renvoyer une table { nom = fonction }")
local noms = {}
for nom in pairs(cas) do noms[#noms + 1] = nom end
table.sort(noms)
local echecs = 0
for _, nom in ipairs(noms) do
  local ok, err = xpcall(cas[nom], debug.traceback)
  if not ok then
    echecs = echecs + 1
    print("ECHEC " .. fichier .. " : " .. nom .. "\\n" .. tostring(err))
  end
end
return #noms, echecs
`;

/** Expose à Lua la globale FICHIERS_DU_DEPOT (liste des .lua installables), Fengari ne sachant pas lister un dossier. */
function exposerFichiers(L, fichiers) {
  lua.lua_createtable(L, fichiers.length, 0);
  fichiers.forEach((fichier, index) => {
    lua.lua_pushstring(L, to_luastring(fichier));
    lua.lua_rawseti(L, -2, index + 1);
  });
  lua.lua_setglobal(L, to_luastring('FICHIERS_DU_DEPOT'));
}

function lancerFichier(fichier, installables) {
  const L = nouvelEtat();
  exposerFichiers(L, installables);
  if (lauxlib.luaL_loadstring(L, to_luastring(BANC)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  lua.lua_pushstring(L, to_luastring(fichier));
  if (lua.lua_pcall(L, 1, 2, 0) !== lua.LUA_OK) {
    console.log(`ECHEC ${fichier} : ${to_jsstring(lua.lua_tostring(L, -1))}`);
    return { total: 1, echecs: 1 };
  }
  return { total: lua.lua_tointeger(L, -2), echecs: lua.lua_tointeger(L, -1) };
}

process.chdir(RACINE);
const filtre = process.argv[2] || '';
let total = 0;
let echecs = 0;

const sources = [...DOSSIERS_SOURCES.flatMap(fichiersLua), ...FICHIERS_SOURCES.filter((f) => fs.existsSync(f))];
for (const fichier of sources) {
  const erreur = erreurDeSyntaxe(fichier);
  total += 1;
  if (erreur) {
    echecs += 1;
    console.log(`SYNTAXE ${erreur}`);
  }
}

const installables = [...fichiersLua('commun'), ...fichiersLua('projets')];
const tests = fichiersLua('tests').filter((f) => path.basename(f).startsWith('test_') && f.includes(filtre));
for (const fichier of tests) {
  const resultat = lancerFichier(fichier, installables);
  total += resultat.total;
  echecs += resultat.echecs;
}

console.log(`${total - echecs}/${total} verts (${sources.length} fichiers compilés, ${tests.length} fichiers de test)`);
process.exit(echecs === 0 ? 0 : 1);
