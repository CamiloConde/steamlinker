BEGIN;

ALTER TABLE perfiles_steam
  ADD COLUMN IF NOT EXISTS ultima_importacion_steperfil TIMESTAMP;

COMMIT;
