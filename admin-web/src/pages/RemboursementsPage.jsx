import { useState, useEffect } from 'react';
import { getRemboursements, marquerRembourse } from '../services/api';
import { RefreshCw, Undo2 } from 'lucide-react';

// Paiements Mobile Money de clients à rembourser à la main (course payée puis
// annulée), tant que le prestataire de paiement n'a pas de remboursement par API.
export default function RemboursementsPage() {
  const [items, setItems] = useState([]);
  const [inclureTraites, setInclureTraites] = useState(false);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState({});
  const [error, setError] = useState(null);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [inclureTraites]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setItems(await getRemboursements(inclureTraites));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleEffectue = async (r) => {
    const montant = Math.round(r.montant).toLocaleString('fr-FR');
    if (!confirm(`Confirmer que ${montant} GNF ont bien été remboursés à ${r.client_nom} (${r.client_telephone}) ?`)) return;
    setProcessing((p) => ({ ...p, [r.course_id]: true }));
    try {
      await marquerRembourse(r.course_id);
      await load();
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    } finally {
      setProcessing((p) => ({ ...p, [r.course_id]: false }));
    }
  };

  const formatDate = (d) =>
    d
      ? new Date(d).toLocaleDateString('fr-FR', {
          day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
        })
      : '—';

  return (
    <div>
      <div className="mb-6 flex items-center justify-between gap-3 flex-wrap">
        <p className="text-[13px] text-gray-500">
          Clients ayant payé par Mobile Money une course ensuite annulée
        </p>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-[12px] text-gray-500">
            <input
              type="checkbox"
              checked={inclureTraites}
              onChange={(e) => setInclureTraites(e.target.checked)}
            />
            Afficher les remboursements déjà faits
          </label>
          <button
            onClick={load}
            className="flex items-center gap-1.5 px-3.5 py-1.5 bg-gray-900 text-white text-[12px] font-medium rounded-lg hover:bg-gray-800 transition-colors"
          >
            <RefreshCw size={13} />
            Rafraîchir
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-xl text-[13px] text-red-600">
          {error}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200/60 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-7 w-7 border-2 border-gray-300 border-t-gray-900" />
          </div>
        ) : items.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-3">
              <Undo2 size={20} className="text-gray-400" />
            </div>
            <p className="text-[14px] font-medium text-gray-900">Aucun remboursement en attente</p>
            <p className="text-[13px] text-gray-400 mt-1">Tous les clients ont été remboursés.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  <th className="px-5 py-3.5">Course</th>
                  <th className="px-5 py-3.5">Client</th>
                  <th className="px-5 py-3.5">Montant</th>
                  <th className="px-5 py-3.5">Référence paiement</th>
                  <th className="px-5 py-3.5">Annulée le</th>
                  <th className="px-5 py-3.5">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {items.map((r) => (
                  <tr key={r.course_id} className="hover:bg-gray-50/40 transition-colors">
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] font-medium text-gray-900">{r.numero_course}</p>
                      <p className="text-[12px] text-gray-400 max-w-[220px] truncate">{r.raison_annulation || '—'}</p>
                    </td>
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] text-gray-900">{r.client_nom}</p>
                      <p className="text-[12px] text-gray-500">{r.client_telephone}</p>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="text-[14px] font-semibold text-gray-900">
                        {Math.round(r.montant).toLocaleString('fr-FR')} GNF
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-[12px] text-gray-500 font-mono">{r.geniuspay_reference || '—'}</td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-400">{formatDate(r.annulee_at)}</td>
                    <td className="px-5 py-3.5">
                      {r.rembourse_at ? (
                        <span className="text-[12px] text-emerald-600">Remboursé le {formatDate(r.rembourse_at)}</span>
                      ) : (
                        <button
                          onClick={() => handleEffectue(r)}
                          disabled={!!processing[r.course_id]}
                          className="px-3 py-1 bg-emerald-500 text-white text-[12px] font-medium rounded-lg hover:bg-emerald-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {processing[r.course_id] ? '…' : 'Marquer remboursé'}
                        </button>
                      )}
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
