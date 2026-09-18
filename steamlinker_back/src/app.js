// App de Express, sin arrancar el servidor ni correr migraciones.
// Separado de index.js para poder importarla en tests (supertest) sin
// abrir un puerto real.

require('dotenv').config();

const path = require('path');
const express = require('express');
const cors = require('cors');
const pool = require('./db');
const adminRoutes = require('./routes/admin');
const { validateEnv, parseCorsOrigins, isProduction } = require('./config/env');
const { securityHeaders } = require('./middleware/security');

const { router: authRoutes } = require('./routes/auth');
const perfilRoutes = require('./routes/perfil');
const publicacionesRoutes = require('./routes/publicaciones');
const matchesRoutes = require('./routes/matches');
const chatRoutes = require('./routes/chat');
const calificacionesRoutes = require('./routes/calificaciones');
const reportesRoutes = require('./routes/reportes');
const amistadRoutes = require('./routes/amistad');
const notificacionesRoutes = require('./routes/notificaciones');
const contactoRoutes = require('./routes/contacto');

validateEnv();

const app = express();
const corsOrigins = parseCorsOrigins();

if (isProduction()) {
    app.set('trust proxy', 1);
}

app.use(securityHeaders);

app.use(
    cors({
        origin(origin, callback) {
            if (!origin) return callback(null, true);
            if (!isProduction()) return callback(null, true);
            if (!corsOrigins || corsOrigins.length === 0) {
                return callback(null, false);
            }
            if (corsOrigins.includes(origin)) {
                return callback(null, true);
            }
            return callback(null, false);
        },
        credentials: true,
    })
);

app.use(express.json({ limit: '1mb' }));

app.use('/admin', express.static(path.join(__dirname, '../public/admin')));

app.use('/auth', authRoutes);
app.use('/perfil', perfilRoutes);
app.use('/publicaciones', publicacionesRoutes);
app.use('/matches', matchesRoutes);
app.use('/chat', chatRoutes);
app.use('/calificaciones', calificacionesRoutes);
app.use('/reportes', reportesRoutes);
app.use('/amistad', amistadRoutes);
app.use('/notificaciones', notificacionesRoutes);
app.use('/contacto', contactoRoutes);
app.use('/api/admin', adminRoutes);

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({
            status: 'ok',
            environment: process.env.NODE_ENV || 'development',
            database: 'connected',
            timestamp: new Date().toISOString(),
        });
    } catch (err) {
        res.status(503).json({
            status: 'degraded',
            database: 'disconnected',
            error: isProduction() ? 'Database unavailable' : err.message,
        });
    }
});

module.exports = app;
