import { useEffect } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import { AuthSlider } from "@/components/AuthSlider";
import AuthPageDesktop from "@/pages/AuthPageDesktop";
import HomePage from "@/pages/HomePage";
import ShareMusicPage from "@/pages/ShareMusicPage";
import { Toast } from "@/components/Toast";
import { useAuthStore } from "@/store/authStore";
import { useIsDesktop } from "@/hooks/useIsDesktop";

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

/** 桌面端使用分栏版认证页，移动端保留滑动切换的 AuthSlider。 */
function AuthGateway() {
  const isDesktop = useIsDesktop();
  if (isDesktop) return <AuthPageDesktop />;
  return <AuthSlider />;
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useAuthStore((state) => state.user);
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

export default function App() {
  return (
    <Router>
      <AuthInitializer />
      <PortraitLocker />
      <Routes>
        {/* 默认显示页：登录页 */}
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<AuthGateway />} />
        <Route path="/register" element={<AuthGateway />} />
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
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
      {/* 全局通用 Toast 提示，复用悦音乐胶囊样式 */}
      <Toast />
    </Router>
  );
}
