const BASE_URL = import.meta.env.VITE_API_URL || 'https://api.sonaiyaa.fr/api/v1';

function getHeaders() {
  const token = localStorage.getItem('token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

let isRefreshing = false;

async function tryRefreshToken() {
  if (isRefreshing) return false;
  isRefreshing = true;
  try {
    const refreshToken = localStorage.getItem('refresh_token');
    if (!refreshToken) return false;
    const res = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    if (res.ok) {
      const data = await res.json();
      localStorage.setItem('token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      return true;
    }
    return false;
  } catch {
    return false;
  } finally {
    isRefreshing = false;
  }
}

async function authFetch(url, options = {}) {
  options.headers = getHeaders();
  let res = await fetch(url, options);
  if (res.status === 401) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      options.headers = getHeaders();
      res = await fetch(url, options);
    }
  }
  return res;
}

async function handleResponse(response) {
  if (!response.ok) {
    if (response.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
      window.location.href = '/login';
      throw new Error('Session expirée. Veuillez vous reconnecter.');
    }
    const data = await response.json().catch(() => ({}));
    throw new Error(data.detail || `Erreur ${response.status}`);
  }
  return response.json();
}

// Auth
// Double authentification admin : avec le bon mot de passe, le backend répond
// 401 `otp_required` et envoie un code SMS ; il faut rappeler avec `otpCode`.
// Ne PAS passer par handleResponse : son traitement du 401 (déconnexion +
// redirection) casserait ce flux.
export async function login(phone, password, otpCode = null) {
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, password, ...(otpCode ? { otp_code: otpCode } : {}) }),
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && data.detail === 'otp_required') {
    return { otp_required: true };
  }
  if (!res.ok) {
    throw new Error(data.detail || 'Identifiants incorrects');
  }
  return data;
}

// Admin stats
export async function getStats() {
  const res = await authFetch(`${BASE_URL}/admin/stats`);
  return handleResponse(res);
}

// Livreurs
export async function getLivreursEnAttente() {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/en-attente`);
  return handleResponse(res);
}

export async function validerLivreur(id) {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/${id}/valider`, { method: 'POST' });
  return handleResponse(res);
}

export async function suspendreLivreur(id) {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/${id}/suspendre`, { method: 'POST' });
  return handleResponse(res);
}

export async function getLivreurDetail(id) {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/${id}`);
  return handleResponse(res);
}

export async function rejeterLivreur(id) {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/${id}/rejeter`, { method: 'POST' });
  return handleResponse(res);
}

export async function getTousLivreurs() {
  const res = await authFetch(`${BASE_URL}/admin/livreurs/tous`);
  return handleResponse(res);
}

// Expediteurs
export async function getExpediteursEnAttente() {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/en-attente`);
  return handleResponse(res);
}

export async function getTousExpediteurs() {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/tous`);
  return handleResponse(res);
}

export async function getExpediteurDetail(id) {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/${id}`);
  return handleResponse(res);
}

export async function validerExpediteur(id) {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/${id}/valider`, { method: 'POST' });
  return handleResponse(res);
}

export async function suspendreExpediteur(id) {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/${id}/suspendre`, { method: 'POST' });
  return handleResponse(res);
}

export async function rejeterExpediteur(id) {
  const res = await authFetch(`${BASE_URL}/admin/expediteurs/${id}/rejeter`, { method: 'POST' });
  return handleResponse(res);
}

// Courses
export async function getCoursesRecentes(limit = 20) {
  const res = await authFetch(`${BASE_URL}/admin/courses/recentes?limit=${limit}`);
  return handleResponse(res);
}

// Retraits wallet
export async function getRetraits() {
  const res = await authFetch(`${BASE_URL}/admin/wallet/retraits`);
  return handleResponse(res);
}

export async function validerRetrait(id) {
  const res = await authFetch(`${BASE_URL}/admin/wallet/retraits/${id}/valider`, { method: 'POST' });
  return handleResponse(res);
}

export async function rejeterRetrait(id) {
  const res = await authFetch(`${BASE_URL}/admin/wallet/retraits/${id}/rejeter`, { method: 'POST' });
  return handleResponse(res);
}

// Utilisateurs
export async function getTousUsers(role = null) {
  const params = role ? `?role=${role}` : '';
  const res = await authFetch(`${BASE_URL}/admin/users${params}`);
  return handleResponse(res);
}

export async function suspendreUser(id) {
  const res = await authFetch(`${BASE_URL}/admin/users/${id}/suspendre`, { method: 'POST' });
  return handleResponse(res);
}

export async function supprimerUser(id) {
  const res = await authFetch(`${BASE_URL}/admin/users/${id}`, { method: 'DELETE' });
  return handleResponse(res);
}

// Remboursements clients (Mobile Money payé puis course annulée)
export async function getRemboursements(inclureTraites = false) {
  const res = await authFetch(`${BASE_URL}/admin/remboursements?inclure_traites=${inclureTraites}`);
  return handleResponse(res);
}

export async function marquerRembourse(courseId) {
  const res = await authFetch(`${BASE_URL}/admin/remboursements/${courseId}/effectue`, { method: 'POST' });
  return handleResponse(res);
}

// Anti-fraude : courses livrées loin de l'adresse déclarée
export async function getCoursesSuspectes(seuilKm = null) {
  const params = seuilKm != null ? `?seuil_km=${seuilKm}` : '';
  const res = await authFetch(`${BASE_URL}/admin/courses/suspectes${params}`);
  return handleResponse(res);
}

// Comptes test (Apple Reviewer + QA interne)
export async function listerComptesTest() {
  const res = await authFetch(`${BASE_URL}/admin/test-accounts`);
  return handleResponse(res);
}

export async function creerCompteTest(payload) {
  const res = await authFetch(`${BASE_URL}/admin/test-accounts`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return handleResponse(res);
}

export async function supprimerCompteTest(userId) {
  const res = await authFetch(`${BASE_URL}/admin/test-accounts/${userId}`, {
    method: 'DELETE',
  });
  return handleResponse(res);
}
