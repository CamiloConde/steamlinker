// Login con Steam (OpenID 2.0) — cubre lo que se puede probar sin depender
// de una cuenta real de Steam ni de la red: que /iniciar exige sesión y
// arma la URL correctamente, y que /callback rechaza los casos inválidos
// (sin state, state ajeno/expirado, cancelado, proveedor equivocado) SIN
// necesitar llamar a Steam — esos son los mismos controles de seguridad
// que protegen el paso real de verificación (check_authentication), que sí
// requiere red real y queda fuera de esta suite. Ver HANDOFF.md.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, usernameUnico, limpiarUsuario } = require('./helpers');

let token, username;

before(async () => {
    username = usernameUnico('test_steamopenid');
    const res = await request(app).post('/auth/registro').send({
        username,
        email: `${username}@example.com`,
        password: 'Passw0rd123',
    });
    token = res.body.token;
});

after(async () => {
    await limpiarUsuario(username);
});

test('GET /steam/openid/iniciar sin token devuelve 401', async () => {
    const res = await request(app).get('/perfil/steam/openid/iniciar');
    assert.equal(res.status, 401);
});

test('GET /steam/openid/iniciar arma la URL de Steam con un state de un solo uso', async () => {
    const res = await request(app)
        .get('/perfil/steam/openid/iniciar')
        .set('Authorization', `Bearer ${token}`);

    assert.equal(res.status, 200);
    assert.ok(res.body.url.startsWith('https://steamcommunity.com/openid/login?'));

    const url = new URL(res.body.url);
    assert.equal(url.searchParams.get('openid.mode'), 'checkid_setup');
    assert.equal(url.searchParams.get('openid.ns'), 'http://specs.openid.net/auth/2.0');
    const returnTo = url.searchParams.get('openid.return_to');
    assert.ok(returnTo.includes('/perfil/steam/openid/callback?state='));
});

test('GET /steam/openid/callback sin state redirige a error (sesion_expirada)', async () => {
    const res = await request(app).get('/perfil/steam/openid/callback');
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /steam=error&motivo=sesion_expirada/);
});

test('GET /steam/openid/callback con un state que no existe redirige a error', async () => {
    const res = await request(app).get('/perfil/steam/openid/callback?state=state_inventado');
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /steam=error&motivo=sesion_expirada/);
});

test('un state ya usado no puede reutilizarse (consumo de un solo uso)', async () => {
    const inicio = await request(app)
        .get('/perfil/steam/openid/iniciar')
        .set('Authorization', `Bearer ${token}`);
    const url = new URL(inicio.body.url);
    const state = url.searchParams.get('openid.return_to').match(/state=([a-f0-9]+)/)[1];

    // Primer uso: mode cancelado (no llega a llamar a Steam), pero consume el state.
    const primero = await request(app).get(`/perfil/steam/openid/callback?state=${state}`);
    assert.equal(primero.status, 302);
    assert.match(primero.headers.location, /steam=error&motivo=cancelado/);

    // Segundo uso del mismo state: ya no existe.
    const segundo = await request(app).get(`/perfil/steam/openid/callback?state=${state}`);
    assert.equal(segundo.status, 302);
    assert.match(segundo.headers.location, /steam=error&motivo=sesion_expirada/);
});

test('un op_endpoint distinto al de Steam se rechaza antes de verificar la firma', async () => {
    const inicio = await request(app)
        .get('/perfil/steam/openid/iniciar')
        .set('Authorization', `Bearer ${token}`);
    const url = new URL(inicio.body.url);
    const state = url.searchParams.get('openid.return_to').match(/state=([a-f0-9]+)/)[1];

    const res = await request(app).get(
        `/perfil/steam/openid/callback?state=${state}&openid.mode=id_res&openid.op_endpoint=https://evil.example.com/openid/login`
    );
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /steam=error&motivo=proveedor_invalido/);
});
