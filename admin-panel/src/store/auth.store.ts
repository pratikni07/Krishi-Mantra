import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface Admin {
  id: string;
  email: string;
  name: string;
  role: string;
  avatar?: string;
}

interface AuthState {
  admin: Admin | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (admin: Admin, token: string) => void;
  logout: () => void;
  setLoading: (loading: boolean) => void;
  updateAdmin: (admin: Partial<Admin>) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      admin: null,
      token: null,
      isAuthenticated: false,
      isLoading: true,

      login: (admin, token) => {
        set({ admin, token, isAuthenticated: true, isLoading: false });
        // Store token for API interceptor
        if (typeof window !== 'undefined') {
          localStorage.setItem('admin_token', token);
        }
      },

      logout: () => {
        set({ admin: null, token: null, isAuthenticated: false, isLoading: false });
        if (typeof window !== 'undefined') {
          localStorage.removeItem('admin_token');
          localStorage.removeItem('auth-storage');
        }
      },

      setLoading: (loading) => set({ isLoading: loading }),

      updateAdmin: (adminData) =>
        set((state) => ({
          admin: state.admin ? { ...state.admin, ...adminData } : null,
        })),
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        admin: state.admin,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
