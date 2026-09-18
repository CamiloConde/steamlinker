-- Formulario de contacto/sugerencias/quejas (Nivel 2 del roadmap, ver
-- HANDOFF.md). id_usu es NULL cuando lo envia alguien sin sesion (el
-- formulario no exige estar logueado).
CREATE TABLE IF NOT EXISTS mensajes_contacto (
    id_mensajecontacto SERIAL PRIMARY KEY,
    id_usu INTEGER REFERENCES usuarios(id_usu) ON DELETE SET NULL,
    nombre_mensajecontacto VARCHAR(100) NOT NULL,
    email_mensajecontacto VARCHAR(100) NOT NULL,
    tipo_mensajecontacto VARCHAR(20) NOT NULL DEFAULT 'sugerencia',
    cuerpo_mensajecontacto TEXT NOT NULL,
    leido_mensajecontacto BOOLEAN DEFAULT FALSE,
    creadoen_mensajecontacto TIMESTAMP DEFAULT NOW(),
    CONSTRAINT mensajes_contacto_tipo_check
        CHECK (tipo_mensajecontacto IN ('sugerencia', 'queja', 'error', 'otro'))
);

CREATE INDEX IF NOT EXISTS idx_mensajes_contacto_leido
    ON mensajes_contacto (leido_mensajecontacto, creadoen_mensajecontacto DESC);
