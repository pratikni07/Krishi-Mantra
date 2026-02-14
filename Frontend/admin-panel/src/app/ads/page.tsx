"use client";

import React, { useEffect, useState } from "react";
import {
  Plus,
  Search,
  MoreVertical,
  Eye,
  Edit,
  Trash2,
  Loader2,
  Image as ImageIcon,
  ExternalLink,
  Calendar,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { formatDate } from "@/lib/utils";
import { adsAPI } from "@/lib/api";

interface Ad {
  _id: string;
  title: string;
  description?: string;
  imageUrl: string;
  redirectUrl?: string;
  type: string;
  position?: number;
  clicks: number;
  impressions: number;
  isActive: boolean;
  startDate?: string;
  endDate?: string;
  createdAt: string;
}

const adTypes = [
  { value: "home", label: "Home Ads" },
  { value: "homeScreen", label: "Home Screen Ads" },
  { value: "splash", label: "Splash Ads" },
  { value: "feed", label: "Feed Ads" },
  { value: "reel", label: "Reel Ads" },
  { value: "news", label: "News Ads" },
];

export default function AdsPage() {
  const [activeTab, setActiveTab] = useState("home");
  const [ads, setAds] = useState<Ad[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    imageUrl: "",
    redirectUrl: "",
    type: "home",
    position: 1,
    isActive: true,
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchAds();
  }, [activeTab]);

  const fetchAds = async () => {
    try {
      setIsLoading(true);
      let response;
      switch (activeTab) {
        case "home":
          response = await adsAPI.getHomeAds();
          break;
        case "homeScreen":
          response = await adsAPI.getHomeScreenAds();
          break;
        case "splash":
          response = await adsAPI.getSplashAds();
          break;
        case "feed":
          response = await adsAPI.getFeedAds();
          break;
        case "reel":
          response = await adsAPI.getReelAds();
          break;
        case "news":
          response = await adsAPI.getNewsAds();
          break;
        default:
          response = await adsAPI.getHomeAds();
      }

      // Most ads APIs return array directly [], Reel Ads return { message, ads }
      if (Array.isArray(response.data)) {
        setAds(response.data || []);
      } else if (response.data.ads) {
        setAds(response.data.ads || []);
      } else if (response.data.data) {
        setAds(response.data.data || []);
      } else {
        setAds([]);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch ads",
        variant: "destructive",
      });
      // Mock data
      setAds([
        {
          _id: "1",
          title: "Premium Fertilizer Sale",
          description: "Get 20% off on all fertilizers",
          imageUrl: "https://images.unsplash.com/photo-1625246333195-78d9c38ad449",
          redirectUrl: "https://example.com",
          type: activeTab,
          position: 1,
          clicks: 1245,
          impressions: 15600,
          isActive: true,
          startDate: "2024-01-01",
          endDate: "2024-03-31",
          createdAt: "2024-01-01",
        },
        {
          _id: "2",
          title: "New Tractor Launch",
          description: "Check out the latest tractor models",
          imageUrl: "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b",
          redirectUrl: "https://example.com",
          type: activeTab,
          position: 2,
          clicks: 890,
          impressions: 12300,
          isActive: true,
          createdAt: "2024-01-10",
        },
        {
          _id: "3",
          title: "Seed Distribution",
          imageUrl: "https://images.unsplash.com/photo-1416879595882-3373a0480b5b",
          type: activeTab,
          position: 3,
          clicks: 456,
          impressions: 8900,
          isActive: false,
          createdAt: "2024-01-15",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.imageUrl) {
      toast({
        title: "Error",
        description: "Please fill all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      const adData = { ...formData, type: activeTab };

      switch (activeTab) {
        case "home":
          await adsAPI.createHomeAd(adData);
          break;
        case "homeScreen":
          await adsAPI.createHomeScreenAd(adData);
          break;
        case "splash":
          await adsAPI.createSplashAd(adData);
          break;
        case "feed":
          await adsAPI.createFeedAd(adData);
          break;
        case "reel":
          await adsAPI.createReelAd(adData);
          break;
        case "news":
          await adsAPI.createNewsAd(adData);
          break;
      }

      toast({
        title: "Success",
        description: "Advertisement created successfully",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        title: "",
        description: "",
        imageUrl: "",
        redirectUrl: "",
        type: activeTab,
        position: 1,
        isActive: true,
      });
      fetchAds();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create advertisement",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this advertisement?")) return;

    try {
      switch (activeTab) {
        case "home":
          await adsAPI.deleteHomeAd(id);
          break;
        case "homeScreen":
          await adsAPI.deleteHomeScreenAd(id);
          break;
        case "splash":
          await adsAPI.deleteSplashAd(id);
          break;
        case "feed":
          await adsAPI.deleteFeedAd(id);
          break;
        case "reel":
          await adsAPI.deleteReelAd(id);
          break;
        case "news":
          await adsAPI.deleteNewsAd(id);
          break;
      }

      toast({
        title: "Success",
        description: "Advertisement deleted",
        variant: "success",
      });
      fetchAds();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete advertisement",
        variant: "destructive",
      });
    }
  };

  const getCTR = (clicks: number, impressions: number) => {
    if (impressions === 0) return "0%";
    return ((clicks / impressions) * 100).toFixed(2) + "%";
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Advertisements</h1>
          <p className="text-muted-foreground">
            Manage platform advertisements across different placements
          </p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Add Advertisement
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Create Advertisement</DialogTitle>
              <DialogDescription>
                Add a new advertisement for {adTypes.find((t) => t.value === activeTab)?.label}
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="title">Title *</Label>
                <Input
                  id="title"
                  value={formData.title}
                  onChange={(e) =>
                    setFormData({ ...formData, title: e.target.value })
                  }
                  placeholder="Ad title"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Input
                  id="description"
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  placeholder="Brief description"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="imageUrl">Image URL *</Label>
                <Input
                  id="imageUrl"
                  value={formData.imageUrl}
                  onChange={(e) =>
                    setFormData({ ...formData, imageUrl: e.target.value })
                  }
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="redirectUrl">Redirect URL</Label>
                <Input
                  id="redirectUrl"
                  value={formData.redirectUrl}
                  onChange={(e) =>
                    setFormData({ ...formData, redirectUrl: e.target.value })
                  }
                  placeholder="https://example.com/landing"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="position">Position</Label>
                  <Input
                    id="position"
                    type="number"
                    min={1}
                    value={formData.position}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        position: parseInt(e.target.value) || 1,
                      })
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>Status</Label>
                  <Select
                    value={formData.isActive ? "active" : "inactive"}
                    onValueChange={(value) =>
                      setFormData({ ...formData, isActive: value === "active" })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="active">Active</SelectItem>
                      <SelectItem value="inactive">Inactive</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </div>
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setShowCreateDialog(false)}
              >
                Cancel
              </Button>
              <Button onClick={handleCreate} disabled={isSubmitting}>
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Creating...
                  </>
                ) : (
                  "Create Ad"
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-6">
          {adTypes.map((type) => (
            <TabsTrigger key={type.value} value={type.value}>
              {type.label}
            </TabsTrigger>
          ))}
        </TabsList>

        {adTypes.map((type) => (
          <TabsContent key={type.value} value={type.value} className="mt-6">
            <Card>
              <CardHeader>
                <CardTitle>{type.label}</CardTitle>
                <CardDescription>
                  Total {ads.length} advertisements in this placement
                </CardDescription>
              </CardHeader>
              <CardContent>
                {isLoading ? (
                  <div className="flex items-center justify-center py-8">
                    <Loader2 className="w-8 h-8 animate-spin text-primary" />
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>Advertisement</TableHead>
                          <TableHead>Position</TableHead>
                          <TableHead>Impressions</TableHead>
                          <TableHead>Clicks</TableHead>
                          <TableHead>CTR</TableHead>
                          <TableHead>Status</TableHead>
                          <TableHead>Date</TableHead>
                          <TableHead className="w-[50px]"></TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {ads.map((ad) => (
                          <TableRow key={ad._id} className="table-row-hover">
                            <TableCell>
                              <div className="flex items-center gap-3">
                                {ad.imageUrl ? (
                                  <img
                                    src={ad.imageUrl}
                                    alt={ad.title}
                                    className="w-16 h-10 rounded object-cover"
                                  />
                                ) : (
                                  <div className="w-16 h-10 rounded bg-muted flex items-center justify-center">
                                    <ImageIcon className="w-5 h-5 text-muted-foreground" />
                                  </div>
                                )}
                                <div>
                                  <p className="font-medium">{ad.title}</p>
                                  {ad.redirectUrl && (
                                    <a
                                      href={ad.redirectUrl}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                      className="text-xs text-primary flex items-center gap-1"
                                    >
                                      <ExternalLink className="w-3 h-3" />
                                      Link
                                    </a>
                                  )}
                                </div>
                              </div>
                            </TableCell>
                            <TableCell>
                              <Badge variant="outline">#{ad.position || "-"}</Badge>
                            </TableCell>
                            <TableCell>{ad.impressions?.toLocaleString() || 0}</TableCell>
                            <TableCell>{ad.clicks?.toLocaleString() || 0}</TableCell>
                            <TableCell>
                              <Badge variant="secondary">
                                {getCTR(ad.clicks || 0, ad.impressions || 0)}
                              </Badge>
                            </TableCell>
                            <TableCell>
                              <Badge variant={ad.isActive ? "success" : "secondary"}>
                                {ad.isActive ? "Active" : "Inactive"}
                              </Badge>
                            </TableCell>
                            <TableCell className="text-sm text-muted-foreground">
                              {formatDate(ad.createdAt)}
                            </TableCell>
                            <TableCell>
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button variant="ghost" size="icon">
                                    <MoreVertical className="w-4 h-4" />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end">
                                  <DropdownMenuLabel>Actions</DropdownMenuLabel>
                                  <DropdownMenuSeparator />
                                  <DropdownMenuItem>
                                    <Eye className="w-4 h-4 mr-2" />
                                    View
                                  </DropdownMenuItem>
                                  <DropdownMenuItem>
                                    <Edit className="w-4 h-4 mr-2" />
                                    Edit
                                  </DropdownMenuItem>
                                  <DropdownMenuSeparator />
                                  <DropdownMenuItem
                                    className="text-destructive"
                                    onClick={() => handleDelete(ad._id)}
                                  >
                                    <Trash2 className="w-4 h-4 mr-2" />
                                    Delete
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}
