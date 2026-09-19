// Cubre POST /calificaciones/crear, incluyendo una vulnerabilidad real
// encontrada en QA (ver HANDOFF.md): id_calificado no se validaba contra
// los participantes reales del match, así que cualquier usuario podía
// citar un match propio aceptado y calificar a un tercero arbitrario,
// manipulando la reputación de cualquiera en el sistema.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenA, idA, usernameA;
let tokenB, idB, usernameB;
let tokenC, idC, usernameC;
let idMatch;

before(async () => {
    usernameA = usernameUnico('test_cali_a');
    const resA = await request(app).post('/auth/registro').send({
        username: usernameA,
        email: `${usernameA}@example.com`,
        password: 'Passw0rd123',
    });
    tokenA = resA.body.token;
    idA = resA.body.usuario.id;

    usernameB = usernameUnico('test_cali_b');
    const resB = await request(app).post('/auth/registro').send({
        username: usernameB,
        email: `${usernameB}@example.com`,
        password: 'Passw0rd123',
    });
    tokenB = resB.body.token;
    idB = resB.body.usuario.id;

    usernameC = usernameUnico('test_cali_c');
    const resC = await request(app).post('/auth/registro').send({
        username: usernameC,
        email: `${usernameC}@example.com`,
        password: 'Passw0rd123',
    });
    tokenC = resC.body.token;
    idC = resC.body.usuario.id;

    const enviar = await request(app)
        .post('/matches/enviar')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_receptor: idB });
    idMatch = enviar.body.id_match;

    await request(app)
        .put(`/matches/${idMatch}/responder`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ estado: 'Aceptada' });
});

after(async () => {
    await pool.query('DELETE FROM calificaciones WHERE id_match = $1', [idMatch]);
    await pool.query('DELETE FROM chat WHERE id_participante1 = $1 OR id_participante2 = $1', [idA]);
    await pool.query('DELETE FROM matches WHERE id_match = $1', [idMatch]);
    await limpiarUsuario(usernameA);
    await limpiarUsuario(usernameB);
    await limpiarUsuario(usernameC);
    await pool.end();
});

test('no se puede calificar a un tercero ajeno al match, aunque el match citado sea real y propio', async () => {
    const res = await request(app)
        .post('/calificaciones/crear')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_match: idMatch, id_calificado: idC, estrellas: 5 });
    assert.equal(res.status, 403);
});

test('no se puede autocalificar citando un match propio', async () => {
    const res = await request(app)
        .post('/calificaciones/crear')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_match: idMatch, id_calificado: idA, estrellas: 5 });
    assert.equal(res.status, 403);
});

test('calificar al participante real del match funciona y actualiza su reputacion', async () => {
    const res = await request(app)
        .post('/calificaciones/crear')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_match: idMatch, id_calificado: idB, estrellas: 4, comentario: 'buen compa' });
    assert.equal(res.status, 201);
    assert.equal(res.body.id_calificado, idB);

    const perfil = await request(app)
        .get('/calificaciones/usuario/' + idB)
        .set('Authorization', `Bearer ${tokenA}`);
    assert.equal(Number(perfil.body.promedio), 4);
    assert.equal(perfil.body.total_ratings, 1);
});

test('no se puede calificar dos veces al mismo usuario en el mismo match', async () => {
    const res = await request(app)
        .post('/calificaciones/crear')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ id_match: idMatch, id_calificado: idB, estrellas: 1 });
    assert.equal(res.status, 409);
});
