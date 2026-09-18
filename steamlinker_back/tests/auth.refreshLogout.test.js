// Rotacion/revocacion de JWT (Nivel 1, ver HANDOFF.md): el JWT solo ya no
// alcanza para poder cerrar sesion de verdad (ni al banear a alguien). Este
// test cubre el ciclo completo del refresh token: emision, rotacion, reuso
// detectado, logout, y revocacion al banear.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let username, email;

before(async () => {
    username = usernameUnico('test_refresh');
    email = `${username}@example.com`;
});

after(async () => {
    await limpiarUsuario(username);
    await pool.end();
});

test('login devuelve token y refreshToken', async () => {
    await request(app).post('/auth/registro').send({
        username,
        email,
        password: 'Passw0rd123',
    });

    const res = await request(app).post('/auth/login').send({
        email,
        password: 'Passw0rd123',
    });

    assert.equal(res.status, 200);
    assert.ok(res.body.token);
    assert.ok(res.body.refreshToken);
});

test('POST /auth/refresh cambia el access token y rota el refresh token', async () => {
    const login = await request(app).post('/auth/login').send({ email, password: 'Passw0rd123' });
    const refreshOriginal = login.body.refreshToken;

    const res = await request(app).post('/auth/refresh').send({ refreshToken: refreshOriginal });

    assert.equal(res.status, 200);
    assert.ok(res.body.token);
    assert.ok(res.body.refreshToken);
    assert.notEqual(res.body.refreshToken, refreshOriginal);
});

test('reutilizar un refresh token ya rotado se rechaza (detección de reuso)', async () => {
    const login = await request(app).post('/auth/login').send({ email, password: 'Passw0rd123' });
    const refreshOriginal = login.body.refreshToken;

    await request(app).post('/auth/refresh').send({ refreshToken: refreshOriginal });
    const segundoIntento = await request(app).post('/auth/refresh').send({ refreshToken: refreshOriginal });

    assert.equal(segundoIntento.status, 401);
});

test('refresh token inexistente devuelve 401', async () => {
    const res = await request(app).post('/auth/refresh').send({ refreshToken: 'no-existe-esto' });
    assert.equal(res.status, 401);
});

test('POST /auth/refresh sin refreshToken devuelve 400', async () => {
    const res = await request(app).post('/auth/refresh').send({});
    assert.equal(res.status, 400);
});

test('POST /auth/logout revoca el refresh token -- ya no sirve para refrescar', async () => {
    const login = await request(app).post('/auth/login').send({ email, password: 'Passw0rd123' });
    const refreshToken = login.body.refreshToken;

    const logout = await request(app).post('/auth/logout').send({ refreshToken });
    assert.equal(logout.status, 200);

    const intentoRefresh = await request(app).post('/auth/refresh').send({ refreshToken });
    assert.equal(intentoRefresh.status, 401);
});

test('POST /auth/logout es idempotente (token ya revocado o inexistente, igual 200)', async () => {
    const res = await request(app).post('/auth/logout').send({ refreshToken: 'lo-que-sea' });
    assert.equal(res.status, 200);
});

test('cambiar la contraseña revoca las sesiones activas', async () => {
    const login = await request(app).post('/auth/login').send({ email, password: 'Passw0rd123' });
    const { token, refreshToken } = login.body;

    const cambio = await request(app)
        .put('/auth/cambiar-contrasena')
        .set('Authorization', `Bearer ${token}`)
        .send({ currentPassword: 'Passw0rd123', newPassword: 'Passw0rd456' });
    assert.equal(cambio.status, 200);

    const intentoRefresh = await request(app).post('/auth/refresh').send({ refreshToken });
    assert.equal(intentoRefresh.status, 401);

    // Se deja la contraseña como estaba para no romper los tests siguientes
    // de este archivo si el runner los reordena.
    const nuevoLogin = await request(app).post('/auth/login').send({ email, password: 'Passw0rd456' });
    await request(app)
        .put('/auth/cambiar-contrasena')
        .set('Authorization', `Bearer ${nuevoLogin.body.token}`)
        .send({ currentPassword: 'Passw0rd456', newPassword: 'Passw0rd123' });
});

test('banear a un usuario revoca sus sesiones activas', async () => {
    const objetivo = usernameUnico('test_refresh_baneado');
    const emailObjetivo = `${objetivo}@example.com`;
    const registro = await request(app).post('/auth/registro').send({
        username: objetivo,
        email: emailObjetivo,
        password: 'Passw0rd123',
    });
    const refreshToken = registro.body.refreshToken;
    const idObjetivo = registro.body.usuario.id;

    // Promovido directo en BD (no hay endpoint para esto, es intencional).
    const admin = usernameUnico('test_refresh_admin');
    const emailAdmin = `${admin}@example.com`;
    const registroAdmin = await request(app).post('/auth/registro').send({
        username: admin,
        email: emailAdmin,
        password: 'Passw0rd123',
    });
    await pool.query('UPDATE usuarios SET tipo_usu = $1 WHERE id_usu = $2', ['admin', registroAdmin.body.usuario.id]);
    const loginAdmin = await request(app).post('/auth/login').send({ email: emailAdmin, password: 'Passw0rd123' });

    const ban = await request(app)
        .post(`/api/admin/usuarios/${idObjetivo}/ban`)
        .set('Authorization', `Bearer ${loginAdmin.body.token}`)
        .send({ motivo: 'prueba automatizada' });
    assert.equal(ban.status, 200);

    const intentoRefresh = await request(app).post('/auth/refresh').send({ refreshToken });
    assert.equal(intentoRefresh.status, 401);

    await limpiarUsuario(objetivo);
    await limpiarUsuario(admin);
});
