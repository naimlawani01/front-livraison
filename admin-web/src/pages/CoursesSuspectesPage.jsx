import { useState, useEffect } from 'react';
import { getCoursesSuspectes } from '../services/api';
import { RefreshCw, AlertTriangle } from 'lucide-react';

// Anti-fraude : courses marquées livrées alors que le livreur était loin de
// l'adresse déclarée du client (fausse adresse pour payer moins, ou fausse
// livraison). Signal à vérifier, pas une preuve : le GPS peut être imprécis.
export default function CoursesSuspectesPage() {
  const [courses, setCourses] = useState([]);
  const [seuil, setSeuil] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setCourses(await getCoursesSuspectes(seuil === '' ? null : Number(seuil)));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="mb-6 flex items-center justify-between gap-3 flex-wrap">
        <p className="text-[13px] text-gray-500">
          Livraisons validées loin de l'adresse déclarée du client
        </p>
        <div className="flex items-center gap-2">
          <input
            type="number"
            min="0"
            step="0.5"
            value={seuil}
            onChange={(e) => setSeuil(e.target.value)}
            placeholder="Seuil km (défaut 1)"
            className="w-40 bg-white border border-gray-200 rounded-lg px-3 py-1.5 text-[12px]"
          />
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
        ) : courses.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-3">
              <AlertTriangle size={20} className="text-gray-400" />
            </div>
            <p className="text-[14px] font-medium text-gray-900">Aucune course suspecte</p>
            <p className="text-[13px] text-gray-400 mt-1">Toutes les livraisons correspondent à l'adresse déclarée.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  <th className="px-5 py-3.5">Course</th>
                  <th className="px-5 py-3.5">Écart</th>
                  <th className="px-5 py-3.5">Distance facturée</th>
                  <th className="px-5 py-3.5">Prix</th>
                  <th className="px-5 py-3.5">Livrée le</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {courses.map((c) => (
                  <tr key={c.course_id} className="hover:bg-gray-50/40 transition-colors">
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] font-medium text-gray-900">{c.numero_course}</p>
                      <p className="text-[11px] text-gray-400 font-mono">expéditeur {c.expediteur_id?.slice(0, 8)} · livreur {c.livreur_id?.slice(0, 8) || '—'}</p>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="text-[14px] font-semibold text-red-600">{c.ecart_km} km</span>
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-600">
                      {c.distance_facturee_km != null ? `${Number(c.distance_facturee_km).toFixed(1)} km` : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-900">
                      {Math.round(c.prix).toLocaleString('fr-FR')} GNF
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-400">
                      {c.livree_at
                        ? new Date(c.livree_at).toLocaleDateString('fr-FR', {
                            day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
                          })
                        : '—'}
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
