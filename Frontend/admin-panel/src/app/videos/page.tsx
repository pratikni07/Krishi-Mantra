"use client";

import React, { useEffect, useState } from "react";
import {
  Plus,
  Search,
  MoreVertical,
  Eye,
  Trash2,
  Loader2,
  Play,
  Clock,
  ThumbsUp,
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
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { formatDate, formatNumber } from "@/lib/utils";
import { videosAPI } from "@/lib/api";

interface Video {
  _id: string;
  title: string;
  description?: string;
  videoUrl: string;
  thumbnailUrl?: string;
  category: string;
  duration?: number;
  views: number;
  likes: number;
  isActive: boolean;
  createdAt: string;
}

const categories = [
  "Farming Techniques",
  "Crop Management",
  "Pest Control",
  "Irrigation",
  "Organic Farming",
  "Livestock",
  "Equipment",
  "Success Stories",
];

export default function VideosPage() {
  const [videos, setVideos] = useState<Video[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    videoUrl: "",
    thumbnailUrl: "",
    category: "",
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchVideos();
  }, [categoryFilter]);

  const fetchVideos = async () => {
    try {
      setIsLoading(true);
      const response = await videosAPI.getVideos(1, 30);
      // API returns: { status, data: { data: [...], pagination: {...} } }
      if (response.data.status === "success" || response.data.success) {
        const videosData = response.data.data?.data || response.data.data || [];
        setVideos(videosData);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch videos",
        variant: "destructive",
      });
      // Mock data
      setVideos([
        {
          _id: "1",
          title: "Complete Guide to Organic Farming",
          description: "Learn the basics of organic farming from experts",
          videoUrl: "https://example.com/video1.mp4",
          thumbnailUrl: "https://images.unsplash.com/photo-1625246333195-78d9c38ad449",
          category: "Organic Farming",
          duration: 1250,
          views: 45600,
          likes: 3200,
          isActive: true,
          createdAt: "2024-01-10",
        },
        {
          _id: "2",
          title: "Drip Irrigation Installation",
          description: "Step by step guide to setting up drip irrigation",
          videoUrl: "https://example.com/video2.mp4",
          thumbnailUrl: "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b",
          category: "Irrigation",
          duration: 890,
          views: 32100,
          likes: 2100,
          isActive: true,
          createdAt: "2024-01-15",
        },
        {
          _id: "3",
          title: "Pest Control in Cotton",
          description: "Effective pest control methods for cotton crops",
          videoUrl: "https://example.com/video3.mp4",
          category: "Pest Control",
          duration: 720,
          views: 28900,
          likes: 1800,
          isActive: true,
          createdAt: "2024-01-20",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.videoUrl || !formData.category) {
      toast({
        title: "Error",
        description: "Please fill all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      await videosAPI.createVideo(formData);
      toast({
        title: "Success",
        description: "Video created successfully",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        title: "",
        description: "",
        videoUrl: "",
        thumbnailUrl: "",
        category: "",
      });
      fetchVideos();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create video",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this video?")) return;

    try {
      await videosAPI.deleteVideo(id);
      toast({
        title: "Success",
        description: "Video deleted",
        variant: "success",
      });
      fetchVideos();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete video",
        variant: "destructive",
      });
    }
  };

  const formatDuration = (seconds?: number) => {
    if (!seconds) return "N/A";
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  const filteredVideos = videos.filter((video) => {
    if (categoryFilter === "all") return true;
    return video.category === categoryFilter;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Farm Videos</h1>
          <p className="text-muted-foreground">
            Manage educational farming videos
          </p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Add Video
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Add Video</DialogTitle>
              <DialogDescription>Add a new farming video</DialogDescription>
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
                  placeholder="Video title"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <textarea
                  id="description"
                  className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  placeholder="Video description"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="category">Category *</Label>
                <Select
                  value={formData.category}
                  onValueChange={(value) =>
                    setFormData({ ...formData, category: value })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select category" />
                  </SelectTrigger>
                  <SelectContent>
                    {categories.map((cat) => (
                      <SelectItem key={cat} value={cat}>
                        {cat}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="videoUrl">Video URL *</Label>
                <Input
                  id="videoUrl"
                  value={formData.videoUrl}
                  onChange={(e) =>
                    setFormData({ ...formData, videoUrl: e.target.value })
                  }
                  placeholder="https://example.com/video.mp4"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="thumbnailUrl">Thumbnail URL</Label>
                <Input
                  id="thumbnailUrl"
                  value={formData.thumbnailUrl}
                  onChange={(e) =>
                    setFormData({ ...formData, thumbnailUrl: e.target.value })
                  }
                  placeholder="https://example.com/thumbnail.jpg"
                />
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
                  "Add Video"
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input placeholder="Search videos..." className="w-full" />
            </div>
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Filter by category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Categories</SelectItem>
                {categories.map((cat) => (
                  <SelectItem key={cat} value={cat}>
                    {cat}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Videos Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          {filteredVideos.map((video) => (
            <Card key={video._id} className="card-hover overflow-hidden">
              {/* Thumbnail */}
              <div className="relative aspect-video bg-muted">
                {video.thumbnailUrl ? (
                  <img
                    src={video.thumbnailUrl}
                    alt={video.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Play className="w-12 h-12 text-muted-foreground" />
                  </div>
                )}
                <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                  <Button variant="secondary" size="icon" className="rounded-full">
                    <Play className="w-6 h-6" />
                  </Button>
                </div>
                {/* Duration */}
                {video.duration && (
                  <Badge
                    variant="secondary"
                    className="absolute bottom-2 right-2 bg-black/70 text-white border-0"
                  >
                    <Clock className="w-3 h-3 mr-1" />
                    {formatDuration(video.duration)}
                  </Badge>
                )}
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button
                      variant="secondary"
                      size="icon"
                      className="absolute top-2 right-2 h-8 w-8 bg-black/50 hover:bg-black/70"
                    >
                      <MoreVertical className="w-4 h-4 text-white" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem>
                      <Eye className="w-4 h-4 mr-2" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem
                      className="text-destructive"
                      onClick={() => handleDelete(video._id)}
                    >
                      <Trash2 className="w-4 h-4 mr-2" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              <CardContent className="p-3">
                <Badge variant="outline" className="mb-2 text-xs">
                  {video.category}
                </Badge>
                <h3 className="font-semibold text-sm line-clamp-2">{video.title}</h3>
                {video.description && (
                  <p className="text-xs text-muted-foreground line-clamp-2 mt-1">
                    {video.description}
                  </p>
                )}
                <div className="flex items-center gap-4 mt-3 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Eye className="w-3 h-3" />
                    {formatNumber(video.views)}
                  </div>
                  <div className="flex items-center gap-1">
                    <ThumbsUp className="w-3 h-3" />
                    {formatNumber(video.likes)}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
