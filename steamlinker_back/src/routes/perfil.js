// Rutas de gestion de perfil de usuario
// Permite editar perfil, agregar juegos y consultar datos del usuario

const express = require('express');
const crypto = require('crypto');
const axios = require('axios');
const pool = require('../db');
const { verificarToken } = require('./auth');
const steamService = require('../services/steamService');

const router = express.Router();

// ── Login con Steam (OpenID 2.0) ────────────────────────────────────────
// Reemplaza pegar el SteamID/URL a mano por el flujo real "Iniciar sesión
// con Steam" que usan otras webs — pedido explícito del usuario (ver
// HANDOFF.md). Steam no ofrece OAuth2/OIDC para esto, solo OpenID 2.0.
//
// Flujo: el usuario YA está logueado en SteamMatch (verificarToken) y pide
// vincular su Steam. 1) /steam/openid/iniciar genera un "state" de un solo
// uso atado a su id_usu y arma la URL de login de Steam. 2) el navegador
// navega a Steam, el usuario inicia sesión ahí. 3) Steam redirige de
// vuelta a /steam/openid/callback con la respuesta firmada. 4) el backend
// SIEMPRE reverifica esa respuesta reenviándola a Steam con
// openid.mode=check_authentication antes de confiar en ella — nunca se
// confía en el claimed_id sin este paso, es la parte que de verdad
// importa de OpenID.
const STEAM_OPENID_ENDPOINT = 'https://steamcommunity.com/openid/login';
const steamOpenIdStates = new Map(); // state -> { id_usu, expires }
const STATE_TTL_MS = 5 * 60 * 1000;

function limpiarStatesExpirados() {
    const ahora = Date.now();
    for (const [key, val] of steamOpenIdStates) {
        if (val.expires < ahora) steamOpenIdStates.delete(key);
    }
}

function appUrlBase() {
    return (process.env.APP_URL || `http://localhost:${process.env.PORT || 3000}`).replace(/\/$/, '');
}

function frontendUrlBase() {
    return (process.env.FRONTEND_URL || 'http://localhost:8080').replace(/\/$/, '');
}

// GET /perfil/steam/openid/iniciar
router.get('/steam/openid/iniciar', verificarToken, (req, res) => {
    limpiarStatesExpirados();
    const state = crypto.randomBytes(24).toString('hex');
    steamOpenIdStates.set(state, { id_usu: req.usuario.id, expires: Date.now() + STATE_TTL_MS });

    const base = appUrlBase();
    const returnTo = `${base}/perfil/steam/openid/callback?state=${state}`;

    const params = new URLSearchParams({
        'openid.ns': 'http://specs.openid.net/auth/2.0',
        'openid.mode': 'checkid_setup',
        'openid.return_to': returnTo,
        'openid.realm': base,
        'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
    });

    res.json({ url: `${STEAM_OPENID_ENDPOINT}?${params.toString()}` });
});

// GET /perfil/steam/openid/callback
// Steam redirige aquí — nunca lo llama el frontend directamente.
router.get('/steam/openid/callback', async (req, res) => {
    const frontend = frontendUrlBase();
    const state = typeof req.query.state === 'string' ? req.query.state : null;
    const entry = state ? steamOpenIdStates.get(state) : null;
    if (state) steamOpenIdStates.delete(state); // un solo uso, se borre o no sea válido

    if (!entry || entry.expires < Date.now()) {
        return res.redirect(`${frontend}/#/home?steam=error&motivo=sesion_expirada`);
    }

    if (req.query['openid.mode'] !== 'id_res') {
        // El usuario canceló el login en Steam, o algo salió mal antes de firmar.
        return res.redirect(`${frontend}/#/home?steam=error&motivo=cancelado`);
    }

    // op_endpoint debe ser el propio Steam — defensa extra contra una
    // respuesta que diga venir de otro proveedor.
    if (req.query['openid.op_endpoint'] !== STEAM_OPENID_ENDPOINT) {
        return res.redirect(`${frontend}/#/home?steam=error&motivo=proveedor_invalido`);
    }

    try {
        const verifyParams = new URLSearchParams();
        for (const [key, value] of Object.entries(req.query)) {
            if (key.startsWith('openid.') && typeof value === 'string') {
                verifyParams.append(key, value);
            }
        }
        verifyParams.set('openid.mode', 'check_authentication');

        const { data: verifyBody } = await axios.post(STEAM_OPENID_ENDPOINT, verifyParams.toString(), {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        });

        if (!/is_valid\s*:\s*true/.test(verifyBody)) {
            return res.redirect(`${frontend}/#/home?steam=error&motivo=firma_invalida`);
        }

        const claimedId = typeof req.query['openid.claimed_id'] === 'string' ? req.query['openid.claimed_id'] : '';
        const match = claimedId.match(/^https:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/);
        if (!match) {
            return res.redirect(`${frontend}/#/home?steam=error&motivo=id_invalido`);
        }
        const steamid64 = match[1];

        const perfilSteam = await steamService.getUserProfile(steamid64);

        await pool.query(
            `INSERT INTO perfiles_steam (id_usu, steam_id, username_steperfil, avatar_url, perfil_url)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (id_usu) DO UPDATE SET
               steam_id = EXCLUDED.steam_id,
               username_steperfil = EXCLUDED.username_steperfil,
               avatar_url = EXCLUDED.avatar_url,
               perfil_url = EXCLUDED.perfil_url`,
            [entry.id_usu, perfilSteam.steamid, perfilSteam.username, perfilSteam.avatar, perfilSteam.profileUrl]
        );

        return res.redirect(`${frontend}/#/home?steam=ok`);
    } catch (err) {
        return res.redirect(`${frontend}/#/home?steam=error&motivo=error_servidor`);
    }
});

// PUT /perfil/editar
// Edita los datos del perfil del usuario logueado
router.put('/editar', verificarToken, async (req, res) => {
    const { descripcion, pais } = req.body;
    // Validación: la columna pais en la BD ha sido ampliada a varchar(100).
    // Limitar entrada por seguridad a 100 caracteres y devolver error claro si excede.
    if (pais && typeof pais === 'string' && pais.length > 100) {
        return res.status(400).json({ error: 'El valor de "pais" es demasiado largo. Máx 100 caracteres.' });
    }

    try {
        const resultado = await pool.query(
            `UPDATE usuarios 
             SET descrip_usu = $1, pais_usu = $2
             WHERE id_usu = $3
             RETURNING id_usu, username_usu, descrip_usu, pais_usu`,
            [descripcion || null, pais || null, req.usuario.id]
        );

        res.json(resultado.rows[0]);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /perfil/descubrir
// Usuarios con publicaciones activas (para encontrar familia / miembros).
// Incluye juegos en comun (de la biblioteca verificada, no de lo que el
// usuario diga tener) con una muestra de hasta 3 para mostrar carátulas,
// total de juegos, tipo de su publicacion mas reciente, si tiene Steam
// vinculado (insignia de "verificado"), y el juego de su publicacion mas
// reciente (con horas jugadas si las tiene registradas) para la fila de
// "juego destacado" de la tarjeta.
router.get('/descubrir', verificarToken, async (req, res) => {
    const { tipo, pais, appid } = req.query;

    try {
        let consulta = `
            SELECT u.id_usu, u.username_usu, u.descrip_usu, u.pais_usu, u.repu_usu,
                   COUNT(DISTINCT p.id_publi)::int AS total_publicaciones,
                   (SELECT p2.tipo_publi FROM publicaciones p2
                    WHERE p2.id_usu = u.id_usu AND p2.estado_publi = TRUE
                    ORDER BY p2.creadoen_publi DESC LIMIT 1) AS tipo_publi_reciente,
                   (SELECT MAX(p3.creadoen_publi) FROM publicaciones p3
                    WHERE p3.id_usu = u.id_usu AND p3.estado_publi = TRUE) AS ultima_publicacion,
                   (SELECT COUNT(*)::int FROM usuarios_juegos uj WHERE uj.id_usu = u.id_usu) AS total_juegos,
                   (SELECT COUNT(*)::int FROM usuarios_juegos uj1
                    JOIN usuarios_juegos uj2 ON uj1.appid = uj2.appid
                    WHERE uj1.id_usu = $1 AND uj2.id_usu = u.id_usu) AS juegos_en_comun,
                   EXISTS(SELECT 1 FROM perfiles_steam ps WHERE ps.id_usu = u.id_usu) AS steam_vinculado,
                   (SELECT json_agg(row_to_json(jc)) FROM (
                        SELECT j.appid, j.nom_jg, j.headerimg_jg
                        FROM usuarios_juegos uj1
                        JOIN usuarios_juegos uj2 ON uj1.appid = uj2.appid
                        JOIN juegos j ON j.appid = uj1.appid
                        WHERE uj1.id_usu = $1 AND uj2.id_usu = u.id_usu
                        LIMIT 3
                    ) jc) AS juegos_comunes_muestra,
                   (SELECT row_to_json(jr) FROM (
                        SELECT j.appid, j.nom_jg, j.headerimg_jg,
                               (SELECT uj.horas_usujg FROM usuarios_juegos uj
                                WHERE uj.id_usu = u.id_usu AND uj.appid = j.appid) AS horas
                        FROM publicaciones p4
                        JOIN publicacion_juegos pj4 ON pj4.id_publi = p4.id_publi
                        JOIN juegos j ON j.appid = pj4.appid
                        WHERE p4.id_usu = u.id_usu AND p4.estado_publi = TRUE
                        ORDER BY p4.creadoen_publi DESC
                        LIMIT 1
                    ) jr) AS juego_reciente
            FROM usuarios u
            JOIN publicaciones p ON p.id_usu = u.id_usu
            LEFT JOIN publicacion_juegos pj ON pj.id_publi = p.id_publi
            WHERE p.estado_publi = TRUE
              AND COALESCE(u.baneado_usu, FALSE) = FALSE
              AND COALESCE(u.perfil_publico, TRUE) = TRUE
              AND u.id_usu <> $1
        `;

        const parametros = [req.usuario.id];
        let contador = 2;

        if (tipo) {
            consulta += ` AND p.tipo_publi = $${contador}`;
            parametros.push(tipo);
            contador++;
        }

        if (pais) {
            consulta += ` AND p.paisfiltro_publi = $${contador}`;
            parametros.push(pais);
            contador++;
        }

        if (appid) {
            consulta += ` AND pj.appid = $${contador}`;
            parametros.push(parseInt(appid, 10));
            contador++;
        }

        consulta += `
            GROUP BY u.id_usu, u.username_usu, u.descrip_usu, u.pais_usu, u.repu_usu
            ORDER BY juegos_en_comun DESC, u.repu_usu DESC
        `;

        const resultado = await pool.query(consulta, parametros);
        res.json({ usuarios: resultado.rows, total: resultado.rows.length });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /perfil/comparar/:id
// Compara bibliotecas (juegos en perfil) entre el usuario logueado y otro
router.get('/comparar/:id', verificarToken, async (req, res) => {
    const otroId = parseInt(req.params.id, 10);
    const miId = req.usuario.id;

    if (!otroId || Number.isNaN(otroId)) {
        return res.status(400).json({ error: 'ID de usuario inválido' });
    }

    if (otroId === miId) {
        return res.status(400).json({ error: 'No puedes compararte contigo mismo' });
    }

    try {
        const otroUser = await pool.query(
            `SELECT username_usu,
                    COALESCE(mostrar_biblioteca, TRUE) AS mostrar_biblioteca,
                    COALESCE(perfil_publico, TRUE) AS perfil_publico
             FROM usuarios WHERE id_usu = $1`,
            [otroId]
        );

        if (otroUser.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        if (otroUser.rows[0].perfil_publico === false) {
            return res.status(403).json({ error: 'Este perfil es privado' });
        }

        const otroUsername = otroUser.rows[0].username_usu;
        const otroMuestraBiblioteca = otroUser.rows[0].mostrar_biblioteca !== false;

        const steamRows = await pool.query(
            `SELECT id_usu, steam_id FROM perfiles_steam WHERE id_usu = ANY($1::int[])`,
            [[miId, otroId]]
        );
        const steamPorUsuario = Object.fromEntries(
            steamRows.rows.map((r) => [r.id_usu, r.steam_id])
        );
        const miSteam = steamPorUsuario[miId];
        const otroSteam = steamPorUsuario[otroId];

        if (miSteam && otroSteam && process.env.STEAM_API_KEY) {
            try {
                const steamResult = await steamService.getCommonGames(miSteam, otroSteam);
                const comunes = steamResult.commonGames.map((g) => ({
                    appid: g.appid,
                    nombre: g.name,
                    headerimg: g.headerImg,
                    capsuleimg: g.capsuleImg,
                    misHoras: g.hoursPlayed,
                    susHoras: g.hoursPlayedB,
                }));

                return res.json({
                    fuente: 'steam',
                    otro_username: otroUsername,
                    totalA: steamResult.totalA,
                    totalB: steamResult.totalB,
                    commonCount: steamResult.commonCount,
                    commonGames: comunes,
                });
            } catch (steamErr) {
                const msg = steamErr.message || 'Error al consultar Steam';
                if (!otroMuestraBiblioteca) {
                    return res.status(403).json({
                        error: 'Biblioteca no disponible. El usuario la ocultó o su perfil de Steam es privado.',
                        detalle_steam: msg,
                    });
                }
            }
        }

        if (!otroMuestraBiblioteca) {
            return res.status(403).json({
                error: 'Este usuario ocultó su biblioteca en Steamlinker.',
            });
        }

        const queryJuegos = `
            SELECT j.appid, j.nom_jg, j.headerimg_jg, j.capsuleimg_jg, uj.horas_usujg
            FROM usuarios_juegos uj
            JOIN juegos j ON uj.appid = j.appid
            WHERE uj.id_usu = $1
        `;

        const [misRows, susRows] = await Promise.all([
            pool.query(queryJuegos, [miId]),
            pool.query(queryJuegos, [otroId]),
        ]);

        const misJuegos = misRows.rows;
        const susJuegos = susRows.rows;
        const setOtro = new Set(susJuegos.map((j) => j.appid));

        const comunes = misJuegos
            .filter((j) => setOtro.has(j.appid))
            .map((j) => {
                const otro = susJuegos.find((o) => o.appid === j.appid);
                return {
                    appid: j.appid,
                    nombre: j.nom_jg,
                    headerimg: j.headerimg_jg,
                    capsuleimg: j.capsuleimg_jg,
                    misHoras: j.horas_usujg || 0,
                    susHoras: otro?.horas_usujg || 0,
                };
            })
            .sort((a, b) => (b.misHoras + b.susHoras) - (a.misHoras + a.susHoras));

        res.json({
            fuente: 'local',
            otro_username: otroUsername,
            totalA: misJuegos.length,
            totalB: susJuegos.length,
            commonCount: comunes.length,
            commonGames: comunes,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /perfil/:id
// Devuelve el perfil publico de cualquier usuario
router.get('/:id', verificarToken, async (req, res) => {
    try {
        const usuario = await pool.query(
            `SELECT id_usu, username_usu, descrip_usu, pais_usu,
                    repu_usu, totalrating_usu, tipo_usu, creadoen_usu,
                    perfil_publico, mostrar_biblioteca, notificaciones_amigos,
                    dos_factor
             FROM usuarios WHERE id_usu = $1`,
            [req.params.id]
        );

        if (usuario.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const perfil = usuario.rows[0];
        const esPropio = req.usuario.id === parseInt(req.params.id, 10);

        if (!esPropio && perfil.perfil_publico === false) {
            return res.status(403).json({ error: 'Este perfil es privado' });
        }

        const mostrarBiblioteca = esPropio || perfil.mostrar_biblioteca !== false;

        let juegos = [];
        if (mostrarBiblioteca) {
            const juegosRes = await pool.query(
                `SELECT j.appid, j.nom_jg, j.headerimg_jg, j.capsuleimg_jg,
                        uj.horas_usujg, uj.esfav_usujg
                 FROM usuarios_juegos uj
                 JOIN juegos j ON uj.appid = j.appid
                 WHERE uj.id_usu = $1
                 ORDER BY uj.esfav_usujg DESC, uj.horas_usujg DESC`,
                [req.params.id]
            );
            juegos = juegosRes.rows;
        }

        const steam = await pool.query(
            `SELECT steam_id, username_steperfil, avatar_url, perfil_url
             FROM perfiles_steam WHERE id_usu = $1`,
            [req.params.id]
        );

        const steamVinculado = steam.rows.length > 0;

        res.json({
            ...perfil,
            juegos,
            biblioteca_oculta: !mostrarBiblioteca,
            steam_vinculado: steamVinculado,
            steam: esPropio || mostrarBiblioteca ? (steam.rows[0] || null) : null,
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /perfil/steam/vincular
// Vincula la cuenta Steam del usuario con su perfil de SteamLinker
router.post('/steam/vincular', verificarToken, async (req, res) => {
    const { steamid } = req.body;
    if (!steamid) {
        return res.status(400).json({ error: 'SteamID o URL de Steam es obligatorio' });
    }

    try {
        const resolvedSteamId = await steamService.resolveSteamId(steamid);
        const perfilSteam = await steamService.getUserProfile(resolvedSteamId);

        await pool.query(
            `INSERT INTO perfiles_steam (id_usu, steam_id, username_steperfil, avatar_url, perfil_url)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (id_usu) DO UPDATE SET
               steam_id = EXCLUDED.steam_id,
               username_steperfil = EXCLUDED.username_steperfil,
               avatar_url = EXCLUDED.avatar_url,
               perfil_url = EXCLUDED.perfil_url`,
            [
                req.usuario.id,
                perfilSteam.steamid,
                perfilSteam.username,
                perfilSteam.avatar,
                perfilSteam.profileUrl,
            ]
        );

        res.json(perfilSteam);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /perfil/steam/importar
// Importa la biblioteca Steam vinculada al perfil del usuario
router.post('/steam/importar', verificarToken, async (req, res) => {
    try {
        const steamRow = await pool.query(
            'SELECT steam_id FROM perfiles_steam WHERE id_usu = $1',
            [req.usuario.id]
        );

        if (steamRow.rows.length === 0) {
            return res.status(400).json({ error: 'No hay cuenta Steam vinculada' });
        }

        const steamid = steamRow.rows[0].steam_id;
        const ownedGames = await steamService.getOwnedGames(steamid);

        const imported = [];
        for (const juego of ownedGames) {
            await pool.query(
                `INSERT INTO juegos (appid, nom_jg, headerimg_jg, capsuleimg_jg)
                 VALUES ($1, $2, $3, $4)
                 ON CONFLICT (appid) DO NOTHING`,
                [juego.appid, juego.name, juego.headerImg, juego.capsuleImg]
            );

            const result = await pool.query(
                `INSERT INTO usuarios_juegos (id_usu, appid, horas_usujg, esfav_usujg)
                 VALUES ($1, $2, $3, $4)
                 ON CONFLICT (id_usu, appid) DO UPDATE
                 SET horas_usujg = EXCLUDED.horas_usujg
                 RETURNING *`,
                [req.usuario.id, juego.appid, juego.hoursPlayed, false]
            );

            imported.push(result.rows[0]);
        }

        res.json({ mensaje: `Importados ${imported.length} juegos`, total: imported.length });
    } catch (err) {
        if (err.message?.includes('privada')) {
            return res.status(403).json({ error: 'La biblioteca de Steam es privada. Hazla pública para importarla.' });
        }
        res.status(500).json({ error: err.message });
    }
});

// DELETE /perfil/steam/desvincular
// Desvincula la cuenta Steam conectada al perfil del usuario
router.delete('/steam/desvincular', verificarToken, async (req, res) => {
    try {
        await pool.query(
            'DELETE FROM perfiles_steam WHERE id_usu = $1',
            [req.usuario.id]
        );
        res.json({ mensaje: 'Cuenta Steam desvinculada correctamente' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /perfil/juegos/agregar
// Agrega un juego al perfil del usuario
// El juego se busca primero en la BD, si no existe se guarda automaticamente
router.post('/juegos/agregar', verificarToken, async (req, res) => {
    const { appid, nombre, headerimg, capsuleimg, horas, favorito } = req.body;

    if (!appid || !nombre) {
        return res.status(400).json({ error: 'appid y nombre son obligatorios' });
    }

    try {
        // Insertar el juego en la tabla juegos si no existe todavia
        await pool.query(
            `INSERT INTO juegos (appid, nom_jg, headerimg_jg, capsuleimg_jg)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (appid) DO NOTHING`,
            [appid, nombre, headerimg || null, capsuleimg || null]
        );

        // Agregar el juego al perfil del usuario
        const resultado = await pool.query(
            `INSERT INTO usuarios_juegos (id_usu, appid, horas_usujg, esfav_usujg)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (id_usu, appid) DO UPDATE 
             SET horas_usujg = $3, esfav_usujg = $4
             RETURNING *`,
            [req.usuario.id, appid, horas || 0, favorito || false]
        );

        res.status(201).json(resultado.rows[0]);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /perfil/juegos/:appid
// Elimina un juego del perfil del usuario
router.delete('/juegos/:appid', verificarToken, async (req, res) => {
    try {
        await pool.query(
            'DELETE FROM usuarios_juegos WHERE id_usu = $1 AND appid = $2',
            [req.usuario.id, req.params.appid]
        );

        res.json({ mensaje: 'Juego eliminado del perfil' });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /perfil/juegos/buscar?q=nombre
// Busca juegos en la Steam Store API
// No requiere API key, es publica
router.get('/juegos/buscar', verificarToken, async (req, res) => {
    const { q } = req.query;

    if (!q) {
        return res.status(400).json({ error: 'Parametro q es obligatorio' });
    }

    try {
        const axios = require('axios');
        const respuesta = await axios.get(
            `https://store.steampowered.com/api/storesearch/`,
            { params: { term: q, l: 'spanish', cc: 'CO' } }
        );

        const juegos = respuesta.data.items.map(j => ({
            appid: j.id,
            nombre: j.name,
            headerimg: `https://cdn.cloudflare.steamstatic.com/steam/apps/${j.id}/header.jpg`,
            capsuleimg: j.tiny_image
        }));

        res.json({ juegos, total: juegos.length });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /perfil/privacidad
// Guarda los ajustes de privacidad del usuario
router.put('/privacidad', verificarToken, async (req, res) => {
    const {
        perfil_publico,
        mostrar_biblioteca,
        notificaciones_amigos,
        dos_factor
    } = req.body;

    try {
        const resultado = await pool.query(
            `UPDATE usuarios
             SET perfil_publico = COALESCE($1, perfil_publico),
                 mostrar_biblioteca = COALESCE($2, mostrar_biblioteca),
                 notificaciones_amigos = COALESCE($3, notificaciones_amigos),
                 dos_factor = COALESCE($4, dos_factor)
             WHERE id_usu = $5
             RETURNING perfil_publico, mostrar_biblioteca, notificaciones_amigos, dos_factor`,
            [
                perfil_publico ?? null,
                mostrar_biblioteca ?? null,
                notificaciones_amigos ?? null,
                dos_factor ?? null,
                req.usuario.id
            ]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        res.json({
            mensaje: 'Ajustes de privacidad guardados',
            privacidad: resultado.rows[0]
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;