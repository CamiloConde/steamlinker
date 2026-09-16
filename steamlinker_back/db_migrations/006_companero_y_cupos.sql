-- Agrega tipo de publicacion "busco_companero" (jugar juntos, sin biblioteca
-- compartida) y soporte de cupos para cierre automatico de listings.
-- Idempotente.

ALTER TABLE publicaciones DROP CONSTRAINT IF EXISTS publicaciones_tipo_publi_check;
ALTER TABLE publicaciones ADD CONSTRAINT publicaciones_tipo_publi_check
    CHECK (tipo_publi IN ('busco_familia', 'busco_miembros', 'busco_companero', 'otro'));

-- Cupos totales que busca la publicacion (ej: familia = 6, companeros = lo que
-- defina el autor). NULL = sin limite de cupos (aplica a 'otro').
ALTER TABLE publicaciones ADD COLUMN IF NOT EXISTS cupos_totales SMALLINT;

ALTER TABLE publicaciones DROP CONSTRAINT IF EXISTS publicaciones_cupos_totales_check;
ALTER TABLE publicaciones ADD CONSTRAINT publicaciones_cupos_totales_check
    CHECK (cupos_totales IS NULL OR cupos_totales > 0);
