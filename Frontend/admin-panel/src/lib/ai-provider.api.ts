import axios from "axios";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

const aiAdminApi = axios.create({
  baseURL: `${API_BASE}/admin/ai-provider`,
  headers: { "Content-Type": "application/json" },
});

aiAdminApi.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = localStorage.getItem("admin_token");
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

aiAdminApi.interceptors.response.use(
  (r) => r,
  (error) => {
    if (error.response?.status === 401 && typeof window !== "undefined") {
      localStorage.removeItem("admin_token");
    }
    return Promise.reject(error);
  }
);

export type ProviderType = "openai" | "vertex";
export type CredentialType = "api_key" | "service_account_json" | "wif";

export interface ProviderModels {
  chat: string;
  vision: string;
  embed: string;
}

export interface ProviderConfigSummary {
  _id: string;
  provider: ProviderType;
  displayName: string;
  models: ProviderModels;
  extras?: Record<string, unknown>;
  status: "unvalidated" | "valid" | "credential_invalid" | "error";
  lastValidatedAt?: string | null;
  lastError?: string | null;
  autoFallback?: boolean;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
  credentials?: {
    type: CredentialType;
    fingerprint: string;
    lastRotatedAt?: string;
    keyCount?: number;
  };
}

export interface AuditEntry {
  _id: string;
  configId?: string;
  provider: ProviderType;
  action:
    | "create"
    | "update"
    | "validate"
    | "activate"
    | "deactivate"
    | "rotate"
    | "delete";
  actor?: string;
  diff?: Record<string, unknown>;
  at: string;
  ip?: string;
  userAgent?: string;
}

function unwrap<T>(promise: Promise<{ data: T }>): Promise<T> {
  return promise.then((r) => r.data);
}

// Stats endpoints live on message-svc; same auth, separate gateway proxy.
const aiStatsApi = axios.create({
  baseURL: `${API_BASE}/admin/ai-stats`,
  headers: { "Content-Type": "application/json" },
});
aiStatsApi.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = localStorage.getItem("admin_token");
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export interface UsageSummary {
  since: string;
  activeProvider: string | null;
  chats: number;
  turns: number;
  tokens: { prompt: number; cached: number; completion: number };
  cacheHitRate: number;
  estimatedUsdCost: number;
  globalMinuteCostUsd: number;
}

export interface ModelBreakdownEntry {
  model: string;
  provider: string;
  turns: number;
  promptTokens: number;
  cachedTokens: number;
  completionTokens: number;
  costUsd: number;
}

export const aiStats = {
  summary: () => unwrap<{ success: boolean } & UsageSummary>(aiStatsApi.get("/summary")),
  models: () =>
    unwrap<{ success: boolean; breakdown: ModelBreakdownEntry[] }>(
      aiStatsApi.get("/models")
    ),
};

export const aiProviderApi = {
  list: () =>
    unwrap<{ success: boolean; configs: ProviderConfigSummary[] }>(
      aiAdminApi.get("/")
    ),
  getOne: (id: string) =>
    unwrap<{ success: boolean; config: ProviderConfigSummary }>(
      aiAdminApi.get(`/${id}`)
    ),
  audit: (configId?: string) =>
    unwrap<{ success: boolean; audit: AuditEntry[] }>(
      aiAdminApi.get(`/audit`, { params: configId ? { configId } : {} })
    ),
  upsertOpenAI: (payload: {
    id?: string;
    displayName: string;
    apiKeys: string[] | string;
    models: ProviderModels;
    extras?: Record<string, unknown>;
  }) => {
    if (payload.id) {
      return unwrap<{ success: boolean; config: ProviderConfigSummary }>(
        aiAdminApi.put(`/openai/${payload.id}`, payload)
      );
    }
    return unwrap<{ success: boolean; config: ProviderConfigSummary }>(
      aiAdminApi.post(`/openai`, payload)
    );
  },
  upsertVertex: (payload: {
    id?: string;
    displayName: string;
    serviceAccountJson: string | Record<string, unknown>;
    models: ProviderModels;
    extras?: Record<string, unknown>;
  }) => {
    if (payload.id) {
      return unwrap<{ success: boolean; config: ProviderConfigSummary }>(
        aiAdminApi.put(`/vertex/${payload.id}`, payload)
      );
    }
    return unwrap<{ success: boolean; config: ProviderConfigSummary }>(
      aiAdminApi.post(`/vertex`, payload)
    );
  },
  activate: (id: string) =>
    unwrap<{ success: boolean; config: ProviderConfigSummary }>(
      aiAdminApi.post(`/${id}/activate`)
    ),
  deactivateAll: () =>
    unwrap<{ success: boolean; deactivated: number }>(
      aiAdminApi.post(`/deactivate`)
    ),
  remove: (id: string) =>
    unwrap<{ success: boolean; id: string }>(aiAdminApi.delete(`/${id}`)),
};
