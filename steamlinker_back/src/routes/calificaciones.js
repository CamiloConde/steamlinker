// Rutas del sistema de calificaciones
// Permite calificar a otro usuario despues de un match aceptado

const express = require('express');
const pool = require('../db');
const { verificarToken } = require('./auth');

const router = express.Router();

// POST /calificaciones/crear
// Califica a otro usuario despues de un match aceptado
router.post('/crear', verificarToken, async (req, res) => {
    const { id_match, id_calificado, estrellas, confiable, logro_cometido, comentario } = req.body;

    if (!id_match || !id_calificado || estrellas === undefined) {
        return res.status(400).json({ error: 'id_match, id_calificado y estrellas son obligatorios' });
    }

    try {
        // Verificar que el match existe y esta aceptado
        const match = await pool.query(
            `SELECT * FROM matches WHERE id_match = $1 AND estado_match = 'Aceptada'
             AND (id_solicitante = $2 OR id_receptor = $2)`,
            [id_match, req.usuario.id]
        );

        if (match.rows.length === 0) {
            return res.status(403).json({ error: 'Match no encontrado o no esta aceptado' });
        }

        // id_calificado tiene que ser EL OTRO participante de este match --
        // no se puede confiar en lo que mande el cliente. Sin esto, cualquiera
        // podia citar un match propio aceptado y calificar a un tercero
        // arbitrario (o a si mismo), inflando o dañando la reputacion de
        // cualquier usuario del sistema.
        const otroParticipante =
            match.rows[0].id_solicitante === req.usuario.id
                ? match.rows[0].id_receptor
                : match.rows[0].id_solicitante;

        if (parseInt(id_calificado, 10) !== otroParticipante) {
            return res.status(403).json({ error: 'Solo puedes calificar al otro participante de este match' });
        }

        // Verificar que no haya calificado ya a este usuario en este match
        const yacalifico = await pool.query(
            `SELECT id_cali FROM calificaciones 
             WHERE id_match = $1 AND id_calificador = $2`,
            [id_match, req.usuario.id]
        );

        if (yacalifico.rows.length > 0) {
            return res.status(409).json({ error: 'Ya calificaste a este usuario en este match' });
        }

        // Insertar la calificacion
        const resultado = await pool.query(
            `INSERT INTO calificaciones 
             (id_match, id_calificador, id_calificado, estrellas_cali, confiable_cali, logrocometido_cali, comentario_cali)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING *`,
            [id_match, req.usuario.id, id_calificado, estrellas, confiable || null, logro_cometido || null, comentario || null]
        );

        // Actualizar la reputacion del usuario calificado
        await pool.query(
            `UPDATE usuarios 
             SET repu_usu = (repu_usu * totalrating_usu + $1) / (totalrating_usu + 1),
                 totalrating_usu = totalrating_usu + 1
             WHERE id_usu = $2`,
            [estrellas, id_calificado]
        );

        res.status(201).json(resultado.rows[0]);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /calificaciones/usuario/:id
// Devuelve todas las calificaciones recibidas por un usuario
router.get('/usuario/:id', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT c.*, u.username_usu AS calificador_username
             FROM calificaciones c
             JOIN usuarios u ON c.id_calificador = u.id_usu
             WHERE c.id_calificado = $1
             ORDER BY c.creadoen_cali DESC`,
            [req.params.id]
        );

        // Traer el promedio actual del usuario
        const usuario = await pool.query(
            `SELECT repu_usu, totalrating_usu FROM usuarios WHERE id_usu = $1`,
            [req.params.id]
        );

        res.json({
            calificaciones: resultado.rows,
            total: resultado.rows.length,
            promedio: usuario.rows[0]?.repu_usu || 0,
            total_ratings: usuario.rows[0]?.totalrating_usu || 0
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;