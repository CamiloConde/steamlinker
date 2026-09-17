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
