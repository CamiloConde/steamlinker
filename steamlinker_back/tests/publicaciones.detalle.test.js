// Cubre el roster "confirmados" de GET /publicaciones/:id, necesario para
// el panel de cupos del detalle de publicacion (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenAutor, autor, idAutor;
let tokenSolicitante, solicitante;
let idPubli;

before(async () => {
    autor = usernameUnico('test_detalle_autor');
    const resAutor = await request(app).post('/auth/registro').send({
        username: autor,
        email: `${autor}@example.com`,
        password: 'Passw0rd123',
    });
    tokenAutor = resAutor.body.token;
    idAutor = resAutor.body.usuario.id;

    solicitante = usernameUnico('test_detalle_solic');
    const resSolic = await request(app).post('/auth/registro').send({
        username: solicitante,
        email: `${solicitante}@example.com`,
        password: 'Passw0rd123',
    });
    tokenSolicitante = resSolic.body.token;

    const resPubli = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ tipo: 'busco_companero', titulo: 'Prueba detalle', cupos_totales: 4 });
    idPubli = resPubli.body.id_publi;

    const resMatch = await request(app)
        .post('/matches/enviar')
        .set('Authorization', `Bearer ${tokenSolicitante}`)
        .send({ id_receptor: idAutor, id_publi: idPubli });

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

test('el detalle trae confirmados con el solicitante aceptado', async () => {
    const res = await request(app).get(`/publicaciones/${idPubli}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.cupos_ocupados, 1);
    assert.equal(res.body.confirmados.length, 1);
    assert.equal(res.body.confirmados[0].username_usu, solicitante);
});
