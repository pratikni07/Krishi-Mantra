"use client";

import React, { useEffect, useState } from "react";
import {
  Store,
  Building2,
  Package,
  TrendingUp,
  Eye,
  DollarSign,
  Users,
  ArrowUpRight,
  ArrowDownRight,
  Loader2,
} from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { marketplaceAPI, companyAPI, productAPI, analyticsAPI } from "@/lib/api";
import { toast } from "sonner";

interface Stats {
  totalMarketplaceProducts: number;
  totalCompanies: number;
  totalCompanyProducts: number;
  totalViews: number;
}

interface TrendingTag {
  tag: string;
  count: number;
  productSample: Array<{ id: string; title: string }>;
}

interface MarketplaceProduct {
  _id: string;
  title: string;
  shortDescription: string;
  priceRange: { min: number; max: number };
  images?: string[];
  sellerName?: string;
  rating: number;
  views?: number;
  status?: string;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({
    totalMarketplaceProducts: 0,
    totalCompanies: 0,
    totalCompanyProducts: 0,
    totalViews: 0,
  });
  const [trendingTags, setTrendingTags] = useState<TrendingTag[]>([]);
  const [recentProducts, setRecentProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setIsLoading(true);
      const [marketplaceRes, companiesRes, productsRes, trendingRes] = await Promise.all([
        marketplaceAPI.getAll(1, 10),
        companyAPI.getAll(1, 100),
        productAPI.getAll(1, 100),
        marketplaceAPI.getTrendingTags(),
      ]);

      // Set stats
      const marketplaceProducts = marketplaceRes.data.data || [];
      const companies = companiesRes.data.data || [];
      const products = productsRes.data.data || [];

      setStats({
        totalMarketplaceProducts: marketplaceRes.data.count || marketplaceProducts.length,
        totalCompanies: companiesRes.data.results || companies.length,
        totalCompanyProducts: productsRes.data.results || products.length,
        totalViews: marketplaceProducts.reduce((acc: number, p: MarketplaceProduct) => acc + (p.views || 0), 0),
      });

      setRecentProducts(marketplaceProducts.slice(0, 5));
      setTrendingTags(trendingRes.data.data || []);
    } catch (error) {
      console.error("Dashboard data fetch error:", error);
      toast.error("Failed to fetch dashboard data");
    } finally {
      setIsLoading(false);
    }
  };

  const statCards = [
    {
      title: "Marketplace Products",
      value: stats.totalMarketplaceProducts,
      icon: Store,
      color: "bg-emerald-100 text-emerald-600",
      trend: "+12%",
      trendUp: true,
    },
    {
      title: "Companies",
      value: stats.totalCompanies,
      icon: Building2,
      color: "bg-blue-100 text-blue-600",
      trend: "+5%",
      trendUp: true,
    },
    {
      title: "Company Products",
      value: stats.totalCompanyProducts,
      icon: Package,
      color: "bg-purple-100 text-purple-600",
      trend: "+8%",
      trendUp: true,
    },
    {
      title: "Total Views",
      value: stats.totalViews,
      icon: Eye,
      color: "bg-orange-100 text-orange-600",
      trend: "+23%",
      trendUp: true,
    },
  ];

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <Loader2 className="w-8 h-8 animate-spin text-emerald-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500">Overview of marketplace performance</p>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {statCards.map((stat) => (
          <Card key={stat.title}>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className={`p-2 rounded-lg ${stat.color}`}>
                  <stat.icon className="w-5 h-5" />
                </div>
                <div className={`flex items-center text-sm ${stat.trendUp ? "text-emerald-600" : "text-red-600"}`}>
                  {stat.trend}
                  {stat.trendUp ? (
                    <ArrowUpRight className="w-4 h-4 ml-1" />
                  ) : (
                    <ArrowDownRight className="w-4 h-4 ml-1" />
                  )}
                </div>
              </div>
              <div className="mt-4">
                <p className="text-2xl font-bold text-gray-900">{stat.value.toLocaleString()}</p>
                <p className="text-sm text-gray-500">{stat.title}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Recent Products */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Marketplace Products</CardTitle>
            <CardDescription>Latest products listed on the marketplace</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentProducts.length === 0 ? (
                <p className="text-gray-500 text-center py-4">No products yet</p>
              ) : (
                recentProducts.map((product) => (
                  <div key={product._id} className="flex items-center gap-4 p-3 rounded-lg bg-gray-50">
                    <div className="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center overflow-hidden">
                      {product.images && product.images[0] ? (
                        <img
                          src={product.images[0]}
                          alt={product.title}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <Package className="w-6 h-6 text-gray-400" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 truncate">{product.title}</p>
                      <p className="text-sm text-gray-500">
                        ₹{product.priceRange.min.toLocaleString()} - ₹{product.priceRange.max.toLocaleString()}
                      </p>
                    </div>
                    <Badge variant={product.status === "active" ? "default" : "secondary"}>
                      {product.status || "active"}
                    </Badge>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>

        {/* Trending Tags */}
        <Card>
          <CardHeader>
            <CardTitle>Trending Tags</CardTitle>
            <CardDescription>Popular tags in the marketplace</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {trendingTags.length === 0 ? (
                <p className="text-gray-500 text-center py-4">No trending tags</p>
              ) : (
                trendingTags.slice(0, 8).map((tag, index) => (
                  <div key={tag.tag} className="flex items-center justify-between p-3 rounded-lg bg-gray-50">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
                        <span className="text-sm font-medium text-emerald-600">#{index + 1}</span>
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{tag.tag}</p>
                        <p className="text-sm text-gray-500">{tag.count} products</p>
                      </div>
                    </div>
                    <TrendingUp className="w-4 h-4 text-emerald-600" />
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
