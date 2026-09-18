// Limita intentos de fuerza bruta en rutas sensibles (login/registro).
// Desactivado en tests para no romper la suite con ráfagas de requests.

const rateLimit = require('express-rate-limit');

const activo = process.env.NODE_ENV !== 'test';

// Login: 10 intentos cada 15 min por IP+email es suficiente para un usuario
// real que se equivoca de contraseña varias veces, y frena un ataque de
// fuerza bruta automatizado.
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    skip: () => !activo,
    message: { error: 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.' },
});

// Registro: más permisivo (una persona registrando varias cuentas de prueba
// es normal), pero sigue frenando creación masiva automatizada de cuentas.
const registroLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
    skip: () => !activo,
    message: { error: 'Demasiadas cuentas creadas desde esta red. Inténtalo más tarde.' },
});

module.exports = { loginLimiter, registroLimiter };
