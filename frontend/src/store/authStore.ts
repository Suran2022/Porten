import { create } from "zustand";
import { LoginMethod } from "@/components/LoginMethodSheet";
import {
  fetchProfile,
  getToken,
  LoginData,
  loginByEmailCode,
  loginByPassword,
  loginByPortenId,
  logout as apiLogout,
  register as apiRegister,
  removeToken,
  sendVerificationCode as apiSendVerificationCode,
  setToken,
} from "@/lib/api";

export interface AuthUser {
  id: number;
  email: string;
  nickname: string;
  avatar: string;
  backgroundUrl: string;
  portenId: string;
  role: string;
  gender?: string | null;
  friendCount: number;
  transDays: number;
  latestDiary?: string | null;
  mood?: string | null;
}

interface AuthState {
  loginMethod: LoginMethod;
  isPasswordMode: boolean;
  isCodeSent: boolean;
  countdown: number;
  isLoading: boolean;
  error: string | null;
  token: string | null;
  user: AuthUser | null;

  setLoginMethod: (method: LoginMethod) => void;
  switchToPasswordMode: () => void;
  switchToCodeMode: () => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  clearError: () => void;
  reset: () => void;
  redirectToLogin: () => void;
  initialize: () => Promise<void>;

  sendCode: (email: string) => Promise<void>;
  login: (payload: {
    email?: string;
    portenId?: string;
    password?: string;
    code?: string;
  }) => Promise<void>;
  register: (payload: {
    email: string;
    password: string;
    code: string;
  }) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (user: AuthUser) => void;
}

let countdownTimer: ReturnType<typeof setInterval> | null = null;

const mapLoginData = (data: LoginData): AuthUser => ({
  id: data.user.id,
  email: data.user.email,
  nickname: data.user.nickname,
  avatar: data.user.avatar_url,
  backgroundUrl: data.user.background_url || "",
  portenId: data.user.porten_id,
  role: data.user.role,
  gender: (data.user as { gender?: string | null }).gender ?? null,
  friendCount: (data.user as { friend_count?: number }).friend_count ?? 0,
  transDays: (data.user as { trans_days?: number }).trans_days ?? 0,
  latestDiary: (data.user as { latest_diary?: string | null }).latest_diary ?? null,
  mood: (data.user as { mood?: string | null }).mood ?? null,
});

const USER_KEY = "porten_user";

const getStoredUser = (): AuthUser | null => {
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch {
    return null;
  }
};

const setStoredUser = (user: AuthUser) => {
  localStorage.setItem(USER_KEY, JSON.stringify(user));
};

const removeStoredUser = () => {
  localStorage.removeItem(USER_KEY);
};

const setAuthSession = (token: string, user: AuthUser) => {
  setToken(token);
  setStoredUser(user);
};

export const useAuthStore = create<AuthState>((set, get) => ({
  loginMethod: "email",
  isPasswordMode: false,
  isCodeSent: false,
  countdown: 0,
  isLoading: false,
  error: null,
  token: getToken(),
  user: null,

  setLoginMethod: (method) =>
    set({
      loginMethod: method,
      isPasswordMode: method === "porten",
      isCodeSent: false,
      countdown: 0,
      error: null,
    }),

  switchToPasswordMode: () =>
    set({
      isPasswordMode: true,
      isCodeSent: false,
      countdown: 0,
      error: null,
    }),

  switchToCodeMode: () =>
    set({
      isPasswordMode: false,
      isCodeSent: true,
      countdown: 0,
      error: null,
    }),

  setLoading: (loading) => set({ isLoading: loading }),
  setError: (error) => set({ error }),
  clearError: () => set({ error: null }),

  reset: () => {
    if (countdownTimer) {
      clearInterval(countdownTimer);
      countdownTimer = null;
    }
    set({
      loginMethod: "email",
      isPasswordMode: false,
      isCodeSent: false,
      countdown: 0,
      isLoading: false,
      error: null,
      token: null,
      user: null,
    });
    removeToken();
    removeStoredUser();
  },

  logout: async () => {
    await apiLogout();
    get().reset();
  },

  redirectToLogin: () => {
    get().reset();
    const publicPaths = ["/login", "/register", "/share/music"];
    if (!publicPaths.includes(window.location.pathname)) {
      window.location.href = "/login";
    }
  },

  initialize: async () => {
    const token = getToken();
    if (!token) {
      // TEMP: Keep the app accessible without authentication during development.
      return;
    }

    const storedUser = getStoredUser();
    if (storedUser) {
      set({ token, user: storedUser });
    }

    try {
      const profile = await fetchProfile();
      const user: AuthUser = {
        id: profile.id,
        email: profile.email,
        nickname: profile.nickname,
        avatar: profile.avatar_url,
        backgroundUrl: profile.background_url || "",
        portenId: profile.porten_id,
        role: profile.role,
        gender: profile.gender ?? null,
        friendCount: profile.friend_count ?? 0,
        transDays: profile.trans_days ?? 0,
        latestDiary: profile.latest_diary ?? null,
        mood: profile.mood ?? null,
      };
      setStoredUser(user);
      set({ token, user });
    } catch (err) {
      // Only force login when the server explicitly rejects the token.
      // Network or transient errors should keep the existing session so the
      // user is not kicked out on a page refresh.
      const isAuthFailure =
        err instanceof Error &&
        /unauthorized|未授权|认证失败|未登录|expired|invalid token/i.test(
          err.message
        );
      if (isAuthFailure || !storedUser) {
        get().redirectToLogin();
      }
    }
  },

  updateUser: (user: AuthUser) => {
    setStoredUser(user);
    set({ user });
  },

  sendCode: async (email) => {
    if (countdownTimer) {
      clearInterval(countdownTimer);
      countdownTimer = null;
    }
    set({ isLoading: true, error: null });
    try {
      await apiSendVerificationCode(email, "login");
      set({ isCodeSent: true, countdown: 60, isLoading: false });
      countdownTimer = setInterval(() => {
        set((state) => {
          if (state.countdown <= 1) {
            if (countdownTimer) {
              clearInterval(countdownTimer);
              countdownTimer = null;
            }
            return { countdown: 0 };
          }
          return { countdown: state.countdown - 1 };
        });
      }, 1000);
    } catch (err) {
      set({
        isLoading: false,
        error: err instanceof Error ? err.message : "发送验证码失败",
      });
    }
  },

  login: async ({ email, portenId, password, code }) => {
    set({ isLoading: true, error: null });
    try {
      let data: LoginData;
      const method = get().loginMethod;
      if (method === "porten" && portenId && password) {
        data = await loginByPortenId(portenId, password);
      } else if (method === "email" && get().isPasswordMode && email && password) {
        data = await loginByPassword(email, password);
      } else if (method === "email" && email && code) {
        data = await loginByEmailCode(email, code);
      } else {
        throw new Error("请输入完整的登录信息");
      }
      const user = mapLoginData(data);
      setAuthSession(data.token.access_token, user);
      set({ token: data.token.access_token, user, isLoading: false });
    } catch (err) {
      const message = err instanceof Error ? err.message : "登录失败";
      set({
        isLoading: false,
        error: message,
      });
      throw new Error(message);
    }
  },

  register: async ({ email, password, code }) => {
    set({ isLoading: true, error: null });
    try {
      const data = await apiRegister(email, password, code);
      const user = mapLoginData(data);
      setAuthSession(data.token.access_token, user);
      set({ token: data.token.access_token, user, isLoading: false });
    } catch (err) {
      const message = err instanceof Error ? err.message : "注册失败";
      set({
        isLoading: false,
        error: message,
      });
      throw new Error(message);
    }
  },
}));
