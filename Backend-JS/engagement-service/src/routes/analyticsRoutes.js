/**
 * Analytics Routes
 * API endpoints for analytics and dashboard
 */

const express = require('express');
const router = express.Router();
const AnalyticsController = require('../controllers/analyticsController');

// Dashboard
router.get('/dashboard', AnalyticsController.getDashboard); // New flexible dashboard endpoint
router.get('/dashboard-summary', AnalyticsController.getDashboardSummary); // Legacy endpoint
router.get('/realtime', AnalyticsController.getRealTimeStats);
router.get('/comparison', AnalyticsController.getPeriodComparison);

// Engagement analytics
router.get('/engagement', AnalyticsController.getEngagementBreakdown);
router.get('/features', AnalyticsController.getFeatureUsage);
router.get('/content', AnalyticsController.getTopContent);

// Session analytics
router.get('/sessions', AnalyticsController.getSessionAnalytics);
router.get('/screens', AnalyticsController.getTopScreens);
router.get('/hourly', AnalyticsController.getHourlyPattern); // New hourly pattern endpoint

// User analytics
router.get('/users/:userId', AnalyticsController.getUserAnalytics);
router.get('/leaderboard', AnalyticsController.getLeaderboard);

// Retention and churn
router.get('/retention', AnalyticsController.getRetentionMetrics);
router.get('/churn', AnalyticsController.getChurnRiskAnalysis);

module.exports = router;
