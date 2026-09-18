// Formulario de contacto / sugerencias / quejas — no exige sesión (un
// visitante sin cuenta también puede escribir), pero si llega un token
// válido se guarda el id_usu para poder darle seguimiento.
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { contactoLimiter } = require('../middleware/rateLimit');

const router = express.Router();

const TIPOS_VALIDOS = ['sugerencia', 'queja', 'error', 'otro'];

function usuarioOpcional(req) {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return null;
    try {
        return jwt.verify(token, process.env.JWT_SECRET).id ?? null;
    } catch {
        return null;
    }
}

// POST /contacto
router.post('/', contactoLimiter, async (req, res) => {
    // honeypot: campo invisible para usuarios reales — un bot que rellena
    // todos los inputs del formulario cae aquí. Se responde 201 falso para
    // no revelarle al bot que fue detectado.
    if (req.body.sitio_web) {
        return res.status(201).json({ mensaje: 'Mensaje enviado' });
    }

    const nombre = req.body.nombre?.toString().trim();
    const email = req.body.email?.toString().trim();
    const cuerpo = req.body.mensaje?.toString().trim();
    const tipo = TIPOS_VALIDOS.includes(req.body.tipo) ? req.body.tipo : 'sugerencia';

    if (!nombre || !email || !cuerpo) {
        return res.status(400).json({ error: 'Nombre, correo y mensaje son obligatorios' });
    }
    if (!email.includes('@')) {
        return res.status(400).json({ error: 'El correo no tiene un formato válido' });
    }
    if (cuerpo.length < 10) {
        return res.status(400).json({ error: 'Cuéntanos un poco más (mínimo 10 caracteres)' });
    }
    if (nombre.length > 100 || email.length > 100 || cuerpo.length > 4000) {
        return res.status(400).json({ error: 'Alguno de los campos es demasiado largo' });
    }

    try {
        const idUsu = usuarioOpcional(req);
        const resultado = await pool.query(
            `INSERT INTO mensajes_contacto (id_usu, nombre_mensajecontacto, email_mensajecontacto, tipo_mensajecontacto, cuerpo_mensajecontacto)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id_mensajecontacto, creadoen_mensajecontacto`,
            [idUsu, nombre, email, tipo, cuerpo]
        );
        res.status(201).json({
            mensaje: 'Mensaje enviado, gracias por escribirnos',
            id: resultado.rows[0].id_mensajecontacto,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
