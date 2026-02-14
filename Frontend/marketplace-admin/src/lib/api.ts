import axios from "axios";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

// Create axios instance for main service
export const api = axios.create({
  baseURL: `${API_BASE}/main`,
  headers: {
    "Content-Type": "application/json",
  },
});

// Add auth token to requests
api.interceptors.request.use(
  (config) => {
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("marketplace_admin_token");
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => Promise.reject(error)
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      if (typeof window !== "undefined") {
        localStorage.removeItem("marketplace_admin_token");
        localStorage.removeItem("marketplace-auth-storage");
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

// Auth APIs
export const authAPI = {
  login: (data: { email: string; password: string }) =>
    api.post("/auth/admin/login", data),
};

// Marketplace Product APIs
export const marketplaceAPI = {
  // Get all products (simplified)
  getAll: (page = 1, limit = 20) =>
    api.get(`/marketplace/?page=${page}&limit=${limit}`),

  // Search products with filters
  search: (params: {
    keyword?: string;
    category?: string;
    minPrice?: number;
    maxPrice?: number;
    condition?: string;
    tags?: string;
  }) => {
    const queryParams = new URLSearchParams();
    if (params.keyword) queryParams.append("keyword", params.keyword);
    if (params.category) queryParams.append("category", params.category);
    if (params.minPrice) queryParams.append("minPrice", params.minPrice.toString());
    if (params.maxPrice) queryParams.append("maxPrice", params.maxPrice.toString());
    if (params.condition) queryParams.append("condition", params.condition);
    if (params.tags) queryParams.append("tags", params.tags);
    return api.get(`/marketplace/search?${queryParams.toString()}`);
  },

  // Get trending tags
  getTrendingTags: () => api.get("/marketplace/trending-tags"),

  // Get single product by ID
  getById: (id: string) => api.get(`/marketplace/${id}`),

  // Get product comments with pagination
  getComments: (productId: string, page = 1, limit = 10) =>
    api.get(`/marketplace/${productId}/comments?page=${page}&limit=${limit}`),

  // Create new product
  create: (data: {
    userId: string;
    title: string;
    shortDescription: string;
    detailedDescription: string;
    media: Array<{ type: "image" | "video"; url: string; isYoutubeVideo?: boolean }>;
    priceRange: { min: number; max: number; currency?: string };
    contactNumber?: string;
    category: string;
    condition: "New" | "Used" | "Refurbished";
    location: string;
    tags: string[];
    rating?: number;
  }) => api.post("/marketplace/", data),

  // Update product
  update: (id: string, data: Partial<{
    title: string;
    shortDescription: string;
    detailedDescription: string;
    media: Array<{ type: "image" | "video"; url: string; isYoutubeVideo?: boolean }>;
    priceRange: { min: number; max: number; currency?: string };
    contactNumber: string;
    category: string;
    condition: "New" | "Used" | "Refurbished";
    location: string;
    tags: string[];
    status: "active" | "sold" | "unavailable";
  }>) => api.put(`/marketplace/${id}`, data),

  // Delete product
  delete: (id: string) => api.delete(`/marketplace/${id}`),

  // Add comment to product
  addComment: (productId: string, data: { userId: string; text: string }) =>
    api.post(`/marketplace/${productId}/comment`, data),

  // Add reply to comment
  addReply: (
    productId: string,
    commentId: string,
    data: { userId: string; text: string }
  ) => api.post(`/marketplace/${productId}/comment/${commentId}/reply`, data),

  // Update product rating
  updateRating: (id: string, rating: number) =>
    api.patch(`/marketplace/${id}/rating`, { rating }),
};

// Company APIs
export const companyAPI = {
  // Get all companies
  getAll: (page = 1, limit = 50) =>
    api.get(`/companies/?page=${page}&limit=${limit}`),

  // Get single company with products
  getById: (id: string) => api.get(`/companies/${id}`),

  // Create company
  create: (data: {
    name: string;
    email: string;
    address: { street: string; city: string; state: string; zip: string };
    phone: string;
    website: string;
    description: string;
    logo: string;
    rating: number;
  }) => api.post("/companies/", data),

  // Update company
  update: (id: string, data: Partial<{
    name: string;
    email: string;
    address: { street: string; city: string; state: string; zip: string };
    phone: string;
    website: string;
    description: string;
    logo: string;
    rating: number;
  }>) => api.patch(`/companies/${id}`, data),

  // Delete company
  delete: (id: string) => api.delete(`/companies/${id}`),
};

// Company Products APIs
export const productAPI = {
  // Get all products
  getAll: (page = 1, limit = 50) =>
    api.get(`/products/?page=${page}&limit=${limit}`),

  // Get single product
  getById: (id: string) => api.get(`/products/${id}`),

  // Create product
  create: (data: {
    companyId: string;
    name: string;
    image: string;
    usage: string;
    usedFor: string;
  }) => api.post("/products/", data),

  // Update product
  update: (id: string, data: Partial<{
    name: string;
    image: string;
    usage: string;
    usedFor: string;
  }>) => api.patch(`/products/${id}`, data),

  // Delete product
  delete: (id: string) => api.delete(`/products/${id}`),
};

// Analytics APIs
export const analyticsAPI = {
  getDashboardStats: (timeframe = "week") =>
    api.get(`/analytics/dashboard-stats?timeframe=${timeframe}`),
  getGeoData: (timeframe = "week") =>
    api.get(`/analytics/geo-data?timeframe=${timeframe}`),
};

// User APIs (for seller info)
export const userAPI = {
  getById: (id: string) => api.get(`/user/users/${id}`),
  search: (query: string) => api.get(`/user/username/search?query=${query}`),
};
