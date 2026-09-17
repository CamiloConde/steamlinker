// Rutas del sistema de chat
// Maneja conversaciones y mensajes entre usuarios

const express = require('express');
const pool = require('../db');
const { verificarToken } = require('./auth');
const { crearNotificacion, usernameDe } = require('../services/notificacionesService');

const router = express.Router();

// GET /chat/conversaciones
// Lista todas las conversaciones del usuario logueado. Incluye el contexto
// del match aceptado mas reciente entre los dos participantes (tipo, juego,
// cupos) para la franja "Match por: X" del chat flotante y de la pantalla
// de conversacion — sin eso, todas las conversaciones se ven identicas.
router.get('/conversaciones', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT c.*,
                    u1.username_usu AS username_participante1,
                    u2.username_usu AS username_participante2,
                    CASE
                        WHEN c.id_participante1 = $1 THEN u2.id_usu
                        ELSE u1.id_usu
                    END AS otro_id,
                    CASE
                        WHEN c.id_participante1 = $1 THEN u2.username_usu
                        ELSE u1.username_usu
                    END AS otro_username,
                    (SELECT mensaje_chat FROM mensaje
                     WHERE id_chat = c.id_chat
                     ORDER BY creadoen_mensaje DESC LIMIT 1) AS ultimo_mensaje,
                    (SELECT creadoen_mensaje FROM mensaje
                     WHERE id_chat = c.id_chat
                     ORDER BY creadoen_mensaje DESC LIMIT 1) AS fecha_ultimo_mensaje,
                    mctx.tipo_publi AS match_tipo_publi,
                    mctx.titulo_publi AS match_titulo_publi,
                    mctx.cupos_totales AS match_cupos_totales,
                    mctx.cupos_ocupados AS match_cupos_ocupados,
                    mctx.juego_nombre AS match_juego_nombre
             FROM chat c
             JOIN usuarios u1 ON c.id_participante1 = u1.id_usu
             JOIN usuarios u2 ON c.id_participante2 = u2.id_usu
             LEFT JOIN LATERAL (
                 SELECT p.tipo_publi, p.titulo_publi, p.cupos_totales,
                        (SELECT COUNT(*)::int FROM matches m2
                         WHERE m2.id_publi = p.id_publi AND m2.estado_match = 'Aceptada') AS cupos_ocupados,
                        (SELECT j.nom_jg FROM publicacion_juegos pj
                         JOIN juegos j ON j.appid = pj.appid
                         WHERE pj.id_publi = p.id_publi LIMIT 1) AS juego_nombre
                 FROM matches m
                 JOIN publicaciones p ON p.id_publi = m.id_publi
                 WHERE m.estado_match = 'Aceptada'
                   AND ((m.id_solicitante = c.id_participante1 AND m.id_receptor = c.id_participante2)
                     OR (m.id_solicitante = c.id_participante2 AND m.id_receptor = c.id_participante1))
                 ORDER BY m.creadoen_match DESC
                 LIMIT 1
             ) mctx ON TRUE
             WHERE c.id_participante1 = $1 OR c.id_participante2 = $1
             ORDER BY fecha_ultimo_mensaje DESC NULLS LAST`,
            [req.usuario.id]
        );

        res.json({ conversaciones: resultado.rows, total: resultado.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /chat/:id/mensajes
// Trae todos los mensajes de una conversacion
router.get('/:id/mensajes', verificarToken, async (req, res) => {
    try {
        // Verificar que el usuario pertenece a este chat
        const chat = await pool.query(
            `SELECT * FROM chat WHERE id_chat = $1 
             AND (id_participante1 = $2 OR id_participante2 = $2)`,
            [req.params.id, req.usuario.id]
        );

        if (chat.rows.length === 0) {
            return res.status(403).json({ error: 'No tienes acceso a este chat' });
        }

        const mensajes = await pool.query(
            `SELECT m.*, u.username_usu AS emisor_username
             FROM mensaje m
             JOIN usuarios u ON m.id_emisor = u.id_usu
             WHERE m.id_chat = $1
             ORDER BY m.creadoen_mensaje ASC`,
            [req.params.id]
        );

        res.json({ mensajes: mensajes.rows, total: mensajes.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /chat/:id/mensaje
// Envia un mensaje en una conversacion
router.post('/:id/mensaje', verificarToken, async (req, res) => {
    const { mensaje, tipo, parent_mensaje } = req.body;

    if (!mensaje) {
        return res.status(400).json({ error: 'El mensaje no puede estar vacio' });
    }

    try {
        // Verificar que el usuario pertenece a este chat
        const chat = await pool.query(
            `SELECT * FROM chat WHERE id_chat = $1
             AND (id_participante1 = $2 OR id_participante2 = $2)`,
            [req.params.id, req.usuario.id]
        );

        if (chat.rows.length === 0) {
            return res.status(403).json({ error: 'No tienes acceso a este chat' });
        }

        const insertado = await pool.query(
            `INSERT INTO mensaje (id_chat, id_emisor, mensaje_chat, tipo_mensaje, parent_mensaje)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING *`,
            [req.params.id, req.usuario.id, mensaje, tipo || 'texto', parent_mensaje || null]
        );

        const conEmisor = await pool.query(
            `SELECT m.*, u.username_usu AS emisor_username
             FROM mensaje m
             JOIN usuarios u ON m.id_emisor = u.id_usu
             WHERE m.id_mensaje = $1`,
            [insertado.rows[0].id_mensaje]
        );

        const filaChat = chat.rows[0];
        const emisorId = req.usuario.id;
        const receptorId =
            filaChat.id_participante1 === emisorId
                ? filaChat.id_participante2
                : filaChat.id_participante1;

        if (receptorId && receptorId !== emisorId) {
            const emisorNombre =
                conEmisor.rows[0].emisor_username ||
                (await usernameDe(emisorId));
            const preview =
                mensaje.length > 100
                    ? `${mensaje.slice(0, 97)}...`
                    : mensaje;
            await crearNotificacion({
                idUsuario: receptorId,
                tipo: 'mensaje',
                titulo: `Nuevo mensaje de ${emisorNombre}`,
                cuerpo: preview,
                refTipo: 'chat',
                refId: parseInt(req.params.id, 10),
                avatar: emisorNombre.charAt(0).toUpperCase(),
            });
        }

        res.status(201).json(conEmisor.rows[0]);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /chat/iniciar
// Inicia una conversacion con otro usuario directamente
// No requiere match previo
router.post('/iniciar', verificarToken, async (req, res) => {
    const id_receptor = parseInt(req.body.id_receptor, 10);

    if (!id_receptor || Number.isNaN(id_receptor)) {
        return res.status(400).json({ error: 'id_receptor es obligatorio' });
    }

    if (id_receptor === req.usuario.id) {
        return res.status(400).json({ error: 'No puedes chatear contigo mismo' });
    }

    try {
        const amistad = await pool.query(
            `SELECT 1 FROM amistad
             WHERE estado_amistad = 'Aceptada'
               AND (
                 (id_solicitante = $1 AND id_receptor = $2)
                 OR (id_solicitante = $2 AND id_receptor = $1)
               )`,
            [req.usuario.id, id_receptor]
        );

        const match = await pool.query(
            `SELECT 1 FROM matches
             WHERE estado_match = 'Aceptada'
               AND (
                 (id_solicitante = $1 AND id_receptor = $2)
                 OR (id_solicitante = $2 AND id_receptor = $1)
               )`,
            [req.usuario.id, id_receptor]
        );

        if (amistad.rows.length === 0 && match.rows.length === 0) {
            return res.status(403).json({
                error: 'Solo puedes chatear con amigos aceptados o matches aceptados',
            });
        }

        const existe = await pool.query(
            `SELECT * FROM chat 
             WHERE (id_participante1 = $1 AND id_participante2 = $2)
             OR (id_participante1 = $2 AND id_participante2 = $1)`,
            [req.usuario.id, id_receptor]
        );

        if (existe.rows.length > 0) {
            return res.json({ chat: existe.rows[0], mensaje: 'Chat ya existente' });
        }

        const resultado = await pool.query(
            `INSERT INTO chat (id_participante1, id_participante2)
             VALUES ($1, $2) RETURNING *`,
            [req.usuario.id, id_receptor]
        );

        res.status(201).json({ chat: resultado.rows[0], mensaje: 'Chat creado' });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;