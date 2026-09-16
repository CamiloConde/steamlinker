# Handoff — continuidad de sesión Claude

Este archivo resume todo lo que se decidió y se hizo en una sesión previa de Claude Code
(en la nube) para que una sesión nueva (local, en otro PC) pueda seguir exactamente donde
se quedó, sin tener que redescubrir nada. Bórralo o muévelo a `docs/` cuando el proyecto
ya no lo necesite como referencia activa.

**Rama de trabajo:** `claude/fervent-cori-2bt1jm` (ya pusheada a `origin`, este archivo
va sobre esa misma rama).

**Identidad de commits:** todos los commits de esta sesión se hicieron a nombre de
`Steamlinker <camilandre0510@gmail.com>` (el dueño del proyecto), sin ningún rastro de
Claude en autoría ni en los mensajes — así lo pidió explícitamente. Para lograrlo sin
tocar la config global de git se usó, en cada commit:

```
GIT_AUTHOR_NAME="Steamlinker" GIT_AUTHOR_EMAIL="camilandre0510@gmail.com" \
GIT_COMMITTER_NAME="Steamlinker" GIT_COMMITTER_EMAIL="camilandre0510@gmail.com" \
git commit --author="Steamlinker <camilandre0510@gmail.com>" -m "..."
```

Si la sesión local tiene otras instrucciones de atribución (por ejemplo, un
`Co-Authored-By: Claude ...` que el harness quiera agregar por defecto), el usuario ya
pidió expresamente que no se incluya — respeta esa preferencia salvo que él diga lo
contrario.

---

## 1. Qué es el proyecto

Steamlinker (nombre nuevo decidido: **SteamMatch**, ver sección 3) es un sitio
especializado para dos cosas:

1. **Encontrar/formar grupos de Steam Family Sharing.** Hoy esto se resuelve en foros
   genéricos (Reddit, Discord, grupos de Facebook) donde la gente publica "tengo esta
   biblioteca, busco N personas" o "busco entrar a una familia con estos juegos". El
   proyecto le da a eso un espacio dedicado, con datos de Steam verificados (biblioteca
   real vía Steam API, no lo que la persona diga tener).
2. **Encontrar compañeros de juego.** Aprovechando la misma infraestructura de
   biblioteca + matching, la gente también puede buscar con quién jugar tal juego
   específico (no para compartir cuenta, para jugar juntos).

Importante: **no es una integración oficial con Valve ni automatiza el Family Sharing
en sí** — Steam no expone eso. El producto es la capa de coordinación/matchmaking
alrededor, no un cliente que activa el sharing por ti.

Nació como proyecto universitario (Ing. de Sistemas, Universidad Tecnológica de
Bolívar, Cartagena) con la obligación de entregarse como app. El usuario ahora quiere
llevarlo más allá del alcance académico: **Beta actual → Web 1.0 → Mobile (Android/iOS)
→ Desktop**.

## 2. Arquitectura actual (no hace falta reescribir nada de base)

- `steamlinker_flutter/` — Frontend en **Flutter/Dart**. Ya tiene targets para
  `web/`, `android/`, `ios/`, `windows/`, `linux/`, `macos/` en el propio repo. Es decir:
  **"Web 1.0" no requiere cambiar de stack**, es en gran parte `flutter build web` +
  darle una capa de layout responsive nueva.
  - Arquitectura por features (`lib/features/<dominio>/{screens,providers}`), estado con
    `provider`, ruteo con `go_router`, HTTP con `dio`.
  - Theming centralizado en `lib/theme/colors.dart` (`SteamColors`) y
    `lib/theme/app_theme.dart` — paleta oscura ya alineada con el lenguaje visual de
    Steam (bien encaminada, el problema no es el color).
  - Navegación actual: `MainShell` (bottom nav de 3 tabs: Inicio/Notificaciones/Perfil,
    patrón de app móvil). **No tiene breakpoints responsive** (casi no hay
    `LayoutBuilder`/`MediaQuery` en el código) — en pantalla ancha se ve una app de
    celular estirada.
- `steamlinker_back/` — Backend **Node.js + Express**, JWT + bcrypt, rutas separadas por
  dominio (`auth`, `users`, `games`, `amistad`, `matches`, `chat`, `publicaciones`,
  `calificaciones`, `notificaciones`, `reportes`, `admin`). El README de esta carpeta
  documenta un flujo completo de **login con Steam OpenID** (`/auth/steam`) que el
  frontend Flutter actual no usa (el login de Flutter es solo email/password) — ver
  sección 5.
- `Steamlinker BD/` — Esquema **PostgreSQL** (12 tablas): `usuarios`, `perfiles_steam`,
  `juegos`, `usuarios_juegos`, `publicaciones`, `publicacion_juegos`, `matches`,
  `calificaciones`, `chat`, `mensaje`, `reportes`, `amistad`. **No existe ninguna tabla
  de "familia"/"grupo"** — ver sección 4, es el hallazgo más importante de esta sesión.

## 3. Naming

Decidido: **SteamMatch** (mejor que "Steamlinker", que suena a "vincular tu cuenta",
no a lo que el producto hace). Pendiente de ejecutar (no se hizo en esta sesión, es
trabajo futuro — task #3 del roadmap está "completed" solo en cuanto a la *decisión*,
no en cuanto a la ejecución del rebranding):

- Actualizar nombre en `pubspec.yaml`, `package.json`, README, bundle IDs, etc.
- Agregar disclaimer de no afiliación con Valve en el footer/landing (usar "Steam" en el
  nombre de un producto no oficial tiene roce con las guías de marca de Valve; hay
  precedentes que lo toleran — SteamDB, SteamGifts, SteamTrades — siempre que quede
  claro que no es oficial).
- Se recomendó atar esta migración de nombre a la decisión de repo (ver sección 6), para
  resolver dos cosas de una vez.

## 4. El hallazgo de producto más importante: falta el modelo de "listing"

El README original promete "crear y gestionar tu propio grupo de Family Sharing", pero
en la base de datos **todo pasa por `publicaciones`** (posts de muro genérico con texto,
imagen, like, comentario) + `amistad` (relación 1 a 1). No hay noción de "oferta de
cupo en familia", "busco cupo", cupos disponibles/ocupados, ni estado abierto/cerrado.

Reinterpretación acordada con el usuario: la tabla `publicaciones` que ya existe (con
`publicacion_juegos`, comentarios, likes) **no hay que tirarla** — encaja perfecto como
contenido de la pestaña **Comunidad** (muro general de discusión, no ligado a un
cupo/anuncio específico). Lo que falta crear es una entidad nueva de **"listing"**
específicamente para **Familia** y **Compañeros**, con campos tipo:

- `tipo`: oferta_cupo | busco_cupo | busco_companero
- `juegos` (relación a `juegos`, igual que ya existe `publicacion_juegos`)
- `cupos_totales` / `cupos_ocupados`
- `estado`: abierto | cerrado
- referencia al usuario autor

Esto es lo que permite que Steamlinker/SteamMatch sea mejor que un post de Reddit:
filtrar por juego, ver qué tan llena está una familia, cerrar automáticamente un listing
cuando se llenan los cupos — nada de eso se puede hacer hoy con el modelo de
publicaciones genéricas.

**Esto es la Fase 1/2 del roadmap y bloquea el trabajo de UI de Familia/Compañeros** —
no tiene sentido construir esas pantallas nuevas sobre el modelo de datos viejo.

## 5. Auth: decisión pendiente de confirmar con el usuario

Hay dos flujos de identidad conviviendo sin resolver:

- Backend: documenta Steam OpenID completo (`/auth/steam`, `/auth/steam/callback`,
  `/auth/me`).
- Frontend Flutter: solo implementa registro/login con email + password
  (`lib/features/auth/screens/login_screen.dart`).

**Recomendación dada (pendiente de confirmación explícita del usuario):** Steam OpenID
como identidad primaria obligatoria antes de publicar un listing o ver matches (así se
garantiza que la biblioteca mostrada es real — es la ventaja central del producto sobre
un foro). Dejar email/password solo como fricción reducida en el registro inicial antes
de vincular Steam, si acaso.

## 6. Seguridad — qué se hizo y qué falta

Se encontró `steamlinker_back/.env` **trackeado en git con secretos reales** desde el
commit inicial del repo (Steam API key, `JWT_SECRET`, `SESSION_SECRET`, password de
Postgres). Acciones tomadas en esta sesión:

- ✅ `git rm --cached steamlinker_back/.env` (el archivo sigue existiendo localmente,
  `.gitignore` ya lo excluía, solo faltaba destrackearlo).
- ✅ Generados nuevos `JWT_SECRET` y `SESSION_SECRET` (random hex de 32 bytes).
- ✅ Usuario revocó la Steam API key vieja y generó una nueva.
- ✅ Usuario cambió el password de Postgres en su instancia local.
- ⏳ **El `.env` de esta sesión en la nube se actualizó con los valores nuevos, pero es
  un archivo distinto al `.env` de la máquina local del usuario** — confirma con él que
  su `.env` local también tiene los 4 valores nuevos (Steam API key, JWT_SECRET,
  SESSION_SECRET, DB_PASSWORD) antes de dar esto por cerrado. **No hay que pedirle que
  pegue esos valores reales en el chat de nuevo ni escribirlos en ningún archivo que se
  vaya a commitear** — eso repetiría el problema original.
- ⏳ **El historial de git todavía contiene los secretos viejos** (ya revocados/rotados,
  así que no son explotables, pero siguen visibles con `git log -p`). Se decidió
  **posponer** la limpieza de historial (`git filter-repo`/BFG) y resolverla cuando se
  haga la migración de repo a SteamMatch (ver sección siguiente) — así no se hace un
  rewrite disruptivo del repo actual sin necesidad.

**Regla para cualquier sesión futura: nunca vuelvas a commitear `.env` ni pegues
secretos reales dentro de archivos versionados (como este mismo HANDOFF.md). Si hace
falta documentar qué variable existe, documenta el nombre, no el valor.**

## 7. Pendiente de decidir: repo nuevo vs seguir en este

Task #2, todavía sin resolver. La recomendación dada: si van a ejecutar el rebranding a
SteamMatch, aprovechar ese momento para arrancar un repo nuevo bajo el nombre
definitivo — resuelve el nombre y el historial con secretos viejos de una sola vez, en
vez de forzar un `filter-repo` + force-push disruptivo sobre "steamlinker" ahora.

## 8. Dirección de diseño (de los wireframes que el usuario compartió)

El usuario compartió 5 mockups (imágenes, no llegan a una sesión nueva salvo que las
vuelva a adjuntar — **pídele que las reenvíe si vas a trabajar en UI**). Descripción para
tener contexto mientras tanto:

1. **Landing pública (deslogueado):** título "¿Con quién quieres conectar?" sobre un
   collage de carátulas de juegos de fondo, dos CTAs grandes lado a lado: "Buscar
   familia" / "Buscar compañeros", con una foto de un gamer con audífonos al lado
   derecho.
2. **Modal de login:** usuario/contraseña, un QR de acceso rápido a la derecha, y abajo
   opciones de "Ingresar con Google" / "Ingresar con Steam", más link de registro.
3. **Vista "Familia" (logueado):** nav superior con 4 pestañas (**Perfil | Familia |
   Compañeros | Comunidad**), sidebar izquierdo (Juegos de la familia, Matchs,
   Discusiones, Guardados), un muro central tipo Facebook (caja "comparte algo con tu
   familia Steam", posts con imagen del juego, like/comentar), y un panel derecho de
   "Chats" con lista de contactos.
4. Misma vista con una **ventana de chat flotante** superpuesta (estilo Messenger),
   anclada abajo a la derecha, con su propio header, historial y campo de envío.
5. **Perfil de usuario:** banner grande de imagen, avatar circular superpuesto,
   contadores de Amigos/Reputación (estrellas) a los lados del nombre, bio, botones
   "Agregar amigo" / "Mensaje", y abajo una grilla "Juegos Steam Db" con carátulas
   reales.

**Aclaración explícita del usuario:** estos wireframes son *dirección/idea*, no diseño
final — puede haber incoherencias, y específicamente no quiere que el resultado final se
vea "genérico de IA" (gradientes azul-morado difusos, fotos de stock genéricas, avatares
placeholder vacíos). Lo que sí es información real de producto y vale la pena portar tal
cual: la IA de navegación de 4 pestañas arriba, el sidebar de Familia, el panel de chats
con ventanas flotantes. La estética final todavía está abierta — usar el lenguaje propio
de Steam (ya encaminado en `SteamColors`) combinado con algo más editorial: tipografía
con carácter (no Roboto default), las carátulas reales de los juegos como elemento
visual fuerte (evitar fotos de stock), iconografía propia, radios/espaciado consistentes.

## 9. Roadmap completo (con estado actual)

Fase 0 — Seguridad:
- [x] #1 Rotar credenciales filtradas
- [ ] #2 Decidir estrategia de historial/repo (pospuesto, atado al rebranding)

Fase 1 — Definición de producto:
- [x] #3 Nombre final del producto → SteamMatch (decisión tomada, ejecución pendiente)
- [ ] #4 Alcance de la pestaña Comunidad → propuesta dada (reusar `publicaciones` tal
      cual), falta confirmación explícita del usuario
- [ ] #5 Estrategia de identidad/auth → propuesta dada (Steam OpenID primario), falta
      confirmación explícita del usuario

Fase 2 — Backend/datos:
- [ ] #6 Diseñar modelo de datos de "listings" (Familia/Compañeros) — ver sección 4
- [ ] #7 Migrar backend a endpoints de listings
- [ ] #8 Actualizar providers/modelos Flutter para listings

Fase 3 — Diseño:
- [ ] #9 Definir sistema de diseño concreto (tipografía, paleta refinada, escala de
      espaciado/radios, tratamiento de avatares/imágenes, iconografía) — documentar
      antes de tocar UI

Fase 4 — Shell web:
- [ ] #10 Shell de navegación responsive (web + móvil, un solo codebase Flutter):
      top-nav de 4 pestañas + sidebar + rail de chat en desktop, mismo bottom-nav actual
      en móvil
- [ ] #11 Chat flotante estilo Messenger para web (evaluar si el chat actual por
      polling alcanza o si hace falta WebSockets para que no se sienta muerto)

Fase 5 — Pantallas:
- [ ] #12 Reconstruir Familia / Compañeros / Perfil / Landing / Login según la nueva IA
      y el sistema de diseño

Fase 6 — No funcional:
- [ ] #13 Tests automatizados básicos + CI (hoy no hay nada real, solo el placeholder
      de plantilla `widget_test.dart`)
- [ ] #14 Despliegue de la Web 1.0 (hosting backend Node + Postgres + `flutter build
      web`, dominio, variables de entorno de producción)

Fase 7 — Lanzamiento:
- [ ] #15 Beta web pública, recoger feedback real antes de empaquetar formalmente
      Android/iOS/Desktop (Flutter ya los soporta con el mismo código — ahí no hay
      trabajo de plataforma nuevo, es empaque y QA)

## 10. Cómo retomar

1. Recrea esta lista de tareas con `TaskCreate`/`TaskList` si tu harness lo soporta, o
   simplemente sigue el checklist de la sección 9 en orden.
2. Confirma con el usuario los dos puntos abiertos de Fase 1 (#4 alcance de Comunidad,
   #5 estrategia de auth) antes de tocar el modelo de datos — mis recomendaciones están
   dadas arriba, pero no hubo confirmación explícita todavía.
3. Pide que reenvíe los wireframes si vas a trabajar en las pantallas (sección 8).
4. Todos los commits van a nombre de `Steamlinker <camilandre0510@gmail.com>` (sección
   inicial) salvo que el usuario diga lo contrario en la nueva sesión.
