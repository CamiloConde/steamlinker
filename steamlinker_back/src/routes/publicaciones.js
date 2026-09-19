// Rutas de publicaciones
// Permite crear, listar, filtrar y cerrar publicaciones

const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { verificarToken } = require('./auth');
const { crearNotificacion, usernameDe } = require('../services/notificacionesService');
const { guardarJuego } = require('../services/juegosService');
const { tieneSteamVinculado, TIPOS_REQUIEREN_STEAM } = require('../utils/verificacion');

const router = express.Router();

const TIPOS_VALIDOS = ['busco_familia', 'busco_miembros', 'busco_companero', 'otro'];

// GET /buscar no exige sesión (se puede ver la lista sin loguearse), pero
// si llega un token válido lo usamos para calcular "juegos en común" --
// mismo patrón que contacto.js.
function usuarioOpcional(req) {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return null;
    try {
        return jwt.verify(token, process.env.JWT_SECRET).id ?? null;
    } catch {
        return null;
    }
}

// POST /publicaciones/crear
// Crea una nueva publicacion con sus juegos asociados
router.post('/crear', verificarToken, async (req, res) => {
    const { tipo, titulo, descripcion, pais, juegos } = req.body;
    let { cupos_totales: cuposTotales } = req.body;

    if (!tipo || !titulo) {
        return res.status(400).json({ error: 'tipo y titulo son obligatorios' });
    }

    if (!TIPOS_VALIDOS.includes(tipo)) {
        return res.status(400).json({ error: `tipo debe ser uno de: ${TIPOS_VALIDOS.join(', ')}` });
    }

    if (TIPOS_REQUIEREN_STEAM.includes(tipo) && !(await tieneSteamVinculado(req.usuario.id))) {
        return res.status(403).json({
            error: 'Debes vincular tu cuenta de Steam antes de publicar en Familia',
            codigo: 'STEAM_REQUERIDO',
        });
    }

    // Antes se ponía un default de 6 cupos para familia/miembros aunque el
    // usuario no eligiera nada -- pedido explícito del usuario: si no se
    // elige, no debe aparecer ningún límite de cupos en la publicación.
    if (cuposTotales != null) {
        cuposTotales = parseInt(cuposTotales, 10);
        if (Number.isNaN(cuposTotales) || cuposTotales <= 0) {
            return res.status(400).json({ error: 'cupos_totales debe ser un entero positivo' });
        }
    } else {
        cuposTotales = null;
    }

    try {
        // Crear la publicacion
        const resultado = await pool.query(
            `INSERT INTO publicaciones (id_usu, tipo_publi, titulo_publi, descrip_publi, paisfiltro_publi, cupos_totales)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING *`,
            [req.usuario.id, tipo, titulo, descripcion || null, pais || null, cuposTotales]
        );

        const publicacion = resultado.rows[0];

        // Asociar los juegos a la publicacion si se enviaron
        if (juegos && juegos.length > 0) {
            for (const juego of juegos) {
                // Guardar el juego si no existe
                await guardarJuego({
                    appid: juego.appid,
                    nombre: juego.nombre,
                    headerimg: juego.headerimg,
                    capsuleimg: juego.capsuleimg,
                });

                // Asociar el juego a la publicacion
                await pool.query(
                    `INSERT INTO publicacion_juegos (id_publi, appid) VALUES ($1, $2)`,
                    [publicacion.id_publi, juego.appid]
                );
            }
        }

        res.status(201).json(publicacion);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /publicaciones/buscar
// Busca publicaciones con filtros opcionales
// Parametros: tipo (uno o varios separados por coma, ej "busco_familia,busco_miembros"), pais, appid, orden (recientes | reputacion)
router.get('/buscar', async (req, res) => {
    const { tipo, pais, appid, orden } = req.query;
    const viewerId = usuarioOpcional(req);

    try {
        // Construir la consulta dinamicamente segun los filtros
        let consulta = `
            SELECT DISTINCT p.*, 
                   u.username_usu, u.repu_usu, u.pais_usu,
                   COUNT(pj.appid) as total_juegos
            FROM publicaciones p
            JOIN usuarios u ON p.id_usu = u.id_usu
            LEFT JOIN publicacion_juegos pj ON p.id_publi = pj.id_publi
            WHERE p.estado_publi = TRUE
        `;

        const parametros = [];
        let contador = 1;

        if (tipo) {
            const tipos = String(tipo).split(',').map((t) => t.trim()).filter(Boolean);
            consulta += ` AND p.tipo_publi = ANY($${contador}::varchar[])`;
            parametros.push(tipos);
            contador++;
        }

        if (pais) {
            consulta += ` AND p.paisfiltro_publi = $${contador}`;
            parametros.push(pais);
            contador++;
        }

        if (appid) {
            consulta += ` AND pj.appid = $${contador}`;
            parametros.push(parseInt(appid));
            contador++;
        }

        consulta += ` GROUP BY p.id_publi, u.username_usu, u.repu_usu, u.pais_usu`;

        // Ordenar por fecha o reputacion del autor
        if (orden === 'reputacion') {
            consulta += ` ORDER BY u.repu_usu DESC`;
        } else {
            consulta += ` ORDER BY p.creadoen_publi DESC`;
        }

        const resultado = await pool.query(consulta, parametros);

        // Traer los juegos y cupos ocupados de cada publicacion. "Juegos en
        // común" solo se calcula si hay un usuario logueado viendo la lista
        // (necesitamos su biblioteca para comparar) y compara contra el
        // autor de la publicación, no contra los juegos asociados a ella --
        // mismo criterio que /perfil/descubrir (solo biblioteca verificada
        // de Steam en ambos lados, para no inflar coincidencias falsas).
        const publicaciones = await Promise.all(
            resultado.rows.map(async (pub) => {
                const juegos = await pool.query(
                    `SELECT j.appid, j.nom_jg, j.headerimg_jg, j.generos_jg
                     FROM publicacion_juegos pj
                     JOIN juegos j ON pj.appid = j.appid
                     WHERE pj.id_publi = $1`,
                    [pub.id_publi]
                );
                const ocupados = await pool.query(
                    `SELECT COUNT(*)::int AS n FROM matches
                     WHERE id_publi = $1 AND estado_match = 'Aceptada'`,
                    [pub.id_publi]
                );

                let juegosEnComun = null;
                let juegosComunesMuestra = null;
                if (viewerId != null && viewerId !== pub.id_usu) {
                    const comunes = await pool.query(
                        `SELECT j.appid, j.nom_jg, j.headerimg_jg
                         FROM usuarios_juegos uj1
                         JOIN usuarios_juegos uj2 ON uj1.appid = uj2.appid
                         JOIN juegos j ON j.appid = uj1.appid
                         WHERE uj1.id_usu = $1 AND uj2.id_usu = $2
                           AND uj1.origen_usujg = 'steam' AND uj2.origen_usujg = 'steam'`,
                        [viewerId, pub.id_usu]
                    );
                    juegosEnComun = comunes.rows.length;
                    juegosComunesMuestra = comunes.rows.slice(0, 3);
                }

                return {
                    ...pub,
                    juegos: juegos.rows,
                    cupos_ocupados: ocupados.rows[0].n,
                    juegos_en_comun: juegosEnComun,
                    juegos_comunes_muestra: juegosComunesMuestra,
                };
            })
        );

        res.json({ publicaciones, total: publicaciones.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /publicaciones/:id/comentarios
router.get('/:id/comentarios', verificarToken, async (req, res) => {
    const idPubli = parseInt(req.params.id, 10);
    if (!idPubli || Number.isNaN(idPubli)) {
        return res.status(400).json({ error: 'ID de publicación inválido' });
    }

    try {
        const resultado = await pool.query(
            `SELECT c.*, u.username_usu
             FROM comentario_publicacion c
             JOIN usuarios u ON c.id_usu = u.id_usu
             WHERE c.id_publi = $1
             ORDER BY c.creadoen_coment ASC`,
            [idPubli]
        );

        res.json({ comentarios: resultado.rows, total: resultado.rows.length });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /publicaciones/:id/comentarios
router.post('/:id/comentarios', verificarToken, async (req, res) => {
    const idPubli = parseInt(req.params.id, 10);
    const { texto, id_padre } = req.body;

    if (!idPubli || Number.isNaN(idPubli)) {
        return res.status(400).json({ error: 'ID de publicación inválido' });
    }

    const textoLimpio = typeof texto === 'string' ? texto.trim() : '';
    if (textoLimpio.length < 2) {
        return res.status(400).json({ error: 'El comentario es demasiado corto' });
    }
    if (textoLimpio.length > 2000) {
        return res.status(400).json({ error: 'El comentario es demasiado largo' });
    }

    try {
        const pub = await pool.query(
            `SELECT id_publi, id_usu, titulo_publi, estado_publi
             FROM publicaciones WHERE id_publi = $1`,
            [idPubli]
        );

        if (pub.rows.length === 0) {
            return res.status(404).json({ error: 'Publicación no encontrada' });
        }

        if (pub.rows[0].estado_publi === false) {
            return res.status(400).json({ error: 'La publicación está cerrada' });
        }

        let idPadre = null;
        if (id_padre != null) {
            idPadre = parseInt(id_padre, 10);
            const padre = await pool.query(
                `SELECT id_coment, id_publi, id_usu FROM comentario_publicacion
                 WHERE id_coment = $1 AND id_publi = $2`,
                [idPadre, idPubli]
            );
            if (padre.rows.length === 0) {
                return res.status(400).json({ error: 'Comentario padre no válido' });
            }
        }

        const insertado = await pool.query(
            `INSERT INTO comentario_publicacion (id_publi, id_usu, id_padre, texto_coment)
             VALUES ($1, $2, $3, $4)
             RETURNING *`,
            [idPubli, req.usuario.id, idPadre, textoLimpio]
        );

        const comentario = insertado.rows[0];
        const autorPubli = pub.rows[0].id_usu;
        const solicitante = await usernameDe(req.usuario.id);

        try {
            if (autorPubli !== req.usuario.id) {
                await crearNotificacion({
                    idUsuario: autorPubli,
                    tipo: 'comment',
                    titulo: 'Nuevo comentario',
                    cuerpo: `${solicitante} comentó en "${pub.rows[0].titulo_publi}".`,
                    refTipo: 'publicacion',
                    refId: idPubli,
                    avatar: solicitante[0]?.toUpperCase() || 'C',
                });
            }

            if (idPadre) {
                const padreRow = await pool.query(
                    'SELECT id_usu FROM comentario_publicacion WHERE id_coment = $1',
                    [idPadre]
                );
                const autorPadre = padreRow.rows[0]?.id_usu;
                if (
                    autorPadre &&
                    autorPadre !== req.usuario.id &&
                    autorPadre !== autorPubli
                ) {
                    await crearNotificacion({
                        idUsuario: autorPadre,
                        tipo: 'reply',
                        titulo: 'Respuesta a tu comentario',
                        cuerpo: `${solicitante} respondió en una publicación.`,
                        refTipo: 'publicacion',
                        refId: idPubli,
                        avatar: solicitante[0]?.toUpperCase() || 'R',
                    });
                }
            }
        } catch (_) { /* no bloquear */ }

        const conUsuario = await pool.query(
            `SELECT c.*, u.username_usu
             FROM comentario_publicacion c
             JOIN usuarios u ON c.id_usu = u.id_usu
             WHERE c.id_coment = $1`,
            [comentario.id_coment]
        );

        res.status(201).json(conUsuario.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /publicaciones/:id
// Devuelve una publicacion especifica con todos sus detalles
router.get('/:id', async (req, res) => {
    try {
        const resultado = await pool.query(
            `SELECT p.*, u.username_usu, u.repu_usu, u.pais_usu
             FROM publicaciones p
             JOIN usuarios u ON p.id_usu = u.id_usu
             WHERE p.id_publi = $1`,
            [req.params.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Publicacion no encontrada' });
        }

        const juegos = await pool.query(
            `SELECT j.appid, j.nom_jg, j.headerimg_jg, j.capsuleimg_jg, j.generos_jg
             FROM publicacion_juegos pj
             JOIN juegos j ON pj.appid = j.appid
             WHERE pj.id_publi = $1`,
            [req.params.id]
        );

        // Quienes se unieron (matches aceptados): el solicitante es quien
        // pidio entrar, no el dueno de la publicacion. Esto es el roster
        // real que respalda el panel de cupos ("CONFIRMADOS N/M").
        const confirmados = await pool.query(
            `SELECT u.id_usu, u.username_usu
             FROM matches m
             JOIN usuarios u ON u.id_usu = m.id_solicitante
             WHERE m.id_publi = $1 AND m.estado_match = 'Aceptada'
             ORDER BY m.creadoen_match ASC`,
            [req.params.id]
        );

        res.json({
            ...resultado.rows[0],
            juegos: juegos.rows,
            cupos_ocupados: confirmados.rows.length,
            confirmados: confirmados.rows,
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /publicaciones/:id/cerrar
// Cierra una publicacion para que no aparezca en busquedas
router.put('/:id/cerrar', verificarToken, async (req, res) => {
    try {
        const resultado = await pool.query(
            `UPDATE publicaciones SET estado_publi = FALSE
             WHERE id_publi = $1 AND id_usu = $2
             RETURNING *`,
            [req.params.id, req.usuario.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Publicacion no encontrada o no te pertenece' });
        }

        res.json({ mensaje: 'Publicacion cerrada', publicacion: resultado.rows[0] });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /publicaciones/:id/editar
// Edita una publicación propia: título, descripción, país, cupos y
// juegos asociados. El tipo (busco_familia/busco_miembros/...) NO se
// puede editar -- cambiar de tipo tiene efectos secundarios (requiere
// Steam, cupos por defecto) que no tiene sentido aplicar a medio camino;
// si alguien quiere otro tipo, crea una publicación nueva.
router.put('/:id/editar', verificarToken, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const { titulo, descripcion, pais, juegos } = req.body;
    let { cupos_totales: cuposTotales } = req.body;

    if (!id || Number.isNaN(id)) {
        return res.status(400).json({ error: 'ID inválido' });
    }
    if (!titulo) {
        return res.status(400).json({ error: 'titulo es obligatorio' });
    }

    try {
        const pub = await pool.query(
            'SELECT id_usu, cupos_totales FROM publicaciones WHERE id_publi = $1',
            [id]
        );
        if (pub.rows.length === 0) {
            return res.status(404).json({ error: 'Publicación no encontrada' });
        }
        if (pub.rows[0].id_usu !== req.usuario.id) {
            return res.status(403).json({ error: 'No puedes editar una publicación que no es tuya' });
        }

        if (cuposTotales !== undefined && cuposTotales !== null) {
            cuposTotales = parseInt(cuposTotales, 10);
            if (Number.isNaN(cuposTotales) || cuposTotales <= 0) {
                return res.status(400).json({ error: 'cupos_totales debe ser un entero positivo' });
            }
            // No se puede bajar el total por debajo de lo ya ocupado --
            // dejaría la publicación en un estado imposible (más gente
            // aceptada de la que "caben").
            const ocupados = await pool.query(
                `SELECT COUNT(*)::int AS n FROM matches WHERE id_publi = $1 AND estado_match = 'Aceptada'`,
                [id]
            );
            if (cuposTotales < ocupados.rows[0].n) {
                return res.status(400).json({
                    error: `Ya tienes ${ocupados.rows[0].n} cupos ocupados -- no puedes poner un total menor`,
                });
            }
        } else if (cuposTotales === undefined) {
            cuposTotales = pub.rows[0].cupos_totales;
        }

        const resultado = await pool.query(
            `UPDATE publicaciones
             SET titulo_publi = $1, descrip_publi = $2, paisfiltro_publi = $3, cupos_totales = $4
             WHERE id_publi = $5
             RETURNING *`,
            [titulo, descripcion || null, pais || null, cuposTotales, id]
        );

        if (juegos !== undefined) {
            await pool.query('DELETE FROM publicacion_juegos WHERE id_publi = $1', [id]);
            for (const juego of juegos) {
                await guardarJuego({
                    appid: juego.appid,
                    nombre: juego.nombre,
                    headerimg: juego.headerimg,
                    capsuleimg: juego.capsuleimg,
                });
                await pool.query(
                    `INSERT INTO publicacion_juegos (id_publi, appid) VALUES ($1, $2)`,
                    [id, juego.appid]
                );
            }
        }

        res.json(resultado.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;