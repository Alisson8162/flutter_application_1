// Painel administrativo - JS puro (sem build step), fala diretamente com a
// API /api/admin/* no mesmo host que serve este arquivo.
//
// IMPORTANTE: nenhum endpoint novo foi criado. Este arquivo consome
// exatamente as mesmas rotas que já existiam (/login, /stats,
// /professionals/pending, /professionals/:id/approve|reject,
// /documents/:id/approve|reject, /rides/recent). A aba "Documentos" é
// derivada em memória a partir da lista de profissionais pendentes (que já
// traz os documentos de cada um), sem chamada extra ao backend.

const API_BASE = '/api/admin';

const state = {
  token: localStorage.getItem('admin_token') || null,
  admin: JSON.parse(localStorage.getItem('admin_data') || 'null'),
  pending: [],
  rides: [],
  coupons: [],
  docsFilter: 'pending',
};

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

function showScreen(id) {
  $$('.screen').forEach((el) => (el.style.display = 'none'));
  $(id).style.display = '';
}

async function api(path, options = {}) {
  const res = await fetch(API_BASE + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}),
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({ success: false, message: 'Resposta inválida' }));
  if (res.status === 401 && path !== '/login') {
    // Sessão inválida/expirada: volta ao login MAS mostra o motivo, em vez
    // de "piscar" a tela sem explicação.
    logout();
    $('#login-error').textContent = data.message || 'Sessão expirada. Entre novamente.';
  }
  return data;
}

function logout() {
  state.token = null;
  state.admin = null;
  localStorage.removeItem('admin_token');
  localStorage.removeItem('admin_data');
  showScreen('#login-screen');
}

// ===================== TOASTS =====================
function toast(message, type = 'success') {
  const stack = $('#toast-stack');
  const el = document.createElement('div');
  el.className = `toast${type === 'error' ? ' error' : ''}`;
  el.textContent = message;
  stack.appendChild(el);
  setTimeout(() => el.remove(), 3200);
}

// ===================== CONFIRM MODAL (substitui confirm()/prompt()) =====================
function askConfirm({ title, message, withInput = false, placeholder = '', confirmLabel = 'Confirmar', danger = false }) {
  return new Promise((resolve) => {
    const modal = $('#confirm-modal');
    $('#confirm-title').textContent = title;
    $('#confirm-message').textContent = message;
    const inputWrap = $('#confirm-input-wrap');
    const input = $('#confirm-input');
    inputWrap.hidden = !withInput;
    input.value = '';
    input.placeholder = placeholder;
    const okBtn = $('#confirm-ok');
    okBtn.textContent = confirmLabel;
    okBtn.className = danger ? 'btn-primary' : 'btn-primary';
    okBtn.style.background = danger ? 'var(--red)' : '';
    okBtn.style.color = danger ? '#2a0d0d' : '';

    modal.style.display = 'flex';

    function cleanup(result) {
      modal.style.display = 'none';
      okBtn.removeEventListener('click', onOk);
      $('#confirm-cancel').removeEventListener('click', onCancel);
      modal.querySelector('.modal-backdrop').removeEventListener('click', onCancel);
      resolve(result);
    }
    function onOk() { cleanup(withInput ? { ok: true, value: input.value } : { ok: true }); }
    function onCancel() { cleanup({ ok: false }); }

    okBtn.addEventListener('click', onOk);
    $('#confirm-cancel').addEventListener('click', onCancel);
    modal.querySelector('.modal-backdrop').addEventListener('click', onCancel);
  });
}

// ===================== LOGIN =====================
$('#login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = $('#login-email').value.trim();
  const password = $('#login-password').value;
  $('#login-error').textContent = '';

  const submitBtn = $('#login-submit');
  submitBtn.disabled = true;
  submitBtn.querySelector('.btn-label').style.opacity = '0';
  submitBtn.querySelector('.spinner').hidden = false;

  let result;
  try {
    result = await api('/login', { method: 'POST', body: JSON.stringify({ email, password }) });
  } catch (err) {
    result = { success: false, message: 'Não foi possível conectar ao servidor.' };
  }

  submitBtn.disabled = false;
  submitBtn.querySelector('.btn-label').style.opacity = '1';
  submitBtn.querySelector('.spinner').hidden = true;

  if (result.success) {
    state.token = result.token;
    state.admin = result.admin || null;
    localStorage.setItem('admin_token', result.token);
    localStorage.setItem('admin_data', JSON.stringify(state.admin));
    try {
      boot();
    } catch (err) {
      console.error('Erro ao abrir o painel:', err);
      $('#login-error').textContent = 'Erro ao abrir o painel: ' + err.message;
      showScreen('#login-screen');
    }
  } else {
    $('#login-error').textContent = result.message || 'Erro ao entrar';
  }
});

$('#logout-btn').addEventListener('click', logout);

// ===================== NAV / TABS =====================
const TAB_TITLES = {
  dashboard: 'Dashboard',
  pending: 'Profissionais',
  docs: 'Documentos',
  rides: 'Corridas',
  coupons: 'Cupons',
};

function goToTab(tab) {
  $$('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  $$('.tab-content').forEach((c) => (c.style.display = 'none'));
  $('#tab-' + tab).style.display = '';
  $('#page-title').textContent = TAB_TITLES[tab] || '';
  closeSidebar();
  if (tab === 'coupons' && state.coupons.length === 0) loadCoupons();
}

$$('.nav-item').forEach((btn) => btn.addEventListener('click', () => goToTab(btn.dataset.tab)));
$$('[data-goto]').forEach((btn) => btn.addEventListener('click', () => goToTab(btn.dataset.goto)));

// mobile sidebar
function openSidebar() {
  $('#sidebar').classList.add('open');
  $('#sidebar-backdrop').classList.add('show');
}
function closeSidebar() {
  $('#sidebar').classList.remove('open');
  $('#sidebar-backdrop').classList.remove('show');
}
$('#menu-toggle').addEventListener('click', openSidebar);
$('#sidebar-backdrop').addEventListener('click', closeSidebar);

$('#refresh-btn').addEventListener('click', () => loadAll(true));

// ===================== IMAGE MODAL =====================
function openImage(url) {
  $('#modal-image').src = url;
  $('#image-modal').style.display = 'flex';
}
$('#image-modal').addEventListener('click', (e) => {
  if (e.target.id === 'image-modal' || e.target.classList.contains('modal-backdrop') || e.target.id === 'modal-close') {
    $('#image-modal').style.display = 'none';
  }
});

// ===================== LABELS =====================
const DOC_LABELS = {
  documento_profissional: 'Documento profissional',
  foto_usuario: 'Foto de perfil',
  documento_frente: 'Documento (frente)',
  documento_verso: 'Documento (verso)',
  selfie: 'Selfie (foto de perfil)',
  certificado: 'Certificado / diploma do curso',
  carteira_trabalho: 'Carteira de trabalho (registro na função)',
  foto_veiculo: 'Foto do veículo',
};

// Documentos que TODO profissional precisa ter aprovados antes de liberar o
// cadastro - usado só para destacar visualmente o que ainda falta.
const REQUIRED_DOC_TYPES = ['selfie', 'certificado', 'carteira_trabalho', 'foto_veiculo'];

function docBadge(doc) {
  if (doc.aprovado) return '<span class="doc-badge badge-approved">Aprovado</span>';
  if (doc.rejeitado) return '<span class="doc-badge badge-rejected">Rejeitado</span>';
  return '<span class="doc-badge badge-pending">Pendente</span>';
}

function docStatus(doc) {
  if (doc.aprovado) return 'approved';
  if (doc.rejeitado) return 'rejected';
  return 'pending';
}

function subscriptionBadge(prof) {
  const status = prof.subscription_status;
  if (status === 'active') return '<span class="doc-badge badge-approved">Mensalidade em dia</span>';
  if (status === 'past_due') return '<span class="doc-badge badge-rejected">Mensalidade atrasada</span>';
  if (status === 'canceled') return '<span class="doc-badge badge-rejected">Assinatura cancelada</span>';
  return '<span class="doc-badge badge-pending">Sem assinatura ativa</span>';
}

function formatMoney(v) {
  const n = Number(v);
  return Number.isFinite(n) ? `R$ ${n.toFixed(2).replace('.', ',')}` : '—';
}

function initials(name) {
  if (!name) return 'A';
  return name.trim().split(/\s+/).slice(0, 2).map((p) => p[0]).join('').toUpperCase();
}

function timeAgo(dateStr) {
  const d = new Date(dateStr);
  const diffMs = Date.now() - d.getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'agora mesmo';
  if (mins < 60) return `há ${mins} min`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `há ${hours}h`;
  const days = Math.floor(hours / 24);
  return `há ${days}d`;
}

// ===================== RENDER: PENDING PROFESSIONALS =====================
function renderPending(professionals, container, { compact = false } = {}) {
  if (!professionals.length) {
    container.innerHTML = '<div class="empty-state">Nenhum profissional aguardando aprovação 🎉</div>';
    return;
  }

  container.innerHTML = professionals
    .map((prof) => {
      const docsHtml = compact
        ? ''
        : (prof.documents || [])
            .map(
              (doc) => `
        <div class="doc-item">
          <img class="doc-thumb" src="${doc.url}" alt="${doc.tipo}" data-open-image="${doc.url}" />
          <span>${DOC_LABELS[doc.tipo] || doc.tipo}</span>
          ${docBadge(doc)}
          ${
            !doc.aprovado
              ? `<div class="actions" style="margin-top:2px">
                   <button class="btn-approve" data-doc-approve="${doc.id}">Aprovar</button>
                   <button class="btn-reject" data-doc-reject="${doc.id}">Rejeitar</button>
                 </div>`
              : ''
          }
        </div>`
            )
            .join('');

      const missingDocs = REQUIRED_DOC_TYPES.filter(
        (type) => !(prof.documents || []).some((d) => d.tipo === type)
      );

      return `
      <div class="card" data-prof-card="${prof.id}">
        <div class="card-header">
          <div>
            <div class="card-title">${prof.name}</div>
            <div class="card-sub">${prof.especialidade || '—'} · ${prof.tipo_veiculo_atendido || '—'} · ${prof.email || prof.phone || ''}</div>
            <div class="card-sub">CPF: ${prof.cpf || '—'} · Cobra ${formatMoney(prof.valor_base)} + ${formatMoney(prof.valor_km)}/km</div>
            ${!compact ? `<div style="margin-top:6px">${subscriptionBadge(prof)}</div>` : ''}
          </div>
          <span class="doc-badge badge-pending">${(prof.documents || []).length} doc(s)</span>
        </div>
        ${
          !compact && missingDocs.length
            ? `<div class="card-sub" style="color:#f87171;margin-bottom:8px">Faltando: ${missingDocs.map((t) => DOC_LABELS[t]).join(', ')}</div>`
            : ''
        }
        ${!compact ? `<div class="docs-grid">${docsHtml || '<span style="color:var(--text-faint)">Nenhum documento enviado ainda</span>'}</div>` : ''}
        ${
          !compact
            ? `<div class="actions">
                 <button class="btn-approve" data-prof-approve="${prof.id}">Aprovar profissional</button>
                 <button class="btn-reject" data-prof-reject="${prof.id}">Reprovar</button>
               </div>`
            : ''
        }
      </div>`;
    })
    .join('');

  bindListActions(container);
}

function bindListActions(container) {
  $$('[data-open-image]', container).forEach((img) =>
    img.addEventListener('click', () => openImage(img.dataset.openImage))
  );

  $$('[data-doc-approve]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const result = await api(`/documents/${btn.dataset.docApprove}/approve`, { method: 'POST' });
      if (result.success) toast('Documento aprovado.');
      else toast(result.message || 'Erro ao aprovar documento', 'error');
      loadPending();
    })
  );

  $$('[data-doc-reject]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const { ok, value } = await askConfirm({
        title: 'Rejeitar documento',
        message: 'Informe o motivo da rejeição (opcional). O profissional será notificado.',
        withInput: true,
        placeholder: 'Ex.: foto ilegível',
        confirmLabel: 'Rejeitar',
        danger: true,
      });
      if (!ok) return;
      const result = await api(`/documents/${btn.dataset.docReject}/reject`, {
        method: 'POST',
        body: JSON.stringify({ motivo: value || '' }),
      });
      if (result.success) toast('Documento rejeitado.');
      else toast(result.message || 'Erro ao rejeitar documento', 'error');
      loadPending();
    })
  );

  $$('[data-prof-approve]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const { ok } = await askConfirm({
        title: 'Aprovar profissional',
        message: 'Ele passará a ficar disponível para atender clientes. Deseja continuar?',
        confirmLabel: 'Aprovar',
      });
      if (!ok) return;
      const result = await api(`/professionals/${btn.dataset.profApprove}/approve`, { method: 'POST' });
      if (result.success) toast('Profissional aprovado com sucesso.');
      else toast(result.message || 'Erro ao aprovar profissional', 'error');
      loadPending();
      loadStats();
    })
  );

  $$('[data-prof-reject]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const { ok } = await askConfirm({
        title: 'Reprovar profissional',
        message: 'Ele será bloqueado e ficará indisponível para atender. Deseja continuar?',
        confirmLabel: 'Reprovar',
        danger: true,
      });
      if (!ok) return;
      const result = await api(`/professionals/${btn.dataset.profReject}/reject`, { method: 'POST' });
      if (result.success) toast('Profissional reprovado.');
      else toast(result.message || 'Erro ao reprovar profissional', 'error');
      loadPending();
      loadStats();
    })
  );
}

// ===================== RENDER: DOCUMENTS TAB =====================
function flattenDocs(professionals) {
  const rows = [];
  professionals.forEach((prof) => {
    (prof.documents || []).forEach((doc) => {
      rows.push({ ...doc, profName: prof.name, profId: prof.id, especialidade: prof.especialidade });
    });
  });
  return rows;
}

function renderDocs() {
  const container = $('#docs-grid');
  const search = $('#search-docs').value.trim().toLowerCase();
  let rows = flattenDocs(state.pending);

  if (state.docsFilter !== 'all') {
    rows = rows.filter((d) => docStatus(d) === state.docsFilter);
  }
  if (search) {
    rows = rows.filter(
      (d) =>
        d.profName.toLowerCase().includes(search) ||
        (DOC_LABELS[d.tipo] || d.tipo).toLowerCase().includes(search)
    );
  }

  if (!rows.length) {
    container.innerHTML = '<div class="empty-state">Nenhum documento encontrado para este filtro.</div>';
    return;
  }

  container.innerHTML = rows
    .map(
      (doc) => `
    <div class="doc-card">
      <img class="doc-card-img" src="${doc.url}" alt="${doc.tipo}" data-open-image="${doc.url}" />
      <div class="doc-card-body">
        <span class="doc-card-title">${doc.profName}</span>
        <span class="doc-card-sub">${DOC_LABELS[doc.tipo] || doc.tipo}</span>
        ${docBadge(doc)}
        ${
          !doc.aprovado
            ? `<div class="doc-card-actions">
                 <button class="btn-approve" data-doc-approve="${doc.id}">Aprovar</button>
                 <button class="btn-reject" data-doc-reject="${doc.id}">Rejeitar</button>
               </div>`
            : ''
        }
      </div>
    </div>`
    )
    .join('');

  bindListActions(container);
}

$$('.segmented-btn', $('#docs-filter')).forEach((btn) =>
  btn.addEventListener('click', () => {
    $$('.segmented-btn', $('#docs-filter')).forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    state.docsFilter = btn.dataset.filter;
    renderDocs();
  })
);
$('#search-docs').addEventListener('input', renderDocs);

// ===================== RENDER: RIDES =====================
function statusPillClass(status) {
  return `status-pill status-${(status || '').toLowerCase()}`;
}

function renderRides(rides, container, { compact = false } = {}) {
  if (!rides.length) {
    container.innerHTML = '<div class="empty-state">Nenhuma corrida registrada ainda</div>';
    return;
  }

  if (compact) {
    container.innerHTML = rides
      .slice(0, 5)
      .map(
        (r) => `
      <div class="card">
        <div class="card-header" style="margin-bottom:0">
          <div>
            <div class="card-title" style="font-size:14px">${r.client_name} → ${r.driver_name || 'sem profissional'}</div>
            <div class="card-sub">${timeAgo(r.created_at)} · R$ ${Number(r.final_price ?? r.estimated_price ?? 0).toFixed(2)}</div>
          </div>
          <span class="${statusPillClass(r.status)}">${r.status}</span>
        </div>
      </div>`
      )
      .join('');
    return;
  }

  container.innerHTML = `
    <table>
      <thead>
        <tr><th>Cliente</th><th>Profissional</th><th>Status</th><th>Pagamento</th><th>Valor</th><th>Criada em</th><th>Ações</th></tr>
      </thead>
      <tbody>
        ${rides
          .map(
            (r) => `
          <tr>
            <td>${r.client_name}</td>
            <td>${r.driver_name || '—'}</td>
            <td><span class="${statusPillClass(r.status)}">${r.status}</span></td>
            <td>${r.payment_status || '—'}</td>
            <td>R$ ${Number(r.final_price ?? r.estimated_price ?? 0).toFixed(2)}</td>
            <td>${new Date(r.created_at).toLocaleString('pt-BR')}</td>
            <td>
              ${
                r.payment_status === 'paid'
                  ? `<button class="btn-reject" data-refund-ride="${r.id}">Reembolsar</button>`
                  : '<span style="color:var(--text-faint)">—</span>'
              }
            </td>
          </tr>`
          )
          .join('')}
      </tbody>
    </table>`;

  $$('[data-refund-ride]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const { ok, value } = await askConfirm({
        title: 'Reembolsar corrida',
        message: 'Isso estorna o valor cobrado do cliente via Stripe. Informe o motivo (opcional).',
        withInput: true,
        placeholder: 'Ex.: serviço não prestado',
        confirmLabel: 'Reembolsar',
        danger: true,
      });
      if (!ok) return;

      const result = await api(`/rides/${btn.dataset.refundRide}/refund`, {
        method: 'POST',
        body: JSON.stringify({ reason: value || '' }),
      });

      if (result.success) toast('Reembolso processado com sucesso.');
      else toast(result.message || 'Erro ao processar reembolso', 'error');

      loadRides();
    })
  );
}

$('#search-rides').addEventListener('input', () => {
  const q = $('#search-rides').value.trim().toLowerCase();
  const filtered = !q
    ? state.rides
    : state.rides.filter(
        (r) =>
          (r.client_name || '').toLowerCase().includes(q) ||
          (r.driver_name || '').toLowerCase().includes(q) ||
          (r.status || '').toLowerCase().includes(q)
      );
  renderRides(filtered, $('#rides-list'));
});

$('#search-pending').addEventListener('input', () => {
  const q = $('#search-pending').value.trim().toLowerCase();
  const filtered = !q
    ? state.pending
    : state.pending.filter(
        (p) =>
          (p.name || '').toLowerCase().includes(q) ||
          (p.especialidade || '').toLowerCase().includes(q) ||
          (p.email || '').toLowerCase().includes(q)
      );
  renderPending(filtered, $('#pending-list'));
});

// ===================== DATA LOADING =====================
async function loadStats() {
  const result = await api('/stats');
  if (result.success) {
    $('#stat-pending-profs').textContent = result.data.profissionais_pendentes;
    $('#stat-pending-docs').textContent = result.data.documentos_pendentes;

    const pendingCount = result.data.profissionais_pendentes;
    const docsCount = result.data.documentos_pendentes;
    const navPending = $('#nav-count-pending');
    const navDocs = $('#nav-count-docs');
    navPending.hidden = !pendingCount;
    navPending.textContent = pendingCount;
    navDocs.hidden = !docsCount;
    navDocs.textContent = docsCount;
  }
}

async function loadPending() {
  const result = await api('/professionals/pending');
  if (result.success) {
    state.pending = result.data;
    renderPending(state.pending, $('#pending-list'));
    renderPending(state.pending, $('#dashboard-pending-preview'), { compact: true });
    renderDocs();
  }
}

async function loadRides() {
  const result = await api('/rides/recent');
  if (result.success) {
    state.rides = result.data;
    renderRides(state.rides, $('#rides-list'));
    renderRides(state.rides, $('#dashboard-rides-preview'), { compact: true });

    $('#stat-rides-total').textContent = state.rides.length;
    const completed = state.rides.filter((r) =>
      ['concluida', 'concluída', 'completed', 'finalizada'].includes((r.status || '').toLowerCase())
    ).length;
    $('#stat-rides-completed').textContent = completed;
  }
}

// ===================== CUPONS =====================
let couponType = 'percentage';

$$('.segmented-btn', $('#coupon-type')).forEach((btn) =>
  btn.addEventListener('click', () => {
    $$('.segmented-btn', $('#coupon-type')).forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    couponType = btn.dataset.type;
  })
);

$('#coupon-form').addEventListener('submit', async (e) => {
  e.preventDefault();

  const payload = {
    code: $('#coupon-code').value.trim().toUpperCase(),
    description: $('#coupon-description').value.trim() || undefined,
    discount_type: couponType,
    discount_value: Number($('#coupon-value').value),
    min_ride_value: $('#coupon-min-value').value ? Number($('#coupon-min-value').value) : undefined,
    max_uses: $('#coupon-max-uses').value ? Number($('#coupon-max-uses').value) : undefined,
    max_uses_per_client: $('#coupon-max-per-client').value ? Number($('#coupon-max-per-client').value) : undefined,
    valid_until: $('#coupon-valid-until').value || undefined,
  };

  if (!payload.code || !payload.discount_value) {
    toast('Preencha ao menos o código e o valor do desconto.', 'error');
    return;
  }

  const result = await api('/coupons', { method: 'POST', body: JSON.stringify(payload) });
  if (result.success) {
    toast('Cupom criado com sucesso.');
    $('#coupon-form').reset();
    loadCoupons();
  } else {
    toast(result.message || 'Erro ao criar cupom', 'error');
  }
});

async function loadCoupons() {
  const result = await api('/coupons');
  if (result.success) {
    state.coupons = result.data;
    renderCoupons();
  }
}

function renderCoupons() {
  const container = $('#coupons-list');
  if (!state.coupons.length) {
    container.innerHTML = '<div class="empty-state">Nenhum cupom criado ainda.</div>';
    return;
  }

  container.innerHTML = state.coupons
    .map((c) => {
      const valueLabel = c.discount_type === 'percentage' ? `${c.discount_value}%` : `R$ ${Number(c.discount_value).toFixed(2)}`;
      const usesLabel = c.max_uses != null ? `${c.uses_count}/${c.max_uses} usos` : `${c.uses_count} usos`;
      return `
      <div class="card">
        <div class="card-header">
          <div>
            <div class="card-title">${c.code} <span class="doc-badge ${c.active ? 'badge-approved' : 'badge-rejected'}">${c.active ? 'Ativo' : 'Inativo'}</span></div>
            <div class="card-sub">${c.description || 'Sem descrição'} · Desconto de ${valueLabel} · ${usesLabel}${c.valid_until ? ' · válido até ' + new Date(c.valid_until).toLocaleDateString('pt-BR') : ''}</div>
          </div>
        </div>
        <div class="actions">
          <button class="${c.active ? 'btn-reject' : 'btn-approve'}" data-toggle-coupon="${c.id}" data-active="${c.active}">
            ${c.active ? 'Desativar' : 'Ativar'}
          </button>
        </div>
      </div>`;
    })
    .join('');

  $$('[data-toggle-coupon]', container).forEach((btn) =>
    btn.addEventListener('click', async () => {
      const active = btn.dataset.active !== 'true';
      const result = await api(`/coupons/${btn.dataset.toggleCoupon}/active`, {
        method: 'PUT',
        body: JSON.stringify({ active }),
      });
      if (result.success) {
        toast(active ? 'Cupom ativado.' : 'Cupom desativado.');
        loadCoupons();
      } else {
        toast(result.message || 'Erro ao atualizar cupom', 'error');
      }
    })
  );
}

async function loadAll(showToast = false) {
  await Promise.all([loadStats(), loadPending(), loadRides()]);
  if (showToast) toast('Painel atualizado.');
}

function paintAdminChip() {
  const name = state.admin?.name || state.admin?.nome || 'Administrador';
  const email = state.admin?.email || '';
  $('#admin-name').textContent = name;
  $('#admin-email').textContent = email;
  $('#admin-avatar').textContent = initials(name);
}

function boot() {
  showScreen('#app-screen');
  paintAdminChip();
  goToTab('dashboard');
  loadAll();
}

if (state.token) {
  boot();
} else {
  showScreen('#login-screen');
}
