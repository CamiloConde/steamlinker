// Cubre el flujo de solicitudes de amistad, incluyendo un bug real
// encontrado en QA (ver HANDOFF.md): rechazar una solicitud bloqueaba
// para siempre volver a enviarla, sin importar cuánto tiempo pasara.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenA, idA, usernameA;
let tokenB, idB, usernameB;

before(async () => {
    usernameA = usernameUnico('test_amistad_a');
    const resA = await request(app).post('/auth/registro').send({
        username: usernameA,
        email: `${usernameA}@example.com`,
        password: 'Passw0rd123',
    });
    tokenA = resA.body.token;
    idA = resA.body.usuario.id;

    usernameB = usernameUnico('test_amistad_b');
    const resB = await request(app).post('/auth/registro').send({
        username: usernameB,
        email: `${usernameB}@example.com`,
        password: 'Passw0rd123',
    });
    tokenB = resB.body.token;
    idB = resB.body.usuario.id;
});

after(async () => {
    await pool.query(
        'DELETE FROM amistad WHERE (id_solicitante = $1 OR id_receptor = $1) AND (id_solicitante = $2 OR id_receptor = $2)',
        [idA, idB]
    );
    await limpiarUsuario(usernameA);
    await limpiarUsuario(usernameB);
    await pool.end();
});

test('enviar solicitud duplicada mientras esta pendiente devuelve 409', async () => {
    const res1 = await request(app)
        .post('/amistad/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    assert.equal(res1.status, 201);
    assert.equal(res1.body.estado_amistad, 'Pendiente');

    const res2 = await request(app)
        .post('/amistad/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    assert.equal(res2.status, 409);

    // Limpieza para el siguiente test
    await pool.query('DELETE FROM amistad WHERE id_amistad = $1', [res1.body.id_amistad]);
});

test('rechazar una solicitud NO bloquea para siempre volver a enviarla (bug real corregido)', async () => {
    const enviar1 = await request(app)
        .post('/amistad/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    assert.equal(enviar1.status, 201);

    const rechazar = await request(app)
        .put(`/amistad/${enviar1.body.id_amistad}/responder`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ estado: 'Rechazada' });
    assert.equal(rechazar.status, 200);
    assert.equal(rechazar.body.estado_amistad, 'Rechazada');

    const enviar2 = await request(app)
        .post('/amistad/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    assert.equal(enviar2.status, 201);
    assert.equal(enviar2.body.estado_amistad, 'Pendiente');
});

test('aceptar una solicitud los deja como amigos, y ya no se puede volver a enviar otra', async () => {
    const solicitudes = await request(app)
        .get('/amistad/solicitudes')
        .set('Authorization', `Bearer ${tokenB}`);
    const pendiente = solicitudes.body.solicitudes.find((s) => s.id_solicitante === idA);
    assert.ok(pendiente, 'debe existir la solicitud pendiente del test anterior');

    const aceptar = await request(app)
        .put(`/amistad/${pendiente.id_amistad}/responder`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ estado: 'Aceptada' });
    assert.equal(aceptar.status, 200);
    assert.equal(aceptar.body.estado_amistad, 'Aceptada');

    const amigosA = await request(app)
        .get('/amistad/amigos')
        .set('Authorization', `Bearer ${tokenA}`);
    assert.ok(amigosA.body.amigos.some((a) => a.amigo_id === idB));

    const reintento = await request(app)
        .post('/amistad/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    assert.equal(reintento.status, 409);
});
