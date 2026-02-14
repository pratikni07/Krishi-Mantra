import axios from "axios";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

// Create axios instances for each service
export const mainApi = axios.create({
  baseURL: `${API_BASE}/main`,
  headers: {
    "Content-Type": "application/json",
  },
});

export const feedApi = axios.create({
  baseURL: `${API_BASE}/feed`,
  headers: {
    "Content-Type": "application/json",
  },
});

export const reelApi = axios.create({
  baseURL: `${API_BASE}/reels`,
  headers: {
    "Content-Type": "application/json",
  },
});

export const notificationApi = axios.create({
  baseURL: `${API_BASE}/notification`,
  headers: {
    "Content-Type": "application/json",
  },
});

export const engagementApi = axios.create({
  baseURL: `${API_BASE}/engagement`,
  headers: {
    "Content-Type": "application/json",
  },
});

// Add auth token to requests
const addAuthInterceptor = (instance: typeof mainApi) => {
  instance.interceptors.request.use(
    (config) => {
      if (typeof window !== "undefined") {
        const token = localStorage.getItem("admin_token");
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
      }
      return config;
    },
    (error) => Promise.reject(error)
  );

  instance.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response?.status === 401) {
        if (typeof window !== "undefined") {
          localStorage.removeItem("admin_token");
          localStorage.removeItem("auth-storage");
          window.location.href = "/auth/login";
        }
      }
      return Promise.reject(error);
    }
  );
};

addAuthInterceptor(mainApi);
addAuthInterceptor(feedApi);
addAuthInterceptor(reelApi);
addAuthInterceptor(notificationApi);
addAuthInterceptor(engagementApi);

// Auth APIs
export const authAPI = {
  login: (data: { email: string; password: string }) =>
    mainApi.post("/auth/admin/login", data),
  getPendingOTPs: () => mainApi.get("/auth/admin/pending-otps"),
  markOTPSent: (otpId: string) =>
    mainApi.put(`/auth/admin/mark-otp-sent/${otpId}`),
};

// User APIs
export const userAPI = {
  getUsers: (page = 1, limit = 10) =>
    mainApi.get(`/user/users?page=${page}&limit=${limit}`),
  getUserById: (id: string) => mainApi.get(`/user/users/${id}`),
  searchUsers: (query: string) =>
    mainApi.get(`/user/username/search?query=${query}`),
  updateSubscription: (userId: string, data: any) =>
    mainApi.put("/user/subscription", { userId, ...data }),
};

// News APIs
export const newsAPI = {
  getNews: (page = 1, limit = 50) =>
    mainApi.get(`/news/?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/news/${id}`),
  createNews: (data: any) => mainApi.post("/news/", data),
  updateNews: (id: string, data: any) => mainApi.put(`/news/${id}`, data),
  deleteNews: (id: string) => mainApi.delete(`/news/${id}`),
  search: (query: string) => mainApi.get(`/news/search?q=${query}`),
};

// Company APIs
export const companyAPI = {
  getCompanies: (page = 1, limit = 50) =>
    mainApi.get(`/companies/?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/companies/${id}`),
  createCompany: (data: any) => mainApi.post("/companies/", data),
  updateCompany: (id: string, data: any) => mainApi.patch(`/companies/${id}`, data),
  deleteCompany: (id: string) => mainApi.delete(`/companies/${id}`),
  verifyCompany: (id: string) => mainApi.put(`/companies/${id}/verify`),
};

// Product APIs
export const productAPI = {
  getProducts: (page = 1, limit = 50) =>
    mainApi.get(`/products/?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/products/${id}`),
  createProduct: (data: any) => mainApi.post("/products/", data),
  updateProduct: (id: string, data: any) => mainApi.patch(`/products/${id}`, data),
  deleteProduct: (id: string) => mainApi.delete(`/products/${id}`),
};

// Advertisement APIs
export const adsAPI = {
  // Home Ads
  getHomeAds: () => mainApi.get("/ads/home-ads"),
  createHomeAd: (data: any) => mainApi.post("/ads/home-ads", data),
  updateHomeAd: (id: string, data: any) =>
    mainApi.put(`/ads/home-ads/${id}`, data),
  deleteHomeAd: (id: string) => mainApi.delete(`/ads/home-ads/${id}`),

  // Home Screen Ads
  getHomeScreenAds: () => mainApi.get("/ads/home-screen-ads"),
  createHomeScreenAd: (data: any) => mainApi.post("/ads/home-screen-ads", data),
  updateHomeScreenAd: (id: string, data: any) =>
    mainApi.put(`/ads/home-screen-ads/${id}`, data),
  deleteHomeScreenAd: (id: string) =>
    mainApi.delete(`/ads/home-screen-ads/${id}`),

  // Splash Ads
  getSplashAds: () => mainApi.get("/ads/splash-modal"),
  createSplashAd: (data: any) => mainApi.post("/ads/splash-modal", data),
  updateSplashAd: (id: string, data: any) =>
    mainApi.put(`/ads/splash-modal/${id}`, data),
  deleteSplashAd: (id: string) => mainApi.delete(`/ads/splash-modal/${id}`),

  // Feed Ads
  getFeedAds: () => mainApi.get("/ads/feed-ads"),
  createFeedAd: (data: any) => mainApi.post("/ads/feed-ads", data),
  updateFeedAd: (id: string, data: any) =>
    mainApi.put(`/ads/feed-ads/${id}`, data),
  deleteFeedAd: (id: string) => mainApi.delete(`/ads/feed-ads/${id}`),

  // Reel Ads
  getReelAds: () => mainApi.get("/ads/reel-ads"),
  createReelAd: (data: any) => mainApi.post("/ads/reel-ads", data),
  updateReelAd: (id: string, data: any) =>
    mainApi.put(`/ads/reel-ads/${id}`, data),
  deleteReelAd: (id: string) => mainApi.delete(`/ads/reel-ads/${id}`),

  // News Ads
  getNewsAds: () => mainApi.get("/ads/news-ads"),
  createNewsAd: (data: any) => mainApi.post("/ads/news-ads", data),
  updateNewsAd: (id: string, data: any) =>
    mainApi.put(`/ads/news-ads/${id}`, data),
  deleteNewsAd: (id: string) => mainApi.delete(`/ads/news-ads/${id}`),

  // Display Settings
  getDisplaySettings: () => mainApi.get("/ads/display"),
  updateDisplaySettings: (data: any) =>
    mainApi.put("/ads/display-settings", data),
};

// Analytics APIs
export const analyticsAPI = {
  getDashboardStats: (timeframe = "week") =>
    mainApi.get(`/analytics/dashboard-stats?timeframe=${timeframe}`),
  getGeoData: () => mainApi.get("/analytics/geo-data"),
  getFeedStats: () => feedApi.get("/analytics/stats"),
  getReelStats: () => reelApi.get("/analytics/stats"),
};

// Engagement/Activity Tracking APIs
export const engagementAPI = {
  // Dashboard
  getDashboard: (params?: { startDate?: string; endDate?: string; timeframe?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    if (params?.timeframe) query.append("timeframe", params.timeframe);
    return engagementApi.get(`/analytics/dashboard?${query.toString()}`);
  },
  getRealTimeStats: () => engagementApi.get("/analytics/realtime"),
  getPeriodComparison: (params?: { startDate?: string; endDate?: string; compareWith?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    if (params?.compareWith) query.append("compareWith", params.compareWith);
    return engagementApi.get(`/analytics/comparison?${query.toString()}`);
  },

  // Engagement Analytics
  getEngagementBreakdown: (params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/engagement?${query.toString()}`);
  },
  getFeatureUsage: (params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/features?${query.toString()}`);
  },
  getTopContent: (params?: { startDate?: string; endDate?: string; limit?: number }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    if (params?.limit) query.append("limit", String(params.limit));
    return engagementApi.get(`/analytics/content?${query.toString()}`);
  },

  // Session Analytics
  getSessionAnalytics: (params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/sessions?${query.toString()}`);
  },
  getTopScreens: (params?: { startDate?: string; endDate?: string; limit?: number }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    if (params?.limit) query.append("limit", String(params.limit));
    return engagementApi.get(`/analytics/screens?${query.toString()}`);
  },
  getHourlyPattern: (params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/hourly?${query.toString()}`);
  },

  // User Analytics
  getUserAnalytics: (userId: string, params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/users/${userId}?${query.toString()}`);
  },
  getLeaderboard: (params?: { metric?: string; limit?: number; startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.metric) query.append("metric", params.metric);
    if (params?.limit) query.append("limit", String(params.limit));
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/leaderboard?${query.toString()}`);
  },

  // Retention and Churn
  getRetentionMetrics: (params?: { startDate?: string; endDate?: string }) => {
    const query = new URLSearchParams();
    if (params?.startDate) query.append("startDate", params.startDate);
    if (params?.endDate) query.append("endDate", params.endDate);
    return engagementApi.get(`/analytics/retention?${query.toString()}`);
  },
  getChurnRiskAnalysis: (params?: { threshold?: number }) => {
    const query = new URLSearchParams();
    if (params?.threshold) query.append("threshold", String(params.threshold));
    return engagementApi.get(`/analytics/churn?${query.toString()}`);
  },
};

// Scheme APIs
export const schemeAPI = {
  getSchemes: (page = 1, limit = 50) =>
    mainApi.get(`/schemes/schemes?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/schemes/schemes/${id}`),
  createScheme: (data: any) => mainApi.post("/schemes/schemes", data),
  updateScheme: (id: string, data: any) => mainApi.put(`/schemes/schemes/${id}`, data),
  deleteScheme: (id: string) => mainApi.delete(`/schemes/schemes/${id}`),
};

// Service APIs
export const serviceAPI = {
  getServices: (page = 1, limit = 50) =>
    mainApi.get(`/service/?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/service/${id}`),
  createService: (data: any) => mainApi.post("/service/", data),
  updateService: (id: string, data: any) => mainApi.put(`/service/${id}`, data),
  deleteService: (id: string) => mainApi.delete(`/service/${id}`),
};

// Feed APIs
export const feedsAPI = {
  getFeeds: (page = 1, limit = 20) =>
    feedApi.get(`/feeds/getAllFeedsAdmin?page=${page}&limit=${limit}`),
  getById: (id: string) => feedApi.get(`/feeds/${id}`),
  createFeed: (data: any) => feedApi.post("/feeds/", data),
  deleteFeed: (id: string) => feedApi.delete(`/feeds/${id}`),
  approveFeed: (id: string) => feedApi.put(`/feeds/${id}/approve`),
  getTrendingHashtags: () => feedApi.get("/feeds/trending/hashtags"),
};

// Reel APIs
export const reelsAPI = {
  getReels: (page = 1, limit = 30) =>
    reelApi.get(`/reels/?page=${page}&limit=${limit}`),
  getById: (id: string) => reelApi.get(`/reels/${id}`),
  createReel: (data: any) => reelApi.post("/reels/", data),
  deleteReel: (id: string) => reelApi.delete(`/reels/${id}`),
  approveReel: (id: string) => reelApi.put(`/reels/${id}/approve`),
  getTrending: () => reelApi.get("/reels/trending"),
  getTrendingTags: () => reelApi.get("/reels/tags/trending"),
};

// Video Tutorial APIs
export const videosAPI = {
  getVideos: (page = 1, limit = 30) =>
    reelApi.get(`/videos/?page=${page}&limit=${limit}`),
  getById: (id: string) => reelApi.get(`/videos/${id}`),
  createVideo: (data: any) => reelApi.post("/videos/", data),
  updateVideo: (id: string, data: any) => reelApi.put(`/videos/${id}`, data),
  deleteVideo: (id: string) => reelApi.delete(`/videos/${id}`),
  search: (query: string) => reelApi.get(`/videos/search?q=${query}`),
};

// Marketplace APIs
export const marketplaceAPI = {
  getAll: (page = 1, limit = 10) =>
    mainApi.get(`/marketplace/?page=${page}&limit=${limit}`),
  getById: (id: string) => mainApi.get(`/marketplace/${id}`),
  create: (data: any) => mainApi.post("/marketplace/", data),
  update: (id: string, data: any) => mainApi.put(`/marketplace/${id}`, data),
  delete: (id: string) => mainApi.delete(`/marketplace/${id}`),
  search: (query: string) => mainApi.get(`/marketplace/search?q=${query}`),
  getTrendingTags: () => mainApi.get("/marketplace/trending-tags"),
};

// Notification APIs
export const notificationAPI = {
  getNotifications: (page = 1, limit = 50) =>
    notificationApi.get(`/notifications?page=${page}&limit=${limit}`),
  sendNotification: (data: any) => notificationApi.post("/notifications", data),
  createBulk: (notifications: any[]) =>
    notificationApi.post("/notifications/bulk", { notifications }),
  getUserNotifications: (userId: string, page = 1, limit = 20) =>
    notificationApi.get(
      `/users/${userId}/notifications?page=${page}&limit=${limit}`
    ),
  getUserPreferences: (userId: string) =>
    notificationApi.get(`/users/${userId}/preferences`),
  updateUserPreferences: (userId: string, data: any) =>
    notificationApi.put(`/users/${userId}/preferences`, data),
};

// Crop Calendar APIs
export const cropCalendarAPI = {
  getCalendar: () => mainApi.get("/crop-calendar/crops"),
  getEntries: () => mainApi.get("/crop-calendar/crops"),
  createEntry: (data: any) => mainApi.post("/crop-calendar/crops", data),
  updateEntry: (id: string, data: any) =>
    mainApi.put(`/crop-calendar/crops/${id}`, data),
  deleteEntry: (id: string) => mainApi.delete(`/crop-calendar/crops/${id}`),
  getActivities: () => mainApi.get("/crop-calendar/activities"),
  createActivity: (data: any) =>
    mainApi.post("/crop-calendar/activities", data),
  getRegions: () => mainApi.get("/crop-calendar/regions"),
  createRegion: (data: any) => mainApi.post("/crop-calendar/regions", data),
};

// Subscription APIs (Super Admin)
export const subscriptionAPI = {
  // Plan Management
  getPlans: () => mainApi.get("/subscription/plans"),
  createPlan: (data: any) => mainApi.post("/subscription/admin/plans", data),
  updatePlan: (id: string, data: any) =>
    mainApi.put(`/subscription/admin/plans/${id}`, data),
  deletePlan: (id: string) => mainApi.delete(`/subscription/admin/plans/${id}`),

  // User Subscription Management
  getAllSubscriptions: (page = 1, limit = 20, filters?: { status?: string; planName?: string }) => {
    const params = new URLSearchParams({ page: String(page), limit: String(limit) });
    if (filters?.status) params.append("status", filters.status);
    if (filters?.planName) params.append("planName", filters.planName);
    return mainApi.get(`/subscription/admin/subscriptions?${params.toString()}`);
  },
  getUserSubscription: (userId: string) =>
    mainApi.get(`/subscription/admin/user/${userId}`),
  updateUserSubscription: (userId: string, data: any) =>
    mainApi.put(`/subscription/admin/user/${userId}`, data),
  cancelUserSubscription: (userId: string, data?: { reason?: string; cancelImmediately?: boolean }) =>
    mainApi.post(`/subscription/admin/user/${userId}/cancel`, data),

  // Subscription Stats
  getStats: () => mainApi.get("/subscription/admin/stats"),
  getRevenueStats: (timeframe = "month") =>
    mainApi.get(`/subscription/admin/revenue?timeframe=${timeframe}`),

  // Usage Stats
  getUserUsageStats: (userId: string) =>
    mainApi.get(`/subscription/admin/user/${userId}/usage`),
  resetUserUsage: (userId: string) =>
    mainApi.post(`/subscription/admin/user/${userId}/reset-usage`),
};

// IoT Add-on APIs (Super Admin)
export const iotAddonAPI = {
  // Add-on Management
  getAddons: () => mainApi.get("/subscription/iot/addons"),
  createAddon: (data: any) => mainApi.post("/subscription/admin/iot/addons", data),
  updateAddon: (id: string, data: any) =>
    mainApi.put(`/subscription/admin/iot/addons/${id}`, data),
  deleteAddon: (id: string) => mainApi.delete(`/subscription/admin/iot/addons/${id}`),

  // User IoT Subscriptions
  getAllUserAddons: (page = 1, limit = 20) =>
    mainApi.get(`/subscription/admin/iot/subscriptions?page=${page}&limit=${limit}`),
  getUserAddons: (userId: string) =>
    mainApi.get(`/subscription/admin/iot/user/${userId}`),
  cancelUserAddon: (userId: string, addonName: string, data?: { reason?: string }) =>
    mainApi.post(`/subscription/admin/iot/user/${userId}/cancel`, { addonName, ...data }),

  // Device Management
  getLinkedDevices: (page = 1, limit = 50) =>
    mainApi.get(`/subscription/admin/iot/devices?page=${page}&limit=${limit}`),
  unlinkDevice: (userId: string, addonName: string, deviceId: string) =>
    mainApi.post(`/subscription/admin/iot/device/unlink`, { userId, addonName, deviceId }),

  // IoT Stats
  getIotStats: () => mainApi.get("/subscription/admin/iot/stats"),
};
