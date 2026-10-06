import { useState, useEffect } from 'react';
import { getStats, getCoursesRecentes } from '../services/api';
import { Package, RefreshCw, Truck, Users, DollarSign, Store, TrendingUp, Wallet, CheckCircle } from 'lucide-react';

function StatCard({ label, value, icon: Icon, color = 'text-gray-900', sub }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200/60 p-5">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[12px] font-medium text-gray-500">{label}</p>
          <p className={`text-2xl font-semibold mt-1.5 ${color}`}>{value}</p>
          {sub && <p className="text-[11px] text-gray-400 mt-1">{sub}</p>}
        </div>
        <div className="w-9 h-9 bg-[#f8f9fa] rounded-lg flex items-center justify-center">
          <Icon size={18} className="text-gray-400" />
        </div>
      </div>
    </div>
  );
}

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

export default function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [courses, setCourses] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [statsData, coursesData] = await Promise.all([
        getStats(),
        getCoursesRecentes(10),
      ]);
      setStats(statsData);
      setCourses(coursesData);
    } catch (e) {
      console.error('Erreur chargement:', e);
    } finally {
      setLoading(false);
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
      <p className="text-[13px] text-gray-500 mb-6">Vue d'ensemble de la plateforme</p>

      {/* KPIs ligne 1 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-3">
        <StatCard
          label="Courses totales"
          value={stats?.total_courses || 0}
          icon={Package}
          sub={`${stats?.courses_terminees || 0} terminées`}
        />
        <StatCard
          label="En cours"
          value={stats?.courses_en_cours || 0}
          icon={RefreshCw}
          color="text-[#FF5A1F]"
        />
        <StatCard
          label="Taux de complétion"
          value={`${stats?.taux_completion || 0}%`}
          icon={TrendingUp}
          color="text-emerald-600"
        />
        <StatCard
          label="Revenus plateforme"
          value={`${Math.round(stats?.revenus_totaux || 0).toLocaleString('fr-FR')} GNF`}
          icon={DollarSign}
          color="text-emerald-600"
        />
      </div>

      {/* KPIs ligne 2 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
        <StatCard
          label="Livreurs actifs"
          value={`${stats?.livreurs_actifs || 0} / ${stats?.total_livreurs || 0}`}
          icon={Truck}
          sub={`${stats?.livreurs_verifies || 0} vérifiés`}
        />
        <StatCard
          label="Expéditeurs"
          value={stats?.total_expediteurs || 0}
          icon={Store}
        />
        <StatCard
          label="Utilisateurs"
          value={stats?.total_utilisateurs || 0}
          icon={Users}
        />
        <StatCard
          label="Retraits en attente"
          value={stats?.retraits_en_attente || 0}
          icon={Wallet}
          color={stats?.retraits_en_attente > 0 ? 'text-amber-600' : 'text-gray-900'}
          sub={stats?.retraits_en_attente > 0 ? 'Action requise' : 'Aucun en attente'}
        />
      </div>

      {/* Recent orders */}
      <div className="bg-white rounded-xl border border-gray-200/60">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-[15px] font-semibold text-gray-900">Courses recentes</h2>
          <button onClick={loadData} className="text-[13px] text-gray-400 hover:text-gray-600 transition-colors">
            Rafraichir
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left text-[11px] font-medium text-gray-400 uppercase tracking-wider">
                <th className="px-5 py-3">Course</th>
                <th className="px-5 py-3">Expéditeur</th>
                <th className="px-5 py-3">Livreur</th>
                <th className="px-5 py-3">Statut</th>
                <th className="px-5 py-3">Prix</th>
                <th className="px-5 py-3">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {courses.map((cmd) => (
                <tr key={cmd.id} className="hover:bg-gray-50/60 transition-colors">
                  <td className="px-5 py-3.5 text-[13px] font-mono font-medium text-gray-900">
                    {cmd.numero_course}
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
                    <StatusBadge status={cmd.status} />
                  </td>
                  <td className="px-5 py-3.5 text-[13px] text-gray-600">
                    {cmd.prix_propose?.toLocaleString('fr-FR')} FCFA
                  </td>
                  <td className="px-5 py-3.5 text-[13px] text-gray-400">
                    {new Date(cmd.created_at).toLocaleDateString('fr-FR', {
                      day: 'numeric',
                      month: 'short',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </td>
                </tr>
              ))}
              {courses.length === 0 && (
                <tr>
                  <td colSpan="6" className="px-5 py-12 text-center text-[13px] text-gray-400">
                    Aucune course pour le moment
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
