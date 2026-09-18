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
  URL. Se agrega como ítem concreto del roadmap (ver "Cuenta y login" abajo).
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
- [ ] Selector de idioma (inglés + español Colombia): técnicamente viable
      con `flutter_localizations`, pero es trabajo real (extraer TODOS los
      strings hardcodeados del código a archivos `.arb`) — no es un toggle.
      Opinión: dejarlo para después de tener usuarios reales que lo pidan;
      hoy sería trabajo especulativo.
- [ ] Botones de redes sociales: el propio usuario duda del valor — de
      acuerdo, bajo prioridad. Si se hace, que lleve a compartir un perfil o
      publicación real, no solo íconos decorativos a redes de la empresa.

**Nivel 4 — funciones grandes, evaluar solo con tracción real de usuarios:**
- [ ] Login con Google (opcional, ya lo marcó el usuario como no urgente)
- [ ] Login con Steam vía OpenID (ver opinión arriba — más barato que Google
      y encaja mejor con la identidad del producto, así que si se hace uno
      de los dos primero, que sea este)
- [ ] Panel de administración renovado a la par del resto de la app (hoy
      `AdminPanelSection` es funcional pero no ha recibido el mismo
      tratamiento visual que el resto desde la ronda 4)
- [ ] Si el "Apoya el proyecto" de Nivel 1.5 funciona bien, evaluar
      integración de pagos locales reales (Nequi/Bancolombia vía un
      agregador tipo Wompi/ePayco — requiere persona jurídica o el
      agregador la absorbe según el plan) más allá de un simple link
      externo a Patreon/Ko-fi.

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

### Cosas pendientes de esta sesión (no alcanzadas, ordenadas por mi
### prioridad si se retoma)

1. **Verificación visual en vivo de toda la sesión** — los cambios (Descubrir,
   Configuración, Avisos, perfil de usuario, "Apoya el proyecto", 404,
   favicon, Aviso legal/Privacidad) están cubiertos por `flutter
   analyze`/`flutter test`/tests de backend (16/16 backend, 10/10
   frontend), pero no se pudieron ver en el navegador por un problema de
   escala de coordenadas en la automatización (no un bug de la app). Antes
   de dar la sesión por cerrada del todo, alguien debería abrir
   `flutter build web` y probar a ojo: Descubrir (filtros, dropdown de
   juego), Configuración (etiquetas decorativas + tarjeta Legal), Avisos →
   Marcadas (que ancle arriba), perfil de otro usuario (que ya no aparezca
   "Match recibido"), Inicio → "Apoya el proyecto" (que el botón abra
   https://ko-fi.com/camiko31), el registro (que muestre y abra los enlaces
   legales), y una URL rota (que caiga en la 404 con estilo).
2. **Logo / identidad visual** — trabajo de diseño gráfico, no de código;
   mejor en una sesión dedicada a eso o con una herramienta de diseño. De
   paso quedan pendientes los íconos grandes de instalación PWA
   (`web/icons/Icon-*.png`, 192/512), que siguen con el logo de Flutter.
3. Nivel 1 queda esencialmente cerrado (legal, privacidad, seguridad
   urgente, 404, CTA única, cookies confirmado que no aplica). Lo único
   pendiente ahí: rotación/revocación de JWT (requiere refresh tokens +
   tabla de sesiones, cambio de esquema más grande) y revisar a fondo
   `npm audit` (vulnerabilidad moderada conocida en `qs`, dependencia
   transitiva de `express`).
4. Nivel 2 queda prácticamente cerrado esta sesión (loading screen, botón
   volver arriba, mensajes de error/éxito unificados, formulario de
   contacto, **y ahora también su vista de admin**). Solo falta:
   optimización de velocidad (medir con Lighthouse una vez desplegado, no
   antes).
5. Todo lo demás del roadmap de Niveles 3–4 de arriba, en ese orden.

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
