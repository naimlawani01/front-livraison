import { useState, useEffect } from 'react';
import { getRetraits, validerRetrait, rejeterRetrait } from '../services/api';
import { RefreshCw, Wallet } from 'lucide-react';

export default function RetraitsPage() {
  const [retraits, setRetraits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState({});
  const [error, setError] = useState(null);

  useEffect(() => {
    loadRetraits();
  }, []);

  const loadRetraits = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getRetraits();
      setRetraits(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleValider = async (id) => {
    setProcessing((p) => ({ ...p, [id]: 'valider' }));
    try {
      await validerRetrait(id);
      setRetraits((prev) => prev.filter((r) => r.id !== id));
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    } finally {
      setProcessing((p) => ({ ...p, [id]: null }));
    }
  };

  const handleRejeter = async (id) => {
    if (!confirm('Confirmer le rejet de ce retrait ?')) return;
    setProcessing((p) => ({ ...p, [id]: 'rejeter' }));
    try {
      await rejeterRetrait(id);
      setRetraits((prev) => prev.filter((r) => r.id !== id));
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    } finally {
      setProcessing((p) => ({ ...p, [id]: null }));
    }
  };

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
        <p className="text-[13px] text-gray-500">Demandes de retrait wallet en attente</p>
        <button
          onClick={loadRetraits}
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

      <div className="bg-white rounded-xl border border-gray-200/60 overflow-hidden">
        {retraits.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-3">
              <Wallet size={20} className="text-gray-400" />
            </div>
            <p className="text-[14px] font-medium text-gray-900">Aucun retrait en attente</p>
            <p className="text-[13px] text-gray-400 mt-1">Toutes les demandes ont été traitées.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  <th className="px-5 py-3.5">Livreur</th>
                  <th className="px-5 py-3.5">Téléphone</th>
                  <th className="px-5 py-3.5">Montant</th>
                  <th className="px-5 py-3.5">Description</th>
                  <th className="px-5 py-3.5">Date</th>
                  <th className="px-5 py-3.5">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {retraits.map((r) => (
                  <tr key={r.id} className="hover:bg-gray-50/40 transition-colors">
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] font-medium text-gray-900">{r.livreur_nom || '—'}</p>
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-600">
                      {r.livreur_phone || '—'}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="text-[14px] font-semibold text-gray-900">
                        {Math.round(r.montant).toLocaleString('fr-FR')} GNF
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-500 max-w-[200px] truncate">
                      {r.description || '—'}
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-400">
                      {new Date(r.created_at).toLocaleDateString('fr-FR', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleValider(r.id)}
                          disabled={!!processing[r.id]}
                          className="px-3 py-1 bg-emerald-500 text-white text-[12px] font-medium rounded-lg hover:bg-emerald-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {processing[r.id] === 'valider' ? '…' : 'Valider'}
                        </button>
                        <button
                          onClick={() => handleRejeter(r.id)}
                          disabled={!!processing[r.id]}
                          className="px-3 py-1 bg-red-50 text-red-600 text-[12px] font-medium rounded-lg hover:bg-red-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {processing[r.id] === 'rejeter' ? '…' : 'Rejeter'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
