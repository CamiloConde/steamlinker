// Cubre el enriquecimiento de GET /matches/recibidos con datos de la
// publicacion asociada (tipo, titulo, cupos), necesario para la bandeja de
// solicitudes pendientes de Inicio (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenAutor, autor;
let tokenSolicitante, solicitante;
let idPubli;

before(async () => {
    autor = usernameUnico('test_recibidos_autor');
    const resAutor = await request(app).post('/auth/registro').send({
        username: autor,
        email: `${autor}@example.com`,
        password: 'Passw0rd123',
    });
    tokenAutor = resAutor.body.token;

    solicitante = usernameUnico('test_recibidos_solic');
    const resSolic = await request(app).post('/auth/registro').send({
        username: solicitante,
        email: `${solicitante}@example.com`,
        password: 'Passw0rd123',
    });
    tokenSolicitante = resSolic.body.token;

    const resPubli = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ tipo: 'busco_companero', titulo: 'Companero para probar recibidos', cupos_totales: 4 });
    idPubli = resPubli.body.id_publi;

    await request(app)
        .post('/matches/enviar')
        .set('Authorization', `Bearer ${tokenSolicitante}`)
        .send({ id_receptor: resAutor.body.usuario.id, id_publi: idPubli });
});

after(async () => {
    // El match referencia a ambos usuarios por llave foranea: hay que
    // borrarlo antes de poder borrar los usuarios de prueba.
    await pool.query('DELETE FROM matches WHERE id_publi = $1', [idPubli]);
    await limpiarUsuario(autor);
    await limpiarUsuario(solicitante);
    await pool.end();
});

test('recibidos incluye tipo_publi, titulo_publi y cupos de la publicacion asociada', async () => {
    const res = await request(app)
        .get('/matches/recibidos')
        .set('Authorization', `Bearer ${tokenAutor}`);

    assert.equal(res.status, 200);
    const match = res.body.matches.find((m) => m.id_publi === idPubli);
    assert.ok(match, 'debe existir el match recien creado');
    assert.equal(match.tipo_publi, 'busco_companero');
    assert.equal(match.titulo_publi, 'Companero para probar recibidos');
    assert.equal(match.cupos_totales, 4);
    assert.equal(match.cupos_ocupados, 0);
});
