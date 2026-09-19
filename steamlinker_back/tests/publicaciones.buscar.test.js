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

test('intencion_pjg distingue juegos que tengo (en mi biblioteca) de juegos que busco (no los tengo)', async () => {
    const appidTengo = 992300;
    const appidBusco = 992301;

    // Solo se agrega a la biblioteca el que "tengo" -- el que "busco" nunca
    // pasa por /perfil/juegos/agregar, solo se manda directo al crear la
    // publicacion (asi es como llega un juego elegido del buscador libre
    // "Juegos que buscas", que no implica que el usuario lo posea).
    await request(app)
        .post('/perfil/juegos/agregar')
        .set('Authorization', `Bearer ${token}`)
        .send({ appid: appidTengo, nombre: 'Juego que tengo' });

    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({
            tipo: 'otro',
            titulo: 'Publi intencion test',
            juegos: [
                { appid: appidTengo, nombre: 'Juego que tengo' },
                { appid: appidBusco, nombre: 'Juego que busco' },
            ],
        });
    assert.equal(res.status, 201);

    const buscar = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publi = buscar.body.publicaciones.find((p) => p.titulo_publi === 'Publi intencion test');
    const jgTengo = publi.juegos.find((j) => j.appid === appidTengo);
    const jgBusco = publi.juegos.find((j) => j.appid === appidBusco);
    assert.equal(jgTengo.intencion_pjg, 'tengo');
    assert.equal(jgBusco.intencion_pjg, 'busco');
});

test('autor_steam_vinculado refleja si el autor tiene Steam vinculado, en /buscar y en el detalle', async () => {
    const resSinSteam = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'otro', titulo: 'Publi autor sin Steam' });
    assert.equal(resSinSteam.status, 201);

    const buscarSinSteam = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiSinSteam = buscarSinSteam.body.publicaciones.find(
        (p) => p.titulo_publi === 'Publi autor sin Steam'
    );
    assert.equal(publiSinSteam.autor_steam_vinculado, false);

    const detalleSinSteam = await request(app).get(`/publicaciones/${resSinSteam.body.id_publi}`);
    assert.equal(detalleSinSteam.body.autor_steam_vinculado, false);

    // Ahora se vincula Steam (fila directa, mismo patron que el resto de
    // los tests -- el gate real de OpenID no se puede automatizar) y se
    // crea OTRA publicacion del mismo autor.
    const idUsu = (
        await pool.query('SELECT id_usu FROM usuarios WHERE username_usu = $1', [username])
    ).rows[0].id_usu;
    await pool.query(
        `INSERT INTO perfiles_steam (id_usu, steam_id, username_steperfil, avatar_url, perfil_url)
         VALUES ($1, $2, 'Test Buscar', null, null)`,
        [idUsu, `7656119${Date.now()}`.slice(0, 17)]
    );

    const resConSteam = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'otro', titulo: 'Publi autor con Steam' });
    assert.equal(resConSteam.status, 201);

    const buscarConSteam = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiConSteam = buscarConSteam.body.publicaciones.find(
        (p) => p.titulo_publi === 'Publi autor con Steam'
    );
    assert.equal(publiConSteam.autor_steam_vinculado, true);

    const detalleConSteam = await request(app).get(`/publicaciones/${resConSteam.body.id_publi}`);
    assert.equal(detalleConSteam.body.autor_steam_vinculado, true);

    // La publicacion vieja del mismo autor tambien debe reflejar el
    // vinculo ahora -- a diferencia de origen_pjg (que queda fijo por
    // juego), esto es un EXISTS en vivo sobre el autor, no algo que se
    // guarde en el momento de crear la publicacion.
    const buscarSinSteam2 = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    const publiSinSteam2 = buscarSinSteam2.body.publicaciones.find(
        (p) => p.titulo_publi === 'Publi autor sin Steam'
    );
    assert.equal(publiSinSteam2.autor_steam_vinculado, true);
});
