import { useState, useEffect } from 'react';
import {
  getLivreursEnAttente,
  getExpediteursEnAttente,
  validerLivreur,
  rejeterLivreur,
  validerExpediteur,
  rejeterExpediteur,
} from '../services/api';
import { CheckCircle, XCircle, RefreshCw, ExternalLink, FileText, Car, User, Store, Image } from 'lucide-react';

const BASE_URL = import.meta.env.VITE_API_URL?.replace('/api/v1', '') || 'https://api.sonaiyaa.fr';

function DocImage({ url, label, icon: Icon }) {
  const [open, setOpen] = useState(false);
  const fullUrl = url ? (url.startsWith('http') ? url : `${BASE_URL}${url}`) : null;
  const isPdf = fullUrl?.toLowerCase().endsWith('.pdf');

  if (!fullUrl) {
    return (
      <div className="flex flex-col items-center gap-1.5">
        <div className="w-20 h-20 rounded-lg bg-gray-100 flex items-center justify-center">
          <Icon size={24} className="text-gray-300" />
        </div>
        <span className="text-[11px] text-gray-400">{label}</span>
        <span className="text-[10px] text-orange-400 font-medium">Manquant</span>
      </div>
    );
  }

  if (isPdf) {
    return (
      <div className="flex flex-col items-center gap-1.5">
        <a
          href={fullUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="w-20 h-20 rounded-lg border border-red-200 bg-red-50 hover:bg-red-100 transition-colors flex flex-col items-center justify-center gap-1 group"
          title={`Ouvrir ${label}`}
        >
          <ExternalLink size={18} className="text-red-400 group-hover:text-red-600" />
          <span className="text-[9px] text-red-400 font-bold">PDF</span>
        </a>
        <span className="text-[11px] text-gray-500">{label}</span>
        <span className="text-[10px] text-green-600 font-medium">Envoyé ✓</span>
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col items-center gap-1.5">
        <button
          onClick={() => setOpen(true)}
          className="w-20 h-20 rounded-lg overflow-hidden border border-gray-200 hover:border-gray-400 transition-colors relative group"
        >
          <img src={fullUrl} alt={label} className="w-full h-full object-cover" />
          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
            <ExternalLink size={14} className="text-white opacity-0 group-hover:opacity-100 transition-opacity" />
          </div>
        </button>
        <span className="text-[11px] text-gray-500">{label}</span>
        <span className="text-[10px] text-green-600 font-medium">Envoyé ✓</span>
      </div>

      {open && (
        <div
          className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4"
          onClick={() => setOpen(false)}
        >
          <div className="relative max-w-3xl max-h-[90vh]" onClick={(e) => e.stopPropagation()}>
            <img src={fullUrl} alt={label} className="max-w-full max-h-[85vh] rounded-xl object-contain" />
            <button
              onClick={() => setOpen(false)}
              className="absolute -top-3 -right-3 w-8 h-8 bg-white rounded-full flex items-center justify-center shadow-lg text-gray-700 hover:bg-gray-100"
            >
              ×
            </button>
            <p className="text-center text-white/70 text-sm mt-3">{label}</p>
          </div>
        </div>
      )}
    </>
  );
}

function LivreurCard({ livreur, onValider, onRejeter, loading }) {
  const docsComplets = livreur.docs_complets;
  const vehiculeLabel = livreur.vehicule_doc_type === 'carte_grise'
    ? 'Carte grise'
    : livreur.vehicule_doc_type === 'permis_conduire'
    ? 'Permis de conduire'
    : 'Permis / Carte grise';

  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg bg-gray-900 flex items-center justify-center text-white font-semibold text-sm">
            {livreur.nom_complet?.charAt(0)?.toUpperCase() ?? 'L'}
          </div>
          <div>
            <p className="font-semibold text-gray-900 text-sm">{livreur.nom_complet}</p>
            <p className="text-[12px] text-gray-400">{livreur.type_vehicule ?? 'Véhicule non renseigné'}</p>
          </div>
        </div>
        <span className={`text-[11px] font-semibold px-2.5 py-1 rounded-full ${docsComplets ? 'bg-green-50 text-green-600' : 'bg-orange-50 text-orange-500'}`}>
          {docsComplets ? 'Docs complets' : 'Docs incomplets'}
        </span>
      </div>

      <div className="px-5 py-4">
        <p className="text-[12px] font-medium text-gray-500 mb-3">Documents</p>
        <div className="flex gap-4">
          <DocImage url={livreur.piece_identite_url} label="Pièce d'identité" icon={FileText} />
          <DocImage url={livreur.vehicule_doc_url} label={vehiculeLabel} icon={Car} />
          <DocImage url={livreur.photo_profil_url} label="Photo profil" icon={User} />
        </div>
      </div>

      <div className="px-5 py-3 border-t border-gray-100 flex gap-2">
        <button
          onClick={() => onValider(livreur.id)}
          disabled={loading || !docsComplets}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg bg-gray-900 text-white text-[13px] font-medium hover:bg-gray-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {loading === livreur.id + '_valider' ? (
            <RefreshCw size={14} className="animate-spin" />
          ) : (
            <CheckCircle size={14} />
          )}
          Valider
        </button>
        <button
          onClick={() => onRejeter(livreur.id)}
          disabled={!!loading}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg bg-red-50 text-red-600 text-[13px] font-medium hover:bg-red-100 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {loading === livreur.id + '_rejeter' ? (
            <RefreshCw size={14} className="animate-spin" />
          ) : (
            <XCircle size={14} />
          )}
          Rejeter
        </button>
      </div>
    </div>
  );
}

function ExpediteurCard({ expediteur, onValider, onRejeter, loading }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg bg-orange-500 flex items-center justify-center text-white font-semibold text-sm">
            {expediteur.nom?.charAt(0)?.toUpperCase() ?? 'P'}
          </div>
          <div>
            <p className="font-semibold text-gray-900 text-sm">{expediteur.nom}</p>
            <p className="text-[12px] text-gray-400">{expediteur.adresse}</p>
          </div>
        </div>
        <span className={`text-[11px] font-semibold px-2.5 py-1 rounded-full ${expediteur.docs_complets ? 'bg-green-50 text-green-600' : 'bg-orange-50 text-orange-500'}`}>
          {expediteur.docs_complets ? 'Docs complets' : 'Docs incomplets'}
        </span>
      </div>

      <div className="px-5 py-4">
        <p className="text-[12px] font-medium text-gray-500 mb-3">Documents</p>
        <div className="flex gap-4">
          <DocImage url={expediteur.devanture_url} label="Photo devanture" icon={Image} />
          <DocImage url={expediteur.rccm_url} label="RCCM" icon={FileText} />
        </div>
      </div>

      <div className="px-5 py-3 border-t border-gray-100 flex gap-2">
        <button
          onClick={() => onValider(expediteur.id)}
          disabled={!!loading}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg bg-gray-900 text-white text-[13px] font-medium hover:bg-gray-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {loading === expediteur.id + '_valider' ? (
            <RefreshCw size={14} className="animate-spin" />
          ) : (
            <CheckCircle size={14} />
          )}
          Valider
        </button>
        <button
          onClick={() => onRejeter(expediteur.id)}
          disabled={!!loading}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg bg-red-50 text-red-600 text-[13px] font-medium hover:bg-red-100 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {loading === expediteur.id + '_rejeter' ? (
            <RefreshCw size={14} className="animate-spin" />
          ) : (
            <XCircle size={14} />
          )}
          Rejeter
        </button>
      </div>
    </div>
  );
}

export default function ValidationPage() {
  const [tab, setTab] = useState('livreurs');
  const [livreurs, setLivreurs] = useState([]);
  const [expediteurs, setExpediteurs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadData();
  }, [tab]);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      if (tab === 'livreurs') {
        const data = await getLivreursEnAttente();
        setLivreurs(data);
      } else {
        const data = await getExpediteursEnAttente();
        setExpediteurs(data);
      }
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleValiderLivreur = async (id) => {
    setActionLoading(id + '_valider');
    try {
      await validerLivreur(id);
      setLivreurs((prev) => prev.filter((l) => l.id !== id));
    } catch (e) {
      alert('Erreur : ' + e.message);
    } finally {
      setActionLoading(null);
    }
  };

  const handleRejeterLivreur = async (id) => {
    if (!confirm('Rejeter ce livreur ? Les documents seront supprimés et il devra renvoyer ses pièces.')) return;
    setActionLoading(id + '_rejeter');
    try {
      await rejeterLivreur(id);
      setLivreurs((prev) => prev.filter((l) => l.id !== id));
    } catch (e) {
      alert('Erreur : ' + e.message);
    } finally {
      setActionLoading(null);
    }
  };

  const handleValiderExpediteur = async (id) => {
    setActionLoading(id + '_valider');
    try {
      await validerExpediteur(id);
      setExpediteurs((prev) => prev.filter((p) => p.id !== id));
    } catch (e) {
      alert('Erreur : ' + e.message);
    } finally {
      setActionLoading(null);
    }
  };

  const handleRejeterExpediteur = async (id) => {
    if (!confirm('Rejeter cet expéditeur ? La photo de devanture sera supprimée.')) return;
    setActionLoading(id + '_rejeter');
    try {
      await rejeterExpediteur(id);
      setExpediteurs((prev) => prev.filter((p) => p.id !== id));
    } catch (e) {
      alert('Erreur : ' + e.message);
    } finally {
      setActionLoading(null);
    }
  };

  const currentList = tab === 'livreurs' ? livreurs : expediteurs;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Validation des comptes</h1>
          <p className="text-sm text-gray-500 mt-0.5">Vérifiez les documents et validez ou rejetez chaque compte</p>
        </div>
        <button
          onClick={loadData}
          className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors text-[13px] font-medium text-gray-700"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          Actualiser
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-gray-100 rounded-xl w-fit mb-6">
        {[
          { key: 'livreurs', label: 'Livreurs', count: livreurs.length },
          { key: 'expediteurs', label: 'Expéditeurs', count: expediteurs.length },
        ].map(({ key, label, count }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`px-4 py-2 rounded-lg text-[13px] font-medium transition-colors flex items-center gap-2 ${
              tab === key ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {label}
            {!loading && count > 0 && (
              <span className={`text-[11px] font-bold px-1.5 py-0.5 rounded-full ${tab === key ? 'bg-orange-100 text-orange-600' : 'bg-gray-200 text-gray-500'}`}>
                {count}
              </span>
            )}
          </button>
        ))}
      </div>

      {error && (
        <div className="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <RefreshCw size={24} className="animate-spin text-gray-300" />
        </div>
      ) : currentList.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <CheckCircle size={40} className="text-green-300 mb-3" />
          <p className="text-gray-500 font-medium">File d'attente vide</p>
          <p className="text-gray-400 text-sm mt-1">Aucun compte en attente de validation</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {tab === 'livreurs'
            ? livreurs.map((l) => (
                <LivreurCard
                  key={l.id}
                  livreur={l}
                  onValider={handleValiderLivreur}
                  onRejeter={handleRejeterLivreur}
                  loading={actionLoading}
                />
              ))
            : expediteurs.map((p) => (
                <ExpediteurCard
                  key={p.id}
                  expediteur={p}
                  onValider={handleValiderExpediteur}
                  onRejeter={handleRejeterExpediteur}
                  loading={actionLoading}
                />
              ))}
        </div>
      )}
    </div>
  );
}
