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

COMMIT;

-- NO hay backfill por SQL aqui a proposito: una version anterior de esta
-- migracion marcaba 'steam' a TODAS las filas existentes de cualquier
-- cuenta con Steam vinculado, sin importar si el juego venia de verdad de
-- la biblioteca o se habia agregado a mano antes -- error real, encontrado
-- por un usuario cuyo Baldur's Gate 3 agregado a mano quedo marcado como
-- verificado. El backfill correcto necesita la API real de Steam para
-- saber cual juego es cual: correr scripts/reconciliar_origen_juegos.js
-- una vez despues de aplicar esta migracion.

-- Ejecutar con: psql -U <usuario> -d <basedatos> -f 008_add_origen_juegos.sql
