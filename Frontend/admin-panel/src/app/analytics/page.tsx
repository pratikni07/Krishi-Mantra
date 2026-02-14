"use client";

import React, { useEffect, useState } from "react";
import {
  Activity,
  Users,
  Clock,
  TrendingUp,
  Eye,
  MousePointerClick,
  Smartphone,
  Calendar,
  BarChart3,
  Loader2,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { formatNumber } from "@/lib/utils";
import { engagementAPI } from "@/lib/api";
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

const COLORS = ["#22c55e", "#3b82f6", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899"];

const timeframeOptions = [
  { value: "today", label: "Today" },
  { value: "week", label: "This Week" },
  { value: "month", label: "This Month" },
  { value: "quarter", label: "This Quarter" },
];

export default function AnalyticsPage() {
  const [isLoading, setIsLoading] = useState(true);
  const [timeframe, setTimeframe] = useState("week");
  const [dashboardData, setDashboardData] = useState<any>(null);
  const [topScreens, setTopScreens] = useState<any[]>([]);
  const [featureUsage, setFeatureUsage] = useState<any[]>([]);
  const [sessionData, setSessionData] = useState<any>(null);
  const [hourlyData, setHourlyData] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchAnalyticsData();
  }, [timeframe]);

  const fetchAnalyticsData = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Fetch multiple analytics endpoints in parallel
      const [dashboardRes, screensRes, featuresRes, sessionsRes, hourlyRes] =
        await Promise.allSettled([
          engagementAPI.getDashboard({ timeframe }),
          engagementAPI.getTopScreens({ timeframe, limit: 10 }),
          engagementAPI.getFeatureUsage({ timeframe }),
          engagementAPI.getSessionAnalytics({ timeframe }),
          engagementAPI.getHourlyPattern({ timeframe }),
        ]);

      // Process dashboard data
      if (dashboardRes.status === "fulfilled" && dashboardRes.value.data.success) {
        setDashboardData(dashboardRes.value.data.data);
      }

      // Process top screens
      if (screensRes.status === "fulfilled" && screensRes.value.data.success) {
        const screens = screensRes.value.data.data || [];
        setTopScreens(screens);
      }

      // Process feature usage
      if (featuresRes.status === "fulfilled" && featuresRes.value.data.success) {
        const features = featuresRes.value.data.data || [];
        setFeatureUsage(features);
      }

      // Process session data
      if (sessionsRes.status === "fulfilled" && sessionsRes.value.data.success) {
        setSessionData(sessionsRes.value.data.data);
      }

      // Process hourly data
      if (hourlyRes.status === "fulfilled" && hourlyRes.value.data.success) {
        const hourly = hourlyRes.value.data.data || [];
        setHourlyData(hourly);
      }
    } catch (err: any) {
      setError(err.message || "Failed to fetch analytics data");
      console.error("Analytics fetch error:", err);
    } finally {
      setIsLoading(false);
    }
  };

  const formatDuration = (seconds: number): string => {
    if (seconds < 60) return `${Math.round(seconds)}s`;
    const minutes = Math.floor(seconds / 60);
    const secs = Math.round(seconds % 60);
    if (minutes < 60) return `${minutes}m ${secs}s`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return `${hours}h ${mins}m`;
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  // Default data for when API doesn't return data
  const defaultStats = {
    totalUsers: 0,
    activeUsers: 0,
    totalSessions: 0,
    avgSessionDuration: 0,
    totalEvents: 0,
    avgEventsPerSession: 0,
    totalScreenViews: 0,
    bounceRate: 0,
  };

  const stats = dashboardData || defaultStats;

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">User Activity Analytics</h1>
          <p className="text-muted-foreground">
            Track user engagement, screen time, and activity patterns
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Calendar className="w-4 h-4 text-muted-foreground" />
          <Select value={timeframe} onValueChange={setTimeframe}>
            <SelectTrigger className="w-[160px]">
              <SelectValue placeholder="Select period" />
            </SelectTrigger>
            <SelectContent>
              {timeframeOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {error && (
        <Card className="border-destructive">
          <CardContent className="pt-6">
            <p className="text-destructive text-center">
              {error}. Using mock data for demonstration.
            </p>
          </CardContent>
        </Card>
      )}

      {/* Key Metrics */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <Users className="w-8 h-8 text-blue-500" />
              <Badge variant="outline" className="text-xs">
                {timeframe}
              </Badge>
            </div>
            <div className="mt-3">
              <p className="text-2xl font-bold">
                {formatNumber(stats.activeUsers || 0)}
              </p>
              <p className="text-sm text-muted-foreground">Active Users</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <Activity className="w-8 h-8 text-green-500" />
              <Badge variant="outline" className="text-xs">
                {timeframe}
              </Badge>
            </div>
            <div className="mt-3">
              <p className="text-2xl font-bold">
                {formatNumber(stats.totalSessions || 0)}
              </p>
              <p className="text-sm text-muted-foreground">Total Sessions</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <Clock className="w-8 h-8 text-orange-500" />
              <Badge variant="outline" className="text-xs">
                avg
              </Badge>
            </div>
            <div className="mt-3">
              <p className="text-2xl font-bold">
                {formatDuration(stats.avgSessionDuration || 0)}
              </p>
              <p className="text-sm text-muted-foreground">Avg Session Time</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <MousePointerClick className="w-8 h-8 text-purple-500" />
              <Badge variant="outline" className="text-xs">
                total
              </Badge>
            </div>
            <div className="mt-3">
              <p className="text-2xl font-bold">
                {formatNumber(stats.totalEvents || 0)}
              </p>
              <p className="text-sm text-muted-foreground">User Actions</p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row 1 */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Hourly Activity Pattern */}
        <Card>
          <CardHeader>
            <CardTitle>Activity Pattern by Hour</CardTitle>
            <CardDescription>
              User engagement throughout the day
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={hourlyData.length > 0 ? hourlyData : generateMockHourlyData()}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis dataKey="hour" className="text-xs" />
                  <YAxis className="text-xs" />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "8px",
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="sessions"
                    name="Sessions"
                    stroke="#3b82f6"
                    fill="#3b82f6"
                    fillOpacity={0.3}
                  />
                  <Area
                    type="monotone"
                    dataKey="events"
                    name="Events"
                    stroke="#22c55e"
                    fill="#22c55e"
                    fillOpacity={0.3}
                  />
                  <Legend />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Top Screens by Time */}
        <Card>
          <CardHeader>
            <CardTitle>Top Screens by View Time</CardTitle>
            <CardDescription>
              Screens where users spend most time
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={topScreens.length > 0 ? topScreens : generateMockScreenData()}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis dataKey="screenName" className="text-xs" />
                  <YAxis className="text-xs" />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "8px",
                    }}
                    formatter={(value: number) => [formatDuration(value), "Avg Time"]}
                  />
                  <Bar dataKey="avgDuration" fill="#8b5cf6" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row 2 */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Feature Usage */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Feature Usage Distribution</CardTitle>
            <CardDescription>
              Most used features in the app
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={featureUsage.length > 0 ? featureUsage : generateMockFeatureData()}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis dataKey="feature" className="text-xs" />
                  <YAxis className="text-xs" />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "8px",
                    }}
                  />
                  <Bar dataKey="count" fill="#22c55e" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Session Stats */}
        <Card>
          <CardHeader>
            <CardTitle>Session Insights</CardTitle>
            <CardDescription>Session quality metrics</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between p-3 rounded-lg bg-blue-50 dark:bg-blue-950">
              <div className="flex items-center gap-2">
                <Eye className="w-5 h-5 text-blue-600" />
                <span className="text-sm font-medium">Screen Views</span>
              </div>
              <Badge className="bg-blue-600">
                {formatNumber(stats.totalScreenViews || 0)}
              </Badge>
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-green-50 dark:bg-green-950">
              <div className="flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-green-600" />
                <span className="text-sm font-medium">Avg Actions/Session</span>
              </div>
              <Badge className="bg-green-600">
                {(stats.avgEventsPerSession || 0).toFixed(1)}
              </Badge>
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-orange-50 dark:bg-orange-950">
              <div className="flex items-center gap-2">
                <TrendingUp className="w-5 h-5 text-orange-600" />
                <span className="text-sm font-medium">Engagement Rate</span>
              </div>
              <Badge className="bg-orange-600">
                {((1 - (stats.bounceRate || 0)) * 100).toFixed(1)}%
              </Badge>
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-purple-50 dark:bg-purple-950">
              <div className="flex items-center gap-2">
                <Smartphone className="w-5 h-5 text-purple-600" />
                <span className="text-sm font-medium">Active Devices</span>
              </div>
              <Badge className="bg-purple-600">
                {formatNumber(stats.activeDevices || stats.activeUsers || 0)}
              </Badge>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Screen Activity Details */}
      <Card>
        <CardHeader>
          <CardTitle>Screen Activity Details</CardTitle>
          <CardDescription>
            Detailed breakdown of user activity per screen
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left p-2 font-medium">Screen Name</th>
                  <th className="text-right p-2 font-medium">Total Views</th>
                  <th className="text-right p-2 font-medium">Unique Users</th>
                  <th className="text-right p-2 font-medium">Avg Time</th>
                  <th className="text-right p-2 font-medium">Total Time</th>
                </tr>
              </thead>
              <tbody>
                {(topScreens.length > 0 ? topScreens : generateMockScreenData()).map((screen: any, index: number) => (
                  <tr key={index} className="border-b last:border-0 hover:bg-muted/50">
                    <td className="p-2 font-medium">{screen.screenName || screen.name}</td>
                    <td className="text-right p-2">{formatNumber(screen.views || screen.count || 0)}</td>
                    <td className="text-right p-2">{formatNumber(screen.uniqueUsers || Math.floor((screen.count || 0) * 0.7))}</td>
                    <td className="text-right p-2">{formatDuration(screen.avgDuration || 0)}</td>
                    <td className="text-right p-2">{formatDuration(screen.totalDuration || (screen.avgDuration || 0) * (screen.count || 0))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

// Mock data generators for when API doesn't return data
function generateMockHourlyData() {
  return Array.from({ length: 24 }, (_, i) => ({
    hour: `${i}:00`,
    sessions: Math.floor(Math.random() * 50) + 10,
    events: Math.floor(Math.random() * 200) + 50,
  }));
}

function generateMockScreenData() {
  const screens = ["Home", "Feed", "Reels", "Marketplace", "Weather", "Crop Calendar", "AI Chat", "Profile"];
  return screens.map((name) => ({
    screenName: name,
    name: name,
    count: Math.floor(Math.random() * 500) + 100,
    views: Math.floor(Math.random() * 500) + 100,
    avgDuration: Math.floor(Math.random() * 120) + 30,
    uniqueUsers: Math.floor(Math.random() * 300) + 50,
  }));
}

function generateMockFeatureData() {
  const features = ["Feed Like", "Reel View", "Product View", "Weather Check", "AI Chat", "Scheme View"];
  return features.map((feature) => ({
    feature,
    count: Math.floor(Math.random() * 1000) + 100,
  }));
}
