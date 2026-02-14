import { create } from "zustand";
import { persist } from "zustand/middleware";

interface Admin {
  _id: string;
  name: string;
  email: string;
  role: string;
}

interface AuthState {
  admin: Admin | null;
  token: string | null;
  isAuthenticated: boolean;
  setAuth: (admin: Admin, token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      admin: null,
      token: null,
      isAuthenticated: false,
      setAuth: (admin, token) => {
        localStorage.setItem("marketplace_admin_token", token);
        set({ admin, token, isAuthenticated: true });
      },
      logout: () => {
        localStorage.removeItem("marketplace_admin_token");
        set({ admin: null, token: null, isAuthenticated: false });
        window.location.href = "/login";
      },
    }),
    {
      name: "marketplace-auth-storage",
    }
  )
);
