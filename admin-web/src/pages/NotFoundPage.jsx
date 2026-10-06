import { useNavigate } from 'react-router-dom';

export default function NotFoundPage() {
  const navigate = useNavigate();
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-[#f8f9fa]">
      <p className="text-[80px] font-bold text-gray-200 leading-none">404</p>
      <p className="text-[18px] font-semibold text-gray-800 mt-2">Page introuvable</p>
      <p className="text-[14px] text-gray-400 mt-1 mb-6">Cette page n'existe pas ou a été déplacée.</p>
      <button
        onClick={() => navigate('/')}
        className="px-5 py-2.5 bg-gray-900 text-white text-[13px] font-medium rounded-xl hover:bg-gray-800 transition-colors"
      >
        Retour au dashboard
      </button>
    </div>
  );
}
