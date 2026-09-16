# Handoff — continuidad del proyecto Steamlinker / SteamMatch

Este archivo resume el estado real del proyecto y las decisiones tomadas, para que
cualquier sesión de Claude (en la nube o local, en cualquier PC) pueda seguir sin
redescubrir nada. Se actualiza en cada sesión relevante — no es un log histórico,
es el estado actual. Bórralo o muévelo a `docs/` solo cuando el proyecto ya no lo
necesite como referencia activa.

**Identidad de commits:** todos los commits van a nombre de
`Steamlinker <camilandre0510@gmail.com>` (el dueño del proyecto), sin rastro de Claude
en autoría ni mensajes — así lo pidió explícitamente. Sin footer de atribución, sin
`Co-Authored-By: Claude`.

---

## 1. Qué es el proyecto — y qué NO es

**SteamMatch** (nombre nuevo decidido, ver sección 3; el repo y la app todavía dicen
"Steamlinker") es un sitio especializado para dos cosas, validado por el SRS académico
original (`Plantilla_SRS.docx`, ver sección 9):

1. **Encontrar/formar grupos de Steam Family Sharing.** Una "Familia" en el sistema son
   **6 usuarios** (el dueño + 5, el límite real de Steam Family Sharing) que comparten
   biblioteca. Hoy esto se resuelve en foros genéricos (Reddit, Discord, grupos de
   Facebook); el proyecto da un espacio dedicado con biblioteca **verificada** vía Steam
   Web API, no lo que la persona diga tener.
2. **Encontrar compañeros de juego** (no para compartir cuenta, para jugar juntos) —
   esto estaba en el alcance **desde el SRS original** (requisito FR9: publicaciones
   "de otro tema no específico, como por ejemplo gente que quiera conectarse con alguien
   para jugar"), no es una idea nueva de esta sesión.

**No es una integración oficial con Valve ni automatiza el Family Sharing en sí** —
Steam no expone eso. El producto es la capa de coordinación/matchmaking alrededor.

**Importante — el proyecto NO está en pañales.** Ya es funcional de punta a punta:
se presentó en la materia de Desarrollo de Software (UTB Cartagena) corriendo en
Android, con nota 5/5. Tiene backend completo, sistema de match, reputación, admin
panel, todo operativo. El trabajo que sigue es **llevarlo a Web 1.0** (Beta actual →
Web 1.0 → Mobile Android/iOS empaquetado formalmente → Desktop), no reconstruirlo.
Flutter ya compila a los 6 targets desde el mismo código — "Web 1.0" es en gran parte
`flutter build web` + una capa de layout responsive + pulir lo que ya existe, no un
proyecto nuevo.

## 2. Arquitectura actual (verificada contra el código real, no solo docs)

- **`steamlinker_flutter/`** — Flutter/Dart. Arquitectura por features
  (`lib/features/<dominio>/{screens,providers}`), estado con `provider`, ruteo con
  `go_router`, HTTP con `dio`. Theming centralizado en `lib/theme/colors.dart`
  (`SteamColors`) — paleta oscura ya alineada con el lenguaje visual de Steam.
  Navegación actual: `MainShell` con bottom nav (patrón de app móvil), **sin
  breakpoints responsive** — en pantalla ancha se ve una app de celular estirada. Eso
  es lo principal por resolver para Web 1.0, no la lógica de negocio.

- **`steamlinker_back/`** — Node.js + Express, JWT + bcrypt, rutas por dominio (`auth`,
  `users`, `games`, `amistad`, `matches`, `chat`, `publicaciones`, `perfil`,
  `calificaciones`, `notificaciones`, `reportes`, `admin`).

- **`Steamlinker BD/`** — PostgreSQL, 12 tablas. Ver sección 4 para el detalle de
  `publicaciones`/`matches` que es el corazón del producto.

- **Setup local:** confirmado funcionando de punta a punta en esta máquina —
  `.env` completo, base `steamlinker` creada, migraciones aplicadas
  (`npm run migrate`), backend responde en `/health` con `"database":"connected"`.
  Nada pendiente de infraestructura para desarrollar localmente.

## 3. Naming

Decidido: **SteamMatch** (mejor que "Steamlinker", que suena a "vincular tu cuenta",
no a lo que el producto hace). Pendiente de **ejecutar** (no hecho todavía):

- Actualizar nombre en `pubspec.yaml`, `package.json`, README, bundle IDs, etc.
- Agregar disclaimer de no afiliación con Valve en el footer/landing (usar "Steam" en
  el nombre de un producto no oficial tiene roce con las guías de marca de Valve; hay
  precedentes que lo toleran — SteamDB, SteamGifts, SteamTrades — siempre que quede
  claro que no es oficial).
- Se recomienda atar esta migración de nombre a la decisión de repo nuevo (sección 7),
  para resolver nombre + historial de secretos viejos de una sola vez.

## 4. El modelo de datos real — mucho más completo de lo que parecía al principio

**Corrección importante sobre esta misma sesión:** al principio se pensó que faltaba
crear una entidad "listing" desde cero para Familia/Compañeros. Al revisar el código
real (no el README, que está desactualizado), **eso ya existe en gran parte**:

- `publicaciones`: `tipo_publi` (`CHECK IN ('busco_familia','busco_miembros','otro')`),
  `paisfiltro_publi` (filtro de país), `estado_publi` (abierto/cerrado), y
  `publicacion_juegos` (juegos ligados, N a N). Backend ya expone
  `GET /publicaciones/buscar` filtrando por tipo/país/appid.
- `matches`: `id_solicitante`, `id_receptor`, **`id_publi` (opcional, liga el match a
  una publicación específica)**, `estado_match` (Pendiente/Aceptada/Rechazada). Al
  aceptar, se crea un chat automáticamente. Esto es exactamente el mecanismo de
  "alguien publica que busca gente para Helldivers → otro lo encuentra filtrando por
  ese juego → manda match desde ese post → si acepta, chat automático" — **ya
  construido**, no hay que inventarlo.
- `amistad`: sistema de solicitud/aceptar **separado a propósito** de `matches`
  (confirmado con el usuario) — `amistad` es agregar amigo en general (como en Steam);
  `matches` es conectar específicamente por una publicación de familia/compañero. No
  son duplicados a limpiar, son dos conceptos distintos que se quedan como están.

**Gaps reales (pequeños, no una tabla nueva):**

1. Falta un valor de `tipo_publi` para "busco compañero de juego" — hoy solo hay
   `busco_familia`/`busco_miembros`/`otro`. Sin esto, un post de Helldivers cae en
   `otro` y se mezcla con Comunidad.
2. Falta `cupos_totales` en `publicaciones` — hoy el cierre de una publicación es
   manual (`PUT /publicaciones/:id/cerrar`), no automático al llenarse. Con el dato del
   SRS, el default natural para `tipo_publi = 'busco_familia'`/`'busco_miembros'` es
   **6** (tamaño real de una Familia Steam); para el tipo de compañeros sería variable
   (2 a N, lo define quien publica). `cupos_ocupados` se puede derivar contando
   `matches` con `estado_match = 'Aceptada'` para ese `id_publi`, no hace falta
   columna aparte.

Esto es una migración pequeña (un `ALTER TABLE` + un nuevo valor de `CHECK`), no un
rediseño de esquema.

## 5. Verificación de Steam — ya construida, falta decidir cuándo exigirla

**Corrección importante:** no existe (ni hace falta construir) un login OAuth "Steam
OpenID" — eso era una promesa del README desactualizada, no código real. Lo que sí
existe y funciona:

- `POST /perfil/steam/vincular` — recibe un SteamID o URL de perfil, lo resuelve y
  verifica contra la Steam Web API pública.
- `POST /perfil/steam/importar` — importa la biblioteca real del SteamID vinculado.

Es decir, la verificación (el diferenciador central del producto frente a un foro
genérico) **ya está construida**. Lo único pendiente de decidir es **en qué punto del
flujo se vuelve obligatoria**:

- Registro (email/password) → cuenta creada, fricción baja, cualquiera entra.
- Comunidad → abierta sin necesidad de Steam vinculado (no depende de biblioteca).
- Familia → **requerido**, confirmado con el usuario. Explorar/mirar listings queda
  libre, pero publicar un listing de tipo `busco_familia`/`busco_miembros` o mandar un
  match hacia uno de esos listings sí exige biblioteca importada — no es una barrera de
  confianza arbitraria, es un requisito funcional (`publicacion_juegos` necesita saber
  qué juegos tiene la persona) y de riesgo real: compartir acceso a biblioteca pagada
  con un desconocido tiene costo real si la otra persona miente.
- Compañeros → **revisado y afinado con el usuario: NO requerido.** A diferencia de
  Familia, jugar juntos no involucra compartir acceso a nada — el costo de que alguien
  exagere qué tiene es bajo (un chat incómodo, no un fraude). Cualquiera con cuenta
  puede publicar/matchear en Compañeros eligiendo el juego del catálogo (buscador de
  juegos ya existente en la app, no requiere biblioteca importada). Si el usuario sí
  tiene Steam vinculado, se le puede mostrar la insignia "verificado ✓" como plus de
  confianza, pero nunca como requisito para esta pestaña.

**Implementado en esta sesión (Fase 2):**
- `steamlinker_back/src/utils/verificacion.js` — helper `tieneSteamVinculado` +
  `TIPOS_REQUIEREN_STEAM = ['busco_familia', 'busco_miembros']` (Compañeros
  deliberadamente fuera de esa lista).
- `POST /publicaciones/crear` — 403 `STEAM_REQUERIDO` si el tipo requiere Steam y el
  usuario no lo tiene vinculado; valida `tipo` contra la lista permitida.
- `POST /matches/enviar` — mismo 403 si `id_publi` apunta a una publicación de tipo
  familia y el que envía el match no tiene Steam vinculado.
- Probado end-to-end con curl: `busco_familia` sin Steam → 403; `busco_companero` sin
  Steam → 201; tipo inválido → 400.

## 6. Seguridad — resuelto

- ✅ `steamlinker_back/.env` destrackeado de git (`.gitignore` ya lo cubre).
- ✅ Steam API key vieja revocada, nueva generada y puesta en `.env` local.
- ✅ `JWT_SECRET`/`SESSION_SECRET` nuevos generados (random hex 32 bytes) y puestos en
  `.env` local.
- ✅ Password de Postgres local confirmado y funcionando (`DB_PASSWORD` en `.env`
  coincide con el rol `postgres` de esta máquina).
- ⏳ El historial de git todavía contiene los secretos viejos (ya revocados/rotados,
  no explotables, pero visibles con `git log -p`). Pospuesto a propósito — se resuelve
  gratis si se migra a un repo nuevo con el rebranding a SteamMatch (sección 7), en vez
  de forzar un `filter-repo`/BFG + force-push disruptivo sobre "steamlinker" ahora.

**Regla permanente: nunca commitear `.env` ni pegar secretos reales en archivos
versionados (incluido este mismo HANDOFF.md). Documentar el nombre de la variable, no
el valor.**

## 7. Pendiente de decidir: repo nuevo vs seguir en este

Sin resolver todavía. Recomendación: si se ejecuta el rebranding a SteamMatch,
aprovechar ese momento para arrancar un repo nuevo bajo el nombre definitivo — resuelve
nombre + historial de secretos viejos de una sola vez.

## 8. Dirección de diseño — los wireframes son lenguaje visual, NO especificación

El usuario compartió 5 mockups hechos por un amigo como referencia de estética/idea de
IA de navegación — **explícitamente no son la regla ni el diseño final**. La versión
real que se quiere llevar adelante es **la que ya existe y funciona en Steamlinker
actual** (probada en clase, nota 5/5), mejorada, no reemplazada por lo que muestran las
imágenes. Antes de tocar cualquier pantalla, revisar el código/IA real en
`lib/features/`, no asumir desde las imágenes.

Lo que sí vale la pena rescatar de los wireframes como *idea* de dirección visual (no
como spec de funcionalidad): nav superior en vez de bottom-nav en desktop, panel de
chat lateral/flotante, tratamiento de perfil con banner+avatar. Estética: usar el
lenguaje propio de Steam (ya encaminado en `SteamColors`) combinado con algo más
editorial — tipografía con carácter, carátulas reales de juegos como elemento visual
fuerte (nunca fotos de stock genéricas), iconografía propia, radios/espaciado
consistentes. Evitar el look "genérico de IA" (gradientes azul-morado difusos, avatares
placeholder vacíos).

Las imágenes no viajan entre sesiones — pedir que las reenvíe si hace falta volver a
verlas.

## 9. Fuente de verdad del alcance funcional: el SRS académico

El usuario compartió `Plantilla_SRS (2).docx` (presentado en la materia, nota 5/5,
17/02/2026, equipo: Miguel Jácome, Camilo Conde, Christian Benitez, Sean Martínez, Jesús
González). Confirma y afina varias cosas ya encontradas en el código:

- Familia = **6 usuarios** compartiendo biblioteca.
- Reputación: calificación **0-5 estrellas** con preguntas cualitativas ("¿se logró el
  cometido?", "¿era estafador/mentiroso?") — ya en la tabla `calificaciones`.
- Filtros: juego, país, reputación, **fecha de publicación** (este último no confirmé
  si está implementado en `GET /publicaciones/buscar` — revisar antes de asumir).
- Publicaciones cubre desde el requisito original tanto familia/miembros como "otro
  tema no específico... gente que quiera conectarse con alguien para jugar" — el caso
  Helldivers estaba contemplado desde el diseño original, no es una idea nueva.
- Fuera de alcance a propósito (documentado, no es negligencia): creación automática de
  familias en Steam, almacenamiento de credenciales externas, mensajería en tiempo real
  *permanente*, transacciones económicas.
- No funcionales relevantes para Web 1.0: responsive "independientemente del
  dispositivo" (ya estaba en el alcance original, no es invención de ahora), HTTPS,
  disponibilidad ≥95%, escalabilidad progresiva.

## 10. Roadmap actualizado

**Fase 0 — Seguridad: cerrada**
- [x] Rotar credenciales filtradas
- [ ] Decidir estrategia de historial de git (pospuesto, atado al rebranding — no
      urgente, las credenciales viejas ya están muertas)

**Fase 1 — Definición de producto: cerrada**
- [x] Nombre final → SteamMatch (decisión tomada, ejecución pendiente)
- [x] Alcance de Comunidad → confirmado, reusar `publicaciones` (tipo `otro`) tal cual
- [x] `matches` vs `amistad` → confirmado, son distintos a propósito, ambos se quedan
- [x] Gateo de Steam por función (sección 5) → confirmado: requerido para publicar/
      match en Familia/Compañeros, libre en Comunidad y para explorar

**Fase 2 — Backend/datos: implementada y probada (migración 006 + rutas + Flutter)**
- [x] Agregar valor `tipo_publi = 'busco_companero'` — migración
      `db_migrations/006_companero_y_cupos.sql`, aplicada en el Postgres local
- [x] Agregar `cupos_totales` a `publicaciones` (default 6 en backend si el tipo es
      familia/miembros y no se manda; libre para compañeros; NULL para `otro`).
      `cupos_ocupados` se deriva en `GET /publicaciones/:id` contando matches con
      `estado_match = 'Aceptada'` para ese `id_publi` (no es columna aparte)
- [x] Auto-cerrar (`estado_publi = FALSE`) en `PUT /matches/:id/responder` cuando al
      aceptar se alcanza `cupos_totales`
- [x] Gateo de Steam — solo Familia (`busco_familia`/`busco_miembros`), NO Compañeros
      (ver sección 5 para el porqué). Implementado en backend
      (`publicaciones.js`, `matches.js`, `utils/verificacion.js`) y en Flutter
      (`publicacion_constants.dart`: `tiposRequierenSteam`/`requiereSteam`;
      `crear_publicacion_screen.dart` muestra el aviso y el campo de cupos;
      `publicaciones_provider.dart` envía `cupos_totales`)
- [ ] **Sin verificar:** los cambios de Flutter no se compilaron — Flutter/Dart no
      está instalado en esta máquina. Correr `flutter analyze` en la primera sesión
      que sí tenga el SDK, sobre todo `crear_publicacion_screen.dart`
- [ ] Revisar si falta filtro por fecha de publicación en `GET /publicaciones/buscar`
      (el SRS lo pide, no confirmé si ya está)
- [ ] Pendiente (no bloqueante): mostrar insignia "verificado ✓" en perfiles/posts de
      quien sí tiene Steam vinculado, como refuerzo de confianza en Compañeros

**Fase 3 — Diseño**
- [ ] Sistema de diseño concreto (tipografía, paleta refinada, radios/espaciado,
      tratamiento de avatares/imágenes, iconografía) documentado antes de tocar UI —
      partiendo de `SteamColors` actual, no de los wireframes

**Fase 4 — Shell web responsive**
- [ ] Breakpoints en `MainShell` (o su reemplazo) para desktop: nav superior/sidebar en
      vez de bottom-nav, manteniendo el bottom-nav actual en móvil — un solo codebase
- [ ] Evaluar si el chat actual (polling) alcanza para web o hace falta WebSockets

**Fase 5 — Pulido de pantallas existentes para web**
- [ ] Ajustar layout de las pantallas ya funcionales (perfil, descubrir, publicaciones,
      matches, amistad, chat, admin) para verse bien en ancho de escritorio — es un
      pase de CSS/layout sobre lo que ya funciona, no reconstrucción de funcionalidad
- [ ] Aplicar el sistema de diseño de la Fase 3 como skin

**Fase 6 — No funcional**
- [ ] Tests básicos + CI (hoy no hay nada real, solo el placeholder de plantilla)
- [ ] Despliegue de Web 1.0 (hosting backend Node + Postgres + `flutter build web`,
      dominio, variables de entorno de producción, secrets de prod separados de dev)

**Fase 7 — Lanzamiento**
- [ ] Beta web pública, recoger feedback real antes de empaquetar formalmente
      Android/iOS/Desktop (Flutter ya los soporta con el mismo código — ahí no hay
      trabajo de plataforma nuevo, es empaque y QA)

## 11. Cómo retomar

1. Sigue el checklist de la sección 10 en orden — Fase 1 está prácticamente cerrada,
   el siguiente trabajo real empieza en Fase 2 (migración pequeña) o Fase 3 (sistema de
   diseño), lo que el usuario prefiera primero.
2. No asumas que falta construir infraestructura de matching/listings — revisa el
   código real (`steamlinker_back/src/routes/`, `Steamlinker BD/scrip bd.sql`) antes de
   proponer cambios grandes; casi todo lo "aspiracional" que parece faltar en
   README/wireframes ya existe en el código.
3. Los wireframes (sección 8) y el SRS (sección 9) son referencias, no specs a seguir
   al pie de la letra — el SRS es más confiable como fuente de requisitos porque
   describe lo que efectivamente se construyó y evaluó.
4. Todos los commits van a nombre de `Steamlinker <camilandre0510@gmail.com>` (sección
   inicial) salvo que el usuario diga lo contrario.
