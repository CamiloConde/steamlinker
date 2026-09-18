const express = require('express');
const pool = require('../db');
const { verificarToken } = require('./auth');

const router = express.Router();

function isAdminTipo(tipo) {
    return String(tipo || '').toLowerCase() === 'admin';
}

function requireAdmin(req, res, next) {
    if (!req.usuario || !isAdminTipo(req.usuario.tipo)) {
        return res.status(403).json({ error: 'Acceso denegado. Se requiere cuenta administrador.' });
    }
    next();
}

// GET /api/admin/estadisticas
router.get('/estadisticas', verificarToken, requireAdmin, async (req, res) => {
    try {
        const [
            usuarios,
            publicaciones,
            reportesTotal,
            reportesPendientes,
            familiasAceptadas,
            solicitudesPendientes,
            usuariosBaneados,
            usuariosSteam,
            juegosVinculados,
            totalChats,
            totalAmistades,
            totalCalificaciones,
            usuariosNuevos7d,
            publicacionesCerradas,
        ] = await Promise.all([
            pool.query('SELECT COUNT(*)::int AS n FROM usuarios'),
            pool.query('SELECT COUNT(*)::int AS n FROM publicaciones'),
            pool.query('SELECT COUNT(*)::int AS n FROM reportes'),
            pool.query(
                `SELECT COUNT(*)::int AS n FROM reportes
                 WHERE LOWER(estado_repor) IN ('pendiente', 'abierto')`
            ),
            pool.query(
                `SELECT COUNT(*)::int AS n FROM matches WHERE estado_match = 'Aceptada'`
            ),
            pool.query(
                `SELECT COUNT(*)::int AS n FROM matches WHERE estado_match = 'Pendiente'`
            ),
            pool.query(
                'SELECT COUNT(*)::int AS n FROM usuarios WHERE COALESCE(baneado_usu, FALSE) = TRUE'
            ),
            pool.query('SELECT COUNT(*)::int AS n FROM perfiles_steam'),
            pool.query('SELECT COUNT(*)::int AS n FROM usuarios_juegos'),
            pool.query('SELECT COUNT(*)::int AS n FROM chat'),
            pool.query(
                `SELECT COUNT(*)::int AS n FROM amistad WHERE estado_amistad = 'Aceptada'`
            ),
            pool.query('SELECT COUNT(*)::int AS n FROM calificaciones'),
            pool.query(
                `SELECT COUNT(*)::int AS n FROM usuarios
                 WHERE creadoen_usu >= NOW() - INTERVAL '7 days'`
            ),
            pool.query(
                'SELECT COUNT(*)::int AS n FROM publicaciones WHERE estado_publi = FALSE'
            ),
        ]);

        res.json({
            totalUsuarios: usuarios.rows[0].n,
            totalPublicaciones: publicaciones.rows[0].n,
            totalReportes: reportesTotal.rows[0].n,
            reportesPendientes: reportesPendientes.rows[0].n,
            familiasFormadas: familiasAceptadas.rows[0].n,
            solicitudesPendientes: solicitudesPendientes.rows[0].n,
            usuariosBaneados: usuariosBaneados.rows[0].n,
            usuariosConSteam: usuariosSteam.rows[0].n,
            juegosEnBibliotecas: juegosVinculados.rows[0].n,
            totalChats: totalChats.rows[0].n,
            totalAmistades: totalAmistades.rows[0].n,
            totalCalificaciones: totalCalificaciones.rows[0].n,
            usuariosNuevos7d: usuariosNuevos7d.rows[0].n,
            publicacionesCerradas: publicacionesCerradas.rows[0].n,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/actividad — eventos recientes para el dashboard
router.get('/actividad', verificarToken, requireAdmin, async (req, res) => {
    try {
        const limite = Math.min(parseInt(req.query.limit, 10) || 20, 50);
        const resultado = await pool.query(
            `
            (
                SELECT 'usuario' AS tipo, u.id_usu AS ref_id,
                       u.username_usu AS titulo,
                       'Nuevo registro' AS detalle,
                       u.creadoen_usu AS fecha
                FROM usuarios u
                ORDER BY u.creadoen_usu DESC
                LIMIT $1
            )
            UNION ALL
            (
                SELECT 'reporte', r.id_repor,
                       u2.username_usu,
                       LEFT(COALESCE(r.motivo_repor, ''), 80),
                       r.creadoen_repor
                FROM reportes r
                JOIN usuarios u2 ON r.id_reportado = u2.id_usu
                ORDER BY r.creadoen_repor DESC
                LIMIT $1
            )
            UNION ALL
            (
                SELECT 'publicacion', p.id_publi,
                       u3.username_usu,
                       LEFT(COALESCE(p.titulo_publi, ''), 80),
                       p.creadoen_publi
                FROM publicaciones p
                JOIN usuarios u3 ON p.id_usu = u3.id_usu
                ORDER BY p.creadoen_publi DESC
                LIMIT $1
            )
            UNION ALL
            (
                SELECT 'match', m.id_match,
                       u4.username_usu,
                       m.estado_match::text,
                       m.creadoen_match
                FROM matches m
                JOIN usuarios u4 ON m.id_solicitante = u4.id_usu
                ORDER BY m.creadoen_match DESC
                LIMIT $1
            )
            ORDER BY fecha DESC
            LIMIT $2
            `,
            [limite, limite]
        );
        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/usuarios/:id — detalle de cuenta
router.get('/usuarios/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    try {
        const usuario = await pool.query(
            `
            SELECT
                u.id_usu, u.username_usu, u.email_usu, u.pais_usu, u.tipo_usu,
                u.descrip_usu, u.repu_usu, u.totalrating_usu, u.creadoen_usu,
                COALESCE(u.baneado_usu, FALSE) AS baneado_usu,
                u.motivo_ban, u.fechaban_usu,
                ps.steam_id, ps.username_steperfil, ps.perfil_url,
                (SELECT COUNT(*)::int FROM publicaciones p WHERE p.id_usu = u.id_usu) AS publicaciones,
                (SELECT COUNT(*)::int FROM usuarios_juegos uj WHERE uj.id_usu = u.id_usu) AS juegos,
                (SELECT COUNT(*)::int FROM reportes r WHERE r.id_reportado = u.id_usu) AS reportes_recibidos,
                (SELECT COUNT(*)::int FROM reportes r2 WHERE r2.id_reportador = u.id_usu) AS reportes_enviados
            FROM usuarios u
            LEFT JOIN perfiles_steam ps ON ps.id_usu = u.id_usu
            WHERE u.id_usu = $1
            `,
            [id]
        );

        if (usuario.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        res.json(usuario.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/usuarios/:id — cambiar rol o reputación
router.put('/usuarios/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const { tipo, repu } = req.body;

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    if (id === req.usuario.id && tipo && String(tipo).toLowerCase() !== 'admin') {
        return res.status(400).json({ error: 'No puedes quitarte el rol de administrador a ti mismo' });
    }

    try {
        const actual = await pool.query(
            'SELECT id_usu, tipo_usu FROM usuarios WHERE id_usu = $1',
            [id]
        );
        if (actual.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const campos = [];
        const valores = [];
        let idx = 1;

        if (tipo !== undefined) {
            const t = String(tipo).toLowerCase();
            if (!['admin', 'usuario'].includes(t)) {
                return res.status(400).json({ error: 'tipo debe ser admin o usuario' });
            }
            campos.push(`tipo_usu = $${idx++}`);
            valores.push(t);
        }

        if (repu !== undefined) {
            const r = Number(repu);
            if (Number.isNaN(r) || r < 0) {
                return res.status(400).json({ error: 'repu inválida' });
            }
            campos.push(`repu_usu = $${idx++}`);
            valores.push(r);
        }

        if (campos.length === 0) {
            return res.status(400).json({ error: 'Nada que actualizar' });
        }

        valores.push(id);
        const resultado = await pool.query(
            `UPDATE usuarios SET ${campos.join(', ')} WHERE id_usu = $${idx} RETURNING id_usu, username_usu, tipo_usu, repu_usu`,
            valores
        );

        res.json({ mensaje: 'Usuario actualizado', usuario: resultado.rows[0] });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /api/admin/usuarios/:id
router.delete('/usuarios/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    if (id === req.usuario.id) {
        return res.status(400).json({ error: 'No puedes eliminar tu propia cuenta desde el panel' });
    }

    try {
        const target = await pool.query(
            'SELECT id_usu, tipo_usu, username_usu FROM usuarios WHERE id_usu = $1',
            [id]
        );
        if (target.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        if (isAdminTipo(target.rows[0].tipo_usu)) {
            return res.status(403).json({ error: 'No se puede eliminar a otro administrador' });
        }

        await pool.query('DELETE FROM usuarios_juegos WHERE id_usu = $1', [id]);
        await pool.query('DELETE FROM perfiles_steam WHERE id_usu = $1', [id]);
        await pool.query('DELETE FROM usuarios WHERE id_usu = $1', [id]);

        res.json({
            mensaje: 'Usuario eliminado',
            usuario: { id_usu: id, username_usu: target.rows[0].username_usu },
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/usuarios
router.get('/usuarios', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                u.id_usu,
                u.username_usu,
                u.email_usu,
                u.pais_usu,
                u.tipo_usu,
                u.repu_usu,
                u.totalrating_usu,
                u.creadoen_usu,
                COALESCE(u.baneado_usu, FALSE) AS baneado_usu,
                u.motivo_ban,
                u.fechaban_usu,
                ps.steam_id,
                (
                    SELECT COUNT(*)::int FROM matches m
                    WHERE m.estado_match = 'Aceptada'
                      AND (m.id_solicitante = u.id_usu OR m.id_receptor = u.id_usu)
                ) AS familias_aceptadas,
                (
                    SELECT COUNT(*)::int FROM publicaciones p WHERE p.id_usu = u.id_usu
                ) AS total_publicaciones
            FROM usuarios u
            LEFT JOIN perfiles_steam ps ON ps.id_usu = u.id_usu
            ORDER BY u.id_usu DESC
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/usuarios/:id/ban
router.post('/usuarios/:id/ban', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const motivo = (req.body.motivo || req.body.reason || 'Incumplimiento de normas').trim();

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    if (id === req.usuario.id) {
        return res.status(400).json({ error: 'No puedes banearte a ti mismo' });
    }

    try {
        const target = await pool.query(
            'SELECT id_usu, tipo_usu FROM usuarios WHERE id_usu = $1',
            [id]
        );
        if (target.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        if (isAdminTipo(target.rows[0].tipo_usu)) {
            return res.status(403).json({ error: 'No se puede banear a otro administrador' });
        }

        const resultado = await pool.query(
            `UPDATE usuarios
             SET baneado_usu = TRUE,
                 motivo_ban = $1,
                 fechaban_usu = NOW()
             WHERE id_usu = $2
             RETURNING id_usu, username_usu, baneado_usu, motivo_ban, fechaban_usu`,
            [motivo, id]
        );

        // Revoca las sesiones activas -- si no, el usuario baneado sigue
        // pudiendo refrescar su token y seguir usando la cuenta hasta que
        // su access token expire solo (hasta 1h). El access token en sí
        // ya emitido no se puede invalidar sin estado, pero esto corta
        // cualquier renovación.
        await pool.query(
            'UPDATE sesiones SET revocadaen_sesion = NOW() WHERE id_usu = $1 AND revocadaen_sesion IS NULL',
            [id]
        );

        res.json({ mensaje: 'Usuario baneado', usuario: resultado.rows[0] });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/usuarios/:id/unban
router.post('/usuarios/:id/unban', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    try {
        const resultado = await pool.query(
            `UPDATE usuarios
             SET baneado_usu = FALSE,
                 motivo_ban = NULL,
                 fechaban_usu = NULL
             WHERE id_usu = $1
             RETURNING id_usu, username_usu, baneado_usu`,
            [id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        res.json({ mensaje: 'Usuario desbaneado', usuario: resultado.rows[0] });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/familias — matches (familias formadas / en proceso)
router.get('/familias', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                m.id_match,
                u1.username_usu AS solicitante,
                u2.username_usu AS receptor,
                m.estado_match,
                m.creadoen_match,
                p.titulo_publi
            FROM matches m
            JOIN usuarios u1 ON m.id_solicitante = u1.id_usu
            JOIN usuarios u2 ON m.id_receptor = u2.id_usu
            LEFT JOIN publicaciones p ON m.id_publi = p.id_publi
            ORDER BY m.id_match DESC
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/solicitudes — matches pendientes con nombres
router.get('/solicitudes', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                m.id_match,
                u1.username_usu AS solicitante,
                u2.username_usu AS receptor,
                m.estado_match,
                m.creadoen_match,
                p.titulo_publi
            FROM matches m
            JOIN usuarios u1 ON m.id_solicitante = u1.id_usu
            JOIN usuarios u2 ON m.id_receptor = u2.id_usu
            LEFT JOIN publicaciones p ON m.id_publi = p.id_publi
            WHERE m.estado_match = 'Pendiente'
            ORDER BY m.creadoen_match DESC
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/reportes
router.get('/reportes', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                r.id_repor,
                r.id_reportador,
                r.id_reportado,
                u1.username_usu AS reportador,
                u2.username_usu AS reportado,
                r.motivo_repor,
                r.estado_repor,
                r.creadoen_repor
            FROM reportes r
            JOIN usuarios u1 ON r.id_reportador = u1.id_usu
            JOIN usuarios u2 ON r.id_reportado = u2.id_usu
            ORDER BY r.id_repor DESC
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/reportes/:id
router.put('/reportes/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    let { estado } = req.body;

    if (!estado) {
        return res.status(400).json({ error: 'estado es obligatorio' });
    }

    const mapa = {
        resuelto: 'Resuelto',
        resuelta: 'Resuelto',
        descartado: 'Descartado',
        descartada: 'Descartado',
        pendiente: 'Pendiente',
        abierto: 'Pendiente',
    };
    estado = mapa[String(estado).toLowerCase()] || estado;

    try {
        const resultado = await pool.query(
            `UPDATE reportes SET estado_repor = $1 WHERE id_repor = $2 RETURNING *`,
            [estado, id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Reporte no encontrado' });
        }

        res.json(resultado.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/contenido
router.get('/contenido', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                p.id_publi,
                p.titulo_publi,
                p.tipo_publi,
                p.estado_publi,
                p.creadoen_publi,
                u.username_usu
            FROM publicaciones p
            JOIN usuarios u ON p.id_usu = u.id_usu
            ORDER BY p.id_publi DESC
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /api/admin/contenido/:id
router.delete('/contenido/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    try {
        const resultado = await pool.query(
            'DELETE FROM publicaciones WHERE id_publi = $1 RETURNING id_publi, titulo_publi',
            [id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Publicación no encontrada' });
        }

        res.json({ mensaje: 'Publicación eliminada', publicacion: resultado.rows[0] });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/chats
router.get('/chats', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                c.id_chat,
                u1.username_usu AS usuario_a,
                u2.username_usu AS usuario_b,
                (
                    SELECT mensaje_chat FROM mensaje
                    WHERE id_chat = c.id_chat
                    ORDER BY creadoen_mensaje DESC
                    LIMIT 1
                ) AS ultimo_mensaje,
                (
                    SELECT creadoen_mensaje FROM mensaje
                    WHERE id_chat = c.id_chat
                    ORDER BY creadoen_mensaje DESC
                    LIMIT 1
                ) AS ultima_actividad,
                (
                    SELECT COUNT(*)::int FROM mensaje m WHERE m.id_chat = c.id_chat
                ) AS total_mensajes
            FROM chat c
            JOIN usuarios u1 ON c.id_participante1 = u1.id_usu
            JOIN usuarios u2 ON c.id_participante2 = u2.id_usu
            ORDER BY ultima_actividad DESC NULLS LAST
            LIMIT 200
        `);

        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/reportes/:id/ban-reportado — banear al usuario reportado
router.post('/reportes/:id/ban-reportado', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }

    try {
        const reporte = await pool.query(
            `SELECT r.id_repor, r.id_reportado, r.motivo_repor, u.tipo_usu, u.username_usu
             FROM reportes r
             JOIN usuarios u ON r.id_reportado = u.id_usu
             WHERE r.id_repor = $1`,
            [id]
        );

        if (reporte.rows.length === 0) {
            return res.status(404).json({ error: 'Reporte no encontrado' });
        }

        const row = reporte.rows[0];
        if (isAdminTipo(row.tipo_usu)) {
            return res.status(403).json({ error: 'No se puede banear a un administrador' });
        }

        const motivo =
            (req.body.motivo || '').trim() ||
            `Baneado tras reporte #${id}: ${row.motivo_repor || 'Incumplimiento de normas'}`;

        await pool.query(
            `UPDATE usuarios
             SET baneado_usu = TRUE, motivo_ban = $1, fechaban_usu = NOW()
             WHERE id_usu = $2`,
            [motivo.slice(0, 500), row.id_reportado]
        );

        await pool.query(
            'UPDATE sesiones SET revocadaen_sesion = NOW() WHERE id_usu = $1 AND revocadaen_sesion IS NULL',
            [row.id_reportado]
        );

        await pool.query(
            `UPDATE reportes SET estado_repor = 'Resuelto' WHERE id_repor = $1`,
            [id]
        );

        res.json({
            mensaje: `Usuario ${row.username_usu} baneado y reporte resuelto`,
            id_reportado: row.id_reportado,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/contenido/:id — cerrar o reabrir publicación
router.put('/contenido/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    let activo = req.body.estado_publi;

    if (activo === undefined && req.body.estado !== undefined) {
        const e = String(req.body.estado).toLowerCase();
        activo = e === 'aprobado' || e === 'activa' || e === 'activo' || e === 'true';
    }

    if (typeof activo !== 'boolean') {
        return res.status(400).json({ error: 'estado_publi (boolean) o estado es obligatorio' });
    }

    try {
        const resultado = await pool.query(
            `UPDATE publicaciones SET estado_publi = $1 WHERE id_publi = $2 RETURNING *`,
            [activo, id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Publicación no encontrada' });
        }

        res.json(resultado.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/admin/mensajes-contacto
// Mensajes del formulario de contacto (Nivel 2 del roadmap). Sin UI propia
// en el panel todavía — expuesto para no dejar los mensajes atrapados solo
// en la base de datos mientras se construye esa pantalla.
router.get('/mensajes-contacto', verificarToken, requireAdmin, async (req, res) => {
    try {
        const resultado = await pool.query(`
            SELECT
                id_mensajecontacto,
                id_usu,
                nombre_mensajecontacto,
                email_mensajecontacto,
                tipo_mensajecontacto,
                cuerpo_mensajecontacto,
                leido_mensajecontacto,
                creadoen_mensajecontacto
            FROM mensajes_contacto
            ORDER BY leido_mensajecontacto ASC, creadoen_mensajecontacto DESC
        `);
        res.json(resultado.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/mensajes-contacto/:id
router.put('/mensajes-contacto/:id', verificarToken, requireAdmin, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
        return res.status(400).json({ error: 'id inválido' });
    }
    try {
        const resultado = await pool.query(
            `UPDATE mensajes_contacto SET leido_mensajecontacto = $1 WHERE id_mensajecontacto = $2 RETURNING *`,
            [req.body.leido !== false, id]
        );
        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Mensaje no encontrado' });
        }
        res.json(resultado.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
