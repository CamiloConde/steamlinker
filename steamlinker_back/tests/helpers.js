// Setup compartido de tests: fuerza DB_NAME=steamlinker_test antes de que
// cualquier otro modulo cargue ./src/db (dotenv no sobreescribe variables
// que ya existen en process.env, asi que basta con setearla aqui primero).
process.env.DB_NAME = 'steamlinker_test';
process.env.NODE_ENV = 'test';

const pool = require('../src/db');
const app = require('../src/app');

function usernameUnico(prefijo) {
    return `${prefijo}_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
}

async function limpiarUsuario(username) {
    await pool.query('DELETE FROM usuarios WHERE username_usu = $1', [username]);
}

module.exports = { app, pool, usernameUnico, limpiarUsuario };
