// Cubre el filtro multi-tipo de GET /publicaciones/buscar, necesario para
// el conmutador Familia (busco_familia+busco_miembros) dentro de
// Publicaciones (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let token;
let username;

before(async () => {
    username = usernameUnico('test_buscar');
    const res = await request(app).post('/auth/registro').send({
        username,
        email: `${username}@example.com`,
        password: 'Passw0rd123',
    });
    token = res.body.token;

    await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_companero', titulo: 'Companero de prueba' });

    await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'otro', titulo: 'Comunidad de prueba' });
});

after(async () => {
    await limpiarUsuario(username);
    await pool.end();
});

test('filtro con un solo tipo devuelve solo ese tipo', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    assert.ok(res.body.publicaciones.every((p) => p.tipo_publi === 'otro'));
    assert.ok(res.body.publicaciones.some((p) => p.titulo_publi === 'Comunidad de prueba'));
});

test('filtro con varios tipos separados por coma devuelve la union', async () => {
    const res = await request(app)
        .get('/publicaciones/buscar')
        .query({ tipo: 'busco_companero,otro' });

    assert.equal(res.status, 200);
    const tipos = res.body.publicaciones.map((p) => p.tipo_publi);
    assert.ok(tipos.includes('busco_companero'));
    assert.ok(tipos.includes('otro'));
});

test('sin filtro de tipo no excluye nada por tipo', async () => {
    const res = await request(app).get('/publicaciones/buscar');
    assert.equal(res.status, 200);
    assert.ok(res.body.total >= 2);
});

test('cada publicacion trae cupos_ocupados', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    assert.ok(res.body.publicaciones.every((p) => typeof p.cupos_ocupados === 'number'));
});

test('sin token, juegos_en_comun y su muestra vienen null (no hay con quien comparar)', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    const publi = res.body.publicaciones.find((p) => p.titulo_publi === 'Comunidad de prueba');
    assert.equal(publi.juegos_en_comun, null);
    assert.equal(publi.juegos_comunes_muestra, null);
});

test('con token, juegos_en_comun solo cuenta biblioteca verificada del autor vs quien mira', async () => {
    const viewer = usernameUnico('test_buscar_viewer');
    const resViewer = await request(app).post('/auth/registro').send({
        username: viewer,
        email: `${viewer}@example.com`,
        password: 'Passw0rd123',
    });
    const tokenViewer = resViewer.body.token;

    // Juego agregado a mano por ambos -- no debe contar como en comun.
    for (const t of [token, tokenViewer]) {
        await request(app)
            .post('/perfil/juegos/agregar')
            .set('Authorization', `Bearer ${t}`)
            .send({ appid: 991100, nombre: 'Juego manual compartido' });
    }
    // Juego "verificado" (origen steam) por ambos -- este si debe contar.
    for (const t of [token, tokenViewer]) {
        await request(app)
            .post('/perfil/juegos/agregar')
            .set('Authorization', `Bearer ${t}`)
            .send({ appid: 991101, nombre: 'Juego verificado compartido' });
    }
    await pool.query(`UPDATE usuarios_juegos SET origen_usujg = 'steam' WHERE appid = 991101`);

    const res = await request(app)
        .get('/publicaciones/buscar')
        .query({ tipo: 'otro' })
        .set('Authorization', `Bearer ${tokenViewer}`);

    assert.equal(res.status, 200);
    const publi = res.body.publicaciones.find((p) => p.titulo_publi === 'Comunidad de prueba');
    assert.equal(publi.juegos_en_comun, 1);
    assert.equal(publi.juegos_comunes_muestra.length, 1);
    assert.equal(publi.juegos_comunes_muestra[0].appid, 991101);

    await limpiarUsuario(viewer);
});

test('juegos de la publicacion traen origen_pjg real (no lo que mande el cliente)', async () => {
    const appid = 992200;
    await request(app)
        .post('/perfil/juegos/agregar')
        .set('Authorization', `Bearer ${token}`)
        .send({ appid, nombre: 'Juego origen test' });

    // Manual todavia -- una publicacion creada ahora debe guardar 'manual'
    // sin importar si el cliente mandara otra cosa (no se manda nada, el
    // backend lo calcula solo).
    const resManual = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({
            tipo: 'otro',
            titulo: 'Publi origen manual',
            juegos: [{ appid, nombre: 'Juego origen test' }],
        });
    assert.equal(resManual.status, 201);

    const buscarManual = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiManual = buscarManual.body.publicaciones.find((p) => p.titulo_publi === 'Publi origen manual');
    assert.equal(publiManual.juegos[0].origen_pjg, 'manual');

    // Ahora se "verifica" (simula import real de Steam) y se crea OTRA
    // publicacion con el mismo juego -- debe guardar 'steam' esta vez,
    // sin tocar la publicacion anterior (el origen queda fijo al momento
    // de asociarlo, no se recalcula despues).
    await pool.query(`UPDATE usuarios_juegos SET origen_usujg = 'steam' WHERE id_usu = $1 AND appid = $2`, [
        (await pool.query('SELECT id_usu FROM usuarios WHERE username_usu = $1', [username])).rows[0].id_usu,
        appid,
    ]);

    const resSteam = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({
            tipo: 'otro',
            titulo: 'Publi origen steam',
            juegos: [{ appid, nombre: 'Juego origen test' }],
        });
    assert.equal(resSteam.status, 201);

    const buscarSteam = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiSteam = buscarSteam.body.publicaciones.find((p) => p.titulo_publi === 'Publi origen steam');
    assert.equal(publiSteam.juegos[0].origen_pjg, 'steam');

    // La publicacion vieja no cambia retroactivamente.
    const buscarManual2 = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiManual2 = buscarManual2.body.publicaciones.find((p) => p.titulo_publi === 'Publi origen manual');
    assert.equal(publiManual2.juegos[0].origen_pjg, 'manual');
});
