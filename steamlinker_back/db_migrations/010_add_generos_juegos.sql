-- Migration: tags de genero por juego (Accion, Co-op, RPG, ...)
-- Hasta ahora la tabla "juegos" no guardaba genero/tags en absoluto, asi
-- que las tarjetas de publicacion no podian mostrar esa info aunque el
-- usuario la pidio -- ver HANDOFF.md, "Pulido menor pendiente". Se llena
-- de a poco: se consulta la Steam Store API solo la primera vez que se ve
-- un appid nuevo (ver services/juegosService.js), nunca en bloque, para no
-- pegarle a esa API con cientos de llamadas seguidas al importar una
-- biblioteca completa.

BEGIN;

ALTER TABLE juegos
  ADD COLUMN IF NOT EXISTS generos_jg TEXT[];

COMMIT;

-- Ejecutar con: psql -U <usuario> -d <basedatos> -f 010_add_generos_juegos.sql
