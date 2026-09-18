/**
 * ====================================================================
 * MÓDULO DE AUTENTICACIÓN - STEAMLINKER API
 * ====================================================================
 * 
 * DESCRIPCIÓN:
 * Este módulo maneja la autenticación de usuarios en la aplicación.
 * Implementa:
 *   - Registro de nuevos usuarios con contraseña encriptada
 *   - Login con email y contraseña
 *   - Generación de tokens JWT para mantener sesiones
 *   - Middleware de verificación de token para rutas protegidas
 *   - Obtención de perfil del usuario autenticado
 * 
 * SEGURIDAD:
 * - Las contraseñas se encriptan con bcryptjs antes de guardar en BD
 * - Se usan tokens JWT con expiración (7 días en registro, 30 en login)
 * - El middleware verificarToken protege rutas que necesitan autenticación
 * - Las credenciales incorrectas devuelven errores genéricos (sin revelar si el email existe)
 * 
 * ====================================================================
 */

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const pool = require('../db');
const { loginLimiter, registroLimiter } = require('../middleware/rateLimit');

const router = express.Router();

// ── Rotación/revocación de sesiones (refresh tokens) ────────────────
// El access token (JWT) ahora vive poco (1h) y sigue sin estado como
// siempre -- lo que cambia es que ya no es el único factor de sesión.
// El refresh token es una cadena aleatoria de alta entropía (no un JWT):
// se guarda hasheada en la tabla `sesiones`, así que SÍ se puede revocar
// de verdad (cerrar sesión, banear a alguien, eliminar la cuenta) en vez
// de tener que esperar a que expire solo. Se hashea con SHA-256 (no
// bcrypt): a diferencia de una contraseña elegida por una persona, un
// refresh token ya es aleatorio de 256 bits -- no hace falta el costo
// computacional de bcrypt para defenderse de fuerza bruta.
const ACCESS_TOKEN_TTL = '1h';
const REFRESH_TOKEN_DIAS = 30;

function generarAccessToken(usuario) {
    return jwt.sign(
        { id: usuario.id_usu, username: usuario.username_usu, tipo: usuario.tipo_usu },
        process.env.JWT_SECRET,
        { expiresIn: ACCESS_TOKEN_TTL }
    );
}

function hashRefreshToken(refreshToken) {
    return crypto.createHash('sha256').update(refreshToken).digest('hex');
}

// Crea una sesión nueva (fila en `sesiones`) y devuelve el refresh token
// en crudo (solo existe en este momento -- lo que se guarda es su hash).
async function crearSesion(idUsu) {
    const refreshToken = crypto.randomBytes(40).toString('hex');
    const expiraEn = new Date(Date.now() + REFRESH_TOKEN_DIAS * 24 * 60 * 60 * 1000);

    await pool.query(
        `INSERT INTO sesiones (id_usu, refresh_hash, expiraen_sesion)
         VALUES ($1, $2, $3)`,
        [idUsu, hashRefreshToken(refreshToken), expiraEn]
    );

    return refreshToken;
}

/**
 * MIDDLEWARE: verificarToken
 * 
 * PROPÓSITO:
 * Valida que las peticiones a rutas protegidas tengan un token JWT válido.
 * 
 * FLUJO:
 * 1. Extrae el token del header 'Authorization: Bearer <token>'
 * 2. Si no existe token, rechaza con error 401
 * 3. Verifica que el token sea válido con la clave secreta
 * 4. Si es válido, decodifica el token y almacena datos en req.usuario
 * 5. Si es inválido/expirado, rechaza con error 401
 * 6. Si todo es correcto, permite continuar con next()
 * 
 * PARÁMETROS:
 * - req: objeto de petición (contiene headers)
 * - res: objeto de respuesta (para enviar errores)
 * - next: función para continuar al siguiente middleware/ruta
 * 
 * RETORNA:
 * - JSONError 401 si no hay token o es inválido
 * - Llama next() si el token es válido
 */
function verificarToken(req, res, next) {
    // Extrae el token del header 'Authorization: Bearer <token>'
    // Si no existe, toma un valor undefined
    const token = req.headers['authorization']?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Token requerido' });
    }
    
    try {
        // Verifica que el token sea válido con la clave JWT_SECRET del .env
        const datos = jwt.verify(token, process.env.JWT_SECRET);
        
        // Si es válido, almacena los datos del token en req.usuario
        // Para usarlos en la siguiente función
        req.usuario = datos;
        
        // Continúa con la siguiente función/middleware
        next();
    } catch (err) {
        // Si el token es inválido o expiró, devuelve error 401
        return res.status(401).json({ error: 'Token invalido o expirado' });
    }
}


// POST /auth/registro
/**
 * ENDPOINT: POST /auth/registro
 * 
 * PROPÓSITO:
 * Crear una nueva cuenta de usuario con email, contraseña, username y país.
 * Al registrarse, el usuario queda automáticamente logueado (recibe un token).
 * 
 * REQUEST (BODY JSON):
 * {
 *   "username": "string",      // Identificador único del usuario (ej: "juan_perez")
 *   "email": "string",          // Email único (ej: "juan@example.com")
 *   "password": "string",       // Contraseña en texto plano (será encriptada)
 *   "pais": "string" (opcional) // País del usuario (ej: "Colombia")
 * }
 * 
 * VALIDACIONES:
 * 1. Username, email y password son obligatorios (error 400 si faltan)
 * 2. El email no debe estar registrado (error 409 si existe)
 * 3. El username no debe estar en uso (error 409 si existe)
 * 
 * FLUJO:
 * 1. Valida que lleguen username, email y password
 * 2. Consulta la BD para verificar que email/username no existan
 * 3. Encripta la contraseña usando bcryptjs (10 saltos de encriptación)
 * 4. Inserta el nuevo usuario en la tabla 'usuarios'
 * 5. Genera un token JWT válido por 7 días
 * 6. Retorna el token y datos del usuario
 * 
 * RESPONSE (201 Created):
 * {
 *   "token": "eyJhbGciOiJIUzI1NiIs...",  // Token JWT para autenticar peticiones
 *   "usuario": {
 *     "id_usu": 5,
 *     "username_usu": "juan_perez",
 *     "email_usu": "juan@example.com",
 *     "pais_usu": "Colombia",
 *     "tipo_usu": "usuario"  // Tipo de cuenta (usuario/admin)
 *   }
 * }
 * 
 * ERRORES POSIBLES:
 * - 400: Campos obligatorios faltantes
 * - 409: Email o username ya existen
 * - 500: Error en la base de datos
 */
router.post('/registro', registroLimiter, async (req, res) => {
    const { username, email, password, pais } = req.body;

    // Validar que lleguen los campos obligatorios
    if (!username || !email || !password) {
        return res.status(400).json({ error: 'Username, email y contrasena son obligatorios' });
    }

    try {
        // Verificar que el email y username no esten en uso
        // Se consultan ambos en una sola query para eficiencia
        const existe = await pool.query(
            'SELECT id_usu FROM usuarios WHERE email_usu = $1 OR username_usu = $2',
            [email, username]
        );
        if (existe.rows.length > 0) {
            return res.status(409).json({ error: 'El email o username ya esta en uso' });
        }

        // Encriptar la contrasena antes de guardarla
        // Se usa bcryptjs con 10 saltos (iteraciones) para seguridad
        // Esto hace que tarde ~100ms en calcular el hash (seguro vs ataques de fuerza bruta)
        const hash = await bcrypt.hash(password, 10);

        // Insertar el nuevo usuario en la base de datos
        // Usa parameterized queries ($1, $2, etc.) para evitar SQL injection
        const resultado = await pool.query(
            `INSERT INTO usuarios (username_usu, email_usu, pwhash_usu, pais_usu)
             VALUES ($1, $2, $3, $4)
             RETURNING id_usu, username_usu, email_usu, pais_usu, tipo_usu`,
            [username, email, hash, pais || null]
        );

        const usuario = resultado.rows[0];

        // Access token (JWT, 1h) + refresh token (guardado hasheado en
        // `sesiones`, revocable de verdad) -- ver comentario junto a
        // crearSesion() arriba.
        const token = generarAccessToken(usuario);
        const refreshToken = await crearSesion(usuario.id_usu);

        // Normalizar la respuesta para que tenga la misma forma que el login
        res.status(201).json({
            token,
            refreshToken,
            usuario: {
                id: usuario.id_usu,
                username: usuario.username_usu,
                email: usuario.email_usu,
                pais: usuario.pais_usu,
                tipo: usuario.tipo_usu,
            }
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


// POST /auth/login
/**
 * ENDPOINT: POST /auth/login ⭐ PRINCIPAL PARA EXPLICAR AL PROFESOR
 * 
 * PROPÓSITO:
 * Iniciar sesión con email y contraseña.
 * Si las credenciales son correctas, devuelve un token JWT válido.
 * El cliente (app Flutter) debe guardar este token y usarlo en todas las peticiones posteriores.
 * 
 * REQUEST (BODY JSON):
 * {
 *   "email": "string",      // Email registrado (ej: "juan@example.com")
 *   "password": "string"    // Contraseña en texto plano
 * }
 * 
 * VALIDACIONES:
 * 1. Email y password son obligatorios (error 400 si faltan)
 * 2. El email debe existir en BD (error 401 si no existe)
 * 3. La contraseña debe coincidir con el hash guardado (error 401 si no coincide)
 * 
 * FLUJO DETALLADO:
 * 1. Valida que lleguen email y password
 * 2. Busca el usuario en BD por email
 * 3. Si no existe, retorna error genérico "Credenciales incorrectas"
 *    (por seguridad: no dice si el email existe o no)
 * 4. Si existe, compara la password del request con el hash guardado
 *    usando bcryptjs.compare() (función segura para comparar contraseñas)
 * 5. Si la contraseña es incorrecta, retorna error 401
 * 6. Si todo es correcto:
 *    - Genera un token JWT válido por 30 días
 *    - El token contiene: id, username, tipo de usuario
 *    - Retorna el token + datos del usuario
 * 
 * RESPONSE (200 OK):
 * {
 *   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",  // Token para peticiones futuras
 *   "usuario": {
 *     "id": 1,
 *     "username": "juan_perez",
 *     "email": "juan@example.com",
 *     "pais": "Colombia",
 *     "tipo": "usuario"
 *   }
 * }
 * 
 * CÓMO USAR EL TOKEN (desde Flutter):
 * - Guardar el token en almacenamiento seguro (ej: SharedPreferences)
 * - En todas las peticiones posteriores, agregar el header:
 *   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 * - El servidor verificará el token con el middleware verificarToken()
 * 
 * ERRORES POSIBLES:
 * - 400: Email o contraseña no proporcionados
 * - 401: Credenciales incorrectas (email no existe o contraseña es inválida)
 * - 500: Error en la base de datos
 */
router.post('/login', loginLimiter, async (req, res) => {
    const { email, password } = req.body;

    // Validar que lleguen los campos obligatorios
    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contrasena son obligatorios' });
    }

    try {
        // Buscar el usuario por email en la base de datos
        const resultado = await pool.query(
            'SELECT * FROM usuarios WHERE email_usu = $1',
            [email]
        );

        // Si el usuario no existe, rechaza sin decir que el email no existe (seguridad)
        if (resultado.rows.length === 0) {
            return res.status(401).json({ error: 'Credenciales incorrectas' });
        }

        const usuario = resultado.rows[0];

        // Verificar que la contrasena coincida con el hash guardado
        // bcrypt.compare() es segura: tarda siempre el mismo tiempo (evita timing attacks)
        const coincide = await bcrypt.compare(password, usuario.pwhash_usu);
        if (!coincide) {
            return res.status(401).json({ error: 'Credenciales incorrectas' });
        }

        if (usuario.baneado_usu === true) {
            return res.status(403).json({
                error: 'Cuenta suspendida por un administrador',
                motivo: usuario.motivo_ban || null,
            });
        }

        // Access token (JWT, 1h) + refresh token (guardado hasheado en
        // `sesiones`, revocable de verdad) -- ver comentario junto a
        // crearSesion() arriba.
        const token = generarAccessToken(usuario);
        const refreshToken = await crearSesion(usuario.id_usu);

        // Retorna el token + datos públicos del usuario
        // (no incluye el hash de contraseña por seguridad)
        res.json({
            token,
            refreshToken,
            usuario: {
                id: usuario.id_usu,
                username: usuario.username_usu,
                email: usuario.email_usu,
                pais: usuario.pais_usu,
                tipo: usuario.tipo_usu
            }
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


// POST /auth/refresh
// Intercambia un refresh token vivo por un access token nuevo. Rota el
// refresh token en cada uso (se revoca el viejo, se crea uno nuevo) --
// si alguien reutiliza uno ya rotado (señal de que se filtró), la sesión
// completa queda invalidada de una: no hay fila viva con ese hash.
router.post('/refresh', async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) {
        return res.status(400).json({ error: 'refreshToken es obligatorio' });
    }

    try {
        const hash = hashRefreshToken(refreshToken);
        const sesion = await pool.query(
            `SELECT s.id_sesion, s.id_usu, u.username_usu, u.tipo_usu, u.baneado_usu
             FROM sesiones s
             JOIN usuarios u ON u.id_usu = s.id_usu
             WHERE s.refresh_hash = $1
               AND s.revocadaen_sesion IS NULL
               AND s.expiraen_sesion > NOW()`,
            [hash]
        );

        if (sesion.rows.length === 0) {
            return res.status(401).json({ error: 'Sesión inválida o expirada' });
        }

        const fila = sesion.rows[0];

        if (fila.baneado_usu === true) {
            return res.status(403).json({ error: 'Cuenta suspendida por un administrador' });
        }

        await pool.query(
            'UPDATE sesiones SET revocadaen_sesion = NOW() WHERE id_sesion = $1',
            [fila.id_sesion]
        );

        const usuario = { id_usu: fila.id_usu, username_usu: fila.username_usu, tipo_usu: fila.tipo_usu };
        const token = generarAccessToken(usuario);
        const nuevoRefreshToken = await crearSesion(fila.id_usu);

        res.json({ token, refreshToken: nuevoRefreshToken });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /auth/logout
// Revoca el refresh token -- idempotente a propósito (siempre 200,
// exista o no la sesión) para que el cliente pueda "cerrar sesión"
// tranquilo sin manejar un caso especial si ya estaba revocada.
router.post('/logout', async (req, res) => {
    const { refreshToken } = req.body;
    if (refreshToken) {
        await pool.query(
            'UPDATE sesiones SET revocadaen_sesion = NOW() WHERE refresh_hash = $1 AND revocadaen_sesion IS NULL',
            [hashRefreshToken(refreshToken)]
        );
    }
    res.json({ mensaje: 'Sesión cerrada' });
});


// GET /auth/perfil
/**
 * ENDPOINT: GET /auth/perfil
 * 
 * PROPÓSITO:
 * Obtener los datos completos del usuario autenticado.
 * Solo funcionan si se envía un token válido en el header Authorization.
 * 
 * SEGURIDAD:
 * - Requiere autenticación (middleware verificarToken)
 * - Solo cada usuario puede acceder a su propio perfil
 * 
 * REQUEST:
 * Headers requeridos:
 * {
 *   "Authorization": "Bearer <token_jwt>"
 * }
 * 
 * RESPONSE (200 OK):
 * {
 *   "id_usu": 1,
 *   "username_usu": "juan_perez",
 *   "email_usu": "juan@example.com",
 *   "descrip_usu": "Amante de los videojuegos",
 *   "pais_usu": "Colombia",
 *   "repu_usu": 250,
 *   "totalrating_usu": 4.8,
 *   "tipo_usu": "usuario",
 *   "creadoen_usu": "2024-01-15T10:30:00Z"
 * }
 * 
 * FLUJO:
 * 1. El middleware verificarToken valida que el token sea válido
 * 2. Si el token es válido, decodifica y extrae req.usuario.id
 * 3. Busca en BD los datos del usuario con ese id
 * 4. Si no existe (no debería pasar), retorna error 404
 * 5. Si existe, retorna todos los datos del perfil
 * 
 * ERRORES POSIBLES:
 * - 401: Token no proporcionado o inválido/expirado (manejado por verificarToken)
 * - 404: Usuario no encontrado (edge case muy raro)
 * - 500: Error en la base de datos
 */
router.get('/perfil', verificarToken, async (req, res) => {
    try {
        // Obtiene el id del usuario desde el token decodificado (guardado en req.usuario por verificarToken)
        const resultado = await pool.query(
            `SELECT id_usu, username_usu, email_usu, descrip_usu, 
                    pais_usu, repu_usu, totalrating_usu, tipo_usu, creadoen_usu
             FROM usuarios WHERE id_usu = $1`,
            [req.usuario.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const usuario = resultado.rows[0];
        res.json({
            id: usuario.id_usu,
            username: usuario.username_usu,
            email: usuario.email_usu,
            descrip: usuario.descrip_usu,
            pais: usuario.pais_usu,
            repu: usuario.repu_usu,
            totalrating: usuario.totalrating_usu,
            tipo: usuario.tipo_usu,
            creadoen: usuario.creadoen_usu,
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /auth/cambiar-contrasena
// Permite al usuario autenticado actualizar su contraseña actual.
router.put('/cambiar-contrasena', verificarToken, async (req, res) => {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
        return res.status(400).json({ error: 'Contraseña actual y nueva son obligatorias' });
    }

    if (newPassword.length < 8) {
        return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 8 caracteres' });
    }

    try {
        const resultado = await pool.query(
            'SELECT pwhash_usu FROM usuarios WHERE id_usu = $1',
            [req.usuario.id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const usuario = resultado.rows[0];
        const coincide = await bcrypt.compare(currentPassword, usuario.pwhash_usu);
        if (!coincide) {
            return res.status(401).json({ error: 'Contraseña actual incorrecta' });
        }

        const hash = await bcrypt.hash(newPassword, 10);
        await pool.query(
            'UPDATE usuarios SET pwhash_usu = $1 WHERE id_usu = $2',
            [hash, req.usuario.id]
        );

        // Cambiar la contraseña revoca todas las sesiones -- si alguien
        // más tenía acceso (token filtrado), este es el momento en que
        // se le cierra la puerta de verdad. El propio usuario va a tener
        // que iniciar sesión de nuevo, que es el comportamiento esperado.
        await pool.query(
            'UPDATE sesiones SET revocadaen_sesion = NOW() WHERE id_usu = $1 AND revocadaen_sesion IS NULL',
            [req.usuario.id]
        );

        res.json({ mensaje: 'Contraseña actualizada correctamente' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /auth/cuenta
// Elimina la cuenta del usuario autenticado y limpia sus datos relacionados.
//
// usuarios_juegos, perfiles_steam, publicaciones, notificaciones y
// comentario_publicacion tienen ON DELETE CASCADE hacia usuarios y no
// necesitan limpieza manual. matches, calificaciones, chat, mensaje,
// reportes y amistad NO la tienen (referencian usuarios sin CASCADE), así
// que borrar la fila de usuarios sin limpiarlas antes fallaba con una
// violación de llave foránea para cualquier cuenta con historial real
// (match, chat, calificación, reporte o amistad) — "Eliminar cuenta" no
// funcionaba salvo en cuentas nuevas sin actividad. Se limpia todo dentro
// de una transacción para no dejar la cuenta a medio borrar si algo falla.
router.delete('/cuenta', verificarToken, async (req, res) => {
    const id = req.usuario.id;
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // mensaje.parent_mensaje se autorreferencia sin CASCADE: se rompe
        // el hilo antes de borrar para no violar esa llave foránea.
        await client.query(
            `UPDATE mensaje SET parent_mensaje = NULL
             WHERE parent_mensaje IN (
                 SELECT id_mensaje FROM mensaje
                 WHERE id_emisor = $1
                    OR id_chat IN (
                        SELECT id_chat FROM chat
                        WHERE id_participante1 = $1 OR id_participante2 = $1
                    )
             )`,
            [id]
        );
        await client.query(
            `DELETE FROM mensaje
             WHERE id_emisor = $1
                OR id_chat IN (
                    SELECT id_chat FROM chat
                    WHERE id_participante1 = $1 OR id_participante2 = $1
                )`,
            [id]
        );
        await client.query(
            'DELETE FROM chat WHERE id_participante1 = $1 OR id_participante2 = $1',
            [id]
        );
        // calificaciones.id_match referencia matches sin CASCADE: debe
        // borrarse antes que los matches, no después.
        await client.query(
            `DELETE FROM calificaciones
             WHERE id_calificador = $1
                OR id_calificado = $1
                OR id_match IN (
                    SELECT id_match FROM matches
                    WHERE id_solicitante = $1 OR id_receptor = $1
                )`,
            [id]
        );
        await client.query(
            'DELETE FROM matches WHERE id_solicitante = $1 OR id_receptor = $1',
            [id]
        );
        await client.query(
            'DELETE FROM reportes WHERE id_reportador = $1 OR id_reportado = $1',
            [id]
        );
        await client.query(
            'DELETE FROM amistad WHERE id_solicitante = $1 OR id_receptor = $1',
            [id]
        );
        await client.query('DELETE FROM usuarios WHERE id_usu = $1', [id]);

        await client.query('COMMIT');
        res.json({ mensaje: 'Cuenta eliminada correctamente' });
    } catch (err) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
});

module.exports = { router, verificarToken };

/**
 * EXPORTACIONES:
 * 
 * 1. router: El enrutador de Express con los endpoints de autenticación
 *    Uso: app.use('/auth', router);
 *    Endpoints disponibles:
 *    - POST /auth/registro      -> crear nueva cuenta
 *    - POST /auth/login         -> iniciar sesión
 *    - GET /auth/perfil         -> obtener datos del usuario (requiere token)
 * 
 * 2. verificarToken: Middleware de autenticación
 *    Uso: router.get('/ruta-protegida', verificarToken, (req, res) => ...)
 *    Propósito: Proteger rutas que requieren que el usuario esté autenticado
 *    Este middleware se usa en otros archivos de rutas (ej: perfil.js, publicaciones.js)
 * 
 * VARIABLES DE ENTORNO REQUERIDAS en .env:
 * - JWT_SECRET: Clave secreta para firmar tokens (ej: "tu_clave_super_secreta_123")
 * - DATABASE_URL: conexión a PostgreSQL (ej: "postgresql://user:pass@localhost/steamlinker")
 * 
 * FLUJO COMPLETO DE AUTENTICACIÓN:
 * 
 * 1. REGISTRO:
 *    Usuario envía: POST /auth/registro con {username, email, password, pais}
 *    API: valida, encripta contraseña, inserta en BD, genera token
 *    Respuesta: {token, usuario}
 * 
 * 2. LOGIN:
 *    Usuario envía: POST /auth/login con {email, password}
 *    API: busca usuario, verifica contraseña, genera token
 *    Respuesta: {token, usuario}
 * 
 * 3. USO DEL TOKEN:
 *    App Flutter: guarda el token (ej: SharedPreferences)
 *    En peticiones posteriores: agrega header "Authorization: Bearer <token>"
 *    API: middleware verificarToken valida el token
 *    Si es válido: req.usuario contiene datos del token, continúa
 *    Si es inválido/expirado: devuelve error 401
 * 
 * 4. OBTENER PERFIL:
 *    Usuario envía: GET /auth/perfil con header Authorization
 *    API: middleware verifica token, obtiene perfil completo
 *    Respuesta: {id, username, email, pais, reputación, etc}
 */

