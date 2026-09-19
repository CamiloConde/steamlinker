-- Migration: guardar el origen (verificado/manual) de cada juego asociado
-- a una publicacion, no solo en la biblioteca del usuario.
--
-- Hasta ahora, para busco_familia/busco_miembros solo se podia elegir
-- entre los juegos que Steam confirma directamente (origen_usujg =
-- 'steam') -- excluia juegos reales que el usuario si tiene pero Steam
-- no puede verificar por API publica, como los que llegan por biblioteca
-- compartida de Familia de Steam (family sharing). El usuario lo
-- reporto con un caso real: tiene la trilogia de Batman Arkham en su
-- familia de Steam, pero nunca aparece como "verificado".
--
-- La solucion no es exigir que TODO sea verificado -- es dejar agregar
-- cualquier juego de la biblioteca (verificado o manual) pero marcar
-- cada uno con su origen real, para que quien vea la publicacion despues
-- sepa cual es cual. Antes esa distincion solo existia mientras se
-- armaba la publicacion (en el checklist) y se perdia al guardar.

BEGIN;

ALTER TABLE publicacion_juegos
  ADD COLUMN IF NOT EXISTS origen_pjg VARCHAR(10) NOT NULL DEFAULT 'manual'
    CHECK (origen_pjg IN ('steam', 'manual'));

COMMIT;

-- Ejecutar con: psql -U <usuario> -d <basedatos> -f 011_add_origen_publicacion_juegos.sql
