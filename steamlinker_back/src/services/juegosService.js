// Punto único para guardar un juego en la tabla `juegos` -- antes cada
// ruta (crear publicación, editar publicación, agregar juego a perfil,
// importar biblioteca) repetía el mismo INSERT ... ON CONFLICT DO NOTHING
// por su cuenta. Centralizado acá para poder enriquecer con géneros de la
// Steam Store API en un solo lugar (ver HANDOFF.md, tags de género).

const pool = require("../db");
const { obtenerGeneros } = require("./steamService");

/**
 * Guarda un juego si no existe todavía. Si es la primera vez que se ve
 * este appid, dispara en segundo plano (sin esperar) una consulta a la
 * Steam Store API para traer sus géneros -- no bloquea la acción real del
 * usuario (crear publicación, agregar juego) ni la revienta si Steam
 * falla o tarda. Juegos ya existentes no se vuelven a consultar.
 * @param {{appid: number, nombre: string, headerimg?: string, capsuleimg?: string}} juego
 */
async function guardarJuego({ appid, nombre, headerimg, capsuleimg }) {
  const resultado = await pool.query(
    `INSERT INTO juegos (appid, nom_jg, headerimg_jg, capsuleimg_jg)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (appid) DO NOTHING
     RETURNING appid`,
    [appid, nombre, headerimg || null, capsuleimg || null]
  );

  if (resultado.rows.length > 0) {
    obtenerGeneros(appid)
      .then((generos) => {
        if (generos && generos.length > 0) {
          return pool.query(`UPDATE juegos SET generos_jg = $1 WHERE appid = $2`, [generos, appid]);
        }
      })
      .catch(() => {});
  }
}

/**
 * Origen real de un juego en la biblioteca del usuario ('steam' si Steam
 * lo confirma, 'manual' si lo agregó a mano o no está en su biblioteca
 * en absoluto). Se consulta acá -- no se confía en lo que mande el
 * cliente -- para que un usuario no pueda marcar como "verificado" un
 * juego que no es. Fuente de verdad real: `usuarios_juegos.origen_usujg`.
 * @param {number} idUsu
 * @param {number} appid
 * @returns {Promise<'steam'|'manual'>}
 */
async function obtenerOrigenJuego(idUsu, appid) {
  const resultado = await pool.query(
    `SELECT origen_usujg FROM usuarios_juegos WHERE id_usu = $1 AND appid = $2`,
    [idUsu, appid]
  );
  return resultado.rows[0]?.origen_usujg === "steam" ? "steam" : "manual";
}

module.exports = { guardarJuego, obtenerOrigenJuego };
