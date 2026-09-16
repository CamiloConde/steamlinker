// Rutas del sistema de matches
// Maneja solicitudes entre usuarios

const express = require('express');
const pool = require('../db');
const { verificarToken } = require('./auth');
const { crearNotificacion, usernameDe } = require('../services/notificacionesService');
const { tieneSteamVinculado, TIPOS_REQUIEREN_STEAM } = require('../utils/verificacion');

const router = express.Router();

// POST /matches/enviar
// Envia una solicitud de match a otro usuario
router.post('/enviar', verificarToken, async (req, res) => {
    const { id_publi } = req.body;
    const id_receptor = parseInt(req.body.id_receptor, 10);

    if (!id_receptor || Number.isNaN(id_receptor)) {
        return res.status(400).json({ error: 'id_receptor es obligatorio' });
    }

    if (id_receptor === req.usuario.id) {
        return res.status(400).json({ error: 'No puedes enviarte una solicitud a ti mismo' });
    }

    try {
        // Si el match es hacia una publicacion de Familia, quien envia tambien
        // necesita Steam vinculado (va a compartir/recibir acceso a biblioteca real).
        if (id_publi) {
            const publi = await pool.query(
                'SELECT tipo_publi FROM publicaciones WHERE id_publi = $1',
                [id_publi]
            );
            const tipoPubli = publi.rows[0]?.tipo_publi;
            if (
                tipoPubli &&
                TIPOS_REQUIEREN_STEAM.includes(tipoPubli) &&
                !(await tieneSteamVinculado(req.usuario.id))
            ) {
                return res.status(403).json({
                    error: 'Debes vincular tu cuenta de Steam antes de solicitar unirte a una Familia',
                    codigo: 'STEAM_REQUERIDO',
                });
            }
        }

        // Verificar que no exista ya un match pendiente entre estos dos usuarios
        const existe = await pool.query(
            `SELECT id_match FROM matches 
             WHERE id_solicitante = $1 AND id_receptor = $2 
             AND estado_match = 'Pendiente'`,
            [req.usuario.id, id_receptor]
        );

        if (existe.rows.length > 0) {
            return res.status(409).json({ error: 'Ya tienes una solicitud pendiente con este usuario' });
        }

        const resultado = await pool.query(
            `INSERT INTO matches (id_solicitante, id_receptor, id_publi)
             VALUES ($1, $2, $3)
             RETURNING *`,
            [req.usuario.id, id_receptor, id_publi || null]
        );

        const match = resultado.rows[0];
        try {
            const solicitante = await usernameDe(req.usuario.id);
            await crearNotificacion({
                idUsuario: id_receptor,
                tipo: 'match',
                titulo: 'Nueva solicitud de match',
                cuerpo: `${solicitante} quiere conectar contigo.`,
                refTipo: 'match',
                refId: match.id_match,
                avatar: solicitante[0]?.toUpperCase() || 'M',
            });
        } catch (_) { /* no bloquear si falla la notificación */ }

        res.status(201).json(match);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /matches/estado/:otroId
// Estado de match y amistad entre el usuario logueado y otro usuario
router.get('/estado/:otroId', verificarToken, async (req, res) => {
    const otroId = parseInt(req.params.otroId, 10);
    const miId = req.usuario.id;

    if (!otroId || Number.isNaN(otroId)) {
        return res.status(400).json({ error: 'ID de usuario inválido' });
    }

    if (otroId === miId) {
        return res.json({ match: null, amistad: null, es_yo: true });
    }

    try {
        const matchRes = await pool.query(
            `SELECT id_match, estado_match, id_solicitante, id_receptor
             FROM matches
             WHERE (id_solicitante = $1 AND id_receptor = $2)
                OR (id_solicitante = $2 AND id_receptor = $1)
             ORDER BY creadoen_match DESC
             LIMIT 1`,
            [miId, otroId]
        );

        const amistadRes = await pool.query(
            `SELECT id_amistad, estado_amistad, id_solicitante, id_receptor
             FROM amistad
             WHERE (id_solicitante = $1 AND id_receptor = $2)
                OR (id_solicitante = $2 AND id_receptor = $1)
             ORDER BY creadoen_amistad DESC
             LIMIT 1`,
            [miId, otroId]
        );

        const matchRow = matchRes.rows[0];
        const amistadRow = amistadRes.rows[0];

        res.json({
            es_yo: false,
            match: matchRow
                ? {
                    id_match: matchRow.id_match,
                    estado: matchRow.estado_match,
                    soy_solicitante: matchRow.id_solicitante === miId,
                }
                : null,
            amistad: amistadRow
                ? {
                    id_amistad: amistadRow.id_amistad,
                    estado: amistadRow.estado_amistad,
                    soy_solicitante: amistadRow.id_solicitante === miId,
                }
                : null,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /matches/recibidos
// Lista las solicitudes recibidas por el usuario logueado
router.get('/recibidos', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT m.*, 
                    u.username_usu AS solicitante_username,
                    u.repu_usu AS solicitante_reputacion,
                    u.pais_usu AS solicitante_pais
             FROM matches m
             JOIN usuarios u ON m.id_solicitante = u.id_usu
             WHERE m.id_receptor = $1
             ORDER BY m.creadoen_match DESC`,
            [req.usuario.id]
        );

        res.json({ matches: resultado.rows, total: resultado.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /matches/enviados
// Lista las solicitudes enviadas por el usuario logueado
router.get('/enviados', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT m.*, 
                    u.username_usu AS receptor_username,
                    u.repu_usu AS receptor_reputacion,
                    u.pais_usu AS receptor_pais
             FROM matches m
             JOIN usuarios u ON m.id_receptor = u.id_usu
             WHERE m.id_solicitante = $1
             ORDER BY m.creadoen_match DESC`,
            [req.usuario.id]
        );

        res.json({ matches: resultado.rows, total: resultado.rows.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /matches/:id/responder
// Acepta o rechaza una solicitud de match
router.put('/:id/responder', verificarToken, async (req, res) => {
    const { estado } = req.body;

    if (!estado || !['Aceptada', 'Rechazada'].includes(estado)) {
        return res.status(400).json({ error: 'estado debe ser Aceptada o Rechazada' });
    }

    try {
        const resultado = await pool.query(
            `UPDATE matches SET estado_match = $1
             WHERE id_match = $2 AND id_receptor = $3
             RETURNING *`,
            [estado, req.params.id, req.usuario.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Match no encontrado o no eres el receptor' });
        }

        const match = resultado.rows[0];

        if (estado === 'Aceptada') {
            await pool.query(
                `INSERT INTO chat (id_participante1, id_participante2)
                 VALUES ($1, $2)
                 ON CONFLICT DO NOTHING`,
                [match.id_solicitante, match.id_receptor]
            );

            // Si el match viene de una publicacion con cupos, cerrarla
            // automaticamente al llenarse.
            if (match.id_publi) {
                try {
                    await pool.query(
                        `UPDATE publicaciones SET estado_publi = FALSE
                         WHERE id_publi = $1
                           AND estado_publi = TRUE
                           AND cupos_totales IS NOT NULL
                           AND cupos_totales <= (
                               SELECT COUNT(*) FROM matches
                               WHERE id_publi = $1 AND estado_match = 'Aceptada'
                           )`,
                        [match.id_publi]
                    );
                } catch (_) { /* no bloquear la aceptacion del match */ }
            }

            try {
                const receptor = await usernameDe(req.usuario.id);
                await crearNotificacion({
                    idUsuario: match.id_solicitante,
                    tipo: 'match_aceptado',
                    titulo: 'Match aceptado',
                    cuerpo: `${receptor} aceptó tu solicitud. Ya pueden chatear.`,
                    refTipo: 'match',
                    refId: match.id_match,
                    avatar: receptor[0]?.toUpperCase() || 'M',
                });
            } catch (_) { /* ignore */ }
        }

        res.json(match);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;