const express = require('express');
const pool = require('../db');
const { verificarToken } = require('./auth');
const { crearNotificacion, usernameDe } = require('../services/notificacionesService');

const router = express.Router();

// POST /amistad/enviar
// Envia una solicitud de amistad
router.post('/enviar', verificarToken, async (req, res) => {
    const id_receptor = parseInt(req.body.id_receptor, 10);

    if (!id_receptor || Number.isNaN(id_receptor)) {
        return res.status(400).json({ error: 'id_receptor es obligatorio' });
    }

    if (id_receptor === req.usuario.id) {
        return res.status(400).json({ error: 'No puedes enviarte una solicitud a ti mismo' });
    }

    try {
        // Solo bloquea si ya hay una solicitud pendiente o ya son amigos --
        // una rechazada NO debe bloquear para siempre (antes sí lo hacía,
        // bug real: rechazar a alguien lo dejaba imposibilitado de volver
        // a pedir amistad, sin importar cuánto tiempo pasara). Mismo
        // criterio que ya usa matches.js para solicitudes de match.
        const existe = await pool.query(
            `SELECT id_amistad FROM amistad
             WHERE ((id_solicitante = $1 AND id_receptor = $2)
                OR (id_solicitante = $2 AND id_receptor = $1))
             AND estado_amistad IN ('Pendiente', 'Aceptada')`,
            [req.usuario.id, id_receptor]
        );

        if (existe.rows.length > 0) {
            return res.status(409).json({ error: 'Ya existe una solicitud entre estos usuarios' });
        }

        const resultado = await pool.query(
            `INSERT INTO amistad (id_solicitante, id_receptor)
             VALUES ($1, $2) RETURNING *`,
            [req.usuario.id, id_receptor]
        );

        const solicitud = resultado.rows[0];
        try {
            const solicitante = await usernameDe(req.usuario.id);
            await crearNotificacion({
                idUsuario: id_receptor,
                tipo: 'friend',
                titulo: 'Nueva solicitud de amistad',
                cuerpo: `${solicitante} quiere ser tu amigo.`,
                refTipo: 'amistad',
                refId: solicitud.id_amistad,
                avatar: solicitante[0]?.toUpperCase() || 'A',
            });
        } catch (_) { /* ignore */ }

        res.status(201).json(solicitud);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /amistad/solicitudes
// Lista las solicitudes de amistad recibidas pendientes
router.get('/solicitudes', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT a.*, u.username_usu AS solicitante_username, u.repu_usu
             FROM amistad a
             JOIN usuarios u ON a.id_solicitante = u.id_usu
             WHERE a.id_receptor = $1 AND a.estado_amistad = 'Pendiente'
             ORDER BY a.creadoen_amistad DESC`,
            [req.usuario.id]
        );

        res.json({ solicitudes: resultado.rows, total: resultado.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /amistad/amigos
// Lista todos los amigos del usuario logueado
router.get('/amigos', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT a.*,
                    CASE 
                        WHEN a.id_solicitante = $1 THEN u2.username_usu
                        ELSE u1.username_usu
                    END AS amigo_username,
                    CASE 
                        WHEN a.id_solicitante = $1 THEN u2.id_usu
                        ELSE u1.id_usu
                    END AS amigo_id,
                    CASE 
                        WHEN a.id_solicitante = $1 THEN u2.repu_usu
                        ELSE u1.repu_usu
                    END AS amigo_reputacion
             FROM amistad a
             JOIN usuarios u1 ON a.id_solicitante = u1.id_usu
             JOIN usuarios u2 ON a.id_receptor = u2.id_usu
             WHERE (a.id_solicitante = $1 OR a.id_receptor = $1)
             AND a.estado_amistad = 'Aceptada'
             ORDER BY a.creadoen_amistad DESC`,
            [req.usuario.id]
        );

        res.json({ amigos: resultado.rows, total: resultado.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /amistad/:id/responder
// Acepta o rechaza una solicitud de amistad
router.put('/:id/responder', verificarToken, async (req, res) => {
    const { estado } = req.body;

    if (!estado || !['Aceptada', 'Rechazada'].includes(estado)) {
        return res.status(400).json({ error: 'estado debe ser Aceptada o Rechazada' });
    }

    try {
        const resultado = await pool.query(
            `UPDATE amistad SET estado_amistad = $1
             WHERE id_amistad = $2 AND id_receptor = $3
             RETURNING *`,
            [estado, req.params.id, req.usuario.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Solicitud no encontrada o no eres el receptor' });
        }

        const solicitud = resultado.rows[0];

        if (estado === 'Aceptada') {
            try {
                const receptor = await usernameDe(req.usuario.id);
                await crearNotificacion({
                    idUsuario: solicitud.id_solicitante,
                    tipo: 'friend_aceptado',
                    titulo: 'Solicitud de amistad aceptada',
                    cuerpo: `${receptor} aceptó tu solicitud de amistad.`,
                    refTipo: 'amistad',
                    refId: solicitud.id_amistad,
                    avatar: receptor[0]?.toUpperCase() || 'A',
                });
            } catch (_) { /* ignore */ }
        }

        res.json(solicitud);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
