// Punto de entrada del servidor SteamMatch

const os = require('os');
const app = require('./app');
const { isProduction } = require('./config/env');
const { runMigrations } = require('./migrate');
const perfilRoutes = require('./routes/perfil');

const PORT = process.env.PORT || 3000;

// Reimporta la biblioteca de Steam de todas las cuentas vinculadas cada
// cierto tiempo -- antes, comprar un juego nuevo no aparecía en la app
// hasta tocar "Importar biblioteca" a mano (pedido explícito del
// usuario: automatizarlo). 6 horas por defecto: frecuente para que se
// sienta automático, sin llamar a la API de Steam más de lo necesario.
const INTERVALO_REIMPORTACION_MS =
    Number(process.env.INTERVALO_REIMPORTACION_HORAS || 6) * 60 * 60 * 1000;

function iniciarReimportacionPeriodica() {
    setInterval(async () => {
        try {
            const resultado = await perfilRoutes.reimportarTodasLasBibliotecas();
            console.log(
                `Reimportación periódica de Steam: ${resultado.ok}/${resultado.total} cuentas ok` +
                (resultado.fallidas > 0 ? ` (${resultado.fallidas} fallidas -- perfil privado o similar)` : '')
            );
        } catch (err) {
            console.error('Error en reimportación periódica de Steam:', err.message);
        }
    }, INTERVALO_REIMPORTACION_MS);
}

async function start() {
    try {
        await runMigrations();
    } catch (err) {
        console.error('Error al ejecutar migraciones:', err.message);
        process.exit(1);
    }

    const host = process.env.HOST || '0.0.0.0';

    const server = app.listen(PORT, host, () => {
        const env = process.env.NODE_ENV || 'development';
        console.log(`SteamMatch API en http://localhost:${PORT} (${env})`);
        if (isProduction() && process.env.CORS_ORIGINS) {
            console.log('CORS permitidos:', process.env.CORS_ORIGINS);
        } else if (!isProduction()) {
            console.log('CORS: todos los orígenes (solo desarrollo)');
            const lan = getLanAddresses();
            if (lan.length > 0) {
                console.log('Red local (móvil físico):');
                for (const ip of lan) {
                    console.log(`  http://${ip}:${PORT}`);
                }
            }
            console.log('Emulador Android → http://10.0.2.2:' + PORT);
        }
        console.log('GET /health');
        if (!isProduction()) {
            console.log(`Panel admin: http://localhost:${PORT}/admin/`);
        }
        console.log(
            `Reimportación automática de Steam: cada ${INTERVALO_REIMPORTACION_MS / 3600000}h`
        );
    });

    iniciarReimportacionPeriodica();

    server.on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
            console.error(`\nPuerto ${PORT} ya en uso (otra instancia del backend u otro proceso).`);
            console.error('  Cierra la otra terminal con npm run dev / npm start, o ejecuta:');
            console.error(`  netstat -ano | findstr :${PORT}`);
            console.error('  taskkill /PID <pid> /F');
            console.error(`  También puedes cambiar PORT en .env\n`);
            process.exit(1);
        }
        console.error(err);
        process.exit(1);
    });
}

function getLanAddresses() {
    const ips = [];
    for (const iface of Object.values(os.networkInterfaces())) {
        for (const addr of iface || []) {
            if (addr.family === 'IPv4' && !addr.internal) {
                ips.push(addr.address);
            }
        }
    }
    return ips;
}

start();
