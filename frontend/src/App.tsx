import { useEffect } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import { AuthSlider } from "@/components/AuthSlider";
import HomePage from "@/pages/HomePage";
import ShareMusicPage from "@/pages/ShareMusicPage";
import { Toast } from "@/components/Toast";
import { useAuthStore } from "@/store/authStore";

function AuthInitializer() {
  const initialize = useAuthStore((state) => state.initialize);

  useEffect(() => {
    initialize();
  }, [initialize]);

  return null;
}

function PortraitLocker() {
  useEffect(() => {
    const lock = async () => {
      try {
        await (screen.orientation as unknown as { lock?: (orientation: string) => Promise<void> }).lock?.("portrait");
      } catch {
        // Locking may fail if the browser requires a user gesture or does not
        // support the API. No fallback or prompt is shown per requirement.
      }
    };
    lock();
  }, []);

  return null;
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  // TEMP: Login protection is disabled for development. Remove this comment and bypass when restoring authentication.
  return children;
}

export default function App() {
  return (
    <Router>
      <AuthInitializer />
      <PortraitLocker />
      <Routes>
        <Route path="/" element={<Navigate to="/home" replace />} />
        <Route path="/login" element={<Navigate to="/home" replace />} />
        <Route path="/register" element={<Navigate to="/home" replace />} />
        {/* 免登录的音乐分享页：接收方打开，听 10s 后弹引导框 */}
        <Route path="/share/music" element={<ShareMusicPage />} />
        <Route
          path="/home"
          element={
            <ProtectedRoute>
              <HomePage />
            </ProtectedRoute>
          }
        />
      </Routes>
      {/* 全局通用 Toast 提示，复用悦音乐胶囊样式 */}
      <Toast />
    </Router>
  );
}
