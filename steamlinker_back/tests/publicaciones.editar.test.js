// PUT /publicaciones/:id/editar -- antes no existía ninguna forma de
// corregir una publicación ya creada (había que borrarla y volver a
// hacerla). El usuario lo pidió explícitamente. Ver HANDOFF.md.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenAutor, idAutor, autor;
let tokenOtro, otro;
let tokenTercero, tercero;
let idPubli;

before(async () => {
    autor = usernameUnico('test_editar_autor');
    const resAutor = await request(app).post('/auth/registro').send({
        username: autor,
        email: `${autor}@example.com`,
        password: 'Passw0rd123',
    });
    tokenAutor = resAutor.body.token;
    idAutor = resAutor.body.usuario.id;

    otro = usernameUnico('test_editar_otro');
    const resOtro = await request(app).post('/auth/registro').send({
        username: otro,
        email: `${otro}@example.com`,
        password: 'Passw0rd123',
    });
    tokenOtro = resOtro.body.token;

    tercero = usernameUnico('test_editar_tercero');
    const resTercero = await request(app).post('/auth/registro').send({
        username: tercero,
        email: `${tercero}@example.com`,
        password: 'Passw0rd123',
    });
    tokenTercero = resTercero.body.token;

    const resPubli = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({
            tipo: 'busco_companero',
            titulo: 'Título original',
            descripcion: 'Descripción original',
            cupos_totales: 4,
        });
    idPubli = resPubli.body.id_publi;
});

after(async () => {
    await pool.query('DELETE FROM chat WHERE id_participante1 = $1 OR id_participante2 = $1', [idAutor]);
    await pool.query('DELETE FROM matches WHERE id_publi = $1', [idPubli]);
    await limpiarUsuario(autor);
    await limpiarUsuario(otro);
    await limpiarUsuario(tercero);
    await pool.end();
});

test('el autor puede editar título, descripción y cupos de su publicación', async () => {
    const res = await request(app)
        .put(`/publicaciones/${idPubli}/editar`)
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({
            titulo: 'Título corregido',
            descripcion: 'Descripción corregida',
            cupos_totales: 3,
        });

    assert.equal(res.status, 200);
    assert.equal(res.body.titulo_publi, 'Título corregido');
    assert.equal(res.body.descrip_publi, 'Descripción corregida');
    assert.equal(res.body.cupos_totales, 3);
});

test('sin título devuelve 400', async () => {
    const res = await request(app)
        .put(`/publicaciones/${idPubli}/editar`)
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ descripcion: 'sin título' });

    assert.equal(res.status, 400);
});

test('otro usuario no puede editar una publicación que no es suya', async () => {
    const res = await request(app)
        .put(`/publicaciones/${idPubli}/editar`)
        .set('Authorization', `Bearer ${tokenOtro}`)
        .send({ titulo: 'Intento ajeno' });

    assert.equal(res.status, 403);
});

test('publicación inexistente devuelve 404', async () => {
    const res = await request(app)
        .put('/publicaciones/99999999/editar')
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ titulo: 'No existe' });

    assert.equal(res.status, 404);
});

test('no se puede bajar cupos_totales por debajo de lo ya ocupado', async () => {
    // Dos matches aceptados -> 2 cupos ocupados de verdad.
    for (const token of [tokenOtro, tokenTercero]) {
        const resMatch = await request(app)
            .post('/matches/enviar')
            .set('Authorization', `Bearer ${token}`)
            .send({ id_receptor: idAutor, id_publi: idPubli });

        await request(app)
            .put(`/matches/${resMatch.body.id_match}/responder`)
            .set('Authorization', `Bearer ${tokenAutor}`)
            .send({ estado: 'Aceptada' });
    }

    const bajarDeMasOcupado = await request(app)
        .put(`/publicaciones/${idPubli}/editar`)
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ titulo: 'Título corregido', cupos_totales: 1 });
    assert.equal(bajarDeMasOcupado.status, 400);

    const igualOcupado = await request(app)
        .put(`/publicaciones/${idPubli}/editar`)
        .set('Authorization', `Bearer ${tokenAutor}`)
        .send({ titulo: 'Título corregido', cupos_totales: 2 });
    assert.equal(igualOcupado.status, 200);
});
