// Cubre el contexto de match ("Match por: juego · N/M") que
// GET /chat/conversaciones agrega a cada fila, necesario para la franja de
// contexto del chat flotante (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenAutor, autor, idAutor;
let tokenSolicitante, solicitante, idSolicitante;
let idPubli;

before(async () => {
    autor = usernameUnico('test_chatctx_autor');
    const resAutor = await request(app).post('/auth/registro').send({
        username: autor,
        email: `${autor}@example.com`,
        password: 'Passw0rd123',
    });
    tokenAutor = resAutor.body.token;
    idAutor = resAutor.body.usuario.id;

    solicitante = usernameUnico('test_chatctx_solic');
    const resSolic = await request(app).post('/auth/registro').send({
        username: solicitante,
        email: `${solicitante}@example.com`,
        password: 'Passw0rd123',
    });
    tokenSolicitante = resSolic.body.token;
    idSolicitante = resSolic.body.usuario.id;

    const resPubli = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({
            tipo: 'busco_companero',
            titulo: 'Prueba contexto de chat',
            cupos_totales: 4,
            juegos: [{ appid: 990992, nombre: 'Juego de contexto' }],
        });
    idPubli = resPubli.body.id_publi;

    const resMatch = await request(app)
        .post('/matches/enviar')
        .set('Authorization', `Bearer ${tokenSolicitante}`)
        .send({ id_receptor: idAutor, id_publi: idPubli });

    // Aceptar crea el chat automaticamente.
    await request(app)
        .put(`/matches/${resMatch.body.id_match}/responder`)
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ estado: 'Aceptada' });
});

after(async () => {
    await pool.query('DELETE FROM chat WHERE id_participante1 = $1 OR id_participante2 = $1', [idAutor]);
    await pool.query('DELETE FROM matches WHERE id_publi = $1', [idPubli]);
    await limpiarUsuario(autor);
    await limpiarUsuario(solicitante);
    await pool.end();
});

test('conversaciones trae el contexto del match aceptado (juego y cupos)', async () => {
    const res = await request(app)
        .get('/chat/conversaciones')
        .set('Authorization', `Bearer ${tokenAutor}`);

    assert.equal(res.status, 200);
    const fila = res.body.conversaciones.find((c) => c.otro_id === idSolicitante);
    assert.ok(fila, 'debe existir la conversacion con el solicitante');
    assert.equal(fila.match_juego_nombre, 'Juego de contexto');
    assert.equal(fila.match_cupos_totales, 4);
    assert.equal(fila.match_cupos_ocupados, 1);
});
