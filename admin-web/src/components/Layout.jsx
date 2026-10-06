import { useState } from 'react';
import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { LayoutDashboard, Truck, Store, Package, LogOut, Menu, X, Wallet, Users, ShieldCheck, FlaskConical } from 'lucide-react';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/validation', label: 'Validation', icon: ShieldCheck },
  { to: '/livreurs', label: 'Livreurs', icon: Truck },
  { to: '/expediteurs', label: 'Expéditeurs', icon: Store },
  { to: '/courses', label: 'Courses', icon: Package },
  { to: '/retraits', label: 'Retraits', icon: Wallet },
  { to: '/users', label: 'Utilisateurs', icon: Users },
  { to: '/comptes-test', label: 'Comptes test', icon: FlaskConical },
];

const pageTitles = {
  '/': 'Dashboard',
  '/validation': 'Validation des comptes',
  '/livreurs': 'Livreurs',
  '/expediteurs': 'Expéditeurs',
  '/courses': 'Courses',
  '/retraits': 'Retraits wallet',
  '/users': 'Utilisateurs',
  '/comptes-test': 'Comptes test',
};

export default function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const pageTitle = pageTitles[location.pathname] || 'Dashboard';

  return (
    <div className="flex h-screen bg-[#f8f9fa]">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/40 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`
        fixed inset-y-0 left-0 z-50 w-[260px] bg-[#0c0c0c] text-white flex flex-col
        transform transition-transform duration-200 ease-in-out
        lg:relative lg:translate-x-0
        ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}
      `}>
        <div className="px-6 py-6 border-b border-white/[0.08] flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white flex items-center justify-center shrink-0">
            <img
              src="/branding/logo_mark.svg"
              alt="Sönaiyaa"
              className="w-7 h-7"
            />
          </div>
          <div className="min-w-0">
            <h1 className="text-[15px] font-semibold tracking-tight leading-tight">Sönaiyaa</h1>
            <p className="text-[12px] text-white/40 leading-tight mt-0.5">Administration</p>
          </div>
        </div>

        <nav className="flex-1 py-3 px-3">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-2.5 rounded-lg text-[14px] font-medium transition-colors mb-0.5 ${
                  isActive
                    ? 'bg-white/[0.1] text-white'
                    : 'text-white/50 hover:text-white/80 hover:bg-white/[0.05]'
                }`
              }
            >
              <Icon size={18} strokeWidth={1.8} />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 mx-3 mb-3 rounded-lg bg-white/[0.05]">
          <p className="text-[13px] text-white/50 truncate">
            {user?.phone || 'Admin'}
          </p>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 text-[13px] text-white/40 hover:text-white/70 transition-colors mt-2"
          >
            <LogOut size={14} />
            Se deconnecter
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top header */}
        <header className="bg-white border-b border-gray-200/60 px-6 py-4 flex items-center gap-4 shrink-0">
          <button
            onClick={() => setSidebarOpen(true)}
            className="lg:hidden p-1.5 -ml-1.5 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <Menu size={20} className="text-gray-600" />
          </button>
          <h2 className="text-[16px] font-semibold text-gray-900">{pageTitle}</h2>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-auto">
          <div className="p-6 lg:p-8 max-w-[1400px]">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
