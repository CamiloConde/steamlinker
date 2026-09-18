-- Migration: rotacion/revocacion de JWT (Nivel 1, ver HANDOFF.md)
-- Hasta ahora el JWT era el unico factor de sesion: un token firmado,
-- sin ningun registro del lado del servidor, valido hasta 30 dias sin
-- forma de invalidarlo antes de tiempo (ni al cerrar sesion, ni al
-- banear a alguien, ni si se filtra). Esta tabla guarda los refresh
-- tokens (no los access tokens -- esos siguen siendo JWT sin estado,
-- de vida corta) para poder revocarlos de verdad.

BEGIN;

CREATE TABLE IF NOT EXISTS sesiones (
    id_sesion SERIAL PRIMARY KEY,
    id_usu INTEGER NOT NULL REFERENCES usuarios(id_usu) ON DELETE CASCADE,
    refresh_hash VARCHAR(64) NOT NULL UNIQUE,
    creadoen_sesion TIMESTAMP DEFAULT NOW(),
    expiraen_sesion TIMESTAMP NOT NULL,
    revocadaen_sesion TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sesiones_usuario ON sesiones(id_usu);
CREATE INDEX IF NOT EXISTS idx_sesiones_refresh_hash ON sesiones(refresh_hash);

COMMIT;

-- Ejecutar con: psql -U <usuario> -d <basedatos> -f 009_create_sesiones.sql
