// DELETE /auth/cuenta fallaba con una violacion de llave foranea para
// cualquier cuenta con historial real (match, calificacion, chat, reporte
// o amistad), porque esas tablas referencian usuarios sin ON DELETE
// CASCADE. Este test reproduce exactamente ese escenario antes de confiar
// en que el endpoint limpia todo correctamente. Ver HANDOFF.md.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenA, idA, usernameA;
let idB, usernameB;

before(async () => {
    usernameA = usernameUnico('test_delcuenta_a');
    const resA = await request(app).post('/auth/registro').send({
        username: usernameA,
        email: `${usernameA}@example.com`,
        password: 'Passw0rd123',
    });
    tokenA = resA.body.token;
    idA = resA.body.usuario.id;

    usernameB = usernameUnico('test_delcuenta_b');
    const resB = await request(app).post('/auth/registro').send({
        username: usernameB,
        email: `${usernameB}@example.com`,
        password: 'Passw0rd123',
    });
    idB = resB.body.usuario.id;

    // Se inserta directo en la BD (no vía API) para no depender de las
    // reglas de negocio de cada endpoint (amistad aceptada, match
    // aceptado, etc.) — lo que se prueba aquí es la limpieza en cascada
    // manual de DELETE /auth/cuenta, no esas reglas.
    await pool.query(
        `INSERT INTO amistad (id_solicitante, id_receptor, estado_amistad) VALUES ($1, $2, 'Aceptada')`,
        [idA, idB]
    );
    const match = await pool.query(
        `INSERT INTO matches (id_solicitante, id_receptor, estado_match) VALUES ($1, $2, 'Aceptada') RETURNING id_match`,
        [idA, idB]
    );
    await pool.query(
        `INSERT INTO calificaciones (id_match, id_calificador, id_calificado, estrellas_cali) VALUES ($1, $2, $3, 5)`,
        [match.rows[0].id_match, idB, idA]
    );
    await pool.query(
        `INSERT INTO reportes (id_reportador, id_reportado, motivo_repor) VALUES ($1, $2, 'motivo de prueba')`,
        [idB, idA]
    );
    const chat = await pool.query(
        `INSERT INTO chat (id_participante1, id_participante2) VALUES ($1, $2) RETURNING id_chat`,
        [idA, idB]
    );
    const msgPadre = await pool.query(
        `INSERT INTO mensaje (id_chat, id_emisor, mensaje_chat) VALUES ($1, $2, 'hola') RETURNING id_mensaje`,
        [chat.rows[0].id_chat, idA]
    );
    // Mensaje que responde a otro (parent_mensaje) — la razón del UPDATE
    // que rompe el hilo antes de borrar en el endpoint real.
    await pool.query(
        `INSERT INTO mensaje (id_chat, id_emisor, mensaje_chat, parent_mensaje) VALUES ($1, $2, 'respuesta', $3)`,
        [chat.rows[0].id_chat, idB, msgPadre.rows[0].id_mensaje]
    );
});

after(async () => {
    await limpiarUsuario(usernameB);
    await pool.end();
});

test('elimina una cuenta con match, calificacion, chat con hilo de respuestas, reporte y amistad', async () => {
    const res = await request(app)
        .delete('/auth/cuenta')
        .set('Authorization', `Bearer ${tokenA}`);

    assert.equal(res.status, 200);

    const check = await pool.query('SELECT 1 FROM usuarios WHERE id_usu = $1', [idA]);
    assert.equal(check.rows.length, 0, 'la cuenta debe quedar eliminada de verdad');
});
