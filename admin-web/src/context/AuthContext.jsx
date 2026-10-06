import { createContext, useContext, useState, useEffect } from 'react';
import { login as apiLogin } from '../services/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (token) {
      const savedUser = localStorage.getItem('user');
      if (savedUser) {
        try {
          setUser(JSON.parse(savedUser));
        } catch {
          logout();
        }
      }
    }
  }, []);

  const login = async (phone, password) => {
    setLoading(true);
    try {
      const data = await apiLogin(phone, password);
      if (data.user.role !== 'ADMIN') {
        throw new Error('Accès réservé aux administrateurs');
      }
      localStorage.setItem('token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      localStorage.setItem('user', JSON.stringify(data.user));
      setToken(data.access_token);
      setUser(data.user);
      return true;
    } catch (e) {
      throw e;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout, isAuthenticated: !!token }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
