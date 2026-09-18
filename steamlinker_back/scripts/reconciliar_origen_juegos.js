// Corrige origen_usujg comparando contra la biblioteca REAL de Steam.
//
// La migracion 008 agrego la columna pero, en una version anterior, un
// backfill por SQL marco 'steam' a TODAS las filas de cualquier cuenta con
// Steam vinculado -- incluidos juegos agregados a mano antes de vincular.
// Este script corrige eso de verdad: para cada usuario con Steam vinculado,
// pide su biblioteca real a la API de Steam y ajusta origen_usujg segun si
// el appid esta ahi o no. Usuarios con perfil privado (la API falla) se
// dejan intactos -- no hay forma de saber su biblioteca real sin acceso.
//
// Ejecutar con: node scripts/reconciliar_origen_juegos.js

const pool = require('../src/db');
const steamService = require('../src/services/steamService');

async function main() {
    const { rows: vinculados } = await pool.query(
        `SELECT id_usu, steam_id, username_steperfil FROM perfiles_steam`
    );

    console.log(`Cuentas con Steam vinculado: ${vinculados.length}`);

    for (const { id_usu, steam_id, username_steperfil } of vinculados) {
        let juegosReales;
        try {
            juegosReales = await steamService.getOwnedGames(steam_id);
        } catch (err) {
            console.log(`- ${username_steperfil} (id_usu=${id_usu}): omitido, ${err.message}`);
            continue;
        }

        const appidsReales = new Set(juegosReales.map((j) => j.appid));

        const { rows: actuales } = await pool.query(
            `SELECT appid, origen_usujg FROM usuarios_juegos WHERE id_usu = $1`,
            [id_usu]
        );

        let corregidosASteam = 0;
        let corregidosAManual = 0;

        for (const { appid, origen_usujg } of actuales) {
            const esReal = appidsReales.has(appid);
            const origenCorrecto = esReal ? 'steam' : 'manual';
            if (origen_usujg !== origenCorrecto) {
                await pool.query(
                    `UPDATE usuarios_juegos SET origen_usujg = $1 WHERE id_usu = $2 AND appid = $3`,
                    [origenCorrecto, id_usu, appid]
                );
                if (origenCorrecto === 'steam') corregidosASteam++;
                else corregidosAManual++;
            }
        }

        console.log(
            `- ${username_steperfil} (id_usu=${id_usu}): ${actuales.length} juegos, ` +
            `${appidsReales.size} reales en Steam, ` +
            `${corregidosASteam} corregidos a 'steam', ${corregidosAManual} corregidos a 'manual'`
        );
    }

    await pool.end();
    console.log('Listo.');
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
