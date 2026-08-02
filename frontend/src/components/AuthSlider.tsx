import { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";
import LoginPage from "@/pages/LoginPage";
import RegisterPage from "@/pages/RegisterPage";

export function AuthSlider() {
  const location = useLocation();
  const isRegister = location.pathname === "/register";
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setMounted(true), 10);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="fixed inset-0 overflow-hidden bg-white">
      <div
        className={cn(
          "flex h-full w-[200%] transition-transform duration-500",
          mounted ? "ease-[cubic-bezier(0.25,0.1,0.25,1)]" : "ease-linear"
        )}
        style={{
          transform: `translateX(${isRegister ? "-50%" : "0%"})`,
        }}
      >
        <div className="h-full w-1/2 overflow-y-auto">
          <LoginPage />
        </div>
        <div className="h-full w-1/2 overflow-y-auto">
          <RegisterPage />
        </div>
      </div>
    </div>
  );
}
