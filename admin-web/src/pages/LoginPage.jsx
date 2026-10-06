import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function LoginPage() {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [otpStep, setOtpStep] = useState(false);
  const [error, setError] = useState('');
  const { login, loading } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const res = await login(phone, password, otpStep ? otpCode.trim() : null);
      if (res === 'otp_required') {
        setOtpStep(true);
        return;
      }
      navigate('/');
    } catch (err) {
      setError(err.message || 'Identifiants incorrects');
    }
  };

  return (
    <div className="min-h-screen bg-[#f8f9fa] flex items-center justify-center p-4">
      <div className="w-full max-w-[380px]">
        {/* Logo */}
        <div className="text-center mb-10">
          <img
            src="/branding/logo_mark.svg"
            alt="Sönaiyaa"
            className="w-16 h-16 mx-auto mb-5"
          />
          <h1 className="text-xl font-semibold text-gray-900">Sönaiyaa</h1>
          <p className="text-gray-400 text-[13px] mt-1">Espace administration</p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl border border-gray-200/60 shadow-sm p-7">
          <form onSubmit={handleSubmit} className="space-y-5">
            {error && (
              <div className="bg-red-50 border border-red-100 text-red-600 text-[13px] px-4 py-3 rounded-xl">
                {error}
              </div>
            )}

            <div>
              <label className="block text-[13px] font-medium text-gray-700 mb-1.5">
                Telephone
              </label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="Numero de telephone"
                className="w-full bg-[#f8f9fa] border border-gray-200 rounded-xl px-4 py-3 text-[14px] text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#0c0c0c]/10 focus:border-gray-300 transition-all"
                required
              />
            </div>

            <div>
              <label className="block text-[13px] font-medium text-gray-700 mb-1.5">
                Mot de passe
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Votre mot de passe"
                className="w-full bg-[#f8f9fa] border border-gray-200 rounded-xl px-4 py-3 text-[14px] text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#0c0c0c]/10 focus:border-gray-300 transition-all"
                required
              />
            </div>

            {otpStep && (
              <div>
                <label className="block text-[13px] font-medium text-gray-700 mb-1.5">
                  Code reçu par SMS
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value)}
                  placeholder="Code à 6 chiffres"
                  className="w-full bg-[#f8f9fa] border border-gray-200 rounded-xl px-4 py-3 text-[14px] text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#0c0c0c]/10 focus:border-gray-300 transition-all"
                  required
                  autoFocus
                />
                <p className="text-[12px] text-gray-400 mt-1.5">
                  Double authentification : un code vient d'être envoyé à votre téléphone.
                </p>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#0c0c0c] text-white font-medium py-3 rounded-xl hover:bg-[#1a1a1a] transition-colors disabled:opacity-50 text-[14px] mt-1"
            >
              {loading ? 'Connexion...' : otpStep ? 'Valider le code' : 'Se connecter'}
            </button>
          </form>
        </div>

        <p className="text-center text-gray-400 text-[12px] mt-6">
          Acces reserve aux administrateurs
        </p>
      </div>
    </div>
  );
}
