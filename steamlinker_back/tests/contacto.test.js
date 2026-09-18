// POST /contacto: formulario de sugerencias/quejas, publico (sin sesion),
// con honeypot anti-spam. Ver HANDOFF.md, Nivel 2.
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool } = require('./helpers');

const idsCreados = [];

after(async () => {
    if (idsCreados.length) {
        await pool.query('DELETE FROM mensajes_contacto WHERE id_mensajecontacto = ANY($1)', [idsCreados]);
    }
    await pool.end();
});

test('crea un mensaje de contacto sin necesitar sesion', async () => {
    const res = await request(app).post('/contacto').send({
        nombre: 'Visitante de prueba',
        email: 'visitante@example.com',
        tipo: 'sugerencia',
        mensaje: 'Sería genial poder filtrar por región dentro de Descubrir.',
    });

    assert.equal(res.status, 201);
    assert.ok(res.body.id);
    idsCreados.push(res.body.id);

    const fila = await pool.query('SELECT * FROM mensajes_contacto WHERE id_mensajecontacto = $1', [res.body.id]);
    assert.equal(fila.rows[0].nombre_mensajecontacto, 'Visitante de prueba');
    assert.equal(fila.rows[0].tipo_mensajecontacto, 'sugerencia');
    assert.equal(fila.rows[0].id_usu, null);
});

test('rechaza sin nombre/correo/mensaje', async () => {
    const res = await request(app).post('/contacto').send({ nombre: 'Solo nombre' });
    assert.equal(res.status, 400);
});

test('rechaza un correo con formato invalido', async () => {
    const res = await request(app).post('/contacto').send({
        nombre: 'Alguien',
        email: 'no-es-un-correo',
        mensaje: 'Mensaje de prueba con suficiente longitud.',
    });
    assert.equal(res.status, 400);
});

test('un tipo invalido cae a "sugerencia" por defecto', async () => {
    const res = await request(app).post('/contacto').send({
        nombre: 'Alguien más',
        email: 'otro@example.com',
        tipo: 'no-existe',
        mensaje: 'Mensaje de prueba con suficiente longitud.',
    });
    assert.equal(res.status, 201);
    idsCreados.push(res.body.id);
    const fila = await pool.query('SELECT tipo_mensajecontacto FROM mensajes_contacto WHERE id_mensajecontacto = $1', [res.body.id]);
    assert.equal(fila.rows[0].tipo_mensajecontacto, 'sugerencia');
});

test('el honeypot descarta el mensaje sin guardarlo, pero responde 201', async () => {
    const antes = await pool.query('SELECT COUNT(*)::int AS n FROM mensajes_contacto');
    const res = await request(app).post('/contacto').send({
        nombre: 'Bot',
        email: 'bot@example.com',
        mensaje: 'Relleno automatico de un formulario.',
        sitio_web: 'http://spam.example.com',
    });
    assert.equal(res.status, 201);
    const despues = await pool.query('SELECT COUNT(*)::int AS n FROM mensajes_contacto');
    assert.equal(despues.rows[0].n, antes.rows[0].n, 'el honeypot no debe insertar nada');
});
