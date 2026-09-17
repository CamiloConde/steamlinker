const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool } = require('./helpers');

test('GET /health responde ok con la base conectada', async () => {
    const res = await request(app).get('/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
    assert.equal(res.body.database, 'connected');
});

after(async () => {
    await pool.end();
});
