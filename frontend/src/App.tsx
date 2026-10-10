import { useCallback, useEffect, useState } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import { AuthSlider } from "@/components/AuthSlider";
import AuthPageDesktop from "@/pages/AuthPageDesktop";
import HomePage from "@/pages/HomePage";
import SchedulePage from "@/pages/SchedulePage";
import WorkplacePage from "@/pages/WorkplacePage";
import AgreementPage from "@/pages/AgreementPage";
import ShareMusicPage from "@/pages/ShareMusicPage";
import ForgotPasswordPage from "@/pages/ForgotPasswordPage";
import TripPage from "@/pages/TripPage";
import CreateTripPage from "@/pages/CreateTripPage";
import { Toast } from "@/components/Toast";
import { SplashScreen } from "@/components/SplashScreen";
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
  const initialized = useAuthStore((state) => state.initialized);
  // 会话本地恢复中不渲染也不重定向：刷新后停留在当前页（含 /trip 等子页面），
  // 避免 user 尚未从 localStorage 恢复时被误踢到登录页再跳回首页。
  if (!initialized) {
    return null;
  }
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

/** 开屏：进入网站时显示 3s（不允许跳过），切换浏览器标签页回来时重新显示 3s。 */
function SplashGate() {
  // key 递增：每次显示重放开屏动画并重置 3s 计时
  const [splashKey, setSplashKey] = useState(0);
  const [mounted, setMounted] = useState(true);
  const [fadingOut, setFadingOut] = useState(false);

  useEffect(() => {
    const onVisibility = () => {
      if (document.visibilityState === "visible") {
        setFadingOut(false);
        setMounted(true);
        setSplashKey((key) => key + 1);
      }
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  const handleDone = useCallback(() => setFadingOut(true), []);
  const handleExited = useCallback(() => setMounted(false), []);

  if (!mounted) {
    return null;
  }
  return (
    <SplashScreen
      key={splashKey}
      fadingOut={fadingOut}
      onDone={handleDone}
      onExited={handleExited}
    />
  );
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
        {/* 找回 Porten 账号独立页面：登录页「忘记密码？」进入，免登录态 */}
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        {/* 免登录的音乐分享页：接收方打开，听 10s 后弹引导框 */}
        <Route path="/share/music" element={<ShareMusicPage />} />
        <Route
          path="/trip"
          element={
            <ProtectedRoute>
              <TripPage />
            </ProtectedRoute>
          }
        />
        {/* 创建我的行程独立页面：从行程页滑入，完成后滑出返回 */}
        <Route
          path="/trip/create"
          element={
            <ProtectedRoute>
              <CreateTripPage />
            </ProtectedRoute>
          }
        />
        {/* 我的日程独立页面：从消息页顶部栏加号菜单进入 */}
        <Route
          path="/schedule"
          element={
            <ProtectedRoute>
              <SchedulePage />
            </ProtectedRoute>
          }
        />
        {/* 跨儿职场独立页面：从消息页顶部栏加号菜单进入 */}
        <Route
          path="/workplace"
          element={
            <ProtectedRoute>
              <WorkplacePage />
            </ProtectedRoute>
          }
        />
        {/* 创建约定独立页面：从消息页顶部栏加号菜单进入 */}
        <Route
          path="/agreement"
          element={
            <ProtectedRoute>
              <AgreementPage />
            </ProtectedRoute>
          }
        />
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
      {/* 开屏效果：首次进入与切回标签页时显示 */}
      <SplashGate />
    </Router>
  );
}
