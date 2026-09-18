-- Migration: distinguir juegos importados de Steam vs. agregados a mano
-- Hasta ahora "usuarios_juegos" no guardaba de donde salio cada fila, asi
-- que un juego agregado manualmente (buscador de Steam Store, sin
-- verificar que el usuario lo posea de verdad) se mostraba identico a uno
-- importado por la API oficial de Steam -- inflando el conteo de "Juegos
-- verificados" y los "juegos en comun" usados para matchear.

BEGIN;

ALTER TABLE usuarios_juegos
  ADD COLUMN IF NOT EXISTS origen_usujg VARCHAR(10) NOT NULL DEFAULT 'manual'
    CHECK (origen_usujg IN ('steam', 'manual'));

-- Backfill de mejor esfuerzo: no hay forma de saber con certeza el origen
-- de las filas que ya existian antes de esta migracion, pero la mayoria
-- de una biblioteca de una cuenta con Steam vinculado llego ahi por
-- importacion masiva (agregar a mano es de a un juego por vez). Marca
-- esas filas como 'steam'; cualquier juego agregado a mano que coincida
-- por casualidad queda mal etiquetado una sola vez, pero de aqui en
-- adelante cada INSERT nuevo marca su origen real.
UPDATE usuarios_juegos
SET origen_usujg = 'steam'
WHERE id_usu IN (SELECT id_usu FROM perfiles_steam);

COMMIT;

-- Ejecutar con: psql -U <usuario> -d <basedatos> -f 008_add_origen_juegos.sql
