// Extensiones del panel admin conectadas al backend SteamMatch

(function patchAdminPanel() {
  window.loadDashboard = async function loadDashboardPatched() {
    try {
      const stats = await api('GET', ENDPOINTS.stats());
      if (stats) {
        const s = stats.data || stats;
        const set = (id, v) => {
          const el = document.getElementById(id);
          if (el) el.textContent = v != null ? Number(v).toLocaleString('es-CO') : '—';
        };
        set('st-usuarios', s.totalUsuarios);
        set('st-familias', s.familiasFormadas);
        set('st-solicitudes', s.solicitudesPendientes);
        set('st-reportes', s.reportesPendientes);
        set('st-publicaciones', s.totalPublicaciones);
        set('st-baneados', s.usuariosBaneados);
        set('st-steam', s.usuariosConSteam);
        set('st-chats', s.totalChats);
        set('st-juegos', s.juegosEnBibliotecas);
        set('st-nuevos', s.usuariosNuevos7d);
        if (s.reportesPendientes > 0) {
          const b = document.getElementById('badge-reportes');
          if (b) {
            b.style.display = '';
            b.textContent = s.reportesPendientes;
          }
        }
      }
    } catch (e) {
      /* stats opcionales */
    }

    try {
      const res = await api('GET', ENDPOINTS.usuarios());
      const lista = (Array.isArray(res) ? res : []).slice(0, 5);
      const el = document.getElementById('dash-usuarios-list');
      if (!lista.length) {
        el.innerHTML = '<div class="empty"><p>Sin usuarios</p></div>';
        return;
      }
      el.innerHTML = `<table><thead><tr><th>Usuario</th><th>Email</th><th>Nivel</th><th>Estado</th></tr></thead><tbody>${lista
        .map((u) => {
          const name = u.username_usu || '—';
          const email = u.email_usu || '—';
          const nivel = u.repu_usu != null ? `★ ${Number(u.repu_usu).toFixed(1)}` : '—';
          const estado = u.baneado_usu ? 'baneado' : 'activo';
          return `<tr>
            <td>${esc(name)}</td>
            <td class="mono">${esc(email)}</td>
            <td>${nivel}</td>
            <td>${statusBadge(estado)}</td>
          </tr>`;
        })
        .join('')}</tbody></table>`;
    } catch (e) {
      document.getElementById('dash-usuarios-list').innerHTML =
        `<div class="empty"><p>No se pudo cargar usuarios. ${esc(e.message)}</p></div>`;
    }

    const actEl = document.getElementById('dash-activity');
    if (!actEl) return;
    try {
      const items = await api('GET', ENDPOINTS.actividad() + '?limit=12');
      const lista = Array.isArray(items) ? items : [];
      if (!lista.length) {
        actEl.innerHTML = '<p style="color:var(--t3);font-size:12px;">Sin actividad reciente</p>';
        return;
      }
      const dot = { usuario: 'green', reporte: 'red', publicacion: 'blue', match: 'yellow' };
      const label = { usuario: 'Nuevo usuario', reporte: 'Reporte', publicacion: 'Publicación', match: 'Match' };
      actEl.innerHTML = lista
        .map((ev) => {
          const tipo = (ev.tipo || '').toLowerCase();
          const d = dot[tipo] || 'blue';
          const titulo = ev.titulo || '—';
          const det = ev.detalle ? '<span> — ' + esc(truncate(ev.detalle, 60)) + '</span>' : '';
          return (
            '<div class="activity-item">' +
            '<div class="activity-dot ' + d + '"></div>' +
            '<div class="activity-text"><strong>' + esc(label[tipo] || tipo) + '</strong> · ' + esc(titulo) + det + '</div>' +
            '<div class="activity-time">' + fmtDateTime(ev.fecha) + '</div></div>'
          );
        })
        .join('');
    } catch (e) {
      actEl.innerHTML = '<p style="color:var(--t3);font-size:12px;">Actividad: ' + esc(e.message) + '</p>';
    }
  };

  window.filterUsuarios = function filterUsuariosPatched() {
    const q = (document.getElementById('usuarios-search')?.value || '').toLowerCase();
    const st = document.getElementById('usuarios-status')?.value || '';
    filtered.usuarios = data.usuarios.filter((u) => {
      const name = (u.username_usu || '').toLowerCase();
      const email = (u.email_usu || '').toLowerCase();
      const steam = (u.steam_id || '').toLowerCase();
      const pais = (u.pais_usu || '').toLowerCase();
      const matchQ = !q || name.includes(q) || email.includes(q) || steam.includes(q) || pais.includes(q);
      const tipo = (u.tipo_usu || 'usuario').toLowerCase();
      const baneado = u.baneado_usu === true;
      let matchSt = true;
      if (st === 'admin' || st === 'usuario') matchSt = tipo === st;
      if (st === 'baneado') matchSt = baneado;
      if (st === 'activo') matchSt = !baneado;
      return matchQ && matchSt;
    });
    pages.usuarios = 1;
    renderUsuarios();
  };

  window.renderUsuarios = function renderUsuariosPatched() {
    const items = renderPagination('usuarios', 'usuarios', renderUsuarios);
    if (!items.length) {
      document.getElementById('usuarios-tbody').innerHTML =
        '<tr><td colspan="8"><div class="empty"><p>No se encontraron usuarios</p></div></td></tr>';
      return;
    }
    document.getElementById('usuarios-tbody').innerHTML = items
      .map((u) => {
        const id = u.id_usu;
        const name = u.username_usu || '—';
        const email = u.email_usu || '—';
        const nivel = u.repu_usu != null ? Number(u.repu_usu).toFixed(1) : '0';
        const familias = u.familias_aceptadas ?? 0;
        const tipo = (u.tipo_usu || 'usuario').toLowerCase();
        const fecha = u.creadoen_usu;
        const baneado = u.baneado_usu === true;
        const esAdmin = tipo === 'admin';
        const estado = baneado ? 'baneado' : 'activo';
        let acciones = '<button class="btn btn-ghost btn-sm" onclick="verUsuario(' + id + ')">Ver</button>';
        if (!esAdmin) {
          acciones += baneado
            ? ` <button class="btn btn-green btn-sm" onclick="accionUsuario('unban',${id})">Desbanear</button>`
            : ` <button class="btn btn-yellow btn-sm" onclick="accionUsuario('ban',${id})">Banear</button>`;
          acciones += ` <button class="btn btn-red btn-sm" onclick="accionUsuario('delete',${id})">Eliminar</button>`;
        }
        return `<tr>
          <td><div class="user-cell"><div class="avatar-txt">${esc(initials(name))}</div><div><div>${esc(name)}</div><div class="mono" style="font-size:10px;">#${id}${u.steam_id ? ' · Steam' : ''}</div></div></div></td>
          <td class="mono">${esc(email)}</td>
          <td>★ ${nivel} <span class="mono" style="color:var(--t3)">(${u.totalrating_usu || 0})</span></td>
          <td>${familias}</td>
          <td>${statusBadge(estado)}</td>
          <td>${statusBadge(tipo)}</td>
          <td class="mono">${fmtDate(fecha)}</td>
          <td><div style="display:flex;gap:5px;flex-wrap:wrap;">${acciones}</div></td>
        </tr>`;
      })
      .join('');
  };

  window.renderReportes = function renderReportesPatched() {
    const items = renderPagination('reportes', 'reportes', renderReportes);
    if (!items.length) {
      document.getElementById('reportes-tbody').innerHTML =
        '<tr><td colspan="6"><div class="empty"><p>No se encontraron reportes</p></div></td></tr>';
      return;
    }
    document.getElementById('reportes-tbody').innerHTML = items
      .map((r) => {
        const id = r.id_repor;
        const rep = r.reportado || '—';
        const by = r.reportador || '—';
        const motivo = r.motivo_repor || '—';
        const estado = r.estado_repor || '—';
        const fecha = r.creadoen_repor;
        const pendiente = String(estado).toLowerCase() === 'pendiente' || String(estado).toLowerCase() === 'abierto';
        const acciones = pendiente
          ? `<button class="btn btn-green btn-sm" onclick="accionReporte('resuelto',${id})">Resolver</button>
             <button class="btn btn-ghost btn-sm" onclick="accionReporte('descartado',${id})">Descartar</button>
             <button class="btn btn-red btn-sm" onclick="banearDesdeReporte(${id})">Banear</button>`
          : '<span class="mono" style="color:var(--t3)">—</span>';
        return `<tr>
          <td><div class="user-cell"><div class="avatar-txt">${esc(initials(rep))}</div>${esc(rep)}</div></td>
          <td>${esc(by)}</td>
          <td style="max-width:200px;">${esc(truncate(motivo, 50))}</td>
          <td>${statusBadge(estado)}</td>
          <td class="mono">${fmtDateTime(fecha)}</td>
          <td><div style="display:flex;gap:6px;flex-wrap:wrap;">${acciones}</div></td></tr>`;
      })
      .join('');
  };

  window.renderSolicitudes = function renderSolicitudesPatched() {
    const items = renderPagination('solicitudes', 'solicitudes', renderSolicitudes);
    if (!items.length) {
      document.getElementById('solicitudes-tbody').innerHTML =
        '<tr><td colspan="5"><div class="empty"><p>No hay solicitudes pendientes</p></div></td></tr>';
      return;
    }
    document.getElementById('solicitudes-tbody').innerHTML = items
      .map((s) => {
        const id = s.id_match || '?';
        const sol = s.solicitante || '—';
        const rec = s.receptor || '—';
        const estado = s.estado_match || '—';
        const fecha = s.creadoen_match;
        return `<tr>
          <td><span class="mono">#${id}</span></td>
          <td>${esc(sol)}</td>
          <td>${esc(rec)}</td>
          <td>${statusBadge(estado)}</td>
          <td class="mono">${fmtDate(fecha)}</td>
        </tr>`;
      })
      .join('');
  };

  window.renderContenido = function renderContenidoPatched() {
    const items = renderPagination('contenido', 'contenido', renderContenido);
    if (!items.length) {
      document.getElementById('contenido-tbody').innerHTML =
        '<tr><td colspan="6"><div class="empty"><p>No hay contenido</p></div></td></tr>';
      return;
    }
    document.getElementById('contenido-tbody').innerHTML = items
      .map((c) => {
        const id = c.id_publi;
        const titulo = c.titulo_publi || '—';
        const tipo = c.tipo_publi || '—';
        const activa = c.estado_publi === true || c.estado_publi === 'true';
        const estadoLabel = activa ? 'activa' : 'cerrada';
        const autor = c.username_usu || '—';
        const fecha = c.creadoen_publi;
        const acciones = (activa
          ? `<button class="btn btn-yellow btn-sm" onclick="accionContenido('cerrar',${id})">Cerrar</button>`
          : `<button class="btn btn-green btn-sm" onclick="accionContenido('reabrir',${id})">Reabrir</button>`) +
          ` <button class="btn btn-red btn-sm" onclick="accionContenido('delete',${id})">Eliminar</button>`;
        return `<tr>
          <td>${statusBadge(tipo)}</td>
          <td>${esc(autor)}</td>
          <td style="max-width:220px;">${esc(truncate(titulo, 60))}</td>
          <td>${statusBadge(estadoLabel)}</td>
          <td class="mono">${fmtDate(fecha)}</td>
          <td>${acciones}</td>
        </tr>`;
      })
      .join('');
  };

  window.accionContenido = async function accionContenidoPatched(estado, id) {
    if (estado === 'delete') {
      showModal('Eliminar publicación', '¿Eliminar permanentemente?', 'Eliminar', 'red', async () => {
        try {
          await api('DELETE', ENDPOINTS.contenidoItem(id));
          toast('Eliminada', 'ok');
          loadContenido();
        } catch (e) {
          toast(e.message, 'err');
        }
      });
      return;
    }
    if (estado === 'cerrar' || estado === 'reabrir') {
      try {
        await api('PUT', ENDPOINTS.contenidoItem(id), {
          estado_publi: estado === 'reabrir',
        });
        toast(estado === 'cerrar' ? 'Publicación cerrada' : 'Publicación reabierta', 'ok');
        loadContenido();
      } catch (e) {
        toast(e.message, 'err');
      }
    }
  };

  window.doLogin = async function doLoginPatched() {
    const email = document.getElementById('login-email').value.trim();
    const pass = document.getElementById('login-pass').value;
    const url = document.getElementById('login-url').value.trim();
    const errEl = document.getElementById('login-error');
    const btn = document.getElementById('login-btn');

    if (!email || !pass) {
      errEl.textContent = 'Completa todos los campos.';
      return;
    }

    if (url) {
      BASE_URL = url;
      localStorage.setItem('sl_base_url', url);
    }

    btn.disabled = true;
    btn.textContent = 'Iniciando sesión…';
    errEl.textContent = '';

    try {
      const res = await fetch(ENDPOINTS.login(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password: pass }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || json.error || 'Credenciales incorrectas');

      token = json.token || json.access_token;
      if (!token) throw new Error('No se recibió token.');

      adminUser = json.usuario || json.user || {};
      const tipo = String(adminUser.tipo || adminUser.tipo_usu || '').toLowerCase();
      if (tipo !== 'admin') {
        throw new Error('Esta cuenta no tiene permisos de administrador.');
      }

      localStorage.setItem('sl_token', token);
      localStorage.setItem('sl_admin', JSON.stringify(adminUser));

      document.getElementById('login-screen').style.display = 'none';
      document.getElementById('app').classList.add('visible');

      const name = adminUser.username || adminUser.email || 'Admin';
      document.getElementById('s-name').textContent = name;
      document.getElementById('s-avatar').textContent = name[0].toUpperCase();

      nav('dashboard');
    } catch (e) {
      errEl.textContent = e.message;
    } finally {
      btn.disabled = false;
      btn.textContent = 'Iniciar sesión';
    }
  };

  window.filterReportes = function filterReportesPatched() {
    const q = (document.getElementById('reportes-search')?.value || '').toLowerCase();
    const st = document.getElementById('reportes-status')?.value || '';
    filtered.reportes = data.reportes.filter((r) => {
      const rep = (r.reportado || '').toLowerCase();
      const repor = (r.reportador || '').toLowerCase();
      const mot = (r.motivo_repor || '').toLowerCase();
      const estado = (r.estado_repor || '').toLowerCase();
      const matchQ = !q || rep.includes(q) || repor.includes(q) || mot.includes(q);
      let matchSt = true;
      if (st === 'abierto') matchSt = estado === 'pendiente' || estado === 'abierto';
      else if (st) matchSt = estado === st;
      return matchQ && matchSt;
    });
    pages.reportes = 1;
    renderReportes();
  };

  ENDPOINTS.actividad = () => `${BASE_URL}${ROUTE_PREFIX}/actividad`;
  ENDPOINTS.chats = () => `${BASE_URL}${ROUTE_PREFIX}/chats`;
  ENDPOINTS.banReportado = (id) => `${BASE_URL}${ROUTE_PREFIX}/reportes/${id}/ban-reportado`;
  data.chats = data.chats || [];
  filtered.chats = filtered.chats || [];
  pages.chats = pages.chats || 1;

  window.loadChats = async function loadChats() {
    const tbody = document.getElementById('chats-tbody');
    if (!tbody) return;
    tbody.innerHTML =
      '<tr><td colspan="5"><div class="loader"><div class="spinner"></div><p>Cargando…</p></div></td></tr>';
    try {
      const res = await api('GET', ENDPOINTS.chats());
      data.chats = Array.isArray(res) ? res : [];
      filterChats();
    } catch (e) {
      tbody.innerHTML = '<tr><td colspan="5"><div class="empty"><p>' + esc(e.message) + '</p></div></td></tr>';
    }
  };

  window.filterChats = function filterChats() {
    const q = (document.getElementById('chats-search')?.value || '').toLowerCase();
    filtered.chats = data.chats.filter((c) => {
      const a = (c.usuario_a || '').toLowerCase();
      const b = (c.usuario_b || '').toLowerCase();
      const m = (c.ultimo_mensaje || '').toLowerCase();
      return !q || a.includes(q) || b.includes(q) || m.includes(q);
    });
    pages.chats = 1;
    renderChats();
  };

  window.renderChats = function renderChats() {
    const tbody = document.getElementById('chats-tbody');
    if (!tbody) return;
    const items = renderPagination('chats', 'chats', renderChats);
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="5"><div class="empty"><p>Sin chats</p></div></td></tr>';
      return;
    }
    tbody.innerHTML = items
      .map(
        (c) =>
          '<tr><td class="mono">#' +
          (c.id_chat || '?') +
          '</td><td>' +
          esc(c.usuario_a || '—') +
          ' ↔ ' +
          esc(c.usuario_b || '—') +
          '</td><td>' +
          esc(truncate(c.ultimo_mensaje || '—', 70)) +
          '</td><td class="mono">' +
          (c.total_mensajes ?? 0) +
          '</td><td class="mono">' +
          fmtDateTime(c.ultima_actividad) +
          '</td></tr>'
      )
      .join('');
  };

  window.chatsPag = (d) => {
    pages.chats = Math.max(1, pages.chats + d);
    renderChats();
  };

  window.verUsuario = async function verUsuario(id) {
    try {
      const u = await api('GET', ENDPOINTS.usuario(id));
      if (!u) return;
      const modal = document.getElementById('usuario-modal');
      const body = document.getElementById('usuario-modal-body');
      if (!modal || !body) return;
      document.getElementById('usuario-modal-title').textContent = u.username_usu || 'Usuario #' + id;
      const baneado = u.baneado_usu === true;
      const esAdmin = (u.tipo_usu || '').toLowerCase() === 'admin';
      const steam = u.steam_id
        ? '<a href="' +
          esc(u.perfil_url || '#') +
          '" target="_blank" style="color:var(--accent)">' +
          esc(u.username_steperfil || u.steam_id) +
          '</a>'
        : 'No vinculado';
      // El nombre para los botones de acción se busca dentro de accionUsuario()
      // a partir del id — no se embebe aquí (ver comentario en accionUsuario).
      let acc =
        '<button class="btn btn-ghost btn-sm" onclick="cambiarRepuUsuario(' + id + ')">Ajustar reputación</button>';
      if (!esAdmin) {
        acc +=
          ' <button class="btn btn-blue btn-sm" onclick="cambiarRolUsuario(' +
          id +
          ", 'admin')\">Hacer admin</button>";
        acc += baneado
          ? ` <button class="btn btn-green btn-sm" onclick="closeUsuarioModal();accionUsuario('unban',${id})">Desbanear</button>`
          : ` <button class="btn btn-yellow btn-sm" onclick="closeUsuarioModal();accionUsuario('ban',${id})">Banear</button>`;
        acc += ` <button class="btn btn-red btn-sm" onclick="closeUsuarioModal();accionUsuario('delete',${id})">Eliminar</button>`;
      }
      body.innerHTML =
        '<div class="detail-grid">' +
        '<div class="detail-field"><div class="df-label">Email</div><div class="df-value mono">' +
        esc(u.email_usu || '—') +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">País</div><div class="df-value">' +
        esc(u.pais_usu || '—') +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Tipo</div><div class="df-value">' +
        statusBadge(u.tipo_usu || 'usuario') +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Estado</div><div class="df-value">' +
        statusBadge(baneado ? 'baneado' : 'activo') +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Reputación</div><div class="df-value">★ ' +
        Number(u.repu_usu || 0).toFixed(1) +
        ' (' +
        (u.totalrating_usu || 0) +
        ')</div></div>' +
        '<div class="detail-field"><div class="df-label">Steam</div><div class="df-value">' +
        steam +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Publicaciones</div><div class="df-value">' +
        (u.publicaciones ?? 0) +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Juegos</div><div class="df-value">' +
        (u.juegos ?? 0) +
        '</div></div>' +
        '<div class="detail-field"><div class="df-label">Reportes recibidos</div><div class="df-value">' +
        (u.reportes_recibidos ?? 0) +
        '</div></div>' +
        '</div>' +
        (baneado && u.motivo_ban
          ? '<p style="margin-top:10px;color:var(--red);font-size:12px;">Motivo: ' + esc(u.motivo_ban) + '</p>'
          : '') +
        '<div style="margin-top:14px;display:flex;flex-wrap:wrap;gap:8px;">' +
        acc +
        '</div>';
      modal.classList.add('open');
    } catch (e) {
      toast(e.message, 'err');
    }
  };

  window.closeUsuarioModal = () => document.getElementById('usuario-modal')?.classList.remove('open');

  window.cambiarRepuUsuario = (id) => {
    const val = prompt('Nueva reputación:', '0');
    if (val === null) return;
    const repu = Number(val);
    if (Number.isNaN(repu) || repu < 0) {
      toast('Valor inválido', 'err');
      return;
    }
    api('PUT', ENDPOINTS.usuario(id), { repu })
      .then(() => {
        toast('Reputación actualizada', 'ok');
        verUsuario(id);
        loadUsuarios();
      })
      .catch((e) => toast(e.message, 'err'));
  };

  window.cambiarRolUsuario = (id, rol) => {
    showModal('Cambiar rol', '¿Confirmar cambio de rol a <strong>' + rol + '</strong>?', 'Confirmar', 'blue', () => {
      api('PUT', ENDPOINTS.usuario(id), { tipo: rol })
        .then(() => {
          toast('Rol actualizado', 'ok');
          verUsuario(id);
          loadUsuarios();
        })
        .catch((e) => toast(e.message, 'err'));
    });
  };

  window.exportarUsuariosCsv = () => {
    const rows = filtered.usuarios.length ? filtered.usuarios : data.usuarios;
    if (!rows.length) {
      toast('Sin datos', 'info');
      return;
    }
    const lines = ['id,username,email,pais,tipo,repu,baneado'];
    rows.forEach((u) => {
      lines.push(
        [u.id_usu, u.username_usu, u.email_usu, u.pais_usu, u.tipo_usu, u.repu_usu, u.baneado_usu ? 1 : 0].join(',')
      );
    });
    const blob = new Blob([lines.join('\n')], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'steammatch-usuarios.csv';
    a.click();
    toast('CSV descargado', 'ok');
  };

  window.banearDesdeReporte = (id) => {
    showModal('Banear reportado', '¿Banear al usuario y resolver el reporte?', 'Banear', 'red', async () => {
      try {
        await api('POST', ENDPOINTS.banReportado(id), {});
        toast('Usuario baneado', 'ok');
        loadReportes();
        loadUsuarios();
      } catch (e) {
        toast(e.message, 'err');
      }
    });
  };

  const origNav = window.nav;
  window.nav = function navFull(section) {
    origNav(section);
    if (section === 'chats') loadChats();
  };

  if (typeof sectionTitles !== 'undefined') {
    sectionTitles.chats = ['Chats', '· conversaciones'];
  }

  // ══════════════════════════════════════════════════════════
  //  MENSAJES DE CONTACTO
  // ══════════════════════════════════════════════════════════
  const TIPO_MENSAJE_LABEL = {
    sugerencia: 'Sugerencia',
    queja: 'Queja',
    error: 'Error',
    otro: 'Otro',
  };

  window.loadMensajesContacto = async function loadMensajesContacto() {
    const tbody = document.getElementById('mensajes-tbody');
    if (!tbody) return;
    tbody.innerHTML =
      '<tr><td colspan="6"><div class="loader"><div class="spinner"></div><p>Cargando…</p></div></td></tr>';
    try {
      const res = await api('GET', ENDPOINTS.mensajesContacto());
      data.mensajes = Array.isArray(res) ? res : [];
      const noLeidos = data.mensajes.filter((m) => !m.leido_mensajecontacto).length;
      const badge = document.getElementById('badge-mensajes');
      if (badge) {
        if (noLeidos > 0) {
          badge.style.display = '';
          badge.textContent = noLeidos;
        } else {
          badge.style.display = 'none';
        }
      }
      filterMensajesContacto();
    } catch (e) {
      tbody.innerHTML = '<tr><td colspan="6"><div class="empty"><p>' + esc(e.message) + '</p></div></td></tr>';
    }
  };

  window.filterMensajesContacto = function filterMensajesContacto() {
    const q = (document.getElementById('mensajes-search')?.value || '').toLowerCase();
    const tipo = document.getElementById('mensajes-tipo')?.value || '';
    const estado = document.getElementById('mensajes-estado')?.value || '';
    filtered.mensajes = data.mensajes.filter((m) => {
      const nombre = (m.nombre_mensajecontacto || '').toLowerCase();
      const email = (m.email_mensajecontacto || '').toLowerCase();
      const cuerpo = (m.cuerpo_mensajecontacto || '').toLowerCase();
      const matchQ = !q || nombre.includes(q) || email.includes(q) || cuerpo.includes(q);
      const matchTipo = !tipo || m.tipo_mensajecontacto === tipo;
      let matchEstado = true;
      if (estado === 'no-leidos') matchEstado = !m.leido_mensajecontacto;
      if (estado === 'leidos') matchEstado = !!m.leido_mensajecontacto;
      return matchQ && matchTipo && matchEstado;
    });
    pages.mensajes = 1;
    renderMensajesContacto();
  };

  window.renderMensajesContacto = function renderMensajesContacto() {
    const tbody = document.getElementById('mensajes-tbody');
    if (!tbody) return;
    const items = renderPagination('mensajes', 'mensajes', renderMensajesContacto);
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="6"><div class="empty"><p>No se encontraron mensajes</p></div></td></tr>';
      return;
    }
    tbody.innerHTML = items
      .map((m) => {
        const id = m.id_mensajecontacto;
        const leido = m.leido_mensajecontacto === true;
        const tipoLabel = TIPO_MENSAJE_LABEL[m.tipo_mensajecontacto] || m.tipo_mensajecontacto || '—';
        const accion = leido
          ? `<button class="btn btn-ghost btn-sm" onclick="marcarLeidoMensaje(${id},false)">Marcar no leído</button>`
          : `<button class="btn btn-green btn-sm" onclick="marcarLeidoMensaje(${id},true)">Marcar leído</button>`;
        return (
          '<tr' + (leido ? '' : ' style="background:rgba(59,130,246,0.06);"') + '>' +
          '<td>' + esc(m.nombre_mensajecontacto || '—') + '</td>' +
          '<td class="mono">' + esc(m.email_mensajecontacto || '—') + '</td>' +
          '<td>' + statusBadge(tipoLabel) + '</td>' +
          '<td style="max-width:280px;">' + esc(truncate(m.cuerpo_mensajecontacto || '', 90)) + '</td>' +
          '<td class="mono">' + fmtDateTime(m.creadoen_mensajecontacto) + '</td>' +
          '<td>' + accion + '</td>' +
          '</tr>'
        );
      })
      .join('');
  };

  window.mensajesPag = (d) => {
    pages.mensajes = Math.max(1, pages.mensajes + d);
    renderMensajesContacto();
  };

  window.marcarLeidoMensaje = async function marcarLeidoMensaje(id, leido) {
    try {
      await api('PUT', ENDPOINTS.mensajeContactoItem(id), { leido });
      toast(leido ? 'Marcado como leído' : 'Marcado como no leído', 'ok');
      loadMensajesContacto();
    } catch (e) {
      toast(e.message, 'err');
    }
  };

  console.info('[SteamMatch Admin] Panel conectado al backend (extendido).');

  // El primer render del dashboard (cuando ya había una sesión guardada)
  // pasaba ANTES de que este script terminara de cargar, así que usaba
  // las versiones viejas/incompletas de loadDashboard/nav definidas en
  // index.html (con bugs reales: "Familias formadas" mostraba el total
  // de publicaciones, y varias tarjetas del dashboard se quedaban en
  // "—" para siempre). El trigger inicial se movió a este punto -- para
  // entonces `window.nav`/`window.loadDashboard` ya son las versiones
  // parcheadas correctas.
  if (typeof token !== 'undefined' && token) {
    window.nav('dashboard');
  }
})();
