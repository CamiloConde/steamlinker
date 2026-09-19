// src/routes/games.js
// ─────────────────────────────────────────────────────────────
//  Endpoints relacionados con juegos y biblioteca de Steam.
// ─────────────────────────────────────────────────────────────

const express      = require("express");
const steamService = require("../services/steamService");

const router = express.Router();

// ── Middleware: verificar que el usuario esté autenticado ───────
function requireAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: "Debes iniciar sesión con Steam primero" });
  }
  next();
}

// ────────────────────────────────────────────────────────────────

/**
 * GET /games/library
 * Devuelve la biblioteca completa del usuario logueado.
 * 
 * Respuesta ejemplo:
 * [
 *   { appid: 814380, name: "Sekiro", hoursPlayed: 85, headerImg: "https://..." },
 *   ...
 * ]
 */
router.get("/library", requireAuth, async (req, res) => {
  try {
    const games = await steamService.getOwnedGames(req.user.steamid);
    res.json({ games, total: games.length });
  } catch (err) {
    // Perfil privado = error más común
    if (err.response?.status === 403 || games?.length === 0) {
      return res.status(403).json({
        error: "La biblioteca de este usuario es privada. Debe hacerla pública en Steam.",
      });
    }
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /games/library/:steamid
 * Devuelve la biblioteca de cualquier usuario por su steamid.
 * Útil para ver el perfil de otro usuario en SteamMatch.
 */
router.get("/library/:steamid", requireAuth, async (req, res) => {
  try {
    const games = await steamService.getOwnedGames(req.params.steamid);
    res.json({ games, total: games.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /games/compare/:steamid
 * Compara la biblioteca del usuario logueado con otro usuario.
 * Clave para el sistema de matchmaking de familias.
 * 
 * Respuesta ejemplo:
 * {
 *   commonGames: [...],
 *   commonCount: 12,
 *   totalA: 247,
 *   totalB: 183
 * }
 */
router.get("/compare/:steamid", requireAuth, async (req, res) => {
  try {
    const result = await steamService.getCommonGames(
      req.user.steamid,
      req.params.steamid
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /games/achievements/:appid
 * Logros del usuario logueado en un juego específico.
 */
router.get("/achievements/:appid", requireAuth, async (req, res) => {
  try {
    const result = await steamService.getPlayerAchievements(
      req.user.steamid,
      req.params.appid
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
