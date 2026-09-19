BEGIN;

ALTER TABLE publicacion_juegos
  ADD COLUMN IF NOT EXISTS intencion_pjg VARCHAR(10) NOT NULL DEFAULT 'tengo'
    CHECK (intencion_pjg IN ('tengo', 'busco'));

COMMIT;
