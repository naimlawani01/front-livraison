import { useState, useEffect } from 'react';
import {
  getExpediteursEnAttente, getTousExpediteurs,
  getExpediteurDetail, validerExpediteur, suspendreExpediteur, rejeterExpediteur,
} from '../services/api';
import { RefreshCw, CheckCircle, AlertTriangle, X, ExternalLink, ChevronRight, Image } from 'lucide-react';

const BASE_URL = import.meta.env.VITE_API_URL?.replace('/api/v1', '') || 'https://api.sonaiyaa.fr';

const TYPE_LABELS = {
  RESTAURANT: 'Restaurant',
  PHARMACIE: 'Pharmacie',
  SUPERMARCHE: 'Supermarché',
  B2B: 'B2B',
  AUTRE: 'Autre',
};

function DocThumb({ url, label }) {
  const [open, setOpen] = useState(false);
  const full = url ? (url.startsWith('http') ? url : `${BASE_URL}${url}`) : null;
  const isPdf = full?.toLowerCase().endsWith('.pdf');

  if (!full) {
    return (
      <div className="flex flex-col items-center gap-1">
        <div className="w-16 h-16 rounded-lg bg-gray-100 flex items-center justify-center text-gray-300">
          <Image size={20} />
        </div>
        <span className="text-[10px] text-gray-400">{label}</span>
      </div>
    );
  }

  if (isPdf) {
    return (
      <div className="flex flex-col items-center gap-1">
        <a
          href={full}
          target="_blank"
          rel="noopener noreferrer"
          className="w-16 h-16 rounded-lg border border-red-200 bg-red-50 hover:bg-red-100 transition-colors flex items-center justify-center group"
          title={`Ouvrir ${label}`}
        >
          <ExternalLink size={16} className="text-red-400 group-hover:text-red-600" />
        </a>
        <span className="text-[10px] text-green-600 font-medium">{label}</span>
        <span className="text-[9px] text-red-400 font-medium">PDF</span>
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col items-center gap-1">
        <button
          onClick={() => setOpen(true)}
          className="w-16 h-16 rounded-lg overflow-hidden border border-gray-200 hover:border-gray-400 transition-colors group relative"
        >
          <img src={full} alt={label} className="w-full h-full object-cover" />
          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
            <ExternalLink size={12} className="text-white opacity-0 group-hover:opacity-100" />
          </div>
        </button>
        <span className="text-[10px] text-green-600 font-medium">{label}</span>
      </div>
      {open && (
        <div className="fixed inset-0 bg-black/80 z-[100] flex items-center justify-center p-4" onClick={() => setOpen(false)}>
          <div className="relative max-w-2xl max-h-[88vh]" onClick={e => e.stopPropagation()}>
            <img src={full} alt={label} className="max-w-full max-h-[82vh] rounded-xl object-contain" />
            <button onClick={() => setOpen(false)} className="absolute -top-3 -right-3 w-7 h-7 bg-white rounded-full flex items-center justify-center shadow text-gray-700 text-sm font-bold hover:bg-gray-100">×</button>
            <p className="text-center text-white/60 text-xs mt-2">{label}</p>
          </div>
        </div>
      )}
    </>
  );
}

function ExpediteurDrawer({ expediteurId, onClose, onAction }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    if (!expediteurId) return;
    setLoading(true);
    getExpediteurDetail(expediteurId)
      .then(setData)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [expediteurId]);

  const handle = async (action, fn, confirm_msg) => {
    if (confirm_msg && !window.confirm(confirm_msg)) return;
    setActionLoading(action);
    try {
      await fn();
      onAction();
      onClose();
    } catch (e) {
      alert('Erreur : ' + e.message);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <>
      <div className="fixed inset-0 bg-black/30 z-40" onClick={onClose} />

      <div className="fixed right-0 top-0 h-full w-full max-w-[480px] bg-white z-50 shadow-2xl flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 className="text-[15px] font-semibold text-gray-900">Détail expediteur</h2>
          <button onClick={onClose} className="w-8 h-8 rounded-lg hover:bg-gray-100 flex items-center justify-center transition-colors">
            <X size={16} className="text-gray-500" />
          </button>
        </div>

        {loading ? (
          <div className="flex-1 flex items-center justify-center">
            <RefreshCw size={20} className="animate-spin text-gray-300" />
          </div>
        ) : !data ? (
          <div className="flex-1 flex items-center justify-center text-gray-400 text-sm">Introuvable</div>
        ) : (
          <div className="flex-1 overflow-y-auto">
            {/* Profile header */}
            <div className="px-6 py-5 border-b border-gray-50">
              <div className="flex items-center gap-4">
                {data.devanture_url && !data.devanture_url.toLowerCase().endsWith('.pdf') ? (
                  <img
                    src={data.devanture_url.startsWith('http') ? data.devanture_url : `${BASE_URL}${data.devanture_url}`}
                    alt={data.nom}
                    className="w-14 h-14 rounded-xl object-cover border border-gray-200"
                  />
                ) : (
                  <div className="w-14 h-14 rounded-xl bg-orange-500 flex items-center justify-center text-white font-bold text-xl">
                    {data.nom?.charAt(0)?.toUpperCase()}
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 text-[15px] truncate">{data.nom}</p>
                  <p className="text-[12px] text-gray-400 mt-0.5">{data.phone || '—'}</p>
                  <div className="flex flex-wrap gap-1.5 mt-2">
                    {data.is_verified ? (
                      <span className="px-2 py-0.5 bg-emerald-50 text-emerald-600 rounded-md text-[10px] font-semibold">Validé</span>
                    ) : (
                      <span className="px-2 py-0.5 bg-amber-50 text-amber-600 rounded-md text-[10px] font-semibold">En attente</span>
                    )}
                    {data.is_open
                      ? <span className="px-2 py-0.5 bg-blue-50 text-blue-600 rounded-md text-[10px] font-semibold">Ouvert</span>
                      : <span className="px-2 py-0.5 bg-gray-100 text-gray-500 rounded-md text-[10px] font-semibold">Fermé</span>
                    }
                    {data.type_expediteur && (
                      <span className="px-2 py-0.5 bg-orange-50 text-orange-500 rounded-md text-[10px] font-semibold capitalize">
                        {TYPE_LABELS[data.type_expediteur] ?? data.type_expediteur}
                      </span>
                    )}
                    {data.docs_complets
                      ? <span className="px-2 py-0.5 bg-green-50 text-green-600 rounded-md text-[10px] font-semibold">Docs ✓</span>
                      : <span className="px-2 py-0.5 bg-red-50 text-red-500 rounded-md text-[10px] font-semibold">Docs incomplets</span>
                    }
                  </div>
                </div>
              </div>
            </div>

            {/* Infos */}
            <div className="px-6 py-4 border-b border-gray-50">
              <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-3">Informations</p>
              <div className="space-y-2.5">
                {[
                  { label: 'Adresse', value: data.adresse || '—' },
                  { label: 'Description', value: data.description || '—' },
                  { label: 'Email', value: data.email || '—' },
                  { label: 'Tél. secondaire', value: data.telephone_secondaire || '—' },
                  { label: 'Coordonnées', value: data.latitude && data.longitude ? `${data.latitude.toFixed(5)}, ${data.longitude.toFixed(5)}` : '—' },
                  { label: 'Membre depuis', value: data.created_at ? new Date(data.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }) : '—' },
                ].map(({ label, value }) => (
                  <div key={label} className="flex items-start justify-between gap-4">
                    <span className="text-[12px] text-gray-400 shrink-0">{label}</span>
                    <span className="text-[12px] font-medium text-gray-700 text-right">{value}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Stats */}
            <div className="px-6 py-4 border-b border-gray-50">
              <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-3">Statistiques</p>
              <div className="grid grid-cols-2 gap-3">
                {[
                  { label: 'Courses livrées', value: data.nombre_courses_terminees ?? 0 },
                  { label: 'Note', value: `⭐ ${Number(data.note_moyenne || 0).toFixed(1)} / 5` },
                  { label: 'Évaluations', value: data.nombre_evaluations ?? 0 },
                  { label: 'Statut', value: data.is_open ? '🟢 Ouvert' : '⚫ Fermé' },
                ].map(({ label, value }) => (
                  <div key={label} className="bg-gray-50 rounded-xl p-3">
                    <p className="text-[10px] text-gray-400 mb-1">{label}</p>
                    <p className="text-[13px] font-semibold text-gray-900">{value}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Document */}
            <div className="px-6 py-4 border-b border-gray-50">
              <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-3">Document</p>
              <DocThumb url={data.devanture_url} label="Photo devanture" />
              <DocThumb url={data.rccm_url} label="RCCM" />
            </div>

            {/* Actions */}
            <div className="px-6 py-4">
              <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-3">Actions</p>
              <div className="flex flex-col gap-2">
                {!data.is_verified && (
                  <button
                    onClick={() => handle('valider', () => validerExpediteur(data.id), null)}
                    disabled={!!actionLoading || !data.docs_complets}
                    className="flex items-center justify-center gap-2 py-2.5 rounded-xl bg-gray-900 text-white text-[13px] font-medium hover:bg-gray-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {actionLoading === 'valider' ? <RefreshCw size={14} className="animate-spin" /> : <CheckCircle size={14} />}
                    Valider le compte
                    {!data.docs_complets && <span className="text-[11px] opacity-60">(docs incomplets)</span>}
                  </button>
                )}
                <button
                  onClick={() => handle('rejeter', () => rejeterExpediteur(data.id), 'Rejeter ce dossier ? La photo de devanture sera effacée.')}
                  disabled={!!actionLoading}
                  className="flex items-center justify-center gap-2 py-2.5 rounded-xl bg-red-50 text-red-600 text-[13px] font-medium hover:bg-red-100 transition-colors disabled:opacity-40"
                >
                  {actionLoading === 'rejeter' ? <RefreshCw size={14} className="animate-spin" /> : <X size={14} />}
                  Rejeter le dossier
                </button>
                <button
                  onClick={() => handle('suspendre', () => suspendreExpediteur(data.id), 'Suspendre cet expéditeur ?')}
                  disabled={!!actionLoading}
                  className="flex items-center justify-center gap-2 py-2.5 rounded-xl border border-gray-200 text-gray-600 text-[13px] font-medium hover:bg-gray-50 transition-colors disabled:opacity-40"
                >
                  {actionLoading === 'suspendre' ? <RefreshCw size={14} className="animate-spin" /> : null}
                  Suspendre le compte
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

export default function ExpediteursPage() {
  const [expediteurs, setExpediteurs] = useState([]);
  const [tousExpediteurs, setTousExpediteurs] = useState([]);
  const [activeTab, setActiveTab] = useState('attente');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedId, setSelectedId] = useState(null);

  useEffect(() => {
    loadData();
  }, [activeTab]);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      if (activeTab === 'attente') {
        const data = await getExpediteursEnAttente();
        setExpediteurs(data);
      } else {
        const data = await getTousExpediteurs();
        setTousExpediteurs(data);
      }
    } catch (e) {
      setError('Impossible de charger les données.');
    } finally {
      setLoading(false);
    }
  };

  const currentList = activeTab === 'attente' ? expediteurs : tousExpediteurs;

  if (loading && currentList.length === 0) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-7 w-7 border-2 border-gray-300 border-t-gray-900" />
      </div>
    );
  }

  return (
    <div>
      {selectedId && (
        <ExpediteurDrawer
          expediteurId={selectedId}
          onClose={() => setSelectedId(null)}
          onAction={loadData}
        />
      )}

      <div className="mb-6 flex flex-col md:flex-row md:items-end md:justify-between gap-4">
        <p className="text-[13px] text-gray-500">Gestion et validation des établissements</p>
        <div className="flex p-1 bg-gray-100 rounded-lg w-fit">
          <button
            onClick={() => setActiveTab('attente')}
            className={`px-3.5 py-1.5 text-[13px] font-medium rounded-md transition-all ${activeTab === 'attente' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
          >
            En attente ({expediteurs.length})
          </button>
          <button
            onClick={() => setActiveTab('tous')}
            className={`px-3.5 py-1.5 text-[13px] font-medium rounded-md transition-all ${activeTab === 'tous' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
          >
            Tous les expediteurs
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-100 text-red-600 p-4 rounded-xl mb-5 text-[13px] flex items-center gap-3">
          <AlertTriangle size={16} />
          <span className="flex-1">{error}</span>
          <button onClick={loadData} className="underline font-medium">Réessayer</button>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200/60 overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-[15px] font-semibold text-gray-900">
            {activeTab === 'attente' ? 'Demandes d\'inscription' : 'Tous les expediteurs'}
          </h2>
          <button onClick={loadData} className="text-[13px] text-gray-400 hover:text-gray-600 flex items-center gap-1.5 transition-colors">
            <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
            Rafraîchir
          </button>
        </div>

        {currentList.length === 0 ? (
          <div className="p-12 text-center">
            <CheckCircle size={32} className="text-emerald-300 mx-auto mb-3" />
            <p className="text-[13px] text-gray-400">
              {activeTab === 'attente' ? 'Aucun expediteur en attente' : 'Aucun expediteur'}
            </p>
          </div>
        ) : activeTab === 'attente' ? (
          <div className="divide-y divide-gray-100">
            {expediteurs.map((r) => (
              <button
                key={r.id}
                onClick={() => setSelectedId(r.id)}
                className="w-full px-5 py-4 flex items-center justify-between hover:bg-gray-50/60 transition-colors text-left"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-10 h-10 bg-orange-500 rounded-full flex items-center justify-center text-white font-semibold text-[13px]">
                    {r.nom?.charAt(0)?.toUpperCase()}
                  </div>
                  <div>
                    <p className="font-medium text-[14px] text-gray-900">{r.nom}</p>
                    <p className="text-[12px] text-gray-400">{r.phone || r.email || '—'} · {r.adresse}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {r.docs_complets
                    ? <span className="text-[11px] px-2 py-0.5 bg-green-50 text-green-600 rounded-full font-medium">Docs ✓</span>
                    : <span className="text-[11px] px-2 py-0.5 bg-orange-50 text-orange-500 rounded-full font-medium">Incomplet</span>
                  }
                  <ChevronRight size={14} className="text-gray-300" />
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider bg-gray-50/50">
                  <th className="px-5 py-3.5">Expéditeur</th>
                  <th className="px-5 py-3.5">Téléphone</th>
                  <th className="px-5 py-3.5">Type</th>
                  <th className="px-5 py-3.5">Statut</th>
                  <th className="px-5 py-3.5">Note</th>
                  <th className="px-5 py-3.5">Ouverture</th>
                  <th className="px-5 py-3.5"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {tousExpediteurs.map((r) => (
                  <tr
                    key={r.id}
                    onClick={() => setSelectedId(r.id)}
                    className="hover:bg-gray-50/40 transition-colors cursor-pointer"
                  >
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] font-medium text-gray-900">{r.nom}</p>
                      <p className="text-[12px] text-gray-400">{r.adresse}</p>
                    </td>
                    <td className="px-5 py-3.5 text-[13px] text-gray-600">{r.phone || '—'}</td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex px-2 py-0.5 bg-gray-100 text-gray-600 rounded-md text-[11px] font-medium">
                        {TYPE_LABELS[r.type_expediteur] ?? r.type_expediteur ?? '—'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      {r.is_verified
                        ? <span className="inline-flex px-2 py-0.5 bg-emerald-50 text-emerald-600 rounded-md text-[11px] font-medium">Validé</span>
                        : <span className="inline-flex px-2 py-0.5 bg-amber-50 text-amber-600 rounded-md text-[11px] font-medium">En attente</span>
                      }
                    </td>
                    <td className="px-5 py-3.5">
                      <p className="text-[13px] font-medium text-gray-900">{Number(r.note_moyenne || 0).toFixed(1)} / 5</p>
                      <p className="text-[11px] text-gray-400">{r.nombre_evaluations} avis</p>
                    </td>
                    <td className="px-5 py-3.5">
                      {r.is_open ? (
                        <span className="inline-flex items-center gap-1.5 text-[12px] text-emerald-600 font-medium">
                          <span className="w-1.5 h-1.5 bg-emerald-500 rounded-full" />
                          Ouvert
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 text-[12px] text-gray-400 font-medium">
                          <span className="w-1.5 h-1.5 bg-gray-300 rounded-full" />
                          Fermé
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      <ChevronRight size={14} className="text-gray-300" />
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
