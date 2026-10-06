import { useState, useEffect } from 'react';
import {
  listerComptesTest,
  creerCompteTest,
  supprimerCompteTest,
} from '../services/api';
import {
  RefreshCw,
  Plus,
  Trash2,
  Copy,
  CheckCircle,
  AlertCircle,
  Apple,
  Store,
  Bike,
  X,
} from 'lucide-react';

const APPLE_REVIEWER_DEFAULTS = {
  expediteur: {
    phone: '+224600000001',
    password: 'AppleReview2026!',
    role: 'EXPEDITEUR',
    nom: 'Sönaiyaa Test Store',
    type_expediteur: 'RESTAURANT',
    adresse: 'Avenue de la République, Conakry',
    latitude: 9.6412,
    longitude: -13.5784,
  },
  livreur: {
    phone: '+224600000002',
    password: 'AppleReview2026!',
    role: 'LIVREUR',
    nom: 'Test Livreur Apple',
    type_vehicule: 'moto',
    solde_initial: 25000,
  },
};

const TYPE_EXPEDITEUR_OPTIONS = ['RESTAURANT', 'PHARMACIE', 'SUPERMARCHE', 'B2B', 'AUTRE'];

export default function TestAccountsPage() {
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(APPLE_REVIEWER_DEFAULTS.expediteur);
  const [submitting, setSubmitting] = useState(false);
  const [lastCreated, setLastCreated] = useState(null);
  const [copied, setCopied] = useState(null);

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setAccounts(await listerComptesTest());
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = async (e) => {
    e?.preventDefault?.();
    setSubmitting(true);
    setError(null);
    try {
      const result = await creerCompteTest(form);
      setLastCreated(result);
      setShowForm(false);
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (userId) => {
    if (!confirm('Supprimer définitivement ce compte test ?')) return;
    try {
      await supprimerCompteTest(userId);
      setAccounts((prev) => prev.filter((a) => a.user_id !== userId));
    } catch (e) {
      alert(`Erreur: ${e.message}`);
    }
  };

  const presetApple = (kind) => {
    setForm(APPLE_REVIEWER_DEFAULTS[kind]);
    setShowForm(true);
    setLastCreated(null);
  };

  const copy = (text, key) => {
    navigator.clipboard.writeText(text);
    setCopied(key);
    setTimeout(() => setCopied(null), 1500);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-[22px] font-semibold text-gray-900 tracking-tight">
            Comptes test
          </h2>
          <p className="text-[13px] text-gray-500 mt-1">
            Comptes pré-vérifiés pour la review Apple et les tests internes.
            Numéros au préfixe <code className="bg-gray-100 px-1 rounded text-[12px]">+224600</code>.
          </p>
        </div>
        <button
          onClick={load}
          className="text-gray-500 hover:text-gray-900 p-2 rounded-lg hover:bg-gray-100"
          title="Actualiser"
        >
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Quick actions Apple */}
      {!showForm && !lastCreated && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <button
            onClick={() => presetApple('expediteur')}
            className="flex items-center gap-3 p-5 bg-white border border-gray-200/60 rounded-2xl hover:border-gray-900 hover:shadow-sm transition-all text-left group"
          >
            <div className="w-12 h-12 rounded-xl bg-orange-50 flex items-center justify-center shrink-0">
              <Store size={22} className="text-orange-600" strokeWidth={1.8} />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <Apple size={14} className="text-gray-400" />
                <span className="text-[13px] font-medium text-gray-900">
                  Compte Expediteur — Apple Reviewer
                </span>
              </div>
              <p className="text-[12px] text-gray-500 mt-1">
                Pré-rempli +224600000001 • prêt pour App Store Connect
              </p>
            </div>
            <Plus size={16} className="text-gray-400 group-hover:text-gray-900" />
          </button>

          <button
            onClick={() => presetApple('livreur')}
            className="flex items-center gap-3 p-5 bg-white border border-gray-200/60 rounded-2xl hover:border-gray-900 hover:shadow-sm transition-all text-left group"
          >
            <div className="w-12 h-12 rounded-xl bg-blue-50 flex items-center justify-center shrink-0">
              <Bike size={22} className="text-blue-600" strokeWidth={1.8} />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <Apple size={14} className="text-gray-400" />
                <span className="text-[13px] font-medium text-gray-900">
                  Compte Livreur — Apple Reviewer
                </span>
              </div>
              <p className="text-[12px] text-gray-500 mt-1">
                Pré-rempli +224600000002 • KYC validé + 25 000 GNF
              </p>
            </div>
            <Plus size={16} className="text-gray-400 group-hover:text-gray-900" />
          </button>
        </div>
      )}

      {/* Last created — credentials box */}
      {lastCreated && (
        <div className="bg-green-50 border border-green-200 rounded-2xl p-5">
          <div className="flex items-start gap-3">
            <CheckCircle size={20} className="text-green-600 shrink-0 mt-0.5" />
            <div className="flex-1 min-w-0">
              <h3 className="text-[14px] font-semibold text-green-900">
                Compte créé avec succès
              </h3>
              <p className="text-[12px] text-green-700 mt-1">
                Copie ces identifiants dans App Store Connect → App Review Information.
              </p>
              <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-2">
                <CredCell
                  label="Username"
                  value={lastCreated.credentials_for_apple_review.username}
                  copyKey="user"
                  copied={copied === 'user'}
                  onCopy={(v) => copy(v, 'user')}
                />
                <CredCell
                  label="Password"
                  value={lastCreated.credentials_for_apple_review.password}
                  copyKey="pass"
                  copied={copied === 'pass'}
                  onCopy={(v) => copy(v, 'pass')}
                />
              </div>
              <button
                className="mt-3 text-[12px] text-green-700 hover:text-green-900 font-medium"
                onClick={() => setLastCreated(null)}
              >
                Fermer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Form */}
      {showForm && (
        <div className="bg-white rounded-2xl border border-gray-200/60 p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="text-[16px] font-semibold text-gray-900">
              Nouveau compte test
            </h3>
            <button
              onClick={() => setShowForm(false)}
              className="p-1.5 hover:bg-gray-100 rounded-lg"
            >
              <X size={16} className="text-gray-500" />
            </button>
          </div>
          <form onSubmit={handleCreate} className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Field label="Téléphone" hint="Doit commencer par +224600">
              <input
                type="text"
                required
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                className={inputClasses}
              />
            </Field>
            <Field label="Mot de passe">
              <input
                type="text"
                required
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                className={inputClasses}
              />
            </Field>
            <Field label="Rôle">
              <select
                value={form.role}
                onChange={(e) =>
                  setForm({
                    ...APPLE_REVIEWER_DEFAULTS[e.target.value === 'EXPEDITEUR' ? 'expediteur' : 'livreur'],
                    phone: form.phone,
                    password: form.password,
                  })
                }
                className={inputClasses}
              >
                <option value="EXPEDITEUR">Expéditeur</option>
                <option value="LIVREUR">Livreur</option>
              </select>
            </Field>
            <Field label="Nom">
              <input
                type="text"
                required
                value={form.nom}
                onChange={(e) => setForm({ ...form, nom: e.target.value })}
                className={inputClasses}
              />
            </Field>
            {form.role === 'EXPEDITEUR' && (
              <>
                <Field label="Type">
                  <select
                    value={form.type_expediteur || 'RESTAURANT'}
                    onChange={(e) => setForm({ ...form, type_expediteur: e.target.value })}
                    className={inputClasses}
                  >
                    {TYPE_EXPEDITEUR_OPTIONS.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Adresse">
                  <input
                    type="text"
                    value={form.adresse || ''}
                    onChange={(e) => setForm({ ...form, adresse: e.target.value })}
                    className={inputClasses}
                  />
                </Field>
              </>
            )}
            {form.role === 'LIVREUR' && (
              <>
                <Field label="Type véhicule">
                  <input
                    type="text"
                    value={form.type_vehicule || 'moto'}
                    onChange={(e) => setForm({ ...form, type_vehicule: e.target.value })}
                    className={inputClasses}
                  />
                </Field>
                <Field label="Solde initial Wallet (GNF)" hint="Pour tester le retrait">
                  <input
                    type="number"
                    value={form.solde_initial || 0}
                    onChange={(e) =>
                      setForm({ ...form, solde_initial: parseFloat(e.target.value) || 0 })
                    }
                    className={inputClasses}
                  />
                </Field>
              </>
            )}
            <div className="md:col-span-2 flex items-center gap-3 pt-2">
              <button
                type="submit"
                disabled={submitting}
                className="bg-[#0c0c0c] text-white font-medium px-5 py-2.5 rounded-xl hover:bg-[#1a1a1a] transition-colors disabled:opacity-50 text-[13px]"
              >
                {submitting ? 'Création…' : 'Créer le compte'}
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="text-[13px] text-gray-500 hover:text-gray-900 px-4 py-2.5"
              >
                Annuler
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-[13px] text-red-700 flex items-center gap-2">
          <AlertCircle size={14} />
          {error}
        </div>
      )}

      {/* Existing test accounts */}
      <div className="bg-white rounded-2xl border border-gray-200/60 overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <h3 className="text-[14px] font-semibold text-gray-900">
            Comptes test existants
          </h3>
          <span className="text-[12px] text-gray-500">{accounts.length} compte(s)</span>
        </div>
        {loading ? (
          <div className="p-8 text-center text-gray-400 text-[13px]">Chargement…</div>
        ) : accounts.length === 0 ? (
          <div className="p-8 text-center text-gray-400 text-[13px]">
            Aucun compte test pour l'instant.
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {accounts.map((a) => (
              <div key={a.user_id} className="px-5 py-4 flex items-center gap-4">
                <div
                  className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                    a.role === 'EXPEDITEUR' ? 'bg-orange-50' : 'bg-blue-50'
                  }`}
                >
                  {a.role === 'EXPEDITEUR' ? (
                    <Store size={18} className="text-orange-600" strokeWidth={1.8} />
                  ) : (
                    <Bike size={18} className="text-blue-600" strokeWidth={1.8} />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-[14px] font-medium text-gray-900 truncate">
                    {a.nom}
                  </p>
                  <p className="text-[12px] text-gray-500 mt-0.5">
                    {a.phone} • {a.role}
                    {!a.is_active && (
                      <span className="ml-2 px-1.5 py-0.5 bg-red-50 text-red-600 rounded">
                        Suspendu
                      </span>
                    )}
                  </p>
                </div>
                <button
                  onClick={() => copy(a.phone, `phone-${a.user_id}`)}
                  className="text-[12px] text-gray-500 hover:text-gray-900 px-2 py-1 rounded hover:bg-gray-100"
                  title="Copier le numéro"
                >
                  {copied === `phone-${a.user_id}` ? <CheckCircle size={14} /> : <Copy size={14} />}
                </button>
                <button
                  onClick={() => handleDelete(a.user_id)}
                  className="text-red-500 hover:text-red-700 p-1.5 rounded hover:bg-red-50"
                  title="Supprimer"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

const inputClasses =
  'w-full bg-[#f8f9fa] border border-gray-200 rounded-xl px-3.5 py-2.5 text-[13px] text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#0c0c0c]/10 focus:border-gray-300 transition-all';

function Field({ label, hint, children }) {
  return (
    <div>
      <label className="block text-[12px] font-medium text-gray-700 mb-1.5">
        {label}
        {hint && <span className="text-gray-400 font-normal ml-1.5">— {hint}</span>}
      </label>
      {children}
    </div>
  );
}

function CredCell({ label, value, copied, onCopy }) {
  return (
    <div className="bg-white border border-green-200 rounded-lg px-3 py-2.5 flex items-center gap-2">
      <div className="flex-1 min-w-0">
        <p className="text-[10px] uppercase tracking-wide text-green-700 font-semibold">
          {label}
        </p>
        <p className="text-[13px] font-mono text-gray-900 truncate">{value}</p>
      </div>
      <button
        onClick={() => onCopy(value)}
        className="text-green-700 hover:text-green-900 p-1.5 rounded hover:bg-green-100"
      >
        {copied ? <CheckCircle size={14} /> : <Copy size={14} />}
      </button>
    </div>
  );
}
