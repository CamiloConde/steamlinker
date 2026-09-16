// Chequeo de verificacion Steam, usado para gatear acciones de Familia
// (compartir biblioteca es de alto riesgo si el usuario no es quien dice ser).
// Companeros NO usa este gateo: ver HANDOFF.md seccion 5.

const pool = require('../db');

const TIPOS_REQUIEREN_STEAM = ['busco_familia', 'busco_miembros'];

async function tieneSteamVinculado(idUsuario) {
    const resultado = await pool.query(
        'SELECT 1 FROM perfiles_steam WHERE id_usu = $1',
        [idUsuario]
    );
    return resultado.rows.length > 0;
}

module.exports = { tieneSteamVinculado, TIPOS_REQUIEREN_STEAM };
