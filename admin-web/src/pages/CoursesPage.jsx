import { useState, useEffect } from 'react';
import { getCoursesRecentes } from '../services/api';
import { RefreshCw, Copy, Check } from 'lucide-react';

function StatusBadge({ status }) {
  const colors = {
    CREEE: 'bg-gray-100 text-gray-600',
    DIFFUSEE: 'bg-blue-50 text-blue-600',
    ACCEPTEE: 'bg-indigo-50 text-indigo-600',
    EN_RECUPERATION: 'bg-amber-50 text-amber-700',
    EN_LIVRAISON: 'bg-purple-50 text-purple-600',
    TERMINEE: 'bg-emerald-50 text-emerald-600',
    ANNULEE: 'bg-red-50 text-red-600',
  };
  const labels = {
    CREEE: 'Creee',
    DIFFUSEE: 'Diffusee',
    ACCEPTEE: 'Acceptee',
    EN_RECUPERATION: 'Recuperation',
    EN_LIVRAISON: 'En livraison',
    TERMINEE: 'Terminee',
    ANNULEE: 'Annulee',
  };
  return (
    <span className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-medium ${colors[status] || 'bg-gray-100 text-gray-500'}`}>
      {labels[status] || status}
    </span>
  );
}

function ModePaiementBadge({ mode, confirme }) {
  if (!mode) return <span className="text-gray-400">—</span>;
  const styles = {
    CASH: 'bg-orange-50 text-orange-600',
    MOBILE_MONEY: confirme === 'oui' ? 'bg-emerald-50 text-emerald-600' : 'bg-blue-50 text-blue-600',
  };
  return (
    <span className={`inline-flex px-2 py-0.5 rounded-md text-[11px] font-medium ${styles[mode] || 'bg-gray-100 text-gray-500'}`}>
      {mode === 'MOBILE_MONEY' ? (confirme === 'oui' ? 'MM ✓ payé' : 'MM en attente') : mode}
    </span>
  );
}

function CopyLinkButton({ url }) {
  const [copied, setCopied] = useState(false);
  if (!url) return <span className="text-gray-300">—</span>;
  const handleCopy = () => {
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <button
      onClick={handleCopy}
      title={url}
      className="flex items-center gap-1 px-2 py-1 rounded-md text-[11px] font-medium bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
    >
      {copied ? <Check size={11} /> : <Copy size={11} />}
      {copied ? 'Copie !' : 'Copier lien'}
    </button>
  );
}

export default function CoursesPage() {
  const [courses, setCourses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    loadCourses();
  }, []);

  const loadCourses = async () => {
    try {
      const data = await getCoursesRecentes(50);
      setCourses(data);
    } catch (e) {
      console.error('Erreur:', e);
    } finally {
      setLoading(false);
    }
  };

  const filteredCourses = filter === 'all'
    ? courses
    : courses.filter((c) => c.status === filter);

  const statusCounts = courses.reduce((acc, c) => {
    acc[c.status] = (acc[c.status] || 0) + 1;
    return acc;
  }, {});

  const filters = [
    { key: 'all', label: 'Toutes', count: courses.length },
    { key: 'DIFFUSEE', label: 'Diffusees', count: statusCounts['DIFFUSEE'] || 0 },
    { key: 'ACCEPTEE', label: 'Acceptees', count: statusCounts['ACCEPTEE'] || 0 },
    { key: 'EN_LIVRAISON', label: 'En livraison', count: statusCounts['EN_LIVRAISON'] || 0 },
    { key: 'TERMINEE', label: 'Terminees', count: statusCounts['TERMINEE'] || 0 },
    { key: 'ANNULEE', label: 'Annulees', count: statusCounts['ANNULEE'] || 0 },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-7 w-7 border-2 border-gray-300 border-t-gray-900" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6 flex items-start justify-between">
        <p className="text-[13px] text-gray-500">Suivi de toutes les courses</p>
        <button
          onClick={loadCourses}
          className="flex items-center gap-1.5 px-3.5 py-1.5 bg-gray-900 text-white text-[12px] font-medium rounded-lg hover:bg-gray-800 transition-colors"
        >
          <RefreshCw size={13} />
          Rafraichir
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-2 mb-5 overflow-x-auto pb-1">
        {filters.map(({ key, label, count }) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-[12px] font-medium whitespace-nowrap transition-all border ${
              filter === key
                ? 'bg-gray-900 text-white border-gray-900'
                : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300 hover:text-gray-700'
            }`}
          >
            {label}
            {count > 0 && (
              <span className={`text-[11px] ${filter === key ? 'text-white/60' : 'text-gray-400'}`}>
                {count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200/60 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider border-b border-gray-100">
                <th className="px-5 py-3.5">Course</th>
                <th className="px-5 py-3.5">Expéditeur</th>
                <th className="px-5 py-3.5">Livreur</th>
                <th className="px-5 py-3.5">Client</th>
                <th className="px-5 py-3.5">Statut</th>
                <th className="px-5 py-3.5">Paiement</th>
                <th className="px-5 py-3.5">Lien paiement</th>
                <th className="px-5 py-3.5">Prix</th>
                <th className="px-5 py-3.5">Commission</th>
                <th className="px-5 py-3.5">Distance</th>
                <th className="px-5 py-3.5">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredCourses.map((cmd) => (
                <tr key={cmd.id} className="hover:bg-gray-50/60 transition-colors">
                  <td className="px-5 py-3.5">
                    <span className="text-[13px] font-mono font-medium text-gray-900">
                      {cmd.numero_course}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <p className="text-[13px] text-gray-900">{cmd.expediteur_nom || '—'}</p>
                    {cmd.expediteur_phone && (
                      <p className="text-[11px] text-gray-400">{cmd.expediteur_phone}</p>
                    )}
                  </td>
                  <td className="px-5 py-3.5">
                    <p className="text-[13px] text-gray-900">{cmd.livreur_nom || '—'}</p>
                    {cmd.livreur_phone && (
                      <p className="text-[11px] text-gray-400">{cmd.livreur_phone}</p>
                    )}
                  </td>
                  <td className="px-5 py-3.5">
                    <p className="text-[13px] text-gray-900">{cmd.contact_client_nom || '—'}</p>
                    {cmd.contact_client_telephone && (
                      <p className="text-[11px] text-gray-400">{cmd.contact_client_telephone}</p>
                    )}
                  </td>
                  <td className="px-5 py-3.5">
                    <StatusBadge status={cmd.status} />
                  </td>
                  <td className="px-5 py-3.5">
                    <ModePaiementBadge mode={cmd.mode_paiement} confirme={cmd.paiement_confirme} />
                  </td>
                  <td className="px-5 py-3.5">
                    {cmd.mode_paiement === 'MOBILE_MONEY' && cmd.paiement_confirme !== 'oui'
                      ? <CopyLinkButton url={cmd.geniuspay_checkout_url} />
                      : <span className="text-gray-300">—</span>
                    }
                  </td>
                  <td className="px-5 py-3.5 text-[13px] font-medium text-gray-900">
                    {cmd.prix_propose?.toLocaleString('fr-FR')} GNF
                  </td>
                  <td className="px-5 py-3.5 text-[13px] text-gray-600">
                    {cmd.commission_plateforme != null ? `${Math.round(cmd.commission_plateforme).toLocaleString('fr-FR')} GNF` : '—'}
                  </td>
                  <td className="px-5 py-3.5 text-[13px] text-gray-600">
                    {cmd.distance_km != null ? `${Number(cmd.distance_km).toFixed(1)} km` : '—'}
                  </td>
                  <td className="px-5 py-3.5 text-[13px] text-gray-400">
                    {new Date(cmd.created_at).toLocaleDateString('fr-FR', {
                      day: 'numeric',
                      month: 'short',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </td>
                </tr>
              ))}
              {filteredCourses.length === 0 && (
                <tr>
                  <td colSpan="11" className="px-5 py-12 text-center text-[13px] text-gray-400">
                    Aucune course {filter !== 'all' ? 'avec ce statut' : ''}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
