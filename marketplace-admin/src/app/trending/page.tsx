"use client";

import React, { useEffect, useState } from "react";
import {
  TrendingUp,
  Loader2,
  Hash,
  Package,
  BarChart3,
  ArrowUpRight,
} from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { marketplaceAPI } from "@/lib/api";

interface TrendingTag {
  tag: string;
  count: number;
  productSample: Array<{ id: string; title: string }>;
}

export default function TrendingPage() {
  const [trendingTags, setTrendingTags] = useState<TrendingTag[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchTrendingTags();
  }, []);

  const fetchTrendingTags = async () => {
    try {
      setIsLoading(true);
      const response = await marketplaceAPI.getTrendingTags();
      if (response.data.success) {
        setTrendingTags(response.data.data || []);
      }
    } catch (error) {
      console.error("Fetch error:", error);
      toast.error("Failed to fetch trending tags");
    } finally {
      setIsLoading(false);
    }
  };

  const totalProducts = trendingTags.reduce((acc, tag) => acc + tag.count, 0);
  const topTag = trendingTags[0];

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
        <h1 className="text-3xl font-bold text-gray-900">Trending Tags</h1>
        <p className="text-gray-500">Popular tags and trends in the marketplace</p>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-emerald-100 rounded-lg">
                <Hash className="w-6 h-6 text-emerald-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{trendingTags.length}</p>
                <p className="text-sm text-gray-500">Total Tags</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-purple-100 rounded-lg">
                <Package className="w-6 h-6 text-purple-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{totalProducts}</p>
                <p className="text-sm text-gray-500">Tagged Products</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-orange-100 rounded-lg">
                <TrendingUp className="w-6 h-6 text-orange-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{topTag?.tag || "-"}</p>
                <p className="text-sm text-gray-500">Top Tag</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Trending Tags List */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Top Tags */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-emerald-600" />
              Top Trending Tags
            </CardTitle>
            <CardDescription>Tags with the most products</CardDescription>
          </CardHeader>
          <CardContent>
            {trendingTags.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Hash className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                <p>No trending tags found</p>
              </div>
            ) : (
              <div className="space-y-3">
                {trendingTags.slice(0, 10).map((tag, index) => (
                  <div
                    key={tag.tag}
                    className="flex items-center justify-between p-3 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
                        <span className="text-sm font-bold text-emerald-600">
                          {index + 1}
                        </span>
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-gray-900">#{tag.tag}</span>
                          {index < 3 && (
                            <ArrowUpRight className="w-4 h-4 text-emerald-500" />
                          )}
                        </div>
                        <span className="text-sm text-gray-500">
                          {tag.count} products
                        </span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="w-24 h-2 bg-gray-200 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-emerald-500 rounded-full"
                          style={{
                            width: `${Math.min(100, (tag.count / (topTag?.count || 1)) * 100)}%`,
                          }}
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Tag Details with Products */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-purple-600" />
              Tag Details
            </CardTitle>
            <CardDescription>Products associated with each tag</CardDescription>
          </CardHeader>
          <CardContent>
            {trendingTags.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Package className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                <p>No tag details available</p>
              </div>
            ) : (
              <div className="space-y-4">
                {trendingTags.slice(0, 5).map((tag) => (
                  <div key={tag.tag} className="p-4 border rounded-lg">
                    <div className="flex items-center justify-between mb-3">
                      <Badge className="bg-emerald-100 text-emerald-700 hover:bg-emerald-200">
                        #{tag.tag}
                      </Badge>
                      <span className="text-sm text-gray-500">
                        {tag.count} products
                      </span>
                    </div>
                    {tag.productSample && tag.productSample.length > 0 && (
                      <div className="space-y-2">
                        <p className="text-xs text-gray-500 font-medium">Sample Products:</p>
                        <div className="space-y-1">
                          {tag.productSample.slice(0, 3).map((product) => (
                            <div
                              key={product.id}
                              className="text-sm text-gray-600 truncate pl-2 border-l-2 border-emerald-200"
                            >
                              {product.title}
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* All Tags Grid */}
      <Card>
        <CardHeader>
          <CardTitle>All Tags</CardTitle>
          <CardDescription>Complete list of marketplace tags</CardDescription>
        </CardHeader>
        <CardContent>
          {trendingTags.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <Hash className="w-12 h-12 mx-auto mb-4 text-gray-300" />
              <p>No tags found</p>
            </div>
          ) : (
            <div className="flex flex-wrap gap-2">
              {trendingTags.map((tag, index) => (
                <Badge
                  key={tag.tag}
                  variant="outline"
                  className={`text-sm py-1.5 px-3 cursor-pointer hover:bg-gray-100 ${
                    index < 3 ? "border-emerald-500 text-emerald-700" : ""
                  }`}
                >
                  #{tag.tag}
                  <span className="ml-2 text-xs text-gray-400">{tag.count}</span>
                </Badge>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
