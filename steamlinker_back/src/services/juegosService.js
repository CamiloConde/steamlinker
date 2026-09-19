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

module.exports = { guardarJuego };
