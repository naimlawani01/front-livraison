import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import LivreursPage from './pages/LivreursPage';
import ExpediteursPage from './pages/ExpediteursPage';
import CoursesPage from './pages/CoursesPage';
import RetraitsPage from './pages/RetraitsPage';
import UsersPage from './pages/UsersPage';
import ValidationPage from './pages/ValidationPage';
import TestAccountsPage from './pages/TestAccountsPage';
import NotFoundPage from './pages/NotFoundPage';

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" />;
}

function AppRoutes() {
  const { isAuthenticated } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={isAuthenticated ? <Navigate to="/" /> : <LoginPage />}
      />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="livreurs" element={<LivreursPage />} />
        <Route path="expediteurs" element={<ExpediteursPage />} />
        <Route path="courses" element={<CoursesPage />} />
        <Route path="retraits" element={<RetraitsPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="validation" element={<ValidationPage />} />
        <Route path="comptes-test" element={<TestAccountsPage />} />
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
