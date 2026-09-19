# Handoff — continuidad del proyecto Steamlinker / SteamMatch

Este archivo resume el estado real del proyecto y las decisiones tomadas, para que
cualquier sesión de trabajo futura (en cualquier PC) pueda seguir sin redescubrir
nada. Se actualiza en cada sesión relevante — no es un log histórico, es el estado
actual. Bórralo o muévelo a `docs/` solo cuando el proyecto ya no lo necesite como
referencia activa.

**Identidad de commits:** todos los commits van a nombre de
`Steamlinker <camilandre0510@gmail.com>` (el dueño del proyecto), sin ningún rastro de
herramientas de asistencia en autoría ni mensajes — así lo pidió explícitamente el
dueño del proyecto. Sin footers de atribución de ningún tipo.

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

**Actualización: la dirección de diseño ya se decidió — ver sección 9.** Se exploraron
4 direcciones visuales (canvas de Artifact) y el usuario confirmó explícitamente:
**"esa es, sigamos con esa dirección"**, refiriéndose a la dirección **"Fiel a Steam"**.

**Actualización 2 — ciclo completo de ida y vuelta sobre renombrar las pestañas a
Familia/Compañeros/Comunidad, revertido al final. No repetir esto.** En una misma
sesión ocurrió, en orden: (1) se construyó una reestructuración de navegación a 4
pestañas (Familia/Compañeros/Comunidad/Perfil, fusionando Descubrir+Publicaciones+
Amigos) basada en los wireframes; (2) el usuario pidió revertirla explícitamente
("los wireframes se adaptan a lo que teniamos, no lo que teniamos al wireframe"); (3)
se revirtió por completo; (4) tras ver capturas comparando el "feel" visual del
wireframe contra la app real, el usuario confirmó **por `AskUserQuestion`** que sí
quería la reestructuración después de todo ("Sí, la misma estructura de 4 pestañas" /
"Fusionar en 3 sub-pestañas"); (5) se reconstruyó, se verificó end-to-end, se hizo
commit y push; (6) el usuario volvió a preguntar "¿qué se supone que es Familia,
Compañeros y Comunidad? Eso era del wireframe, no de lo que teníamos" — es decir, aun
con la confirmación explícita del paso (4) documentada y citada de vuelta, el usuario
decidió en una pregunta de confirmación posterior **volver a Descubrir/Publicaciones/
Amigos** (los nombres/estructura originales de antes de esta sesión). Se revirtió otra
vez — código restaurado exactamente al estado del commit `7a21401` (el que sólo tenía
el rediseño visual de `PublicacionCard`, sin tocar nombres de pestañas). Los nombres
**Familia/Compañeros/Comunidad NO se van a usar** — la app conserva
**Descubrir Gamers / Publicaciones / Amigos**. Lo que SÍ sigue vigente y confirmado
aparte es aplicarle a estas pantallas (con sus nombres originales) el lenguaje visual
del wireframe: nav superior horizontal, layout de 3 columnas en las pantallas tipo
feed, colores/posiciones acordes, panel de chat flotante — ver el pie de esta sección
para el estado de eso. **Lección reforzada para cualquier sesión futura**: ni siquiera
una confirmación explícita por `AskUserQuestion` garantiza que el usuario no vuelva a
cambiar de opinión sobre algo estructural — cuando pase una segunda vez, no basta con
citar la confirmación anterior y seguir adelante on the user's word; hay que preguntar
de nuevo, en frío, sin asumir que lo ya confirmado sigue en pie, y evitar construir en
grande (nav global + varias pantallas a la vez) hasta que el nombre/estructura de base
esté firme.

## 9. Sistema de diseño (Fase 3) — decidido e implementado

Se probaron 4 direcciones visuales en un canvas de diseño (tipografía + radios +
tratamiento de tags, todas sobre la misma paleta `SteamColors`): táctico/competitivo
(Rajdhani+Barlow, radio 4px), editorial (Space Grotesk+IBM Plex Sans, radio 10px),
comunidad/cálido (Bricolage Grotesque+Work Sans, radio 16px), y **fiel a Steam**. El
usuario eligió explícitamente esta última — razón: **SteamMatch está inspirado en
Steam, tiene sentido que se sienta familiar a su lenguaje visual real, no a una
identidad genérica inventada.**

**Dirección elegida — "Fiel a Steam":**
- **Una sola familia tipográfica en toda la app** (no una display + una de texto) —
  así es como el propio Steam lo hace, cambia peso/tamaño, no de fuente.
- Fuente: **Source Sans 3** — sustituto abierto de Motiva Sans (la fuente propietaria
  real de Steam; no se puede licenciar para terceros, y copiarla al pixel sería
  imitar demasiado de cerca la marca de Valve, lo que ya se descartó por la misma
  razón del disclaimer de no afiliación).
- **Radio casi recto (2px)** en cards, botones, inputs y tags — Steam prácticamente no
  redondea esquinas.
- **Etiquetas en mayúsculas con letter-spacing** para tipo de publicación, país, tags
  de género — patrón real de la tienda de Steam.
- Azul de acento actualizado a **`#66C0F4`** (el azul real de acento de Steam), en vez
  del `#4C91C9` más apagado que se usaba antes.

**Actualización — este azul pastel se abandonó más adelante.** El usuario lo sintió
"apagado"/"triste" al ver la app terminada, y tras comparar contra una paleta más
vívida inspirada en el wireframe (canvas de diseño, confirmado explícitamente), se
cambió a `#3B82F6`. El resto de la dirección "Fiel a Steam" (una sola tipografía,
radio casi recto, mayúsculas+tracking en etiquetas) sigue vigente — ver el checklist
de Fase 5 (entrada "Paleta de color renovada") para el detalle completo de qué tokens
cambiaron y por qué.

**Implementado en esta sesión (a nivel de tokens del theme, no pantalla por
pantalla):**
- `steamlinker_flutter/pubspec.yaml` — agregado `google_fonts: ^6.2.1` (resuelto a
  6.3.3).
- `lib/theme/app_theme.dart` — `fontFamily`/`textTheme` ahora usan
  `GoogleFonts.sourceSans3TextTheme(...)` en vez de `'Roboto'`.
- `lib/theme/colors.dart` — `SteamColors.blue` actualizado a `0xFF66C0F4` (cascada
  automática a los ~27 archivos que ya referencian ese token).
- `lib/theme/radii.dart` (nuevo) — `SteamRadii.sm = 2` documentado como el radio
  estándar a usar en vez de valores sueltos (`BorderRadius.circular(6)`, `(10)`, etc.)
  cuando se toquen las pantallas.
- Verificado con `flutter analyze`: 0 errores.

**Deliberadamente NO hecho en este paso** (es trabajo de Fase 5, "pulido de
pantallas", no de Fase 3): no se reemplazaron los radios sueltos ya hardcodeados en
cada widget/pantalla por `SteamRadii.sm`, ni se aplicaron las etiquetas en mayúsculas
al resto de la UI. Fase 3 deja el *sistema* listo (tokens centralizados); aplicarlo
pantalla por pantalla es la Fase 5.

## 10. Fuente de verdad del alcance funcional: el SRS académico

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

## 11. Roadmap actualizado

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
- [x] Flutter SDK instalado en esta máquina (`C:\flutter`, 3.47.4 stable) y verificado:
      `flutter analyze` sobre los archivos de esta fase → 0 errores, solo 2 infos de
      estilo (mismo patrón que ya usaba el archivo). `flutter doctor`: Chrome (web) y
      Windows (desktop) disponibles; Android SDK y Visual Studio NO instalados (no
      bloquea Web 1.0, sí bloqueará empacar Android/Windows desktop más adelante).
      Nota: hay una segunda instalación de Flutter en `C:\dev\flutter` en el PATH del
      usuario, no tocada — si algo se comporta raro con versión de Flutter, revisar
      cuál de las dos está activa en el PATH.
- [ ] Revisar si falta filtro por fecha de publicación en `GET /publicaciones/buscar`
      (el SRS lo pide, no confirmé si ya está)
- [ ] Pendiente (no bloqueante): mostrar insignia "verificado ✓" en perfiles/posts de
      quien sí tiene Steam vinculado, como refuerzo de confianza en Compañeros

**Fase 3 — Diseño: decidida e implementada a nivel de tokens (ver sección 9)**
- [x] Dirección elegida: "Fiel a Steam" — Source Sans 3 (una sola familia), radio 2px,
      azul `#66C0F4`, etiquetas en mayúsculas con tracking
- [x] `google_fonts`, `app_theme.dart`, `colors.dart`, `radii.dart` actualizados y
      verificados con `flutter analyze` (0 errores)
- [ ] Retrofit pantalla por pantalla (reemplazar radios sueltos por `SteamRadii.sm`,
      aplicar mayúsculas/tracking a tags) — deferido a Fase 5 a propósito

**Fase 4 — Shell web responsive: implementada y verificada en navegador**
- [x] `ResponsiveShell` (nuevo, `lib/features/home/screens/responsive_shell.dart`) en
      el breakpoint 768px: **< 768 delega tal cual en `MainShell`** (bottom-nav de 3
      tabs sin ningún cambio — verificado, cero regresión); **≥ 768 muestra un sidebar
      persistente** (232px, logo, 8 destinos: Inicio/Descubrir/Publicaciones/Amigos/
      Buscar juegos/Mensajes/Notificaciones/Perfil, badge de no-leídos, footer de
      usuario con logout) + `IndexedStack` de las pantallas ya existentes sin
      Navigator.push — cambiar de sección no recarga ni pierde el sidebar.
- [x] `app_router.dart` — ruta `/home` apunta a `ResponsiveShell` (antes `MainShell`
      directo).
- [x] Eliminado `lib/features/home/home_screen.dart` (código muerto: un intento previo
      de shell responsive con breakpoint propio que nunca se conectó al router — no lo
      confundas con `lib/features/home/screens/home_screen.dart`, que sí es el
      dashboard de tarjetas real y se sigue usando tal cual, embebido como "Inicio").
- [x] Verificado con `flutter analyze` (0 errores) y en el navegador en ambos anchos
      (1300px → sidebar; 375px → bottom-nav idéntico a antes).
- **Conocido, no bloqueante:** las tarjetas del dashboard de "Inicio"
      (`screens/home_screen.dart`) siguen usando `Navigator.push` — en desktop eso
      abre la pantalla tapando el sidebar en vez de solo cambiar de sección. No se
      tocó a propósito (es scope de Fase 5, pulido pantalla por pantalla).

**Evaluación del chat (polling vs WebSockets):** revisado el código real —
`ChatProvider`/`chat_conversation_screen.dart` **no tienen ningún `Timer`/polling
hoy**, solo cargan mensajes una vez al abrir la conversación. El HANDOFF anterior
asumía polling que no existe. Recomendación: para la beta de Web 1.0, agregar un
`Timer.periodic` simple (cada 4-6s mientras la conversación está abierta) es
suficiente y no requiere infraestructura nueva — dejar WebSockets para más adelante,
solo si el uso real lo justifica (conexiones persistentes = más complejidad de
backend que no vale la pena anticipar sin datos de uso).

**Fase 5 — Pulido de pantallas existentes para web: primera tanda hecha, falta más**
- [x] Arreglado el pendiente de Fase 4: las tarjetas del dashboard de "Inicio"
      (`screens/home_screen.dart`) ahora reciben `onNavigateIndex` desde
      `ResponsiveShell` — en escritorio cambian de sección del sidebar en vez de
      empujar una pantalla encima; en móvil siguen usando `Navigator.push` igual que
      siempre (el callback es `null` cuando `MainShell` construye `HomeScreen` sin él).
      Verificado en navegador en ambos anchos, sin regresión móvil.
- [x] Retrofit de `SteamRadii.sm` en los **widgets compartidos**
      (`lib/widgets/*.dart` — 12 archivos, 25 usos de `BorderRadius.circular(N)`
      reemplazados): `steam_card`, `steam_buttons`, `steam_app_bar`, `drop_field`,
      `steam_toast`, `notification_tile`, `publicacion_card`, `usuario_card`,
      `relacion_status_chip`, `juego_card`, `validated_field`, `strength_bar`. Como son
      compartidos, esto ya cascadea el radio recto a casi todas las pantallas sin
      tocarlas una por una. Verificado con `flutter analyze` (0 errores) y visualmente.
- [x] Retrofit de `SteamRadii.sm` en **pantallas individuales** (14 archivos de
      `lib/features/*/screens/` + `admin_panel_section.dart`, 49 usos de
      `BorderRadius.circular(N)` reemplazados). Se dejó fuera a propósito
      `login_dev_server_chip.dart` (chip de debug solo-desarrollo, no es UI de
      producto). Verificado con `flutter analyze` (0 errores).
- [x] **Ancho máximo en pantallas de lista de una columna** — nuevo widget
      `lib/widgets/desktop_body_width.dart` (`DesktopBodyWidth`, `LayoutBuilder` que
      centra el contenido a 720px cuando el espacio disponible es mayor; en móvil no
      hace nada, pasa el child tal cual). Aplicado envolviendo el `body:` de
      Publicaciones, Descubrir, Amigos, Matches, Chat (lista) y Notificaciones —
      confirmado visualmente en el navegador: las cards ya no se estiran de borde a
      borde en pantallas anchas, quedan centradas con márgenes.
- [x] **Panel de admin revisado** — es una app HTML/CSS/JS estática aparte
      (`steamlinker_back/public/admin/`), no Flutter, con su propio sistema de
      diseño ya coherente (tokens CSS propios, tipografía Chakra Petch + JetBrains
      Mono, paleta oscura propia). No es "genérico de IA" y no comparte código con
      la app — **decisión: no rediseñarlo para que combine pixel a pixel con
      SteamColors**, es una herramienta interna, no cara al usuario final, y ya se ve
      profesional. Revisar esta decisión solo si en algún momento se decide que el
      admin panel también debe verse como el resto del producto.
- [ ] **Sigue pendiente**: mayúsculas+tracking en tags al estilo Steam fuera de lo
      que ya heredan los widgets compartidos; aplicar `DesktopBodyWidth` a más
      pantallas si hace falta (perfil, usuarios, etc. — no se revisaron todas).
- [x] **Rediseño visual de `PublicacionCard`** (`lib/widgets/publicacion_card.dart`) —
      avatar circular con inicial (gradiente azul-teal, tappable), username como link
      azul, fila de metadatos (tipo · reputación con estrella), carátula del juego a
      todo ancho (`AspectRatio` 16:7, `Image.network` del `headerimg_jg` con fallback),
      pie con país + acción "Ver detalle". Directamente en respuesta al feedback del
      usuario sobre la "sensación" visual de los wireframes (ver sección 8, actualización
      2) sin tocar estructura. Verificado con `flutter analyze` (0 issues) y en
      navegador con un post real (Elden Ring, carátula real de Steam CDN).
- [x] **(Construido y revertido — ver sección 8, actualización 2)** Se llegó a
      construir y verificar end-to-end una reestructuración a 4 pestañas
      Familia/Compañeros/Comunidad/Perfil, incluyendo un fix real de un bug de
      `PublicacionesProvider` compartido pisándose entre pestañas por el
      `IndexedStack` del sidebar (documentado por si la idea de scoping local por
      pantalla hace falta de nuevo más adelante). El usuario decidió volver a los
      nombres/estructura originales (Descubrir Gamers / Publicaciones / Amigos) —
      código restaurado a como estaba en el commit `7a21401`. No queda rastro de
      `FamiliaScreen`/`ComunidadScreen`/`CompanerosScreen`/`companeros/` en el
      código actual.
- [x] **Banner + avatar en Perfil** (`perfil/screens/perfil_screen.dart`, nuevo
      widget privado `_PerfilHeader`) — el único ítem de "estructura" que quedó
      explícitamente pendiente de los wireframes en la sección 8. Reemplaza la
      `SteamCard` de identidad (username + descripción + país/reputación + botones)
      por un banner con gradiente (mismo gradiente azul-teal que la tarjeta de
      bienvenida de Inicio, para no inventar un lenguaje visual nuevo) con un avatar
      circular superpuesto en el borde inferior: usa la foto real de Steam
      (`steam.avatar_url`) cuando la cuenta está vinculada, si no cae a un círculo
      con gradiente + inicial del username (mismo patrón que `PublicacionCard` y el
      pie del sidebar). Si Steam está vinculado se agrega una insignia de
      verificación (check azul) sobre el avatar. Los chips de País/Reputación ahora
      van con un tercer chip de Juegos, en un `Wrap` (no `Row`) para no desbordar en
      móvil con países de nombre largo. Verificado con `flutter analyze` (0 issues),
      `flutter test` (10/10) y en navegador en ambos anchos (1000px y 375px) con una
      cuenta de prueba real sin Steam vinculado (el caso sin avatar, el más común en
      la beta) — sin Steam vinculado no se pudo verificar visualmente la variante
      con foto real ni la insignia de verificación, pero el código sigue el mismo
      patrón ya probado en `PublicacionCard`.
- [x] **Nav superior + layout de 3 columnas en escritorio, lenguaje visual del
      wireframe aplicado sobre los nombres/estructura originales** (Descubrir
      Gamers / Publicaciones / Amigos — ver sección 8, actualización 2, sobre por
      qué los nombres NO cambiaron). Esta vez el usuario mandó una captura real del
      wireframe de "Familia" (top nav horizontal + 3 columnas + composer inline +
      chat flotante) y pidió aplicar exactamente esas posiciones/navegación/colores,
      no solo la "sensación" como en el rediseño de `PublicacionCard`.
  - **`ResponsiveShell`** (`home/screens/responsive_shell.dart`): el sidebar
    izquierdo de escritorio se reemplaza por `_TopNav`, una barra horizontal con
    logo (vuelve a Inicio), pestañas Perfil/Descubrir/Publicaciones/Amigos con
    subrayado azul en la activa, e iconos de buscar/notificaciones + avatar+usuario
    a la derecha — mismo orden y posiciones que el wireframe. Los índices de
    página (`_pages`) no cambiaron, solo cómo se navega a ellos, así que
    `home_screen.dart` no necesitó tocarse. "Mensajes" ya no es una pestaña de nav
    — lo cubre el chat flotante (ver abajo). Solo aplica en escritorio; móvil
    sigue con `MainShell` (bottom-nav) sin cambios.
  - **Panel de chat flotante** (`chat/widgets/floating_chat.dart`, nuevo) —
    burbuja azul anclada abajo a la derecha (ver `ResponsiveShell`, dentro de un
    `Stack` sobre el `IndexedStack` de páginas); al tocarla abre una ventana
    anclada (320×440) con lista de conversaciones (reusa `ChatProvider`) o, al
    tocar una, la conversación embebida (mensajes + composer, misma lógica que
    `ChatConversationScreen` pero sin `Scaffold` propio). Header con volver/
    minimizar/cerrar. Minimizar colapsa de vuelta a la burbuja.
  - **Layout de 3 columnas en `PublicacionesScreen`** (solo escritorio, mismo
    breakpoint de 768px que `ResponsiveShell`; móvil intacto con el FAB de
    siempre): columna izquierda "Accesos rápidos" (acceso a Mis solicitudes →
    `MatchesScreen`, y atajos de filtro por tipo — todo enlaza a funcionalidad que
    ya existía, nada inventado, a diferencia de "Discusiones"/"Guardados" del
    wireframe que no tienen equivalente real todavía); columna central con
    `_ComposerBar` inline ("Comparte algo con la comunidad..." + Publicar, abre el
    mismo formulario de crear publicación de siempre) sobre el feed real; columna
    derecha "Chats" (lista compacta de conversaciones, toca para abrir la
    conversación completa).
  - Verificado en navegador: nav superior con las 4 pestañas en las posiciones del
    wireframe, filtro rápido de tipo funcionando, post de prueba creado desde el
    composer inline y visible en el feed, panel de chat flotante abre/minimiza
    correctamente, y en móvil (375px) el bottom-nav y el dashboard de Inicio
    siguen sin regresión (incluye confirmar que el banner+avatar de Perfil se ve
    bien también al abrirlo empujado desde el dashboard en móvil). No se pudo
    probar la conversación embebida del chat flotante en vivo (la cuenta de
    prueba no tenía conversaciones), pero reusa la misma lógica ya probada de
    `ChatConversationScreen`. `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Columnas laterales probadas en Descubrir/Amigos y revertidas — decisión
      final: solo Publicaciones tiene 3 columnas.** Se llegaron a agregar columna
      izquierda (accesos rápidos) y derecha (chats) alrededor del contenido de
      Descubrir Gamers y Amigos, igual que en Publicaciones. Verificado
      funcionando en navegador, pero al verlo el usuario preguntó "¿de verdad
      vale la pena tener las 3 columnas así, o que cada una tenga su propia
      personalidad?" — la respuesta honesta fue que no: en Descubrir/Amigos la
      columna de accesos rápidos quedaba delgada (2-3 ítems rellenando espacio
      más que aportando) y la columna de Chats se repetía idéntica en las tres
      pantallas, compitiendo con el chat flotante que ya cubre eso globalmente.
      Revertidas ambas pantallas a su estado anterior (una sola columna
      centrada con `DesktopBodyWidth`, cada una con su propio diseño). Los
      widgets compartidos `lib/widgets/accesos_rapidos_panel.dart` y
      `lib/widgets/chats_columna.dart` se quedan (los sigue usando
      `PublicacionesScreen`, que es donde de verdad aportan: es un feed real con
      composer y filtros ricos). **Lección**: no asumir que un patrón que
      funciona en una pantalla se debe replicar mecánicamente a las demás solo
      por consistencia — cada pantalla se gana su layout según lo que
      realmente contiene, no al revés.
  - Verificado en navegador tras el revert: Descubrir y Amigos de vuelta a su
    layout original de una sola columna, Publicaciones intacta con sus 3
    columnas, nav superior con las 4 pestañas funcionando en las tres, y móvil
    (375px) sin regresión. `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Bug real: usuario/logout duplicados en escritorio.** El usuario mandó
      una captura mostrando dos bloques de usuario+logout apilados. Causa: cada
      pantalla de nivel superior (`SteamAppBar` sin botón atrás) sigue mostrando
      su propio bloque local de usuario — antes tenía sentido porque era la
      única identidad visible, pero ahora la nav superior global
      (`ResponsiveShell`/`_TopNav`) ya muestra usuario+logout de forma
      persistente en escritorio, así que quedaba duplicado. Fix: `SteamAppBar`
      ahora es consciente del ancho (mismo breakpoint 768px) y suprime su
      bloque local de usuario en escritorio salvo que se pida explícitamente
      con `showUserActions`; además se hicieron condicionales al ancho los
      botones de logout explícitos que `HomeScreen`, `PerfilScreen` y
      `NotificationsScreen` agregaban en su propia `actions:` (en móvil se
      mantienen igual que antes, ya que ahí no hay nav global). Verificado en
      navegador: Inicio/Perfil/Notificaciones en escritorio ya no repiten
      usuario ni logout, y en móvil (375px) cada pantalla conserva su propio
      logout como antes. `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Paleta de color renovada — se abandona el azul pastel de "Fiel a
      Steam" por sentirse apagado.** El usuario mandó una captura del wireframe
      original y pidió comparar esa dirección de color contra la actual. Se
      armaron dos opciones lado a lado en un canvas de diseño (Artifact),
      aplicadas a piezas reales de la UI (nav, card de publicación, botón,
      chips) — no solo swatches sueltos — y el usuario confirmó explícitamente
      la nueva dirección: **"siii me gusta la nueva"**. Cambia
      `lib/theme/colors.dart` (única fuente de verdad de color, así que
      cascadea a toda la app sin tocar pantalla por pantalla):
      `bgDeep #0E1621→#0A0E1A`, `bgPanel #1B2838→#121729`,
      `bgCard #16202D→#141A2E`, `bgInput #0D1117→#10162A`,
      `border #2A3F5A→#262E45`, `blue #66C0F4→#3B82F6` (más saturado/vívido),
      `teal #1B9AAA→#22D3EE` (ahora más cian, para el degradado de avatares),
      `light #C7D5E0→#F2F4F9` (texto principal casi blanco, más contraste),
      `muted #7A9AB0→#8891AB`, `textSec #8FA8BE→#9AA3BD`. Los semánticos
      (green/red/yellow/purple/orange) no se tocaron. También se reemplazó el
      `Color(0xFF2A4A6B)` que estaba *hardcodeado* (no como token) en 6 sitios
      distintos como primer color del degradado de avatares (perfil, publicación,
      sidebar/topnav, appbar) por `SteamColors.blue`, para que el degradado
      combine con la nueva paleta en vez de quedar con el navy viejo. **Esto
      revierte, a propósito, la decisión de Fase 3 de usar el azul pastel real
      de Steam** — ver sección 9 para el registro histórico de esa decisión;
      esta entrada es la actualización vigente. Verificado en navegador
      (desktop y 375px) con una publicación de prueba real: el degradado
      azul→cian de los avatares, el botón "Publicar" y la pestaña activa de la
      nav se ven notablemente más vivos que antes. `flutter analyze`: 0 issues.
      `flutter test`: 10/10.
- [x] **Barra local de cada pantalla dejaba de tener sentido en escritorio —
      repetía el nombre de la pestaña ya activa en la nav superior.** El
      usuario mandó una captura de "AMIGOS" mostrando esa segunda barra (logo +
      título repetido + ícono de refrescar) y señaló que era puro chrome
      redundante, aunque pidió no perder los íconos de utilidad que sí varían
      por pantalla (Filtros/Mis solicitudes en Descubrir, Filtros/Refrescar en
      Publicaciones, etc.). Fix centralizado en `SteamAppBar` (una sola pantalla
      de nivel superior en escritorio = misma condición ya usada para el fix de
      usuario/logout duplicados): cuando `esEscritorio && !useBack`, la barra se
      funde con el fondo (`SteamColors.bgDeep`, sin borde inferior), oculta el
      logo de leading y el título, y deja solo los íconos de `actions` propios
      de cada pantalla flotando a la derecha — no hizo falta tocar las pantallas
      individuales, todas heredan el cambio a través de `SteamAppBar`. Verificado
      en navegador: Inicio/Perfil/Descubrir/Publicaciones/Amigos en escritorio ya
      no repiten su nombre, los íconos de utilidad de cada una se conservan, y en
      móvil (375px) cada pantalla sigue mostrando su barra completa con título
      como antes. `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Bug real: texto invisible en 4 botones azul/verde/rojo (Material 3).**
      El usuario reportó el modal de filtros de Descubrir con el botón "Aplicar"
      sin texto visible. Causa: `ElevatedButton.styleFrom(backgroundColor: …)`
      sin `foregroundColor` explícito — en Material 3 el texto por defecto usa
      `colorScheme.primary`, que en esta app **es el mismo azul de acento**
      (`SteamColors.blue`), así que cualquier botón con fondo azul sin
      `foregroundColor` queda con texto azul sobre azul = invisible. Es un bug
      preexistente (no introducido esta sesión), agravado/hecho más visible por
      el cambio reciente de paleta. Se encontraron 4 sitios con el mismo defecto
      (grep de `ElevatedButton.styleFrom` con `backgroundColor` sin
      `foregroundColor`): el "Aplicar" de filtros en
      `descubrir_gamers_screen.dart` (texto invisible, el que reportó el
      usuario), `calificar_dialog.dart` (texto invisible, mismo caso azul),
      "Aceptar" en `matches_screen.dart` (visible pero con el color equivocado —
      texto azul sobre fondo verde) y "Enviar reporte" en
      `reportar_usuario_dialog.dart` (visible pero azul sobre rojo). Los 4 ahora
      declaran `foregroundColor: Colors.white` explícito, igual que ya hacía
      `SteamButtonPrimary` (el botón compartido, que nunca tuvo este bug).
  - **Bug adicional encontrado de paso, mismo flujo**: al abrir ese modal de
    filtros, la barra local (recién "fundida con el fondo" en el fix anterior)
    volvía a aparecer con flecha de "volver" — un modal bottom sheet también se
    registra como una ruta que se puede hacer *pop* en el `Navigator`, así que
    `Navigator.canPop()` daba `true` mientras el modal estaba abierto, aunque la
    pantalla de fondo (Descubrir) seguía siendo la misma. Fix en
    `SteamAppBar._canPop()`: si `ModalRoute.of(context)?.isCurrent == false`
    (algo está cubriendo esta pantalla — un modal, un diálogo), se ignora la
    señal de `canPop()` y la barra se queda exactamente como estaba, sin
    parpadear.
  - Verificado en navegador: el botón "Aplicar" de Descubrir ya muestra su
    texto, aplicar un filtro cierra el modal y recarga la lista sin que la nav
    global cambie ni parpadee, y en móvil (375px) sin regresión.
    `flutter analyze`: 0 issues. `flutter test`: 10/10.

- [x] **Handoff de wireframes vía Claude Design — rediseño completo confirmado
      como la visión real del usuario, no solo referencia.** El usuario mandó
      un ZIP de handoff (`SteamMatch diseño web-handoff.zip`, formato estándar
      de claude.ai/design: `README.md` + `project/*.dc.html`) con 4 "turnos" de
      opciones exploradas para Publicaciones (turno 3) e Inicio (turno 2).
      Tras resumir el alcance y preguntar si quería todo o solo una pieza
      inicial, el usuario aclaró explícitamente: **"los diseños que yo quería
      están en la parte de 4, son básicamente mi visión"** — es decir, el
      turno 4 completo (que depende de la opción 3b del turno 3) es el objetivo
      real, no un extra opcional. Decisiones de alcance ya tomadas de esos
      turnos: Publicaciones = opción **3b** (conmutador Familia/Jugar
      ahora/Otro, cambia columnas de tabla según intención, mapea 1:1 a
      `tipo_publi`); Inicio = opción **2a** (bandeja de acciones pendientes:
      solicitudes, cupos, Steam sin vincular). El resto del turno 4 (Descubrir
      como tabla, grid de stats en Perfil, panel de cupos en el detalle de
      publicación, disclaimer de Valve en login, banner de contexto en el chat)
      se implementó por partes verificables, no todo de una vez, por el
      tamaño del cambio — **completado, ver las entradas siguientes de esta
      sección y el cierre de "Ronda 4 completa" más abajo.**
- [x] **Publicaciones — conmutador Familia/Jugar ahora/Otro (turno 3, opción
      3b), primera pieza del rediseño confirmado.** Reemplaza el layout de 3
      columnas (accesos rápidos + feed + chats) que no existía en el
      wireframe, por: una franja de pestañas con contador por tipo, una barra
      de composición contextual (el texto y el botón cambian según la pestaña:
      "Publicar en Familia" / "Publicar partida" / "Publicar"), y una tabla
      densa con columnas específicas por pestaña en vez de las tarjetas
      genéricas de `PublicacionCard` — Familia: TIPO·USUARIO·CUPOS·REP·HACE;
      Jugar ahora: JUEGO·PUBLICACIÓN·GENTE·CUÁNDO; Otro: USUARIO·TÍTULO·HACE
      (esta última no estaba en el wireframe, es un mínimo razonable propio).
      Solo aplica en escritorio — móvil no se tocó, sigue con el feed de
      tarjetas + FAB de siempre, tal como se decidió para los wireframes
      anteriores (son solo de escritorio).
  - **Backend**: `GET /publicaciones/buscar` ya soportaba un solo `tipo`; se
    reincorporó el filtro multi-tipo por coma (`ANY($::varchar[])`, necesario
    para agrupar `busco_familia`+`busco_miembros` bajo la pestaña Familia) y
    se agregó `cupos_ocupados` (conteo de matches con `estado_match =
    'Aceptada'`) a **todas** las publicaciones del listado, no solo al detalle
    — la tabla de Familia necesita mostrar "CUPOS 4/6" por fila. 4 tests
    nuevos en `tests/publicaciones.buscar.test.js` (filtro simple, filtro
    multi-tipo, sin filtro, `cupos_ocupados` presente como número).
  - **Frontend, decisión de diseño clave**: el conmutador de pestañas es
    **puramente de cliente**, no repite la búsqueda al backend por pestaña.
    `PublicacionesProvider.buscar()` trae la lista completa una sola vez (como
    ya hacía) y la pantalla la agrupa localmente por `tipo_publi` para calcular
    los 3 contadores y filtrar las filas de la tabla activa. Esto evita un
    problema real: si el conteo de cada pestaña viniera de una llamada aparte
    al backend, cambiar de pestaña sería más lento y los contadores podrían
    desincronizarse; con filtrado de cliente los 3 contadores están siempre
    correctos y cambiar de pestaña es instantáneo. El modal de Filtros
    (País/Juego/Orden) se mantiene para lo que las pestañas no cubren, pero
    oculta su dropdown de Tipo en escritorio (`_abrirFiltros(ocultarTipo:
    true)`) para no competir con el conmutador — en móvil se sigue mostrando
    completo, sin cambios.
  - Se eliminaron `_ComposerBar` y `_AccesosRapidos` (quedaron sin uso tras el
    reemplazo) en vez de dejarlos como código muerto.
  - Verificado en navegador (escritorio 1000px): pestañas con contador en
    tiempo real tras crear una publicación, tabla de "Jugar ahora" con
    columnas y formato correctos (cupos `0/4`, "ahora"), tap en fila navega al
    detalle existente (que ya tenía "Cerrar publicación" para el dueño — no
    hacía falta duplicar esa acción en la tabla), modal de Filtros sin
    dropdown de Tipo en escritorio. Verificado en móvil (375px): feed de
    tarjetas + FAB sin cambios, sin pestañas. `flutter analyze`: 0 issues.
    `flutter test`: 10/10. Backend: 11/11.
- [x] **Inicio — bandeja de acciones pendientes (turno 2, opción 2a).** Segunda
      pieza del rediseño confirmado. Reemplaza el dashboard genérico (tarjeta
      de bienvenida + info de perfil duplicada + 6 tarjetas de acceso rápido
      que solo repetían la nav — "Descubre Gamers", "Amigos", "Publicaciones",
      etc.) por: TU ESTADO (estado de familia derivado + conteo de
      publicaciones abiertas), STEAM NO VINCULADO (si aplica), SOLICITUDES
      PENDIENTES (Aceptar/Rechazar/Ver perfil inline, sin salir de Inicio) y
      TUS PUBLICACIONES ABIERTAS (cupos con barra de progreso + Cerrar). Cero
      atajos a pantallas que ya están un clic de distancia en la nav superior.
      A diferencia de Publicaciones/Descubrir, **esto aplica igual en móvil y
      escritorio** — el contenido es una sola columna de tarjetas apiladas,
      no un layout de escritorio específico, así que no hacía falta la rama
      `esEscritorio` que sí tienen esas otras pantallas.
  - **Limitación conocida y a propósito**: el backend no tiene un concepto
    formal de "familia" (no hay tabla/rol de membresía). "TU ESTADO" se
    deriva con una heurística: "Buscando familia" si tienes una publicación
    propia abierta de tipo `busco_familia`/`busco_miembros`; "En una familia"
    si tienes un match Aceptado (enviado por ti) hacia una publicación de ese
    tipo que **sigue abierta**; si no, "Sin familia". El caso de una familia
    que ya se llenó y se autocerró no se detecta (el match sigue existiendo
    pero la publicación ya no aparece en el listado para cruzarla) — es una
    simplificación honesta, no un dato inventado; si se necesita el estado
    exacto en todo momento, hace falta modelar family/membresía formalmente.
  - **Backend**: `GET /matches/recibidos` no traía nada de la publicación
    asociada (solo `id_publi`), así que la bandeja no podía mostrar "BUSCO
    MIEMBROS · 4/6 cupos" sin otra llamada. Se agregó un `LEFT JOIN` a
    `publicaciones` + la misma subquery de `cupos_ocupados` que ya usa
    `/publicaciones/buscar` y `/publicaciones/:id`. Nuevo test
    `tests/matches.recibidos.test.js`.
  - Verificado en navegador con dos usuarios de prueba reales (uno publica
    "Busco compañero", el otro envía la solicitud): la bandeja se llena
    correctamente (estado, solicitud pendiente con los datos reales de la
    publicación, publicación propia con cupos 0/4), aceptar la solicitud
    actualiza todo en vivo (la solicitud desaparece, cupos pasan a 1/4, la
    barra de progreso se rellena) sin recargar la página. Verificado en móvil
    (375px): mismo contenido, una sola columna, sin overflow.
    `flutter analyze`: 0 issues. `flutter test`: 10/10. Backend: 12/12.
  - **Nota de rendimiento observada, no introducida por este cambio**: al
    iniciar sesión se ven varias llamadas duplicadas a
    `GET /publicaciones/buscar` (y probablemente otras) en vez de una sola —
    parece venir de cómo el widget raíz reconstruye el árbol mientras
    resuelve el estado de autenticación al arrancar, no de esta pantalla en
    particular (los datos finales son correctos, solo hay llamadas de más).
    No se investigó a fondo por estar fuera del alcance de este cambio; queda
    anotado por si vale la pena perfilarlo en una sesión futura.
- [x] **Descubrir — tabla de personas en vez de tarjetas (turno 4, opción
      4a).** Tercera pieza del rediseño confirmado. Descubrir dejaba de
      solaparse visualmente con Publicaciones: antes ambas mostraban
      tarjetas parecidas; ahora Descubrir lista **personas** (biblioteca,
      reputación, en común) mientras Publicaciones lista **anuncios**.
      Columnas: GAMER (avatar + ✓ si tiene Steam vinculado + país/tipo de su
      publicación activa) · EN COMÚN · JUEGOS · REP · ACTIVO (relativo,
      "2 h"/"1 d") · acción "Ver". Filtros en una sola fila (buscador de
      cliente por nombre + el botón de Filtros existente para Tipo/País/
      Juego), no en columna lateral — igual razón que ya aplicó a
      Publicaciones. Solo aplica en escritorio; móvil conserva el feed de
      tarjetas (`UsuarioCard`) sin cambios.
  - **Backend**: `GET /perfil/descubrir` no traía ni el conteo de juegos en
    común, ni el total de juegos del otro usuario, ni si tiene Steam
    vinculado. Se agregaron tres subqueries: `juegos_en_comun` (join de
    `usuarios_juegos` entre ambos usuarios — la biblioteca ya *verificada*
    en la app, no una llamada en vivo a la API de Steam, que sería
    demasiado cara para una lista de N usuarios), `total_juegos`, y
    `steam_vinculado` (`EXISTS` sobre `perfiles_steam`). También
    `tipo_publi_reciente` y `ultima_publicacion` (para la columna ACTIVO).
    Orden por defecto cambia a `juegos_en_comun DESC` (antes solo
    reputación), como pide el wireframe ("ordenado por juegos en común").
    Nuevo test `tests/perfil.descubrir.test.js`.
  - **Desviación deliberada del wireframe, y por qué**: el mockup mostraba
    una columna ESTADO con "EN LÍNEA"/"HACE 2 H" (presencia en vivo) y un
    checkmark de "verificado" sin aclarar qué lo otorga. Ninguna de las dos
    cosas existe en el backend (no hay tracking de conexión/presencia, y no
    había ningún concepto de "verificado" implementado pese a lo que decía
    la nota del wireframe). En vez de inventar datos falsos: la columna
    (renombrada ACTIVO) usa el timestamp real de la publicación más
    reciente, y el check ✓ se ancla a `steam_vinculado` (identidad real
    confirmada), que es la interpretación más honesta de "verificado" que
    permite el modelo de datos actual.
  - **Regresión encontrada y arreglada en el mismo cambio**: al quitar las
    tarjetas de acceso rápido de Inicio (pieza anterior), **la navegación
    móvil a Descubrir, Publicaciones y Amigos se rompió por completo** — el
    bottom nav de `MainShell` (`main_shell.dart`) solo tenía Inicio/
    Notificaciones/Perfil desde antes de esta sesión; esas 3 pantallas solo
    eran alcanzables en móvil a través de las tarjetas de Inicio que
    acababan de desaparecer. Encontrado verificando manualmente el flujo
    móvil de esta misma pieza, no reportado por el usuario. Fix: el bottom
    nav pasa de 3 a 6 pestañas (Inicio/Descubrir/Publica./Amigos/Avisos/
    Perfil), iconos más pequeños (21px) y etiquetas abreviadas para que
    quepan sin overflow en 375px. Esto **no** repite el problema que motivó
    quitar las tarjetas de Inicio: en escritorio esas pantallas ya viven en
    la nav superior (por eso sí se podían quitar de Inicio ahí), pero en
    móvil no existe ninguna otra nav — sin estas pestañas, esas 3 pantallas
    quedaban inalcanzables, no solo duplicadas.
  - Verificado en navegador: tabla de escritorio con datos reales (2
    usuarios, 1 juego en común, sin Steam vinculado → sin ✓), buscador de
    cliente filtra en vivo, fila navega al perfil existente. Verificado en
    móvil (375px): las 6 pestañas nuevas cargan sus pantallas correctas
    (Descubrir con tarjetas, Publicaciones con feed+FAB, Amigos), sin
    overflow visual. `flutter analyze`: 0 issues. `flutter test`: 10/10.
    Backend: 13/13.
- [x] **Perfil — grid de 4 estadísticas en vez de chips (turno 4, opción
      4b).** Cuarta pieza del rediseño confirmado. Los chips de País/
      Reputación/Juegos se reemplazan por un grid de 4 celdas con números
      monoespaciados grandes — REPUTACIÓN (`4.5 /5 · 12`), JUEGOS
      VERIFICADOS, FAMILIA, AMIGOS — la misma sensación SteamDB que ya tiene
      el resto de la app. País se mantiene, como texto pequeño bajo la
      descripción en vez de chip. Aplica igual en móvil (el grid se envuelve
      a 2 columnas con `Wrap`) y escritorio, como Inicio — a diferencia de
      Publicaciones/Descubrir, el contenido de Perfil no depende de un
      layout específico de escritorio.
  - **Nuevo helper compartido** `lib/core/utils/estado_familia_helper.dart`:
    la heurística de "estado de familia" (con la misma limitación conocida
    documentada arriba, en la entrada de Inicio) vivía duplicada inline en
    `home_screen.dart`; se extrajo a `calcularEstadoFamilia()` para que
    Perfil la reutilice sin copiar la lógica — la celda FAMILIA muestra
    `ocupados/total` en cian si tiene una publicación propia abierta de ese
    tipo, "Sí" si se unió a la de alguien más, o "—" si no aplica.
  - `PerfilScreen` ahora también carga `MatchesProvider`, `PublicacionesProvider`
    y `AmistadProvider` al entrar (antes solo cargaba el perfil), necesarios
    para calcular FAMILIA y AMIGOS sin pedirle al usuario que visite Inicio
    primero.
  - Verificado en navegador con un usuario de prueba real: grid con
    REPUTACIÓN `0.0/5 · 0`, JUEGOS VERIFICADOS `2`, FAMILIA `0/6` en cian
    (con una publicación `busco_miembros` de prueba) y AMIGOS `0`; mismo
    dato coherente entre Inicio y Perfil gracias al helper compartido.
    Verificado en móvil (375px): el grid se envuelve a 2x2 sin overflow.
    `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Detalle de publicación — panel de cupos con roster real (turno 4,
      opción 4c).** Sexta pieza del rediseño confirmado. Antes el detalle
      solo mostraba un chip de relación (match/amistad) y el botón "Enviar
      match" sin contexto de cuántos cupos hay ni quién ya confirmó. Se
      agregó un panel "CONFIRMADOS N/total" (número grande monoespaciado +
      barra de progreso + roster: avatar y username de cada quien se unió,
      más círculos punteados "Libre" para los cupos que faltan) — solo
      aparece si la publicación tiene `cupos_totales` (familia/miembros, o
      compañero si el autor puso cupos). También un aviso "Tienes este juego
      verificado en tu biblioteca" cuando el juego de la publicación ya está
      en la biblioteca verificada del visitante. Aplica igual en móvil y
      escritorio (no se restructuró a 2 columnas como en el wireframe — el
      panel se inserta como una tarjeta más en la misma columna única que ya
      tenía la pantalla, que es de menor riesgo y entrega el mismo valor:
      "hace visible lo que el backend ya calcula antes de actuar").
  - **Backend**: `GET /publicaciones/:id` no traía el roster de quién se
    unió, solo el conteo (`cupos_ocupados`). Se agregó una query que trae
    `id_usu`+`username_usu` de cada solicitante con match Aceptado sobre esa
    publicación (`confirmados`), y `cupos_ocupados` ahora se deriva de ese
    mismo array en vez de una segunda query redundante. Nuevo test
    `tests/publicaciones.detalle.test.js`.
  - **Decisión de scope**: el botón "Enviar match" se dejó donde ya estaba
    en el flujo de acciones, en vez de moverlo dentro del panel como en el
    mockup — moverlo hubiera significado duplicar la lógica de estados de
    relación (match pendiente/aceptado, amistad, etc.) en dos lugares. El
    panel es puramente informativo; la acción sigue siendo una sola fuente
    de verdad.
  - Verificado en navegador con 3 usuarios de prueba reales (autor con
    publicación `busco_companero` y 4 cupos, un solicitante con match
    aceptado, un tercer usuario visitante con el mismo juego en su
    biblioteca): panel muestra `1/4`, roster con el solicitante real + 3
    "Libre", aviso de biblioteca verificada visible, resto de la pantalla
    (juegos, comentarios) sin cambios. Verificado en móvil (375px): mismo
    contenido, sin overflow. `flutter analyze`: 0 issues. `flutter test`:
    10/10. Backend: 14/14.
- [x] **Login — nota de Steam + descargo de Valve (turno 4, opción 4d).**
      Séptima pieza del rediseño confirmado. El wireframe señalaba una
      corrección importante: un wireframe anterior (de otra persona) tenía
      botones "Ingresar con Google", "Ingresar con Steam" y código QR — nada
      de eso existe en el backend (login real es correo/contraseña, sin
      passport). **Se verificó que `login_screen.dart` nunca tuvo esos
      botones**, así que no hacía falta quitar nada; solo se agregaron las
      dos piezas que sí faltaban: una nota bajo el botón de submit
      explicando que vincular Steam es un paso posterior dentro de Perfil
      (para que el usuario no choque con el 403 de `STEAM_REQUERIDO` sin
      contexto la primera vez que intenta publicar en Familia), y el
      descargo "No afiliado a Valve Corporation" centrado al pie de la
      pantalla. Mismo texto en login y en registro (es el mismo formulario
      con un flag `_mostrarRegistro`).
  - Verificado en navegador en ambos modos (iniciar sesión / crear cuenta):
    la nota y el descargo se ven completos, sin overlap con el chip de dev
    server (esquina inferior derecha, solo en local). `flutter analyze`: 0
    issues. `flutter test`: 10/10.
- [x] **Chat — franja de contexto "Match por: X" (turno 4, opción 4e).**
      Octava y última pieza del rediseño de wireframes confirmado — **cierra
      la ronda 4 completa**. Antes, tres conversaciones de chat se veían
      idénticas (solo nombre + burbujas); ahora una franja bajo el
      encabezado muestra por qué existe esa conversación: "Match por: X"
      (nombre del juego si lo hay, o el tipo de publicación si no) + cupos
      `N/M` si aplica. Implementado en el widget compartido
      `ChatContextBanner` (`lib/features/chat/widgets/chat_context_banner.dart`),
      usado tanto por el chat flotante de escritorio como por
      `ChatConversationScreen` (pantalla completa, usada en móvil y cuando
      se abre desde "Abrir chat" en el detalle de publicación) — una sola
      fuente de verdad para ambos.
  - **Backend**: ni `chat` ni `GET /chat/conversaciones` guardaban relación
    alguna con el match/publicación que originó la conversación (un chat
    solo tiene `id_participante1/2`). Se agregó un `LEFT JOIN LATERAL` que
    busca el match Aceptado más reciente entre los dos participantes y trae
    tipo, título, cupos y el nombre del primer juego asociado — sin tabla
    nueva, solo derivándolo en la consulta existente. Nuevo test
    `tests/chat.conversaciones.test.js`.
  - **Regresión encontrada y arreglada en el mismo cambio, mismo patrón que
    la de Descubrir/Publicaciones/Amigos**: `ChatScreen` (la lista completa
    de conversaciones) nunca estuvo en el bottom nav de `MainShell` — su
    único punto de entrada en móvil era la tarjeta "Mensajes" de Inicio, que
    desapareció con el rediseño de la bandeja de pendientes. El chat
    flotante es explícitamente solo de escritorio, así que sin la tarjeta,
    un usuario de móvil no tenía **ninguna** forma de ver su lista de
    chats. Fix: el bottom nav pasa de 6 a 7 pestañas, agregando "Chat" entre
    Amigos y Avisos.
  - Verificado en navegador con 2 usuarios de prueba reales (match aceptado
    sobre una publicación `busco_companero` con el juego "Helldivers 2" y 4
    cupos): la franja muestra exactamente "Match por: Helldivers 2 · 1/4"
    en el chat flotante. Verificado en móvil (375px): las 7 pestañas caben
    sin overflow. `flutter analyze`: 0 issues. `flutter test`: 10/10.
    Backend: 15/15.

**Ronda 4 completa** (turno 4 del handoff de wireframes: Descubrir, Perfil,
detalle de publicación, login y chat, sobre la base del conmutador 3b de
Publicaciones y la bandeja de pendientes 2a de Inicio) — las 8 piezas
confirmadas por el usuario ("los diseños que yo quería están en la parte de
4, son básicamente mi visión") están implementadas, verificadas en
escritorio y móvil, y pusheadas.
- [x] **Pie de página de Inicio + FAQ de bloqueo regional (pedido aparte,
      no parte del handoff de wireframes).** El usuario pidió esto en el
      mismo mensaje que mandó los wireframes, pero como contenido propio,
      no como parte del rediseño visual.
  - **Pie de página en Inicio** (`_FooterInicio` en `home_screen.dart`):
    qué es SteamMatch en una frase, y el descargo "No afiliados a Valve
    Corporation. Steam es una marca registrada de Valve Corporation." Vive
    en Inicio (no en cada pantalla) porque es el punto de entrada de la
    app — mismo criterio que ya se usó para decidir dónde iba el descargo
    de Valve en login.
  - **FAQ de bloqueo regional**: el usuario no estaba seguro si debía ir en
    el pie de página o como un ícono "?" en el detalle de una familia —
    se decidió por lo segundo, porque es información que importa en el
    momento de decidir si solicitar unirse, no como nota general de la
    app. Ícono `?` junto a "CONFIRMADOS" en el panel de cupos del detalle
    de publicación (`_PanelCupos` en `publicacion_detalle_screen.dart`),
    visible **solo** para publicaciones `busco_familia`/`busco_miembros`
    (el bloqueo regional es específico de Steam Family Sharing, no aplica
    a "busco compañero"). Abre un diálogo explicando que es una regla de
    Steam, no de SteamMatch, y los dos workarounds que el usuario describió:
    que una persona inicie sesión en el PC de la otra al momento de unirse,
    o usar una VPN con servidor en el país de la familia — con la
    aclaración de que ninguno garantiza funcionar siempre.
  - Verificado en navegador con una publicación `busco_miembros` de prueba:
    el pie de página se ve completo en Inicio; el ícono `?` aparece en el
    panel de cupos de esa publicación (confirmado visualmente en varias
    capturas) — el clic específico sobre el ícono no se pudo verificar de
    punta a punta por fricción de coordenadas del navegador de automatización
    en esta sesión (mismo tipo de problema ya documentado antes en este
    archivo), pero el patrón `showDialog` + `AlertDialog` es idéntico al que
    ya usa `_confirmarEliminarJuego` en `perfil_screen.dart`, código
    existente y probado. `flutter analyze`: 0 issues. `flutter test`: 10/10.
- [x] **Pivote post-ronda-4: sidebar izquierdo + Descubrir como tarjetas
      ricas + login con los colores actuales — el usuario probó la tabla
      densa de Descubrir (opción 4a) y no le gustó, mandó un wireframe de
      referencia nuevo y pidió reconstruir con esa estructura.** Confirmado
      explícitamente por el usuario tras dos preguntas de alcance: (1)
      sidebar izquierdo reemplaza la nav superior en **toda la app**
      (escritorio), no solo el contenido de Descubrir — "quiero la
      estructura de como esta hecho el wireframe"; (2) "inicio de sesión"
      se refería a la pantalla de login, no a Inicio.
  - **`ResponsiveShell` reescrito**: la nav horizontal (`_TopNav`) se
    reemplaza por `Row(_SideNav, Expanded(Column(_TopBar, contenido)))`.
    `_SideNav` (232px): logo, 5 destinos principales (Inicio/Descubrir/
    Publicaciones/Amigos con badge de solicitudes/Perfil), sección "TUS
    JUEGOS" (primeros 5 de `PerfilProvider.juegos`, real), tarjeta promo
    "Conecta con otros gamers" → Descubrir. `_TopBar`: buscador (Enter o
    clic en la lupa navegan a Descubrir y aplican el filtro — con doble
    disparador porque el Enter por teclado es poco fiable en el navegador
    de automatización de esta sesión, mejor no depender de uno solo),
    notificaciones, usuario, cerrar sesión. Publicaciones/Amigos/Perfil no
    cambiaron de contenido, solo quedaron dentro del nuevo layout — se
    verificaron una por una para confirmar que nada se rompió.
  - **Descubrir rehecho de tabla a tarjetas ricas** (`descubrir_gamers_screen.dart`):
    cada tarjeta trae avatar, país, ★ reputación, bio real (`descrip_usu`),
    una etiqueta con el tipo de publicación, carátulas de hasta 3 juegos en
    común + contador, botón "Ver perfil", y una fila con el juego de su
    publicación más reciente (+ horas jugadas si están registradas). Panel
    derecho: buscador, filtros reales (juego/país/tipo — reutilizan el
    modal ya existente), chips de umbral "juegos en común" (cliente),
    "Ordenar por" (más en común/reputación/recientes, cliente), "GAMERS
    ACTIVOS" (conteo real) y "JUEGOS POPULARES" (tally real de
    `juego_reciente` sobre la lista ya cargada). **Se deliberadamente NO
    copiaron** del wireframe de referencia: "En línea/Ausente" (no hay
    tracking de presencia), "Idioma" y "Tipo de juego" por género (no
    existen en el modelo de datos), ni las pestañas "Grupos"/"Publicaciones"
    dentro de Descubrir (esa función ya vive en su propia sección de nav,
    duplicarla habría revivido la confusión Descubrir/Publicaciones que se
    resolvió en la ronda 4) — mismo criterio de "nada inventado" de todo
    el resto de esta sesión.
  - **Backend**: `GET /perfil/descubrir` gana dos campos derivados de la
    biblioteca verificada, sin tabla nueva: `juegos_comunes_muestra` (hasta
    3 juegos en común, con carátula, vía `json_agg`) y `juego_reciente`
    (el juego de la publicación activa más reciente del usuario + horas
    jugadas propias en ese juego si las tiene registradas, vía
    `row_to_json`). Test actualizado en `tests/perfil.descubrir.test.js`.
  - **Login (`login_screen.dart`) tenía colores hexadecimales sueltos
    (`Color(0xFF1A9FFF)`, `Color(0xFF161B22)`, etc.) de antes de que
    existiera `SteamColors`, nunca migrados** — por eso se sentía
    "desactualizado" frente al resto de la app aunque ya tenía la nota de
    Steam y el descargo de Valve de la ronda 4. Reemplazados uno a uno por
    los tokens de `SteamColors`/`SteamRadii` (logo con degradado azul→cian
    en vez de un círculo azul plano, fondo `bgDeep`, tarjeta `bgCard`,
    bordes `border`, texto `textSec`/`muted`/`light`), y el botón principal
    ahora declara `foregroundColor` explícito (mismo patrón del bug de
    Material 3 arreglado antes en esta sesión, para que no quede en riesgo
    si algún día cambia el tema). Test `widget_test.dart` actualizado
    ("INICIAR SESION" → "INICIAR SESIÓN", con tilde, consistente con el
    resto de la app).
  - Verificado en navegador: sidebar + top bar funcionando en Inicio/
    Descubrir/Publicaciones/Amigos/Perfil sin regresiones; buscador de la
    barra superior filtra Descubrir correctamente (probado con clic en la
    lupa); tarjetas de Descubrir con datos reales de 3 usuarios de prueba
    (bio, tipo, juegos en común con carátula, orden por "más en común");
    panel derecho con GAMERS ACTIVOS y JUEGOS POPULARES correctos; login
    con la paleta actual en escritorio y móvil, formulario de registro
    también. `flutter analyze`: 0 issues. `flutter test`: 10/10. Backend:
    15/15.

**Nota operativa importante para cualquier sesión futura que use el build web
local:** Flutter Web registra un *service worker* que cachea agresivamente. Después
de cada `flutter build web`, **la primera carga en el navegador puede servir la
build anterior** — hace falta un segundo `navigate`/recarga para ver los cambios
reales. Pasó varias veces en esta sesión y generó falsos negativos ("el cambio no
se aplicó") que en realidad sí estaban aplicados. Si algo no se ve reflejado tras un
rebuild, recarga una segunda vez antes de asumir que el código está mal.

**Fase 6 — No funcional: tests + CI cerrados, despliegue pendiente**
- [x] **Backend testeable**: `src/app.js` (exporta la app de Express) separado de
      `src/index.js` (solo arranca el servidor) — necesario para testear rutas con
      `supertest` sin abrir un puerto real.
- [x] **7 tests de backend** (`steamlinker_back/tests/`, `node --test` + `supertest`,
      contra una base `steamlinker_test` dedicada, sin tocar la de desarrollo):
      `/health`, y el gateo de Steam completo de la Fase 2 (familia/miembros → 403,
      compañero → 201, tipo inválido → 400, sin token → 401).
- [x] **10 tests de Flutter**: el placeholder de login (nunca se había corrido — al
      correrlo encontró un overflow de layout real, ya arreglado, ver abajo) + nuevo
      `test/publicacion_constants_test.dart` (gateo de Steam del lado Flutter).
- [x] **`flutter analyze` en 0 issues** (antes 58, todos bloqueaban CI porque
      `--fatal-infos` viene activado por defecto): 34 `withOpacity` deprecado, 11
      `BuildContext` usado tras un `await` sin guardia (revisados uno por uno, no en
      bloque — varios necesitaban `context.mounted` en vez de `State.mounted` porque
      el `context` venía de un builder anidado), 7 parámetros `(_, __)`→`(_, _)`, 4
      sintaxis null-aware modernas, 2 triviales (`default` inalcanzable, `?? null`
      redundante).
- [x] **CI en GitHub Actions** (`.github/workflows/ci.yml`) — dos jobs en cada
      push/PR a `main`: backend (Postgres 16 de servicio + `npm test`) y Flutter
      (`analyze` + `test`). **Ya corrió en GitHub, en verde, primer intento**
      (commit `35f3121`, ~2 min).
- [x] **Limpieza de dependencias del backend**: quitados `passport`/
      `passport-google-oauth20`/`passport-steam` (confirmado con grep que no se usan
      en ningún lado — el login real es email/password, sección 5). `npm audit fix`
      bajó de 8 vulnerabilidades (5 high) a 1 moderate, sin saltos de versión mayor.
- [x] **`steamlinker_back/node_modules` destrackeado de git** (1512 archivos que
      nunca debieron commitearse — ya estaba en `.gitignore` pero quedó trackeado
      desde antes; mismo patrón que el fix de `.env` en Fase 0). Los archivos siguen
      en disco, solo se sacaron del control de versiones.
- [ ] **Despliegue de Web 1.0 — pendiente, decisión tomada, ejecución no.** El
      usuario confirmó: **Railway** para backend + Postgres (recomendado por mí, sin
      preferencia previa), **sin dominio propio todavía** (URL gratuita del hosting
      tipo `algo.up.railway.app` está bien para la beta). Falta: el usuario crea la
      cuenta de Railway y conecta el repo (no lo puedo hacer yo, requiere su cuenta),
      luego configurar variables de entorno de producción (secrets nuevos, nunca los
      de dev/CI), `CORS_ORIGINS` apuntando al dominio del frontend, y decidir dónde
      queda el `flutter build web` (¿Railway también, o Vercel/Netlify para el
      estático? — pendiente de definir en la sesión que ejecute el despliegue).

**Fase 7 — Lanzamiento**
- [ ] Beta web pública, recoger feedback real antes de empaquetar formalmente
      Android/iOS/Desktop (Flutter ya los soporta con el mismo código — ahí no hay
      trabajo de plataforma nuevo, es empaque y QA)
- [x] **Auditoría real en móvil (clic por clic, no solo revisión de código) —
      pedida después de aprobar el sidebar/Descubrir/login.** El usuario
      reportó "funciones que no hacen nada", funciones "bugeadas" y pidió
      una revisión general. Se encontraron y arreglaron 3 bugs reales:
  - **Bug real: "Reseñas" se quedaba cargando para siempre** (spinner
    infinito). Causa raíz: `CalificacionesProvider.cargarDeUsuario()` casteaba
    `respuesta.data['promedio']` directo a `num`, pero Postgres devuelve
    `AVG()` como **string** (`"0.00"`), no como número JSON — el cast
    lanzaba un `TypeError` que el `catch (DioException)` no atrapaba
    (no es una `DioException`), así que `_cargandoResenas` nunca volvía a
    `false`. Arreglado con `double.tryParse('${...}')` en vez de un cast
    directo. Mismo tipo de bug que otros ya arreglados esta sesión: el
    backend y el frontend asumían tipos distintos para el mismo campo.
  - **Bug real: el título de la barra superior desaparecía o se cortaba en
    móvil** ("DESCUBRIR" no se veía nada, "NOTIFICACIONES"→"NOT...",
    "PUBLICACIONES"→"PUBLIC..."). Causa raíz: cada pantalla repetía un
    bloque de usuario (nombre + "En línea" + avatar, sin `onTap`, puro
    adorno) en su propia `SteamAppBar`, y en pantallas con varios íconos de
    acción (Descubrir tiene 3: bandeja, filtros, refrescar) la suma de
    íconos + ese bloque ancho superaba los 375px disponibles y empujaba el
    título fuera de la pantalla — en release no se ve el aviso de overflow
    que sí aparece en debug, así que quedaba invisible sin ningún error
    visible. Arreglado en `steam_app_bar.dart`: `_UserActions` se redujo a
    solo el avatar (se quitó el nombre y "En línea", que además eran
    redundantes — ya existe la pestaña Perfil en el bottom nav) y el título
    ganó `overflow: TextOverflow.ellipsis` como defensa adicional.
  - **Bug menor: pluralización** — "1 juegos en común" en
    `comparar_biblioteca_screen.dart` (siempre plural). Arreglado.
  - Resto de la app probado en vivo en móvil (Inicio, Amigos con aceptar
    solicitud real, chat con mensaje real, Publicaciones con crear/filtrar,
    Perfil/Configuración completo, Descubrir) **sin más bugs encontrados** —
    el resto funciona como se diseñó. `flutter analyze`: 0 issues.
    `flutter test`: 10/10.
- [x] **Segunda pasada de correcciones, pedida tras revisar una captura del
      panel de Descubrir — todos los hallazgos de la auditoría anterior se
      cerraron esta ronda:**
  - **Bug real confirmado por el usuario: en el modal de Filtros, el
    desplegable "Juego en publicación" no dejaba seleccionar nada.** Causa
    raíz: `DropdownButton` de Flutter exige que cada `DropdownMenuItem`
    tenga un `value` único — si dos juegos de la biblioteca comparten el
    mismo nombre visible, quedan dos items con el mismo `value` y el widget
    entra en un estado inconsistente. En debug esto lanza un `assert()`
    visible; en el build de release ese `assert()` se descarta en silencio
    (mismo patrón que el bug del título invisible: release oculta errores
    que debug sí muestra), dejando el dropdown sin poder cambiar de
    selección. Arreglado en `_abrirFiltros()`
    (`descubrir_gamers_screen.dart`) deduplicando la lista de nombres antes
    de construir los items. Reproducido a propósito en el backend de prueba
    (dos juegos con el mismo nombre) para confirmar la causa antes de
    arreglar.
  - **Redundancia real: el ícono de filtros (🎛) de la barra superior y los
    botones de filtro del panel lateral abrían el mismo modal.** Solo pasa
    en escritorio — en móvil no existe el panel lateral, así que ahí el
    ícono sigue siendo la única entrada a Filtros. Se ocultó el ícono
    superior solo cuando `esEscritorio == true`.
  - **Configuración: los 2 controles decorativos que quedan
    ("Notificaciones de amigos", "Autenticación en dos pasos") ahora se
    marcan en la propia UI** con una etiqueta "DECORATIVA · NO FUNCIONAL
    POR AHORA" (`ToggleRow.decorativo`, `account_settings_screen.dart`) —
    se guardan igual que antes, pero ya no fingen tener efecto.
    **"Correos promocionales" se eliminó por completo**: quitado del
    frontend (`account_settings_screen.dart`, `PerfilProvider`) y del
    backend (`GET /perfil/:id` y `PUT /perfil/privacidad` en
    `perfil.js`) — la columna `correos_promocionales` queda huérfana en la
    base de datos (sin código que la lea o escriba ya), no se hizo
    migración para borrarla.
  - **"Interesantes" → "Marcadas", con funcionalidad real nueva**: se
    simplificó el modelo de tri-estado (👍 me interesa / 👎 no me interesa)
    a uno binario (marcada / sin marcar) — el estado "no me interesa" nunca
    tuvo ningún efecto ni en frontend ni en backend, así que se quitó del
    menú en vez de mantenerlo decorativo. La funcionalidad real que pidió
    el usuario: **las notificaciones marcadas ahora se anclan arriba de las
    pestañas "Todas" y "No leídas"** (`notifications_screen.dart`), para
    que marcar algo sirva para no perderlo de vista en vez de ser un
    archivador que nadie vuelve a mirar. De paso se corrigió el glifo roto
    (▯) del estado vacío, reemplazando el carácter "⋮" (que no siempre
    renderiza bien) por texto ("el menú de tres puntos").
  - **"Match recibido" (botón fantasma con `onTap: null`) se eliminó** de
    `usuario_detalle_screen.dart` — mi opinión, dada porque el usuario
    preguntó si era necesario: no, era pura redundancia. El mismo estado
    ("Match enviado" / "Match recibido") ya lo comunica
    `RelacionStatusRow` justo arriba, con un ícono de reloj de arena — el
    botón deshabilitado no agregaba información, solo el riesgo de que
    alguien lo confundiera con un botón real. Aprovechando el mismo hallazgo,
    se quitó también el "Ver reseñas" duplicado del menú ⋮ (queda solo el
    botón visible del cuerpo — la reseña es una acción común, no debería
    vivir en un menú secundario junto a "Reportar usuario").
  - Verificado con `flutter analyze` (0 issues), `flutter test` (10/10) y
    la suite de backend (15/15). **Pendiente**: no se pudo repetir la
    verificación visual en vivo en el navegador esta vez — la automatización
    de clics tuvo problemas de escala de coordenadas contra el build de
    release (viewport reportado en CSS px vs. tamaño real de la captura,
    ver nota de entorno de sesiones anteriores) y no valió la pena seguir
    insistiendo. Recomendado: el usuario prueba manualmente Descubrir →
    Filtros → Juego, Configuración, y Avisos → Marcadas en el próximo
    `flutter build web` antes de darlo por cerrado del todo.

### Roadmap hacia 1.0 — todo lo pedido por el usuario para guardar de cara a
### futuras sesiones, con criterio de priorización

El usuario pidió guardar una lista larga de funciones para la 1.0 y dejó
claro que quiere mi opinión honesta sobre qué es necesario y qué no — **no
se debe interpretar como "hacer todo esto en la próxima sesión"**, es una
mochila de trabajo pendiente para ir sacando por partes, priorizada.

**Preguntas puntuales que el usuario hizo, con la respuesta dada en el chat
(no repetida en detalle aquí, solo el resumen de la decisión):**
- *Buscador siempre visible en la barra superior de escritorio*: el usuario
  dudaba de si tiene sentido. Opinión dada: tiene sentido si de verdad busca
  jugadores (ya lo hace, filtra Descubrir), pero hoy es la única pieza de la
  UI que promete "búsqueda global" sin serlo — vale la pena, no quitarlo.
- *Login de Steam vía SteamID/URL vs. "Iniciar sesión con Steam" (OpenID)*:
  el usuario prefiere el flujo tipo OAuth que usan otras webs. Steam ofrece
  esto gratis (OpenID 2.0, sin necesidad de una app registrada como en
  Google/Discord) — es totalmente viable y bastante más cómodo que pegar una
  URL. **Hecho** en una sesión posterior — ver Nivel 4 más abajo.
- *Notificaciones "interesantes"*: ver el hallazgo de la auditoría arriba —
  existe, funciona, pero no tiene un propósito claro todavía.

**Nivel 1 — fundamentales para cualquier beta pública (no son "nice to
have", son requisitos mínimos para que lanzar sea responsable):**
- [x] **Aviso legal + Política de privacidad — hechos.**
      `lib/features/legal/screens/` (`aviso_legal_screen.dart`,
      `politica_privacidad_screen.dart`, compartiendo el armazón
      `legal_document_screen.dart`). Contenido redactado a partir del
      esquema real de la base de datos (qué tablas existen, cuáles tienen
      `ON DELETE CASCADE` y cuáles no, qué se guarda de Steam solo si el
      usuario vincula su cuenta, que no hay cookies ni analítica ni
      publicidad, que las donaciones de Ko-fi ocurren fuera de la app) —
      no es texto genérico de plantilla legal. Enlazados desde
      Configuración → tarjeta "Legal", y desde el formulario de registro
      ("Al crear tu cuenta, aceptas nuestro Aviso legal y nuestra Política
      de privacidad", con enlaces tocables reales, visible solo en modo
      registro).
      **Al redactar la política de privacidad se encontró y arregló un bug
      real**: `DELETE /auth/cuenta` ("Eliminar cuenta" en Zona de Peligro)
      solo limpiaba `usuarios_juegos` y `perfiles_steam` antes de borrar al
      usuario — pero `matches`, `calificaciones`, `chat`, `mensaje`,
      `reportes` y `amistad` referencian `usuarios` **sin** `ON DELETE
      CASCADE`, así que borrar una cuenta con cualquier match, chat,
      calificación, reporte o amistad fallaba con un error 500 de llave
      foránea — "Eliminar cuenta" solo funcionaba en cuentas nuevas sin
      actividad. Arreglado con una transacción que limpia todo en el orden
      correcto (los mensajes que son respuesta de otro rompen ese enlace
      antes de borrarse; `calificaciones` se borra antes que `matches`
      porque depende de esa llave). Cubierto por un test nuevo
      (`tests/auth.eliminarCuenta.test.js`) que reproduce el escenario
      exacto que fallaba antes del fix. Suite de backend: 16/16.
- [x] **Aviso de cookies — no aplica, confirmado por código, no supuesto.**
      Se revisó todo el backend y frontend: no hay `cookie-parser`, no hay
      cookies de sesión (el login usa JWT guardado vía `SharedPreferences`,
      no cookies), y `express-session` estaba en las dependencias del
      backend sin usarse en ningún lado — se quitó del `package.json`.
- [x] **Página 404 personalizada — hecha.** `NotFoundScreen`
      (`lib/features/errors/screens/not_found_screen.dart`), conectada como
      `errorBuilder` de GoRouter en `app_router.dart`. Con la paleta y
      tipografía del resto de la app (no el error genérico sin estilo de
      GoRouter), muestra la ruta pedida cuando la conoce, y una sola
      llamada a la acción: "Volver a Inicio". Un usuario sin sesión que
      cae en una URL rota sigue yendo primero a `/login` (el `redirect`
      global corre antes que el `errorBuilder`) — comportamiento correcto,
      no se cambió.
- [x] **Una sola llamada a la acción clara — revisado, ya cumplía.**
      Login/registro: un único formulario con un único botón primario
      ("INGRESAR"/"CREAR CUENTA"); el toggle login↔registro no es una CTA
      que compita, es navegación entre los dos estados de la misma
      pantalla de un solo propósito. El resto (nota de Steam, y ahora el
      enlace a Aviso legal/Privacidad) es informativo, no otra acción.
      Inicio ya cumplía esto desde el rediseño de la ronda 4.
- [~] **Seguridad**: el usuario pidió explícitamente "tocar" esto. Auditado
      y con la parte más urgente ya arreglada esta sesión (mientras el
      usuario abría la cuenta de Ko-fi):
  - [x] **XSS real y explotable en el panel de administración,
        encontrado y arreglado.** Casi todas las funciones de
        `public/admin/index.html` y `admin-panel.js` interpolaban campos
        controlados por usuarios finales (username, email, país, motivo
        de reporte, mensajes de chat, títulos de publicación, motivo de
        baneo) directamente en `innerHTML` sin escapar. Un username o
        mensaje con `<img src=x onerror=...>` se habría ejecutado en la
        sesión del administrador que abre Usuarios/Reportes/Chats —
        y el panel guarda su propio JWT en `localStorage.sl_token`,
        así que era robo de sesión de admin, no solo un `alert()`.
        Arreglado con una función `esc()` compartida aplicada en todos
        los puntos de interpolación (~25 sitios entre los dos archivos),
        y se eliminó el patrón fragil de pasar el nombre del usuario
        embebido en un atributo `onclick="...('nombre')"` (se rompía o
        era otro vector de inyección con comillas/`<` en el nombre) —
        ahora `accionUsuario(accion, id)` busca el nombre en la caché
        local y lo escapa recién al pintarlo.
  - [x] **Rate-limiting en `/auth/login` y `/auth/registro`** con
        `express-rate-limit` (login: 10 intentos/15 min por IP; registro:
        20 cuentas/hora por IP; desactivado en `NODE_ENV=test` para no
        romper la suite). Verificado en vivo: el intento #11 de login
        devuelve `429`.
  - [x] CORS en producción: ya estaba bien resuelto de antes (orígenes
        explícitos vía `CORS_ORIGINS`, sin fallback abierto) — confirmado
        al auditar, sin cambios necesarios.
  - [ ] **Pendiente, no arreglado esta sesión**: JWT no tiene rotación ni
        revocación — expira solo (7 días en registro, 30 en login) pero
        no hay forma de invalidar un token robado antes de su expiración
        natural (necesitaría refresh tokens + tabla de sesiones, cambio
        de esquema más grande — no se improvisó dentro de esta pasada).
        Tampoco se sanitizan explícitamente comentarios/descripciones en
        el **lado Flutter** (bajo riesgo real: Flutter no interpreta HTML
        en `Text()`, así que el vector serio era el panel admin, ya
        cerrado) ni se revisó `npm audit` a fondo — hay una vulnerabilidad
        moderada conocida en `qs` (dependencia transitiva de `express`,
        DoS en `qs.stringify` con arrays anidados) sin fix automático
        disponible todavía sin subir `express` de versión mayor.

**Nivel 1.5 — pedido explícitamente para el día 1 por el usuario, fuera del
orden de prioridad que yo hubiera sugerido por defecto:**
- [x] **Donaciones / "cómprame un café" estilo SteamDB — cerrado.** El
      usuario fue explícito: *"lo de patreon si lo querria funcionando
      para el dia 1"*. Esto estaba en Nivel 4 en la versión anterior de
      este roadmap — se subió aquí porque el usuario lo pidió
      directamente, no porque mi criterio haya cambiado sobre qué tan
      crítico es para el producto en sí (sigue sin ser parte del SRS ni
      del flujo core de matching).
      Se le preguntó al usuario qué cuenta usar; eligió "ninguna todavía,
      recomiéndame" — se recomendó **Ko-fi** (0% de comisión de plataforma
      en donaciones/membresías, a diferencia del ~8-12% de Patreon; no
      exige persona jurídica en Colombia; configuración en minutos), y el
      usuario creó la cuenta en la misma sesión:
      **https://ko-fi.com/camiko31**.
      Tarjeta `ApoyarProyectoCard`
      (`lib/features/perfil/widgets/apoyar_proyecto_card.dart`), usando
      `url_launcher` igual que el enlace al panel de administración. La URL
      real ya está puesta como valor por defecto de `AppConfig.kofiUrl`
      (sigue pudiendo sobreescribirse con `--dart-define=KOFI_URL=...` si
      algún día cambia). El botón "Invitar un café" queda funcionando de
      verdad desde este build — no hace falta tocar código de nuevo.
      **Movida de Perfil a Inicio** (pedido del usuario tras la primera
      versión: en Perfil quedaba "un poco escondida"): ahora vive en
      `home_screen.dart`, justo antes del pie de página, visible sin
      necesidad de entrar a otra pantalla.
      El link a Nequi/Bancolombia para Colombia que se mencionó en la
      sesión anterior queda fuera de esta ronda (Ko-fi ya acepta tarjetas
      internacionales; un canal 100% local es un paso posterior si de
      verdad hace falta, ver Nivel 4).

**Nivel 2 — mejoras de producto con impacto real, más baratas de lo que
parecen:**
- [x] **Formulario de contacto / sugerencias / quejas — hecho.**
      Backend: tabla `mensajes_contacto` (migración
      `007_create_mensajes_contacto.sql`, aplicada tanto en la BD de
      desarrollo como en `steamlinker_test`) + `POST /contacto`
      (`src/routes/contacto.js`), público — no exige sesión, pero guarda
      `id_usu` si llega un token válido. Protección anti-spam de las dos
      formas baratas que alcanzan para una beta: **honeypot** (campo
      `sitio_web` invisible para una persona real; si llega relleno, el
      backend responde 201 falso sin guardar nada, para no delatarle al
      bot que fue detectado) + **rate-limit** (`contactoLimiter`, 8
      mensajes/hora por IP, mismo patrón que login/registro). Validación
      real: nombre/correo/mensaje obligatorios, formato de correo,
      longitud mínima del mensaje (10 caracteres) y máximos para evitar
      payloads gigantes. Cubierto por 5 tests nuevos
      (`tests/contacto.test.js`), suite de backend: 21/21.
      Frontend: `ContactoScreen`
      (`lib/features/contacto/screens/contacto_screen.dart`), enlazada
      desde Configuración → tarjeta "Ayuda y legal" (que antes era solo
      "Legal", ahora agrupa también el contacto). Precarga nombre/correo
      si hay sesión iniciada, usa `showSteamToast` para confirmar envío o
      mostrar errores — consistente con el resto de la app.
      **UI de admin agregada en la misma sesión** (además del endpoint
      `GET`/`PUT /api/admin/mensajes-contacto`, mismo patrón que
      `/reportes`): sección nueva "Mensajes" en el panel
      (`public/admin/index.html` + `admin-panel.js`), con búsqueda,
      filtro por tipo/leído, badge de no leídos en el sidebar y acción
      "Marcar leído"/"Marcar no leído". Verificado en vivo contra el
      backend real (cuenta admin de prueba temporal, creada y borrada
      dentro de la sesión): se mandaron 2 mensajes reales por
      `POST /contacto`, aparecieron en la tabla con el badge de tipo
      correcto y el resaltado de no leído.
      **Nota de esa verificación, no un bug de la app**: al probar con
      `curl` desde esta sesión de Bash, las tildes llegaban corruptas
      (mojibake, "Ser�a" en vez de "Sería") — se confirmó con un
      `fetch()` limpio desde el propio navegador que el backend, Postgres
      y la respuesta JSON manejan UTF-8 sin problema (canción/país/botón
      se guardaron perfectos); la corrupción era de la terminal de esta
      sesión al escribir el comando `curl`, no del código.
- [x] **Mensajes de error y de éxito consistentes — unificados.** Se
      encontró un bug real al auditar: `showSteamToast` siempre mostraba
      un ícono de palomita verde (✓) sin importar el color pasado — un
      toast de error en rojo mostraba de todos modos un check de éxito.
      Arreglado con un ícono elegido según el color
      (`error_outline`/`warning_amber_rounded`/`check_circle_outline`/
      `info_outline`), sin tener que tocar los ~30 sitios que ya llamaban
      a `showSteamToast`. Además se migraron **13 `SnackBar` genéricos sin
      estilo** (grises, del tema por defecto de Material, chocando con el
      resto de la app) a `showSteamToast` en: `login_screen.dart` (las 7
      validaciones del formulario + el mensaje de sesión iniciada — de
      paso se corrigieron tildes: "Sesion"→"Sesión", "contrasena"→
      "contraseña"), `amistad_screen.dart`, `chat_conversation_screen.dart`,
      `matches_screen.dart` (×2), `publicaciones_screen.dart`,
      `admin_panel_section.dart` (×2) y `apoyar_proyecto_card.dart`. Se
      agregó soporte opcional de `action`/`duration` a `showSteamToast`
      para no perder el botón "Copiar" que tenía el aviso del panel admin.
      **Sin tocar a propósito**: `login_dev_server_chip.dart` (herramienta
      de depuración solo para desarrollo local, nunca la ve un usuario
      real) y los `TextStyle(color: Colors.red)` inline de texto de error
      (ej. mensajes de carga fallida) — eso es texto en pantalla, no
      notificaciones tipo toast, y no era el problema reportado.
- [~] **Favicon custom — parcial.** El ícono del logo (`Icons.sports_esports`
      sobre círculo con gradiente azul→teal, el mismo motivo que login/
      sidebar) se generó como PNG real vía canvas del navegador y
      reemplazó `web/favicon.png` (el ícono azul de Flutter por defecto).
      También se corrigieron `<title>`, meta `description` y
      `web/manifest.json` (nombre/descripción/colores), que todavía tenían
      el texto genérico de plantilla ("steamlinker_flutter", "A new
      Flutter project."). **No se tocaron** `web/icons/Icon-*.png` (192/512
      y variantes maskable, usados al instalar como PWA) — intentar
      generarlos por el mismo camino (canvas → base64 → decodificar)
      falló por el tamaño del base64 al transcribirlo; de bajo impacto
      real hoy porque nadie está instalando la PWA todavía, y de todas
      formas hay que rehacerlos cuando exista el logo real (ver pendiente
      de identidad visual, sección de Nivel 2).
- [x] **Loading screen inicial — hecho.** Splash puro HTML/CSS en
      `web/index.html` (círculo con el gradiente azul→teal de la marca +
      "STEAMMATCH"), visible antes de que cargue cualquier JS — se pinta
      apenas el navegador recibe el HTML, no espera al motor de Flutter.
      Se quita solo al evento real `flutter-first-frame` (nunca por un
      `setTimeout` arbitrario, que podría desaparecer antes de tiempo en
      una red lenta o quedarse pegado si Flutter tarda más).
- [x] **Botón "volver arriba" en listas largas — hecho en Descubrir y
      Publicaciones (vista móvil).** `ScrollToTopFab`
      (`lib/widgets/scroll_to_top_fab.dart`): aparece solo después de bajar
      ~400px, anima el scroll de vuelta a 0 en vez de saltar de golpe. En
      Publicaciones se ubica abajo a la izquierda para no chocar con el FAB
      "Crear" que ya vive abajo a la derecha. **No se hizo en la vista de
      escritorio de ninguna de las dos pantallas** (usan tabla/panel
      lateral con menos necesidad real de esto, y son layouts distintos
      que no comparten el mismo `ScrollController`) — alcance acotado a
      propósito, no un olvido.
- [ ] Optimización de velocidad: ya se hizo tree-shaking de íconos en cada
      build; falta medir con Lighthouse una vez esté desplegado, no antes
- [x] ~~Arreglar los hallazgos de la auditoría de esta sesión que quedaron
      pendientes~~ — cerrado esta ronda, ver la sección 7 de arriba
      ("Segunda pasada de correcciones").
- [ ] **Logo / identidad visual propia** (pedido por el usuario en esta
      misma sesión, de pasada: *"nos faltaria diseñar un logo, algun tipo
      sello de identidad"*). Hoy el "logo" es un ícono genérico de Material
      (`Icons.sports_esports`) sobre un círculo con gradiente — funciona
      como placeholder pero no es una marca propia. Esto es trabajo de
      diseño gráfico (no de código) — mejor candidato para una sesión
      dedicada o una herramienta de diseño, no algo que deba improvisarse
      dentro de una sesión de desarrollo.

**Nivel 3 — pulido visual, alto costo/beneficio dudoso para una beta:**
- [x] **Animaciones y microinteracciones — pedido explícito del usuario,
      hecho.** El usuario eligió esto directamente entre las opciones de
      Nivel 3 cuando se le preguntó qué seguía.
  - [x] **Transiciones entre pantallas**: `PageTransitionsTheme` nuevo en
        `theme/app_theme.dart` (`_FadeThroughTransitionsBuilder`, fundido +
        leve subida), aplicado igual en las 6 plataformas de
        `TargetPlatform` en vez de dejar que Flutter elija el estilo nativo
        según `defaultTargetPlatform` — en Flutter Web eso depende del
        user-agent detectado y se sentía inconsistente entre navegadores.
        Como `MaterialPageRoute` y las rutas de GoRouter leen el tema
        automáticamente, esto afecta **todas** las transiciones de la app
        sin tocar cada pantalla una por una.
  - [x] **Animación del hero/banner de bienvenida en Inicio**: fundido +
        leve subida + escala al montar la pantalla, una sola vez (nada de
        bucles infinitos — es una pantalla que se revisita todo el tiempo,
        un movimiento constante cansaría). `_HeroEntrada` en
        `home_screen.dart`, con `TweenAnimationBuilder`.
  - [x] **Microinteracciones — se encontraron 4 puntos reales sin ningún
        feedback al tocar** (no "podría ser más lindo", literalmente cero
        respuesta visual al tap, un `GestureDetector` plano en vez de
        `InkWell`): la tarjeta de juego (`JuegoCard`, usada en perfil/
        búsqueda/publicaciones), las 7 pestañas del bottom nav en móvil
        (`main_shell.dart` — la navegación más usada de toda la app en
        móvil no tenía ripple), y los selectores de pestañas "Solicitudes/
        Amigos" y "Recibidos/Enviados" (`amistad_screen.dart`,
        `matches_screen.dart`, mismo componente duplicado en los dos
        archivos). Los demás botones/tarjetas de la app ya usaban
        `Material`+`InkWell` correctamente — no fue una reescritura
        general, fueron arreglos puntuales donde de verdad faltaba.
  - **Sin verificar en vivo en navegador**: mismo límite de coordenadas de
    la automatización de sesiones anteriores; para esto además ni
    inyectar el token por `localStorage` funcionó para llegar más allá
    del login. Confirmado por `flutter analyze`/`flutter test` y revisión
    manual — son APIs estándar de Flutter (`PageTransitionsTheme`,
    `TweenAnimationBuilder`, `Material`/`InkWell`) usadas de forma
    convencional, bajo riesgo de que no se vean como se espera.
- [~] **Selector de idioma (español/inglés) — pedido explícito del usuario,
      infraestructura completa + una porción real traducida, resto
      pendiente y documentado (no fingido como terminado).**
  - [x] **Infraestructura completa**: `flutter_localizations` + `intl` en
        `pubspec.yaml` (`generate: true`), `l10n.yaml`,
        `lib/l10n/app_es.arb` (base) y `lib/l10n/app_en.arb`, código
        generado con `flutter gen-l10n` y comiteado (no hace falta
        recordar correrlo en cada sesión). `LocaleProvider`
        (`lib/core/providers/locale_provider.dart`) guarda el idioma
        elegido en `SharedPreferences` y persiste entre sesiones; español
        es el default. `MaterialApp.router` en `main.dart` queda
        conectado vía `Consumer<LocaleProvider>`.
  - [x] **Selector real en Configuración**: tarjeta "Idioma" (ES/EN) en
        `account_settings_screen.dart`, con el mismo estilo de chip que
        las pestañas Solicitudes/Amigos.
  - [x] **Pantallas totalmente traducidas** (el idioma que se elija SÍ
        cambia lo que se ve, no es cosmético): login/registro completo
        (`login_screen.dart` — título, labels, validaciones, nota de
        Steam, enlaces legales, toggle login↔registro), el bottom nav
        móvil (`main_shell.dart`) y el sidebar de escritorio completo,
        incluida la tarjeta "Conecta con otros gamers"
        (`responsive_shell.dart`).
  - [ ] **Sin traducir todavía — la gran mayoría de la app**: Inicio (el
        resto además de lo que ya se hizo), Descubrir, Publicaciones,
        Perfil, Configuración (excepto lo ya hecho), Chat, Notificaciones,
        Amistad, Aviso legal/Privacidad, Contacto, y el panel de admin.
        Elegir inglés hoy deja esas pantallas en español — **esto es
        deliberado y documentado, no un descuido**: traducir todo de una
        sentada arriesgaba una migración mecánica sin verificar sobre
        decenas de archivos. Nota real de alcance encontrada al hacer
        esto: hasta una pantalla aparentemente simple como Inicio termina
        dependiendo de `PublicacionConstants.etiquetaTipo()` y
        `PaisUtil.codigoANombre()` (nombres de tipo de publicación y de
        país), que son sus propios sistemas de texto hardcodeado — para
        traducir Inicio de verdad hay que traducir esos dos módulos
        primero. El patrón para seguir extendiendo esto en sesiones
        futuras: agregar claves a los dos `.arb`, `flutter pub get`
        (regenera `AppLocalizations`), reemplazar los `Text('...')`
        literales por `AppLocalizations.of(context)!.miClave` pantalla
        por pantalla — nunca a medias dentro de una misma pantalla.
  - **Sin verificar en vivo**: mismo límite de `localStorage`/
    `SharedPreferences` de esta sesión (tampoco funcionó forzar
    `flutter.locale_code` antes del arranque). Verificado que el español
    (default) se sigue viendo exactamente igual que antes — `flutter
    analyze`, `flutter test` y el build de producción, todos limpios.
- [ ] Botones de redes sociales: el propio usuario duda del valor — de
      acuerdo, bajo prioridad. Si se hace, que lleve a compartir un perfil o
      publicación real, no solo íconos decorativos a redes de la empresa.

**Nivel 4 — funciones grandes, evaluar solo con tracción real de usuarios:**
- [ ] Login con Google (opcional, ya lo marcó el usuario como no urgente)
- [x] **Login con Steam vía OpenID — pedido explícito del usuario, hecho.**
      Reemplaza pegar el SteamID/URL a mano por el flujo real "Iniciar
      sesión con Steam" (Steam no ofrece OAuth2/OIDC para esto, solo
      OpenID 2.0). Sigue vinculando a una cuenta de SteamMatch ya
      existente (el usuario debe estar logueado en la app primero) — no es
      un reemplazo del login por correo/contraseña, es solo un mejor
      camino para el mismo paso de vinculación que ya existía.
      **Backend** (`perfil.js`): `GET /steam/openid/iniciar` (con sesión)
      genera un `state` de un solo uso atado al `id_usu`, atado con TTL de
      5 minutos en un Map en memoria (no hace falta Redis para un flujo
      interactivo de este tamaño), y arma la URL real de Steam.
      `GET /steam/openid/callback` es adonde Steam redirige — **nunca
      confía en la identidad reclamada sin reverificarla**: reenvía todos
      los `openid.*` a Steam con `openid.mode=check_authentication` antes
      de guardar nada (la parte que de verdad importa de OpenID 2.0), más
      chequeo de que `openid.op_endpoint` sea el propio Steam (defensa
      contra mix-up con otro proveedor) y que el `claimed_id` tenga el
      formato exacto esperado. Nueva variable `FRONTEND_URL` en
      `.env.example` (adónde volver después del login).
      Cubierto por 6 tests nuevos (`tests/perfil.steamOpenId.test.js`):
      exige sesión, arma bien la URL, rechaza state ausente/inexistente/
      ya usado, rechaza `op_endpoint` falso — todo lo que no requiere red
      real a Steam. El paso de `check_authentication` en sí (la
      verificación de firma) no tiene test automático porque requeriría
      mockear la red a steamcommunity.com y no hay librería de mocking en
      este proyecto — **sí se verificó a mano**: se pidió la URL real al
      endpoint corriendo contra el backend de desarrollo y se abrió en el
      navegador — Steam la aceptó y mostró su pantalla de login real, sin
      errores de parámetros (no se completó el login: no hay credenciales
      de Steam disponibles ni se deben escribir contraseñas reales).
      **Frontend**: en Perfil, "Iniciar sesión con Steam" es ahora el
      botón principal; pegar el SteamID/URL a mano sigue disponible como
      alternativa colapsada ("¿No funciona? Vincula pegando tu SteamID o
      URL") por si el flujo OpenID falla — no se eliminó, se degradó a
      respaldo. `ResponsiveShell` detecta `?steam=ok|error` al volver de
      Steam (el backend redirige ahí) y muestra el resultado con un toast,
      luego limpia la URL para no repetir el aviso si se recarga la
      página a mano.
      **El usuario probó el login real con su propia cuenta de Steam en la
      sesión siguiente y funcionó** — se le creó una cuenta admin
      (`camilandre0510@gmail.com`) para poder probar login + panel admin a
      la vez. De esa prueba real salieron 5 ajustes:
  - [x] **Importación automática de la biblioteca al vincular** — antes
        había que darle a "Importar biblioteca" como paso manual aparte
        justo después de vincular, lo cual se sentía redundante. Ahora
        `GET /steam/openid/callback` importa la biblioteca de una vez
        (se extrajo `importarBibliotecaSteam()` como función compartida
        con `POST /steam/importar`, que sigue existiendo para
        reimportar más tarde). Si el perfil es privado, la vinculación
        igual queda guardada — se avisa con un toast distinto en vez de
        tratarlo como error del login.
  - [x] **"Ver todos →" en el sidebar ahora desplaza hasta la sección de
        Juegos** en vez de aterrizar arriba de Perfil obligando a bajar
        a mano. `PerfilScrollSignal` (`perfil_scroll_signal.dart`): como
        Perfil vive dentro de un `IndexedStack` que no se reconstruye al
        cambiar de pestaña, hace falta una señal aparte (no alcanza con
        pasarle un parámetro nuevo al widget) — un `ChangeNotifier`
        simple al que Perfil se suscribe una vez en `initState` y usa
        `Scrollable.ensureVisible` sobre un `GlobalKey` en la tarjeta de
        Juegos.
  - [x] **El avatar de la esquina superior derecha no mostraba la foto de
        Steam ya vinculada** — solo mostraba la inicial genérica, aunque
        la propia pantalla de Perfil sí mostraba la foto real. Arreglado
        en `_UserBadge` (sidebar de escritorio) y `_UserActions`
        (`SteamAppBar`, móvil): si hay `perfil['steam']['avatar_url']`,
        se usa esa foto; si no, sigue el círculo con inicial de siempre.
  - [x] **El panel de administración "no abría"** — causa real
        encontrada: `AdminPanelSection._abrirPanel` usaba
        `LaunchMode.externalApplication` sin `webOnlyWindowName`, que en
        Flutter Web abre una pestaña nueva (`_blank`) — un bloqueador de
        ventanas emergentes puede dejarla sin abrir del todo sin que
        `launchUrl` lo reporte como error. Arreglado navegando la misma
        pestaña (`webOnlyWindowName: '_self'`), mismo patrón ya usado
        para Ko-fi y el propio login de Steam.
  - [x] Botones "Configuración"/"Salir" del header de Perfil, más
        compactos (`compact: true` en el primero, padding reducido en el
        segundo) — el usuario los sentía "muy grandes, muy ocupados".
  - [x] **Investigación cerrada: distinguir juegos propios de compartidos
        por Family Sharing NO es viable sin pedirle al usuario su sesión
        privada de Steam — se descarta, no se va a construir.**
        `GetOwnedGames` (la API pública, con API key normal) confirma que
        nunca expone esa distinción — devuelve la licencia, nunca cómo se
        obtuvo. El único endpoint que sí lo sabe es uno no documentado,
        `IFamilyGroupsService/GetSharedLibraryApps` (así es como
        probablemente lo hace SteamDB): necesita un `family_groupid` (se
        consigue con `GetFamilyGroupForUser`) más un `access_token` de
        corta duración que **solo se puede sacar de una sesión de
        navegador ya logueada en steamcommunity.com/store.steampowered.com**
        (vía `store.steampowered.com/pointssummary/ajaxgetasyncconfig`) —
        no es algo que el login OpenID 2.0 que ya usamos entregue, ni algo
        que una API key de servidor pueda pedir en nombre de otro usuario.
        Construir esto exigiría pedirle al usuario que de alguna forma nos
        entregue su sesión activa de Steam (cookies/token), que es
        exactamente el tipo de práctica que no vale la pena ni deberíamos
        montar: no es solo "difícil", es pedir un credential que no nos
        corresponde tener. Conclusión: nos quedamos con la biblioteca vía
        `GetOwnedGames` (Steam-API-key) tal como está, sin distinción de
        familia. Fuentes: FAQ de SteamDB, hilo de GitHub
        `IsThereAnyDeal/AugmentedSteam#1907`, documentación de
        `IFamilyGroupsService` reconstruida por la comunidad.
        **Nota para un "después" largo (pedido explícito del usuario, no
        para retomar pronto)**: si alguna vez Steam publica una API
        oficial y documentada para membresía de Family Sharing (no el
        endpoint no documentado de arriba), vale la pena reabrir esto.
        Mientras eso no pase, seguir intentándolo no cambia la
        conclusión — no es cuestión de esfuerzo, es que el dato
        simplemente no está expuesto por ningún medio legítimo hoy.
        **Aclaración final, tras preguntar de nuevo "¿pero cómo hace
        SteamDB entonces?":** SteamDB no resuelve el mismo problema. Lo
        que muestra públicamente (campo `exfgls`/"Exclude from family
        sharing") es si un JUEGO es elegible para compartirse — un dato
        del catálogo, igual para cualquiera que lo consulte, sin relación
        con ninguna cuenta. No es "¿de quién es esta copia del juego que
        tengo yo?" (eso sigue siendo privado, sin exponerse por ningún
        medio público, ni en SteamDB). Cierre definitivo del tema.
  - [x] **Integridad de "Juegos verificados" — problema real encontrado
        por el usuario probando con su cuenta, corregido.** Agregar un
        juego a mano (buscador de Steam Store, sin dueño real verificado)
        se mostraba idéntico a uno importado de verdad por la API de
        Steam, y ambos contaban igual en "Juegos verificados" y en
        "juegos en común" para matchear — el usuario lo probó agregando
        Baldur's Gate 3 sin tenerlo realmente. Arreglado con una columna
        nueva `origen_usujg` ('steam' | 'manual') en `usuarios_juegos`
        (migración `008_add_origen_juegos.sql`). `importarBibliotecaSteam` siempre estampa
        'steam' (incluso sobre un juego agregado a mano antes — un import
        real de Steam es autoritativo); `POST /juegos/agregar` estampa
        'manual' solo en el INSERT inicial (editar horas/favorito después
        no degrada un juego ya verificado). El conteo "JUEGOS VERIFICADOS"
        en Perfil ahora solo cuenta origen 'steam'; cada fila de juego
        muestra un badge STEAM/MANUAL; "juegos en común" en
        `/perfil/descubrir` y `/perfil/comparar/:id` (rama local, sin API
        key) ahora exige origen 'steam' en ambos lados — ya no se puede
        inflar una coincidencia agregando a mano el juego que le falta.
        El aviso "Tienes este juego verificado en tu biblioteca" en el
        detalle de una publicación también exige origen 'steam'. Test
        `perfil.descubrir.test.js` actualizado para cubrir ambos casos
        (27/27 tests de backend pasando).
        **Bug real encontrado al probarlo**: la primera versión de la
        migración traía un backfill por SQL que marcaba 'steam' a TODAS
        las filas existentes de cualquier cuenta ya vinculada — sin mirar
        si el juego venía de verdad de Steam o se había agregado a mano
        antes de vincular. El usuario lo encontró de inmediato: su
        Baldur's Gate 3 (agregado a mano, nunca lo tuvo en Steam de
        verdad) quedó marcado como verificado por ese backfill ciego.
        Corregido quitando el backfill por SQL de la migración y
        agregando `scripts/reconciliar_origen_juegos.js`: para cada
        cuenta vinculada, pide la biblioteca REAL a la API de Steam y
        ajusta `origen_usujg` juego por juego según si el appid está ahí
        o no. Ya se corrió una vez contra la cuenta real del usuario
        (`node scripts/reconciliar_origen_juegos.js`): de 55 juegos, 54
        confirmados como 'steam' y 1 (Baldur's Gate 3) corregido a
        'manual'. Cualquier despliegue nuevo que ya tenga cuentas
        vinculadas con juegos agregados a mano antes de esta migración
        debe correr ese script una vez.
  - [x] **¿Qué pasa si alguien vincula con el perfil de Steam en
        privado? — pregunta directa del usuario, respondida con UI
        nueva.** Antes: la cuenta quedaba vinculada pero sin biblioteca,
        con un solo toast que se perdía al cerrarse, sin ninguna pista
        persistente de qué hacer. Ahora, en Inicio, si hay Steam vinculado
        pero la biblioteca está vacía aparece una tarjeta persistente
        ("BIBLIOTECA VACÍA") con la explicación y un botón que abre
        directo `steamcommunity.com/my/edit/settings` (ajustes de
        privacidad de Steam) más un atajo a Perfil para reimportar
        (`_TarjetaBibliotecaVacia` en `home_screen.dart`).
  - [x] **Bug de scroll en Inicio (hueco intermitente arriba del todo) —
        mitigación aplicada, sin poder verificarse en vivo.** El usuario
        describió un hueco que aparece en la zona superior según la
        posición del scroll y desaparece al volver a subir. Lectura más
        probable con el código a la vista: `RefreshIndicator` (pull-to-
        refresh) en Flutter Web puede armarse solo con la rueda del mouse/
        trackpad si la física de scroll permite un rebote elástico al
        llegar al tope — un problema documentado de Flutter Web, no
        exclusivo de esta app. Se fijó `ClampingScrollPhysics` explícito
        en el `SingleChildScrollView` de Inicio (antes usaba la física
        ambiental por defecto, que puede variar) — esto no le quita la
        función de pull-to-refresh a quien sí arrastra de verdad en
        móvil/touch, solo evita el rebote elástico que dispara el hueco
        sin que nadie esté jalando. **El usuario lo probó y el hueco
        seguía ahí** — describió que se veía "como si la parte del centro
        estuviera separada del resto". Eso apuntó a otra causa: se
        confirmó por JS (`document.querySelectorAll('canvas').length ===
        0`, con `<flutter-view>` presente) que esta build usa el
        **renderer HTML de Flutter Web** (no CanvasKit) — el que dibuja
        cada widget como DOM real y es más propenso a "costuras" de
        composición con `Transform`/`Opacity` dentro de un scroll.
        `_HeroEntrada` (la animación de entrada de la tarjeta de
        bienvenida, agregada en la ronda de animaciones) envolvía el
        child en `Opacity` + dos `Transform` **para siempre**, incluso
        después de terminar la animación de una sola vez (en t=1 son un
        no-op matemáticamente, pero seguían creando una capa de
        composición aparte). Esa capa separada puede desincronizarse del
        resto del scroll — encaja con "la parte del centro separada del
        resto". Arreglado: en cuanto `t >= 1.0`, `_HeroEntrada` devuelve
        el child SIN envolver, así la tarjeta vuelve a ser un nodo normal
        del árbol una vez terminada la animación (99% del tiempo que
        alguien hace scroll en Inicio). **Tampoco se pudo confirmar en
        vivo esta segunda vez**: se logró loguear con la cuenta real en
        el navegador integrado (a diferencia del intento anterior) y se
        hizo scroll repetido con rueda sintética sin lograr reproducir el
        hueco, pero un scroll de rueda simulado puede no replicar el
        gesto exacto de trackpad/mouse real que sí lo dispara — hace
        falta que el usuario lo confirme de nuevo en su navegador real.
- [x] **Bug real encontrado al reconciliar contra Steam: el backfill de
      origen de juegos marcaba mal las cuentas con juegos agregados a
      mano antes de vincular.** Ver arriba en la sección de integridad de
      "juegos verificados" — corregido con
      `scripts/reconciliar_origen_juegos.js` contra la API real.
- [x] **Rediseño del header de escritorio + sidebar — pedido explícito
      tras QA, con 3 decisiones confirmadas por el usuario antes de
      implementar (`AskUserQuestion`).** El usuario mandó capturas
      mostrando que, en escritorio, cada pantalla (Inicio, Descubrir,
      Publicaciones, Amigos) tenía su propia barra de `SteamAppBar`
      "fundida con el fondo" (sin título, por diseño) apilada DEBAJO de
      la barra global de `ResponsiveShell` (`_TopBar`) — dejaba ~57px
      vacíos con 1-2 íconos sueltos flotando a la derecha, muy notorio en
      Amigos (solo tenía el ícono de refrescar, en un hueco enorme).
      Reproducido en vivo con el navegador integrado a 1400px (antes solo
      se había probado en 436px, que nunca activa el layout de
      escritorio — por eso no se veía este problema antes).
      Implementado:
  - Nueva señal compartida `lib/core/refresh_signal.dart` (mismo patrón
    que `PerfilScrollSignal`, con el índice de a cuál pantalla refrescar
    para no refrescar las 8 a la vez solo porque todas viven en el mismo
    `IndexedStack`): un solo ícono de refrescar en `_TopBar`
    (`responsive_shell.dart`) que reemplaza al que estaba duplicado en
    Inicio/Descubrir/Publicaciones/Amigos.
  - "Mis solicitudes" (Descubrir) se movió del AppBar al cuerpo de
    escritorio (`_CuerpoEscritorio`, junto al título "Descubrir"); el
    filtro (`tune_rounded`) de Publicaciones se movió a la fila de
    pestañas (`_ConmutadorTabs.trailing`).
  - Las 4 pantallas ahora ponen `appBar: null` en escritorio (antes
    reservaban la barra vacía siempre) — el contenido arranca justo
    debajo de la barra global, sin doble barra.
  - **"Tus juegos" del sidebar, de lista decorativa a atajo real**: un
    clic en cualquier juego de la lista ahora lleva a Descubrir ya
    filtrado por ese juego (`DescubrirGamersScreen` gana
    `filtroAppidExterno`/`filtroJuegoNombreExterno`, mismo patrón que
    `busquedaExterna`). **Bug propio encontrado al probarlo**: la primera
    versión solo guardaba el filtro en el estado local sin volver a
    pedirle la lista al backend con el nuevo `appid` — corregido
    llamando `_recargar()` después de actualizar el filtro; confirmado
    en la red que el request ahora sí manda `?appid=...`.
  - **"Conecta con otros gamers" (sidebar) se elimina** — el usuario la
    señaló como 100% redundante con el ítem "Descubrir" de la nav, un
    clic arriba en el mismo sidebar. En su lugar va **"Apoya el
    proyecto"**: antes solo visible al fondo del scroll de Inicio, ahora
    visible en todas las pantallas de escritorio sin scrollear (versión
    compacta propia, `_ApoyarProyectoSidebar`, porque la tarjeta original
    basada en `SteamCard` no entraba cómoda en los 232px del rail). Se
    quitó de Inicio para no duplicarla.
  - **Efecto colateral en el bug de scroll de Inicio**: al quitar la
    doble barra (global + propia) en Inicio también, el árbol de widgets
    cambió de forma real — no se pudo reproducir el hueco de nuevo en el
    navegador integrado tras este cambio, pero ya van 2 intentos previos
    donde tampoco se pudo reproducir ahí y el usuario sí lo vio en su
    navegador real, así que **sigue sin confirmación real** hasta que el
    usuario lo pruebe.
- [x] **Cuarto intento del bug de scroll en Inicio, con más pistas del
      usuario (Chrome + trackpad, parece exclusivo de Inicio).**
      `_HeroEntrada` se reescribió de `TweenAnimationBuilder` a un
      `StatefulWidget` con su propio `AnimationController`: el intento
      anterior comparaba el objeto `Tween` por identidad, y como
      `_HeroEntrada.build()` creaba un `Tween(begin:0,end:1)` nuevo en
      cada rebuild del padre (Home se reconstruye seguido, cada vez que
      Matches/Publicaciones/Perfil notifican), eso podía disparar un
      `didUpdateWidget` interno de forma sutil incluso después de que la
      animación ya había terminado. Ahora corre una sola vez en
      `initState` y, tras terminar, el `build()` nunca vuelve a crear
      `Opacity`/`Transform` sin importar cuántas veces se reconstruya el
      padre. En paralelo, `RefreshIndicator` de Inicio ahora usa
      `notificationPredicate: (n) => !esEscritorio && ...` en vez de
      quitarlo del árbol — queda montado pero totalmente inerte en
      escritorio (jalar para refrescar no es un gesto real con
      mouse/trackpad, y el refrescar ya vive en la barra global). **Sigue
      sin poder reproducirse en el navegador integrado de Claude** —
      van 4 intentos sobre el mismo síntoma sin verificación visual
      directa; solo el usuario lo ve en su Chrome real.
- [x] **Corrección importante al diagnóstico del intento 2/3: esta build
      NO usa el renderer HTML de Flutter Web — la lectura de "0 canvas"
      de esa sesión estaba mal.** Al revisar de nuevo (`flutter build web
      -h` en Flutter 3.47.4 ya ni siquiera tiene la opción
      `--web-renderer`: CanvasKit/Skwasm es la única opción hoy, el
      renderer HTML se eliminó del engine) y volver a buscar canvases
      atravesando manualmente el shadow DOM de `flt-glass-pane`
      (`document.querySelectorAll('canvas')` no lo hace solo), se
      confirma que sí hay una jerarquía `FLT-SCENE-HOST`/`FLT-SCENE`
      típica de CanvasKit — el conteo en 0 fue por buscar mal, no porque
      falte canvas. La teoría de "costura de composición por el renderer
      HTML" del intento 2 queda descartada como explicación real; el fix
      de esa ronda (dejar de re-envolver `_HeroEntrada`) puede seguir
      siendo una mejora válida por otras razones, pero no por el motivo
      que se documentó entonces.
      **Investigación con búsqueda web**: encontré issues abiertos de
      Flutter relacionados con huecos de renderizado en scroll con
      CanvasKit (`flutter/flutter#185931`) y comportamiento anormal de
      touchpad en Flutter Web en Windows (`flutter/flutter#125743`) —
      ninguno es un match exacto (el primero es específico de Safari,
      confirmado que NO afecta Chrome/Edge; el segundo es sobre
      animaciones de "snap" prematuras, no huecos visuales), pero sí
      confirman que Flutter Web tiene una categoría conocida de bugs de
      scroll específicos de touchpad/CanvasKit que no son necesariamente
      arreglables desde código de la app.
      **Decisión: pausar este bug tras 4 intentos sin poder verlo en
      vivo, en vez de seguir arreglando a ciegas.** Ya se cubrieron las
      hipótesis razonables a nivel de código de la app (física del
      scroll, capa de animación persistente, doble barra, RefreshIndicator).
      Si el usuario confirma que el 4to intento tampoco funcionó, lo más
      productivo antes de seguir tocando código sería que el propio
      usuario aislara la variable: ¿pasa igual con mouse normal (sin
      trackpad)?, ¿en qué posición exacta de scroll (siempre la misma o
      aleatoria)?, ¿pasa también en Descubrir/Publicaciones (con scroll
      real, tienen RefreshIndicator igual) o es exclusivo de Inicio? Sin
      esos datos, seguir iterando a ciegas tiene rendimientos decrecientes.
- [x] **RESUELTO DE VERDAD — causa real encontrada (5to intento, con la
      descripción exacta del usuario): no era un bug de renderizado, era
      un problema de hit-testing.** El usuario dio la pista que faltaba:
      "si pongo el mouse en el centro scrollea, si lo quito de ahí ya no
      me deja" — y que también pasaba en Publicaciones, "creo que es por
      cómo está compuesto". Eso apuntaba a algo estructural, no visual.
      **Causa real**: `DesktopBodyWidth` (el widget que centra contenido
      en pantallas anchas con `Align + ConstrainedBox`) se estaba usando
      envolviendo el `SingleChildScrollView`/`ListView` COMPLETO en vez
      de envolver solo el contenido de adentro. `ConstrainedBox` no solo
      angosta lo que se VE — angosta el propio `RenderBox` del
      `Scrollable`, que es literalmente el área donde Flutter escucha los
      eventos de rueda del mouse (`PointerScrollEvent`). Con
      `maxWidth: 760` en una ventana de 1400px, el Scrollable quedaba
      centrado y angosto: el mouse tenía que estar sobre esos ~760px del
      centro para que la rueda hiciera algo — exactamente el síntoma
      descrito, en ambas pantallas. Los 4 intentos anteriores (física del
      scroll, animación de `_HeroEntrada`, doble barra, `RefreshIndicator`
      inerte) apuntaban todos al lugar equivocado porque el problema
      nunca fue de renderizado ni de gestos — era que la zona interactiva
      real era más angosta que la pantalla completa.
      **Arreglo**: `DesktopBodyWidth` ahora deja documentado en su propio
      comentario que NO debe envolver un scrollable directamente. Se
      agregó `DesktopBodyWidth.margenHorizontal(anchoDisponible,
      maxWidth)`, un helper estático que calcula el margen simétrico
      necesario, para usarlo como `padding` DEL scrollable (el padding de
      un `ListView`/`SingleChildScrollView` no angosta su propio
      `RenderBox` — es una `SliverPadding` interna, así que el área de
      scroll con rueda sigue siendo toda la pantalla). Se corrigieron
      **7 pantallas**: `home_screen.dart` y `apoyar_proyecto_screen.dart`
      (se movió `DesktopBodyWidth` de afuera del `SingleChildScrollView`
      a adentro, envolviendo solo el `Column`); `amistad_screen.dart`,
      `descubrir_gamers_screen.dart` (rama móvil), `publicaciones_screen.
      dart` (ambas ramas) y `matches_screen.dart` (se quitó
      `DesktopBodyWidth` del todo y se pasa el margen calculado como
      `padding` extra al `ListView` de cada una). `notifications_screen.
      dart` también, de paso, aprovechando que ya se estaba tocando ese
      archivo esta ronda. **`chat_screen.dart` se dejó igual a propósito**
      -- es la única pantalla de las 8 que nunca se selecciona como
      pestaña activa en escritorio (confirmado antes, `FloatingChat` es
      un overlay separado que no navega ahí), así que su versión con el
      bug no es visible en la práctica hoy.
      **Confirmado en vivo con el navegador integrado**: con la ventana en
      1400px, la rueda del mouse cerca del borde derecho de la pantalla
      (fuera de donde antes vivía el contenido angosto) ahora sí
      scrollea Publicaciones — antes de este arreglo no respondía ahí.
- [x] **"Apoya el proyecto" ya no se duplica en Inicio (escritorio)** —
      ahora que vive siempre visible en el sidebar, repetirla en Inicio
      sería la misma redundancia que se le quitó a "Conecta con otros
      gamers". Sigue apareciendo en Inicio solo en móvil (`!esEscritorio`),
      donde no hay sidebar.
- [x] **"TU ESTADO" (Inicio) renombrada a "TU ESTADO EN STEAMMATCH"** — el
      usuario señaló que el estado ("Sin familia"/"Buscando
      familia"/"En una familia") se calcula 100% a partir de tus
      publicaciones/matches en la app (`calcularEstadoFamilia`, ver
      `estado_familia_helper.dart`), sin ninguna relación con si ya
      tienes una familia real de Steam Family Sharing por fuera —
      confirmado por el propio usuario probando con una cuenta que ya
      tiene familia real en Steam pero mostraba un estado distinto
      basado solo en publicaciones de prueba. El nombre "TU ESTADO" a
      secas se prestaba a leerse como un hecho objetivo de su cuenta de
      Steam; ahora deja explícito que es tu progreso usando SteamMatch
      para armar/encontrar familia, no un reflejo de tu cuenta real. Solo
      se tocó el label en Inicio — el stat "FAMILIA" del grid de Perfil
      se dejó igual por ahora (es un valor corto, no una afirmación
      completa, menos propenso a la misma confusión).
- [x] **Bug real de regresión encontrado por el usuario: "Ver todos" de
      una publicación abierta en Inicio lo dejaba sin poder volver.**
      Causa: `_FilaPublicacionPropia.onTap` (fila de "Tus publicaciones
      abiertas" en Inicio) siempre hizo un `Navigator.push` directo hacia
      `PublicacionesScreen`, sin pasar por `_ir()` (el helper que en
      escritorio cambia de pestaña en vez de pushear). Mientras
      `PublicacionesScreen` tenía su propio `SteamAppBar` con flecha de
      volver siempre, esto era inofensivo; al quitarle el AppBar en
      escritorio (rediseño de header, arriba) un push directo dejaba al
      usuario sin ninguna forma de volver. Arreglado en dos capas:
  - `home_screen.dart`: ese `onTap` ahora usa `_ir(2, const
    PublicacionesScreen())`, igual que el resto de los botones de Inicio.
  - Más importante — **las 4 pantallas (Home, Descubrir, Publicaciones,
    Amigos) ahora chequean `Navigator.of(context, rootNavigator:
    true).canPop()`** antes de omitir el AppBar en escritorio: si de
    verdad se llegó pusheando encima (desde cualquier otro lugar que no
    pasé a revisar uno por uno, ej. `pushAppScreen(context, const
    AmistadScreen())` en `notifications_screen.dart`), el AppBar con
    flecha de volver se muestra igual aunque sea escritorio. Solo se
    omite del todo cuando la pantalla es una pestaña real del
    `IndexedStack` (no se puede volver, porque no hay a dónde).
- [x] **Publicaciones en escritorio pasa de tabla densa a tarjeta rica
      (pedido explícito, comparando contra Descubrir y un wireframe con
      tarjetas).** `_TablaPublicaciones`/`_FilaTabla` (columnas TIPO/
      USUARIO/CUPOS/REP/HACE) se eliminaron del todo — en vez de diseñar
      una tarjeta nueva desde cero, se reutiliza `PublicacionCard`
      (`widgets/publicacion_card.dart`), que ya existía y ya se usaba en
      móvil: avatar+autor+reputación, título, descripción, portada del
      juego, país y "Ver detalle". `_buildLista` (la función que arma la
      lista para móvil) ganó un parámetro opcional `filas` para poder
      pasarle la lista ya filtrada por pestaña (Familia/Jugar ahora/Otro)
      del lado de escritorio, en vez de duplicar la lógica de armado de
      lista. **Pendiente, no incluido en esta pasada**: el wireframe que
      mandó el usuario también tenía tags de género (Soulslike/Co-op/...)
      y avatares de "juegan en común" — `PublicacionCard` no los tiene
      todavía; se puede agregar después si hace falta más pulido.
- [x] **Bug real: refrescar y filtros aparecían duplicados en escritorio
      (Publicaciones, y en general las 4 pantallas) — el chequeo de
      `Navigator.canPop()` del punto anterior daba un falso positivo.**
      El usuario lo encontró probando: en Publicaciones aparecían DOS
      juegos de íconos de filtro/refrescar, uno en la barra global y otro
      flotando arriba del todo (el AppBar "fantasma" que se suponía
      debía desaparecer). Causa real: el router de esta app (GoRouter)
      deja el stack raíz de Flutter con más de una entrada incluso en el
      caso normal de navegar entre pestañas, así que
      `Navigator.of(context, rootNavigator: true).canPop()` no es una
      señal confiable para distinguir "soy una pestaña embebida" de "me
      pushearon encima". Reemplazado por una señal explícita: las 4
      pantallas (`HomeScreen`, `DescubrirGamersScreen`,
      `PublicacionesScreen`, `AmistadScreen`) ahora reciben un parámetro
      -- `onNavigateIndex` en Home (ya existía, se reutilizó tal cual) y
      un `esPestana: bool` nuevo en las otras tres -- que `ResponsiveShell`
      pasa explícitamente en `true` al construirlas como pestañas del
      `IndexedStack`. Cualquier otro lugar que las construya sin ese
      parámetro (`pushAppScreen`, un `Navigator.push` directo) sigue
      mostrando el AppBar completo por defecto, sin necesidad de adivinar
      nada sobre el estado del Navigator.
- [x] **"TU ESTADO EN STEAMMATCH" ahora muestra la etiqueta real de tu
      publicación ("Busco familia" o "Busco miembros") en vez de un
      "Buscando familia" genérico para ambos tipos.** El usuario insistió
      en que la tarjeta debía "captar una intención real": tiene una
      publicación real de tipo `busco_miembros` (ya tiene gente/cupos,
      está reclutando) pero la tarjeta decía "Buscando familia" (como si
      estuviera buscando unirse a una) — literalmente lo opuesto.
      `calcularEstadoFamilia` (`estado_familia_helper.dart`) ahora usa
      `PublicacionConstants.etiquetaTipo(tipo)` en vez de un string fijo,
      así que muestra el texto exacto de lo que de verdad publicaste. Se
      evaluó y descartó la alternativa de un selector manual de
      "propósito" (familia/compañeros/chill): reemplazar un dato real
      (cupos ocupados de una publicación real) por algo puramente
      declarativo habría sido un paso atrás, no adelante.
- [x] **"Apoya el proyecto" ahora separa Colombia de otros países —
      pedido explícito, con datos reales del usuario.** Nueva pantalla
      `ApoyarProyectoScreen` (`features/perfil/screens/
      apoyar_proyecto_screen.dart`): Colombia muestra una llave Bre-B
      (sistema de pagos inmediatos interoperable, copiable con un toque —
      `AppConfig.brebKey`, configurable vía `--dart-define=BREB_KEY=...`,
      con el valor real del usuario por defecto); otros países sigue
      usando Ko-fi (`AppConfig.kofiUrl`, sin cambios). El botón "Invitar
      un café" tanto en `ApoyarProyectoCard` (Inicio, móvil) como en el
      sidebar de escritorio ya no abre Ko-fi directo — ahora llevan a
      esta pantalla nueva, con un botón "Ver cómo apoyar". **Por qué una
      llave y no número de cuenta/Nequi por separado**: Bre-B permite
      registrar una llave alfanumérica que no expone cédula/celular/
      correo — el usuario prefirió expresamente esta opción por ser más
      simple y más privada que mostrar varios identificadores en crudo.
- [x] **Tono más "chill" en las descripciones de SteamMatch, y se quita
      "hecho por una sola persona"** — pedido explícito del usuario.
      Aunque es cierto técnicamente, prefirió no decirlo; "independiente"
      alcanza. Tocado en `ApoyarProyectoScreen`, `ApoyarProyectoCard` y el
      footer de Inicio (`_FooterInicio`).
- [x] **Bug real encontrado revisando el default del panel de admin: el
      panel forzaba la URL muerta de Render en cada carga, pisando
      cualquier configuración guardada.** El usuario dijo "haz lo que
      tengas que hacer" con el `https://steamlinker.onrender.com`
      encontrado la ronda anterior — se probó con `curl` (conexión TLS
      exitosa, pero **90 segundos sin ninguna respuesta HTTP**, mucho más
      que un cold-start típico de la capa gratis de Render) y se concluye
      que no es un despliegue funcional hoy. Se encontró además que
      `public/admin/index.html` no solo tenía ese default -- había una
      línea que **sobreescribía `localStorage.sl_base_url` con esa URL
      muerta en cada carga de página**, sin importar qué hubiera
      configurado antes. Corregido: el default ahora es
      `http://localhost:3000` (donde de verdad corre el backend hoy) y la
      línea que forzaba la URL muerta ahora solo rellena el campo con lo
      que ya esté activo, respetando `localStorage`.
      **Nota importante para el usuario**: este arreglo solo cambia el
      *default* para quien nunca lo haya usado — si tu propio navegador
      ya tenía `sl_base_url` guardado en `localStorage` apuntando a la
      URL muerta (de antes de este arreglo), el código nuevo no lo borra
      solo. Si el panel "no te deja entrar", en la pantalla de login
      borra el campo de URL y escribe `http://localhost:3000` a mano.
- [x] **Formulario de feedback/sugerencias, más visible — pedido
      explícito.** Antes solo existía escondido en Configuración → Ayuda
      y legal → Contacto y sugerencias. Nueva tarjeta `_FeedbackCard` en
      Inicio (visible en móvil y escritorio, justo debajo de "Tus
      publicaciones abiertas"), con un botón directo a `ContactoScreen`.
- [ ] Panel de administración renovado a la par del resto de la app (hoy
      `AdminPanelSection` es funcional pero no ha recibido el mismo
      tratamiento visual que el resto desde la ronda 4)

**Mi criterio general, ya que se pidió directamente:** no, no hay que hacer
todo esto — varias cosas de los niveles 3 y 4 son apuestas razonables solo
si el producto ya tiene usuarios reales dándole señal de qué vale la pena
(idiomas, redes sociales). Lo que sí es innegociable para cualquier beta
pública responsable es el Nivel 1 completo (legal + seguridad básica).
Los hallazgos de la auditoría (antes en Nivel 2) ya se cerraron esta sesión.
Patreon/donaciones se subió a Nivel 1.5 porque el usuario lo pidió
explícitamente para el día 1, no porque mi criterio por defecto lo pusiera
ahí — sigue bloqueado en la práctica hasta que el usuario decida qué
cuenta(s) reales usar. El orden sugerido si se retoma esto en una sesión
futura: Nivel 1 → Nivel 1.5 (en cuanto haya respuesta sobre las cuentas) →
Nivel 2 → recién ahí evaluar Niveles 3 y 4 con la app ya en manos de gente
real.

### Cosas pendientes (actualizado 2026-09-18, tras la ronda de rediseño de
### escritorio + integridad de datos — ordenadas por mi prioridad)

1. ~~Bug de scroll~~ **RESUELTO (5to intento) — causa real: `DesktopBodyWidth`
   angostaba el `Scrollable` mismo, no solo lo que se veía, así que la
   rueda del mouse solo funcionaba con el cursor sobre esa franja
   centrada.** Ver detalle completo arriba en Nivel 4. Confirmado en vivo.
   Si vuelve a aparecer en alguna pantalla nueva que use
   `DesktopBodyWidth`, revisar primero que no esté envolviendo un
   scrollable directamente (leer el comentario en
   `widgets/desktop_body_width.dart`).
2. **Selector de idioma: traducir el resto de la app.** Sigue igual que
   antes de esta ronda — la infraestructura (`.arb`, `AppLocalizations`,
   `LocaleProvider`) ya está completa; falta traducción pantalla por
   pantalla (Inicio, Descubrir, Publicaciones, Perfil, Configuración,
   Chat, Notificaciones, Amistad, legal, Contacto, admin). Ojo con
   `PublicacionConstants.etiquetaTipo()`/`PaisUtil.codigoANombre()`
   (sistemas de strings aparte que Inicio también usa).
3. ~~Logo / identidad visual~~ **RESUELTO (por ahora) — ver puntos 13 y
   14 más abajo.** Concepto "dos controles" elegido por el usuario,
   implementado de verdad (`AppLogoMark`, favicon/iconos PWA
   regenerados, panel de admin rebrandeado). Se puede cambiar más
   adelante si el usuario decide otro concepto.
4. **Pulido menor pendiente** (el usuario dijo "cuando puedas", sin
   prisa):
   - [x] **RESUELTO — "Juegos en común" en `PublicacionCard` + tags de
     género.** Ambos requerían trabajo real de backend, ya hecho:
     - `GET /publicaciones/buscar` ahora calcula `juegos_en_comun` /
       `juegos_comunes_muestra` por publicación, comparando la
       biblioteca verificada (origen Steam) del autor contra la de
       quien mira -- mismo criterio que `/perfil/descubrir` (no infla
       coincidencias con juegos agregados a mano). La ruta no exige
       sesión (se puede ver la lista sin loguearse), así que se agregó
       un `usuarioOpcional()` que decodifica el token si llega pero no
       lo exige (mismo patrón ya usado en `contacto.js`) -- sin token,
       ambos campos vienen `null` (no se puede comparar sin saber quién
       mira). Cubierto por 2 tests nuevos en
       `tests/publicaciones.buscar.test.js`, más verificado en vivo
       contra el servidor real corriendo (dos cuentas de prueba, un
       juego verificado en común, `juegos_en_comun: 1` confirmado por
       la API real).
     - `juegos.generos_jg TEXT[]` (migración `010_add_generos_juegos.sql`)
       -- se llena **de a poco**, no en bloque: nuevo servicio
       compartido `services/juegosService.js` (`guardarJuego()`)
       reemplaza los 4 `INSERT INTO juegos ... ON CONFLICT DO NOTHING`
       que estaban duplicados por toda la app (crear publicación,
       editar publicación, agregar juego a perfil). Solo la PRIMERA
       vez que se ve un appid nuevo, dispara en segundo plano (sin
       esperar la respuesta) una consulta a la Steam Store API
       (`appdetails`, nueva función `steamService.obtenerGeneros()`)
       para traer sus géneros -- best-effort a propósito: nunca
       bloquea ni revienta la acción real del usuario si Steam falla o
       tarda. **Deliberadamente NO se usa en la importación masiva de
       biblioteca** (`importarBibliotecaSteam`, puede ser cientos de
       juegos de una) -- ahí se sigue insertando sin géneros, para no
       pegarle a la API de Steam con llamadas seguidas y arriesgar
       rate-limiting; esos juegos se backfillean solos, orgánicamente,
       si más adelante alguien los agrega/asocia de a uno. Verificado
       en vivo contra la Steam Store API real (Dota 2, appid 570 →
       `['Acción', 'Estrategia', 'Free to Play']` en unos segundos).
       `PublicacionCard` muestra hasta 4 tags del primer juego de la
       publicación, como chips morados.
     - 46/46 tests de backend, `flutter analyze` limpio,
       `flutter test test/widget_test.dart` pasa.
   - Revisar si el stat "FAMILIA" del grid de Perfil necesita el mismo
     tipo de aclaración que se le hizo a "TU ESTADO" en Inicio (bajo
     esfuerzo real, sí se puede hacer directo cuando se retome -- sigue
     pendiente, no se tocó esta ronda).
5. Nivel 1: **rotación/revocación de JWT — hecho esta ronda, Nivel 1
   queda cerrado del todo.** Antes el JWT era el único factor: firmado,
   sin ningún registro del lado del servidor, válido hasta 30 días sin
   forma de invalidarlo antes de tiempo (ni al cerrar sesión, ni al
   banear a alguien, ni si se filtraba). Ahora:
   - Nueva tabla `sesiones` (migración `009_create_sesiones.sql`):
     guarda el hash SHA-256 de cada refresh token, con expiración y
     revocación.
   - El **access token** (JWT) baja de 7-30 días a **1 hora** — sigue
     sin estado como siempre (eso no cambia), pero ahora una revocación
     tarda como máximo 1h en tomar efecto en vez de hasta 30 días.
   - El **refresh token** (string aleatorio de 40 bytes, no un JWT) vive
     30 días y **rota en cada uso**: `POST /auth/refresh` revoca el que
     se usó y devuelve uno nuevo — si alguien reutiliza uno ya rotado
     (señal de que se filtró), la sesión completa queda invalidada de
     una vez (no hay fila viva con ese hash).
   - `POST /auth/logout` revoca el refresh token — idempotente a
     propósito (siempre 200).
   - Banear a un usuario (las 2 rutas que lo hacen en `admin.js`) y
     cambiar la contraseña ahora **revocan todas las sesiones activas**
     de esa cuenta — antes un usuario baneado o con contraseña
     comprometida seguía con acceso completo hasta que su JWT expirara
     solo.
   - `DELETE /auth/cuenta` no necesitó cambios — `sesiones` tiene
     `ON DELETE CASCADE` hacia `usuarios`.
   - **Frontend**: `ApiClient` (Dio) gana un interceptor que, ante un
     401, intenta refrescar el token automáticamente y reintenta la
     petición original una sola vez antes de rendirse y cerrar sesión
     (`_refreshing` evita que dos peticiones que fallan casi a la vez
     disparen dos refresh en paralelo, importante porque el refresh
     token rota). `TokenStorage` guarda ambos tokens; `AuthProvider`
     los persiste al registrarse/loguear, y `logout()` ahora llama a
     `POST /auth/logout` antes de borrar el token local (mejor esfuerzo:
     si falla por falta de red, igual cierra sesión local).
   - Cubierto por 9 tests nuevos (`tests/auth.refreshLogout.test.js`):
     login devuelve ambos tokens, refresh rota, reuso de un token ya
     rotado se rechaza, token inexistente/vacío se rechaza, logout
     revoca y es idempotente, cambiar contraseña revoca sesiones,
     banear revoca sesiones. **Verificado también en vivo contra el
     backend de desarrollo real corriendo** (`curl`): login real emite
     ambos tokens, refresh real rota correctamente, reuso del token
     viejo devuelve 401 — no solo tests, el flujo completo end-to-end
     funciona tal cual (36/36 tests de backend pasando en total).
   **`npm audit` sí se investigó a fondo esta ronda**: la vulnerabilidad moderada de `qs`
   (2.2.5-6.15.3) **no viene de `express`** como se pensaba — `express`
   (vía `body-parser`) ya usa `qs@6.16.0`, una versión segura fuera del
   rango vulnerable. La única instancia vulnerable (`qs@6.14.2`) llega
   por `supertest` → `superagent`, y `supertest` es **devDependency**
   (solo se usa corriendo tests, nunca se instala ni corre en
   producción). `npm audit fix` (con y sin `--force`) confirma que no
   hay una versión más nueva de `superagent` que resuelva esto todavía —
   es un problema sin arreglar en esa librería, no algo que este proyecto
   pueda corregir por su cuenta. Conclusión: **no hay riesgo real en el
   backend desplegado**, solo en el entorno de desarrollo/tests. No amerita
   más acción que revisar de nuevo si `superagent` publica una versión
   nueva más adelante.
5b. **Bug real: Perfil y Avisos se habían quedado fuera de la ronda de
   header de escritorio — mismo hueco reportado por el usuario, ahora
   con captura.** La ronda del rediseño de header solo tocó las 4
   pantallas que el usuario señaló en ese momento (Home/Descubrir/
   Publicaciones/Amigos); `PerfilScreen` y `NotificationsScreen` seguían
   con su `SteamAppBar` fundida-con-el-fondo pero SIN condicional,
   dejando el mismo hueco vacío en escritorio. `PerfilScreen` no
   necesita `esPestana` (solo se construye como pestaña, nunca se pushea
   sola en escritorio — confirmado grepeando todos los usos). Igual
   `NotificationsScreen` (solo el bell de la barra global la selecciona);
   "Todo leído" se movió a la fila de pestañas cuando hay notificaciones
   sin leer. **`BusquedaScreen` y `ChatScreen` se revisaron y NO
   necesitaban el fix**: `BusquedaScreen` solo se ve pusheada de verdad
   (desde "Ir a búsqueda" en Perfil) — el índice de pestaña nunca se
   selecciona en ningún lado del código; `ChatScreen` (índice 5) tampoco
   se selecciona nunca — `FloatingChat` es un overlay autónomo que no
   navega ahí. Ambas están "vivas" en el `IndexedStack` pero nunca se
   muestran como pestaña activa en escritorio, así que su AppBar
   incondicional no produce ningún hueco visible en la práctica.
   Confirmado en vivo (Perfil) con el navegador integrado.
6. Nivel 2: optimización de velocidad (Lighthouse, una vez desplegado) —
   sin cambios esta ronda.
7. Nivel 3: solo "botones de redes sociales" pendiente (el usuario duda
   del valor — baja prioridad real). **Aclarado con el usuario**: se
   refiere a presencia del *proyecto* (correo/Discord en el footer), no
   a que cada perfil de usuario muestre sus redes personales (eso sí
   sería un tema de privacidad) — pendiente de implementar.
7b. **Publicaciones: 3 hallazgos de una sesión de pruebas real.**
   - [x] **Bug real: el campo "Cupos buscados" aceptaba texto libre.**
     `keyboardType: TextInputType.number` solo cambia el teclado en
     pantalla en móvil — en web/escritorio con teclado físico no
     impedía escribir letras. Se agregó
     `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`, que sí
     lo bloquea de verdad.
   - [x] **Aclarado (no era un bug): "¿la publicación se cierra sola al
     llenar los cupos?" — SÍ, ya estaba implementado.** El usuario
     preguntó directamente. Revisando `matches.js` (`PUT
     /matches/:id/responder`): al aceptar un match que hace que
     `cupos_ocupados >= cupos_totales`, la publicación se cierra
     automáticamente (`estado_publi = FALSE`). Ya funcionaba, solo no
     era obvio desde la UI — podría valer la pena un texto tipo "se
     cierra sola al llenarse" cerca del campo de cupos, pendiente de
     decidir.
   - [x] **Nueva función: editar una publicación ya creada.** Antes no
     existía ninguna forma de corregir una publicación — había que
     borrarla y volver a hacerla. Nuevo `PUT /publicaciones/:id/editar`
     (backend): valida dueño, no permite bajar `cupos_totales` por
     debajo de lo ya ocupado (dejaría la publicación en un estado
     imposible), reemplaza los juegos asociados si se envían. El tipo
     (`busco_familia`/`busco_miembros`/...) **no se puede editar** —
     cambiar de tipo tiene efectos secundarios (requiere Steam, cupos
     por defecto) que no tiene sentido a medio camino; si alguien quiere
     otro tipo, crea una publicación nueva. `CrearPublicacionScreen`
     ahora acepta un `publicacionExistente` opcional que precarga todos
     los campos y cambia a modo edición (título "EDITAR PUBLICACIÓN",
     tipo deshabilitado, botón "Guardar cambios"). Nuevo botón de lápiz
     en `PublicacionCard` (junto al de cerrar, solo en tus propias
     publicaciones) que abre el formulario en modo edición. Cubierto por
     5 tests nuevos (`tests/publicaciones.editar.test.js`): edición
     exitosa, título obligatorio, no puedes editar lo ajeno, 404 si no
     existe, no se puede bajar cupos por debajo de lo ocupado. 41/41
     tests de backend. **Verificado en vivo**: los campos precargan
     correctamente al abrir "Editar publicación".
   - [x] **RESUELTO — decidido y probado como "prueba" a pedido
     explícito del usuario ("hagamos una prueba de esas recomendaciones
     para ver").** Ver detalle completo en el punto 11 (ronda de
     UX de publicaciones/país) más abajo: botón "Marcar todos" +
     restricción de "Buscar en Steam" para tipos que exigen Steam
     (familia/miembros).
8. Roadmap Nivel 4 restante: login con Google, rediseño visual del panel
   de administración. **Pagos locales (Nequi/Bancolombia) ya no está acá
   — se implementó esta ronda vía llave Bre-B**, ver arriba.
9. **Renombrar Steamlinker → SteamMatch en el repo — pedido por el
   usuario, evaluado: NO es una tarea grande como se temía, se divide en
   3 categorías con prioridad muy distinta.**
   - [x] **Ya arreglado esta ronda (strings reales visibles al
     usuario)**: el error `'Este usuario ocultó su biblioteca en
     Steamlinker.'` en `perfil.js` (lo devuelve la API y se muestra tal
     cual en la UI), el `<title>` del panel de admin, y el placeholder
     del campo de email del login de admin.
   - [x] **RESUELTO — pasada rápida hecha.** `SteamlinkerApp` →
     `SteamMatchApp` (y `_SteamlinkerAppState` → `_SteamMatchAppState`)
     en `main.dart` + `test/widget_test.dart`; comentarios y
     `console.log`/`debugPrint` con "Steamlinker" en
     `main.dart`/`index.js`/`games.js`; CSV del admin ya renombrado a
     `steammatch-usuarios.csv` (ronda anterior); título del `README.md`
     raíz (`# Steamlinker` → `# SteamMatch`, la mención a la carpeta
     real `Steamlinker BD/` se dejó igual porque describe un path que
     sigue existiendo); `description` de `steamlinker_back/package.json`.
     También se encontraron y corrigieron 2 lugares genuinamente
     visibles para un usuario que no estaban en el radar original: el
     nombre de la app bajo el ícono en **iOS** (`CFBundleDisplayName`
     en `Info.plist`) y en **Android** (`android:label` en
     `AndroidManifest.xml`) seguían diciendo "Steamlinker" -- sería lo
     primero que vería cualquiera si algún día se compila para móvil.
     `flutter analyze` limpio, `flutter test test/widget_test.dart`
     pasa, 42/42 tests de backend, backend real reiniciado sin errores.
   - **NO recomiendo tocar, mi criterio**: el nombre de las carpetas
     (`steamlinker_back`/`steamlinker_flutter`), el `name` en
     `pubspec.yaml`/`package.json` (solo 2 archivos de test usan
     `package:steamlinker_flutter/...`, así que técnicamente es barato,
     pero renombrar el paquete Dart activo mueve el nombre por el que
     Flutter identifica el proyecto), el nombre de la base de datos
     (`steamlinker`/`steamlinker_test`) y el nombre del repo en GitHub.
     Ninguno de estos lo ve un usuario final — son identificadores
     internos de infraestructura, y cambiarlos tiene costo real (romper
     rutas de desarrollo local, `.env` existentes, posibles scripts de
     despliegue) sin ningún beneficio de marca a cambio. Un producto
     real puede perfectamente tener un nombre de carpeta/paquete interno
     distinto al nombre público — es una práctica común, no una
     inconsistencia que alguien de afuera note.
   - **Encontrado de paso, no soy quien debe decidirlo**: el panel de
     admin (`public/admin/index.html`) trae baked-in un default real,
     `https://steamlinker.onrender.com`, como URL del backend
     (`BASE_URL`). Esto sugiere que en algún momento hubo (¿o hay?) un
     backend desplegado de verdad en Render con ese nombre. No lo toqué
     — si ese despliegue existe y sigue en uso, cambiar el string sin
     más contexto podría romper el acceso por defecto al panel. El
     usuario debería confirmar si ese despliegue sigue vivo antes de
     tocarlo.
10. **Checklist de SEO/descubribilidad que mandó el usuario — organizado
    por prioridad real, con mi criterio de qué aplica y qué no todavía.**
    El bloqueo de fondo: **la mayoría de estos ítems no tienen sentido
    sin un dominio real y el backend+frontend desplegados de verdad** —
    hoy todo corre en local. No es que falte hacerlos, es que el
    prerrequisito de todos ellos (el dominio) no está resuelto.
    - **Tier 0 — la decisión que desbloquea todo lo demás**: **el
      dominio** (comprarlo + decidir dónde se despliega el backend y el
      frontend). Nada de lo que sigue tiene sentido real sin esto
      primero. Esto es una decisión del usuario (presupuesto, proveedor),
      no algo que se resuelva escribiendo código.
      **⏰ PENDIENTE EXPLÍCITO, recordar al usuario**: el usuario decidió
      hacerlo "cuando ya sea necesario, puede ser poco antes de tener la
      1.0" — no antes. Si se retoma esta sesión o una futura y la 1.0 se
      empieza a ver cerca, sacar el tema.
      **Mi recomendación de hosting cuando llegue el momento** (el
      despliegue anterior en Render, `steamlinker.onrender.com`, era
      solo para la presentación de la universidad, no pensado para
      quedarse — por eso está muerto hoy):
      - **Backend (Node) + base de datos**: **Railway** en vez de volver
        a Render. Render free tier tiene "cold starts" (la primera
        petición después de ~15 min inactivo tarda 30-60s en responder)
        — aceptable para una demo, no para un 1.0 real. Railway no
        duerme la app así, tiene mejor experiencia de despliegue (conectas
        el repo y ya), y para el tráfico bajo de un proyecto así el
        costo con el crédito mensual que da debería ser mínimo. Ojo
        aparte: el Postgres gratis de Render se borra a los 90 días si
        no se pasa a un plan pago — otra razón para no volver a ese setup
        tal cual estaba.
      - **Frontend** (el build de `flutter build web`): Netlify o Vercel,
        cualquiera de los dos — capa gratis de sobra para este tamaño de
        proyecto, ambos con despliegue automático conectando el repo de
        GitHub.
      - **Conectar el dominio**: una vez comprado, la raíz
        (`steammatch.com`) apunta al frontend (Netlify/Vercel) y un
        subdominio (`api.steammatch.com`) al backend (Railway) — cada
        proveedor da sus propias instrucciones DNS exactas al momento.
    - [x] **Tier 1 — RESUELTO, hecho esta ronda (no dependía del
      dominio):**
      - **Metatítulos/descripciones**: revisados, ya estaban bien
        (`<title>SteamMatch</title>`, `meta name="description"` con
        una frase concreta, `apple-mobile-web-app-title`). No hacía
        falta tocar nada.
      - **Texto alternativo en imágenes**: agregado `semanticLabel`/
        `Semantics(image: true, label: ...)` en las ~11 carátulas de
        juego y fotos de perfil que se mostraban sin ninguno
        (`juego_card.dart`, `publicacion_card.dart`,
        `usuario_detalle_screen.dart`, `comparar_biblioteca_screen.dart`,
        `publicacion_detalle_screen.dart`, `descubrir_gamers_screen.dart`
        -- `_MiniCaratula` ganó un parámetro `nombre` opcional --,
        `perfil_screen.dart` x3, `busqueda_screen.dart`,
        `responsive_shell.dart` x2, `steam_app_bar.dart`). La mayoría
        son `DecorationImage` dentro de un `BoxDecoration`, que no
        tiene forma nativa de llevar texto alternativo -- se envolvió
        el `Container` en `Semantics(image: true, label: ...)` en esos
        casos; los 2 `Image.network` directos usan su propio
        `semanticLabel`. Las fotos de perfil propias llevan un label
        genérico ("Tu foto de perfil de Steam"); las carátulas de
        juego usan el nombre real del juego.
      - **Contraste de colores**: auditoría real contra WCAG 2.1
        (cálculo de luminancia relativa, no una revisión visual) de
        todas las combinaciones fondo/texto de `SteamColors`. Resultado:
        prácticamente todo pasa cómodo (7:1+ en la mayoría de fondo +
        texto). **Un hallazgo real, no corregido a propósito**: texto
        blanco sobre el azul de marca en botones primarios
        (`SteamButtonPrimary`, 13px bold) da 3.68:1 -- por debajo del
        4.5:1 que exige AA para texto normal (aunque sí pasa el 3:1 de
        "componentes de UI"). No lo toqué porque el azul de marca ya
        fue confirmado explícitamente por el usuario antes (ver
        comentario en `colors.dart`) -- no es mi lugar cambiar un color
        de marca ya decidido sin que lo pida. Queda anotado por si en
        algún momento se quiere ajustar el tono del azul o usar un azul
        más oscuro solo para fondos de botón con texto encima.
      - **Enlaces rotos**: auditados los únicos 2 links externos reales
        de toda la app Flutter (`AppConfig.kofiUrl` →
        `https://ko-fi.com/camiko31`, y el enlace a
        `https://steamcommunity.com/my/edit/settings` en Inicio) --
        ambos cargan correctamente, verificado en vivo con el
        navegador integrado.
      - `flutter analyze` limpio, `flutter test test/widget_test.dart`
        pasa, `dart format` corrido en los archivos tocados.
    - **Tier 2 — depende 100% de tener el dominio ya resuelto, pero
      simples una vez que exista**: sitemap.xml y robots.txt, Google
      Search Console (verificación de propiedad), indexación de Google.
    - **Tier 3 — opcional / cuestionable, mi opinión honesta**:
      - **Analítica**: de acuerdo con el usuario en que no vale la pena
        todavía — sin tráfico real no hay nada que medir. Mejor
        justo cuando se publique el dominio, no antes.
      - **"Ficha de Google" (Google Business Profile)**: esto es para
        negocios con presencia física/local (restaurantes, tiendas,
        consultorios) — SteamMatch es una app web, no aplica en el
        sentido tradicional. Si el usuario se refería a otra cosa (ej.
        una futura ficha en Google Play si algún día hay app nativa),
        aclarar — tal como está pedido, no es un ítem real para este
        proyecto.
      - **Velocidad de carga optimizada**: parcialmente ya cubierto
        (tree-shaking de fuentes/íconos ya activo en cada `flutter build
        web`), pero medirla de verdad con Lighthouse solo tiene sentido
        una vez desplegado — ya estaba anotado así en el Nivel 2 de
        arriba, no es un ítem nuevo.

11. **Ronda de UX en publicaciones + país (pedido explícito del
    usuario, todo implementado y verificado en vivo).**
    - **⏰ PENDIENTE GENERAL, anotado a pedido explícito**: "debemos
      trabajar más en el UX" — el usuario lo dijo en general, sin
      apuntar a una pantalla específica más allá de lo que se resolvió
      esta ronda. Tenerlo presente para futuras rondas de revisión
      visual/interacción, no hay un ítem concreto más que anotar.
    - [x] **`PaisUtil` ampliado de 5 a 28 países**, con Latinoamérica
      completa (Colombia, México, Argentina, Chile, Perú, Ecuador,
      Venezuela, Bolivia, Paraguay, Uruguay, Costa Rica, Panamá,
      Guatemala, Honduras, El Salvador, Nicaragua, República
      Dominicana, Puerto Rico, Cuba) primero en la lista, más España,
      EE.UU., Canadá, Brasil, Reino Unido, Alemania, Francia, Italia,
      Portugal. Refactorizado a un solo mapa nombre↔código (antes eran
      dos switch duplicados). `account_settings_screen.dart` tenía su
      **propia lista hardcodeada de 5 países duplicada** (con su propio
      switch nombre↔código) completamente desincronizada de
      `PaisUtil` — se eliminó y ahora usa `PaisUtil` directamente.
    - [x] **Nuevo widget `PaisSelectorField`**
      (`lib/widgets/pais_selector_field.dart`) reemplazando `DropField`
      específicamente para país (no para "Tipo", que sigue con solo 4
      opciones y no lo necesita). Con 28 países un dropdown plano
      obligaba a desplazarse uno por uno — pedido explícito del
      usuario de simplificar eso. Se ve igual que `DropField` pero al
      tocarlo abre una hoja modal con un buscador de texto arriba que
      filtra la lista en vivo. Aplicado en los 3 lugares reales donde
      se elige país: `account_settings_screen.dart`,
      `descubrir_gamers_screen.dart` (filtro), `crear_publicacion_screen.dart`
      y `publicaciones_screen.dart` (filtro). Verificado en vivo:
      buscar "bra" filtra correctamente a solo "Brasil".
    - [x] **Botón "Marcar todos" en la biblioteca de
      `crear_publicacion_screen.dart`**, pedido explícito del usuario.
      Alterna entre marcar/desmarcar todos los juegos de la lista
      mostrada. Además se agregó texto aclaratorio explicando qué
      significa "juegos verificados" — pedido explícito, el usuario
      dijo que esa sección no dejaba claro qué era.
    - [x] **Prueba de mi recomendación anterior, aceptada explícitamente
      por el usuario para probar**: para tipos que exigen Steam
      (`busco_familia`/`busco_miembros`), la sección de biblioteca ahora
      se filtra a **solo juegos con `origen == 'steam'`** (los
      realmente verificados, no los agregados a mano) y se renombra a
      "Juegos verificados"; el buscador libre "Buscar en Steam" se
      **oculta por completo** para esos dos tipos (ya no tiene sentido
      ofrecer un juego que ni siquiera está en tu cuenta cuando el tipo
      exige justamente esa verificación). Para `busco_companero`/`otro`
      todo sigue igual que antes (biblioteca completa + buscador
      libre), porque esos tipos no exigen Steam y no hay problema de
      integridad. Es una prueba, no una decisión cerrada — si el
      usuario la prueba y no le convence, es fácil revertir
      (`_requiereSteam`/`_bibliotecaMostrada` en
      `crear_publicacion_screen.dart`).
    - [x] **Cupos: eliminado el default silencioso de 6 para
      familia/miembros cuando se deja vacío — pedido explícito.** Antes
      el backend (`POST /publicaciones/crear`) ponía `cupos_totales = 6`
      automáticamente para `busco_familia`/`busco_miembros` si el
      usuario no elegía nada. El usuario pidió que si no se elige nada,
      la publicación **no muestre ningún límite de cupos** (ya el panel
      de detalle solo se renderiza `if (pub['cupos_totales'] != null)`,
      así que con `cupos_totales` en `null` de verdad desaparece del
      todo). Se quitó la constante `CUPOS_DEFAULT_FAMILIA` y la rama que
      la usaba; ahora simplemente queda `null` si no se especifica,
      para cualquier tipo. Revisado que ningún otro lugar de la UI
      asuma un valor no nulo (`chat_context_banner.dart`,
      `home_screen.dart`, `estado_familia_helper.dart` — todos ya
      manejaban `int?` y ya eran condicionales en `!= null`, así que no
      hubo que tocar nada más). El texto del campo cambió de "opcional,
      familia = 6 por defecto" a "opcional" + un `helperText` explicando
      la consecuencia de dejarlo vacío. Actualizado
      `tests/publicaciones.gate.test.js` (el test que verificaba el
      default viejo ya no aplica, se agregó uno nuevo que confirma que
      queda en `null`). 42/42 tests de backend, `flutter analyze`
      limpio, build web verificado en vivo (edición de una publicación
      real "busco_miembros" mostrando correctamente cupos, país,
      "Juegos verificados" con "Marcar todos" y el texto aclaratorio).
    - [x] **Ronda 3 de conceptos de logo**, pedida explícitamente:
      "figura en sí o tipografía, que no tenga que ver con controles,
      concéntrate en la parte de Match". Mostrados 4 conceptos nuevos
      (sin controles, como las rondas 1 y 2 sí tenían) enfocados en la
      idea de conexión/coincidencia: "Enlace de cadena" (dos anillos
      alargados superpuestos), "Pulso conectado" (dos puntos unidos por
      una línea tipo electrocardiograma que hace un pico al centro),
      "Monograma SM" tipográfico (S en azul + M en teal fundidas por
      kerning negativo), y "Lente/intersección" (dos círculos
      superpuestos tipo Venn con el área de traslape rellena — lectura
      literal de "match = coincidencia"). Solo mostrados en el chat
      (`mcp__visualize__show_widget`), no son archivos del repo —
      pendiente que el usuario elija entre estos y las 6 opciones de
      las rondas 1-2 (donde ya había mostrado preferencia por "Chispa
      de Match" para el logo grande y "Monograma S" para el favicon).

12. **Corrección sobre la marcha, pedida explícitamente tras probar el
    punto 11**: el usuario aclaró que ocultar "Buscar en Steam" para
    `busco_familia`/`busco_miembros` (implementado como prueba en el
    punto anterior) estaba mal pensado. Ejemplo real que dio: si buscas
    miembros y NO tienes Baldur's Gate 3, pero quieres encontrar a
    alguien que sí lo tenga, necesitas poder buscarlo aunque no esté en
    tu biblioteca verificada -- la sección no es solo "ofrece lo tuyo",
    también es "indica qué buscas en el otro". **Revertido**: el
    buscador libre de Steam Store vuelve a estar disponible para los 4
    tipos de publicación. Para `busco_familia`/`busco_miembros` ahora
    tiene un texto aclaratorio nuevo ("Aunque no los tengas -- sirve
    para indicar qué juegos buscas en quien te contacte") y el
    encabezado cambia a "Juegos que buscas" en vez de "Buscar en
    Steam". La sección de "Juegos verificados" (biblioteca filtrada a
    `origen == 'steam'` + botón "Marcar todos") se queda igual que
    antes -- ese mecanismo sigue teniendo sentido para ofrecer lo que
    de verdad tienes, el error estaba solo en quitar el buscador libre.
    `crear_publicacion_screen.dart`, `flutter analyze` limpio.
13. **Logo finalizado (por ahora): concepto "1b. Dos controles"
    elegido explícitamente por el usuario** ("dos controles casi
    tocándose -- vamos a jugar juntos, más literal"), con la aclaración
    de que se puede cambiar más adelante -- esto no cierra el tema para
    siempre, solo destraba tener un logo real en vez del ícono
    genérico de Material Design que había de placeholder.
    - [x] Nuevo widget reutilizable `AppLogoMark`
      (`lib/widgets/app_logo_mark.dart`): `CustomPainter` que dibuja
      las dos siluetas de control (sin depender de ningún paquete de
      SVG externo, coherente con el resto del proyecto) con un
      parámetro `color` para adaptarse a cada contexto. Reemplaza
      `Icon(Icons.sports_esports, ...)` en los 3 lugares donde estaba
      de placeholder: `steam_app_bar.dart` (chip circular con borde
      azul), `responsive_shell.dart` (chip cuadrado azul del sidebar
      de escritorio) y `login_screen.dart` (círculo con degradado
      azul→teal). Verificado en vivo en los 3 contextos.
    - [x] **Favicon y los 4 íconos PWA regenerados de verdad** (antes
      eran genéricos/placeholder): `web/favicon.png` (16×16),
      `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`,
      `Icon-maskable-512.png`. Fondo: cuadrado a sangre completa (sin
      esquinas redondeadas en el archivo -- el redondeo lo aplica el
      SO/navegador) con degradado diagonal azul→teal (los mismos
      colores de marca, `SteamColors.blue`/`teal`). Marca: mismas dos
      siluetas de control que `AppLogoMark`, en `SteamColors.bgDeep`.
      Las versiones "maskable" llevan la marca más chica (escala 0.96
      contra 1.3 de las normales) para no salirse de la zona segura que
      recortan Android/iOS al aplicarles máscara de forma. Generados
      dibujando el SVG en un `<canvas>` dentro del navegador integrado
      (`canvas.toDataURL('image/png')`) y guardados a disco vía un
      pequeño servidor HTTP local temporal (evita mandar strings base64
      de cientos de KB como salida de herramienta) -- proceso ad hoc,
      no quedó ningún script permanente en el repo.
    - Pendiente, no bloqueante: el usuario puede pedir variantes del
      mismo concepto (colores, ángulo, proporciones) o cambiar de
      concepto del todo más adelante -- no se cerró como decisión
      final e irreversible.
14. **Rediseño de identidad del panel de admin (alcance elegido
    explícitamente por el usuario entre 3 opciones: "solo identidad de
    marca", sin tocar estructura/layout que ya funcionaba bien).**
    - [x] **Bug real encontrado antes de rediseñar nada**: había DOS
      implementaciones de `loadDashboard()`/`nav()` compitiendo -- una
      vieja e incompleta dentro de `index.html` (con un bug real:
      "Familias formadas" mostraba `totalPublicaciones` en vez de
      `familiasFormadas`, y 6 de las 10 tarjetas del dashboard se
      quedaban en "—" para siempre) y una versión nueva y completa en
      `admin-panel.js` (parcheaba `window.loadDashboard`/`window.nav`
      correctamente). El problema: `index.html` disparaba el primer
      render (`nav('dashboard'); loadDashboard();`) ANTES de que
      `admin-panel.js` terminara de cargar, así que la primera pintura
      siempre usaba la versión vieja rota -- solo se veía bien si
      navegabas manualmente fuera y volvías a Dashboard. Corregido
      moviendo el trigger inicial al final de `admin-panel.js` (donde
      `window.nav`/`window.loadDashboard` ya son las versiones
      parcheadas) y quitando el trigger duplicado de `index.html`.
      Verificado en vivo: recargando la página ya logueado, las 10
      tarjetas cargan bien de una, sin tener que hacer clic a otra
      sección y volver.
    - [x] **Paleta de colores realineada a `SteamColors`** (antes el
      panel tenía su propia paleta suelta sin relación con la app):
      `--accent` de `#1b8cff` a `#3B82F6` (`SteamColors.blue`), los 5
      tonos de fondo (`--bg0`..`--bg4`) retinteados hacia el azul
      marino de `SteamColors.bgDeep/bgPanel/bgCard`, texto/estados
      (`--t1`/`--t2`/`--t3`, rojo/verde/amarillo/naranja) alineados a
      sus equivalentes de `SteamColors`. Todo pasa por variables CSS
      en `:root`, así que un solo cambio se propaga a toda la interfaz
      (confirmado por grep: no quedaban colores sueltos fuera de esas
      variables, salvo los del logo nuevo).
    - [x] **Logo + nombre**: los dos SVG de placeholder (un ícono de
      "personas conectadas" genérico) se reemplazaron por la misma
      marca de dos controles (`AppLogoMark`) sobre el mismo degradado
      azul→teal, en el login y en el sidebar. "Steam*linker*" →
      "Steam*Match*" en ambos lugares (el `<title>` ya decía
      SteamMatch). Se agregó también un favicon propio para la pestaña
      del panel (antes no tenía ninguno, `<link rel="icon">` con la
      misma marca en SVG inline) -- antes de este cambio la pestaña
      del navegador no mostraba nada.
    - [x] De paso, bajo esfuerzo: "Steamlinker" → "SteamMatch" en los
      últimos 3 lugares que quedaban en `admin-panel.js` (comentario de
      cabecera, `console.info` de arranque, nombre del CSV que se
      descarga -- ahora `steammatch-usuarios.csv`).
    - [x] **Confirmado por el usuario en vivo (2026-09-19): "ya entré
      al panel, todo se ve bien"** -- las secciones que no pude revisar
      yo mismo (Familias, Solicitudes, Reportes, Contenido, Chats,
      Mensajes, Configuración) las vio él directamente. Rediseño de
      identidad del panel de admin cerrado del todo.

## 12. Cómo retomar

1. Sigue el checklist de la sección 11 en orden — Fases 1, 2 y 3 (a nivel de tokens)
   están cerradas. El siguiente trabajo real es Fase 4 (shell responsive) o el retrofit
   de Fase 5 (aplicar `SteamRadii`/tipografía pantalla por pantalla).
2. No asumas que falta construir infraestructura de matching/listings — revisa el
   código real (`steamlinker_back/src/routes/`, `Steamlinker BD/scrip bd.sql`) antes de
   proponer cambios grandes; casi todo lo "aspiracional" que parece faltar en
   README/wireframes ya existe en el código.
3. Los wireframes (sección 8) y el SRS (sección 10) son referencias, no specs a seguir
   al pie de la letra — el SRS es más confiable como fuente de requisitos porque
   describe lo que efectivamente se construyó y evaluó.
4. Todos los commits van a nombre de `Steamlinker <camilandre0510@gmail.com>` (sección
   inicial) salvo que el usuario diga lo contrario.
