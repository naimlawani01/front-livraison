import { useState, useEffect } from 'react';
import { getTousUsers, suspendreUser, supprimerUser } from '../services/api';
import { RefreshCw, Users, Trash2, Ban, CheckCircle } from 'lucide-react';

const ROLE_STYLES = {
  ADMIN: 'bg-purple-50 text-purple-700',
  LIVREUR: 'bg-blue-50 text-blue-700',
  EXPEDITEUR: 'bg-orange-50 text-orange-700',
};

const ROLE_LABELS = {
  ADMIN: 'Admin',
  LIVREUR: 'Livreur',
  EXPEDITEUR: 'Expéditeur',
};

const ROLE_FILTERS = ['Tous', 'LIVREUR', 'EXPEDITEUR', 'ADMIN'];

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('Tous');
  const [processing, setProcessing] = useState({});
  const [confirmDelete, setConfirmDelete] = useState(null); // user object to confirm
  const [error, setError] = useState(null);

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getTousUsers();
      setUsers(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSuspendre = async (user) => {
    setProcessing((p) => ({ ...p, [user.id]: 'suspend' }));
    try {
      const res = await suspendreUser(user.id);
      setUsers((prev) =>
        prev.map((u) => (u.id === user.id ? { ...u, is_active: res.is_active } : u))
      );
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    } finally {
      setProcessing((p) => ({ ...p, [user.id]: null }));
    }
  };

  const handleDelete = async () => {
    if (!confirmDelete) return;
    const { id } = confirmDelete;
    setConfirmDelete(null);
    setProcessing((p) => ({ ...p, [id]: 'delete' }));
    try {
      await supprimerUser(id);
      setUsers((prev) => prev.filter((u) => u.id !== id));
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    } finally {
      setProcessing((p) => ({ ...p, [id]: null }));
    }
  };

  const filteredUsers = filter === 'Tous' ? users : users.filter((u) => u.role === filter);

  const counts = users.reduce((acc, u) => {
    acc[u.role] = (acc[u.role] || 0) + 1;
    return acc;
  }, {});

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-7 w-7 border-2 border-gray-300 border-t-gray-900" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <p className="text-[13px] text-gray-500">
          {users.length} utilisateur{users.length !== 1 ? 's' : ''} au total
        </p>
        <button
          onClick={loadUsers}
          className="flex items-center gap-1.5 px-3.5 py-1.5 bg-gray-900 text-white text-[12px] font-medium rounded-lg hover:bg-gray-800 transition-colors"
        >
          <RefreshCw size={13} />
          Rafraîchir
        </button>
      </div>

      {error && (
        <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-xl text-[13px] text-red-600">
          {error}
        </div>
      )}

      {/* Filtres */}
      <div className="flex gap-2 mb-5 flex-wrap">
        {ROLE_FILTERS.map((r) => {
          const count = r === 'Tous' ? users.length : counts[r] || 0;
          return (
            <button
              key={r}
              onClick={() => setFilter(r)}
              className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-[12px] font-medium transition-all border ${
                filter === r
                  ? 'bg-gray-900 text-white border-gray-900'
                  : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300 hover:text-gray-700'
              }`}
            >
              {r === 'Tous' ? 'Tous' : ROLE_LABELS[r]}
              <span className={`text-[11px] ${filter === r ? 'text-white/60' : 'text-gray-400'}`}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Tableau */}
      <div className="bg-white rounded-xl border border-gray-200/60 overflow-hidden">
        {filteredUsers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-3">
              <Users size={20} className="text-gray-400" />
            </div>
            <p className="text-[14px] font-medium text-gray-900">Aucun utilisateur</p>
            <p className="text-[13px] text-gray-400 mt-1">
              {filter !== 'Tous' ? `Aucun ${ROLE_LABELS[filter].toLowerCase()} trouvé.` : ''}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  <th className="px-5 py-3.5">Téléphone</th>
                  <th className="px-5 py-3.5">Nom</th>
                  <th className="px-5 py-3.5">Rôle</th>
                  <th className="px-5 py-3.5">Statut</th>
                  <th className="px-5 py-3.5">Inscrit le</th>
                  <th className="px-5 py-3.5">Dernière connexion</th>
                  <th className="px-5 py-3.5">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredUsers.map((u) => {
                  const isAdmin = u.role === 'ADMIN';
                  const busy = !!processing[u.id];
                  return (
                    <tr key={u.id} className={`hover:bg-gray-50/40 transition-colors ${!u.is_active ? 'opacity-50' : ''}`}>
                      <td className="px-5 py-3.5">
                        <span className="text-[13px] font-medium text-gray-900">{u.phone}</span>
                      </td>
                      <td className="px-5 py-3.5 text-[13px] text-gray-600">
                        {u.nom || <span className="text-gray-300">—</span>}
                      </td>
                      <td className="px-5 py-3.5">
                        <span className={`inline-flex px-2 py-0.5 rounded-md text-[11px] font-medium ${ROLE_STYLES[u.role] || 'bg-gray-100 text-gray-500'}`}>
                          {ROLE_LABELS[u.role] || u.role}
                        </span>
                      </td>
                      <td className="px-5 py-3.5">
                        {u.is_active ? (
                          <span className="inline-flex items-center gap-1 text-[12px] text-emerald-600">
                            <CheckCircle size={12} /> Actif
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[12px] text-red-500">
                            <Ban size={12} /> Suspendu
                          </span>
                        )}
                      </td>
                      <td className="px-5 py-3.5 text-[13px] text-gray-400">
                        {new Date(u.created_at).toLocaleDateString('fr-FR', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </td>
                      <td className="px-5 py-3.5 text-[13px] text-gray-400">
                        {u.last_login
                          ? new Date(u.last_login).toLocaleDateString('fr-FR', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric',
                              hour: '2-digit',
                              minute: '2-digit',
                            })
                          : '—'}
                      </td>
                      <td className="px-5 py-3.5">
                        {isAdmin ? (
                          <span className="text-[12px] text-gray-300">—</span>
                        ) : (
                          <div className="flex items-center gap-2">
                            <button
                              onClick={() => handleSuspendre(u)}
                              disabled={busy}
                              className={`px-2.5 py-1 rounded-lg text-[12px] font-medium transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${
                                u.is_active
                                  ? 'bg-amber-50 text-amber-600 hover:bg-amber-100'
                                  : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-100'
                              }`}
                            >
                              {processing[u.id] === 'suspend' ? '…' : u.is_active ? 'Suspendre' : 'Réactiver'}
                            </button>
                            <button
                              onClick={() => setConfirmDelete(u)}
                              disabled={busy}
                              className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                              title="Supprimer définitivement"
                            >
                              {processing[u.id] === 'delete' ? (
                                <div className="w-3.5 h-3.5 border border-gray-400 border-t-transparent rounded-full animate-spin" />
                              ) : (
                                <Trash2 size={14} />
                              )}
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal de confirmation de suppression */}
      {confirmDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-sm mx-4">
            <div className="w-10 h-10 bg-red-50 rounded-full flex items-center justify-center mb-4">
              <Trash2 size={18} className="text-red-500" />
            </div>
            <h3 className="text-[15px] font-semibold text-gray-900 mb-1">
              Supprimer cet utilisateur ?
            </h3>
            <p className="text-[13px] text-gray-500 mb-1">
              <span className="font-medium text-gray-700">{confirmDelete.phone}</span>
              {confirmDelete.nom && ` · ${confirmDelete.nom}`}
            </p>
            <p className="text-[12px] text-red-500 mb-5">
              Cette action est irréversible. Le profil associé sera également supprimé.
            </p>
            <div className="flex gap-2">
              <button
                onClick={() => setConfirmDelete(null)}
                className="flex-1 px-4 py-2 border border-gray-200 rounded-xl text-[13px] font-medium text-gray-600 hover:bg-gray-50 transition-colors"
              >
                Annuler
              </button>
              <button
                onClick={handleDelete}
                className="flex-1 px-4 py-2 bg-red-500 text-white rounded-xl text-[13px] font-medium hover:bg-red-600 transition-colors"
              >
                Supprimer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
