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
  Heart,
  MessageCircle,
  Share2,
  Flag,
  CheckCircle,
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
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useToast } from "@/hooks/use-toast";
import { formatDate, formatNumber } from "@/lib/utils";
import { reelsAPI } from "@/lib/api";

interface Reel {
  _id: string;
  userId: {
    _id: string;
    name: string;
    profileImage?: string;
  };
  title: string;
  description?: string;
  videoUrl: string;
  thumbnailUrl?: string;
  views: number;
  likes: number;
  comments: number;
  shares: number;
  isReported: boolean;
  isApproved: boolean;
  createdAt: string;
}

export default function ReelsPage() {
  const [reels, setReels] = useState<Reel[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedReel, setSelectedReel] = useState<Reel | null>(null);
  const [showReelDialog, setShowReelDialog] = useState(false);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    videoUrl: "",
    thumbnailUrl: "",
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchReels();
  }, [statusFilter]);

  const fetchReels = async () => {
    try {
      setIsLoading(true);
      const response = await reelsAPI.getReels(1, 30);
      // API returns: { status, data: { data: [...], pagination: {...} } }
      if (response.data.status === "success" || response.data.success) {
        const reelsData = response.data.data?.data || response.data.data || [];
        setReels(reelsData);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch reels",
        variant: "destructive",
      });
      // Mock data
      setReels([
        {
          _id: "1",
          userId: { _id: "u1", name: "Rajesh Kumar" },
          title: "Organic Farming Tips",
          description: "Learn about organic farming methods",
          videoUrl: "https://example.com/video1.mp4",
          thumbnailUrl: "https://images.unsplash.com/photo-1625246333195-78d9c38ad449",
          views: 15600,
          likes: 1245,
          comments: 89,
          shares: 234,
          isReported: false,
          isApproved: true,
          createdAt: "2024-01-20",
        },
        {
          _id: "2",
          userId: { _id: "u2", name: "Priya Sharma" },
          title: "Cotton Harvesting Techniques",
          description: "Best practices for cotton harvesting",
          videoUrl: "https://example.com/video2.mp4",
          thumbnailUrl: "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b",
          views: 8900,
          likes: 678,
          comments: 45,
          shares: 123,
          isReported: false,
          isApproved: true,
          createdAt: "2024-01-18",
        },
        {
          _id: "3",
          userId: { _id: "u3", name: "Amit Patel" },
          title: "Irrigation System Setup",
          videoUrl: "https://example.com/video3.mp4",
          views: 5200,
          likes: 345,
          comments: 23,
          shares: 56,
          isReported: true,
          isApproved: false,
          createdAt: "2024-01-15",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.videoUrl) {
      toast({
        title: "Error",
        description: "Please fill all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      await reelsAPI.createReel(formData);
      toast({
        title: "Success",
        description: "Reel created successfully",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        title: "",
        description: "",
        videoUrl: "",
        thumbnailUrl: "",
      });
      fetchReels();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create reel",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleApprove = async (reelId: string) => {
    try {
      await reelsAPI.approveReel(reelId);
      toast({
        title: "Success",
        description: "Reel approved",
        variant: "success",
      });
      fetchReels();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to approve reel",
        variant: "destructive",
      });
    }
  };

  const handleDelete = async (reelId: string) => {
    if (!confirm("Are you sure you want to delete this reel?")) return;

    try {
      await reelsAPI.deleteReel(reelId);
      toast({
        title: "Success",
        description: "Reel deleted",
        variant: "success",
      });
      fetchReels();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete reel",
        variant: "destructive",
      });
    }
  };

  const filteredReels = reels.filter((reel) => {
    if (statusFilter === "all") return true;
    if (statusFilter === "reported") return reel.isReported;
    if (statusFilter === "pending") return !reel.isApproved;
    if (statusFilter === "approved") return reel.isApproved;
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Reels</h1>
          <p className="text-muted-foreground">
            Manage short video content
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="warning" className="px-3 py-1">
            <Flag className="w-3 h-3 mr-1" />
            {reels.filter((r) => r.isReported).length} Reported
          </Badge>
          <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="w-4 h-4 mr-2" />
                Add Reel
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create Reel</DialogTitle>
                <DialogDescription>
                  Add a new reel to the platform
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
                    placeholder="Reel title"
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
                    placeholder="Reel description"
                  />
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
                    "Create Reel"
                  )}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input placeholder="Search reels..." className="w-full" />
            </div>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Reels</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="reported">Reported</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Reels Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          {filteredReels.map((reel) => (
            <Card key={reel._id} className="card-hover overflow-hidden">
              {/* Thumbnail */}
              <div className="relative aspect-[9/16] bg-muted">
                {reel.thumbnailUrl ? (
                  <img
                    src={reel.thumbnailUrl}
                    alt={reel.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Play className="w-12 h-12 text-muted-foreground" />
                  </div>
                )}
                <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                  <Button
                    variant="secondary"
                    size="icon"
                    className="rounded-full"
                    onClick={() => {
                      setSelectedReel(reel);
                      setShowReelDialog(true);
                    }}
                  >
                    <Play className="w-6 h-6" />
                  </Button>
                </div>
                {/* Status Badge */}
                <div className="absolute top-2 left-2">
                  {reel.isReported && (
                    <Badge variant="destructive" className="text-xs">
                      <Flag className="w-3 h-3 mr-1" />
                      Reported
                    </Badge>
                  )}
                  {!reel.isApproved && !reel.isReported && (
                    <Badge variant="warning" className="text-xs">
                      Pending
                    </Badge>
                  )}
                </div>
                {/* Views */}
                <div className="absolute bottom-2 left-2">
                  <Badge variant="secondary" className="bg-black/60 text-white border-0">
                    <Eye className="w-3 h-3 mr-1" />
                    {formatNumber(reel.views)}
                  </Badge>
                </div>
              </div>

              <CardContent className="p-3">
                {/* User Info */}
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Avatar className="w-6 h-6">
                      <AvatarImage src={reel.userId.profileImage} />
                      <AvatarFallback className="text-xs">
                        {reel.userId.name?.charAt(0)?.toUpperCase() || "U"}
                      </AvatarFallback>
                    </Avatar>
                    <span className="text-xs text-muted-foreground">
                      {reel.userId.name}
                    </span>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon" className="h-6 w-6">
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem
                        onClick={() => {
                          setSelectedReel(reel);
                          setShowReelDialog(true);
                        }}
                      >
                        <Eye className="w-4 h-4 mr-2" />
                        View
                      </DropdownMenuItem>
                      {!reel.isApproved && (
                        <DropdownMenuItem onClick={() => handleApprove(reel._id)}>
                          <CheckCircle className="w-4 h-4 mr-2" />
                          Approve
                        </DropdownMenuItem>
                      )}
                      <DropdownMenuSeparator />
                      <DropdownMenuItem
                        className="text-destructive"
                        onClick={() => handleDelete(reel._id)}
                      >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>

                {/* Title */}
                <p className="font-medium text-sm line-clamp-1">{reel.title}</p>

                {/* Stats */}
                <div className="flex items-center gap-3 mt-2 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Heart className="w-3 h-3" />
                    {formatNumber(reel.likes)}
                  </div>
                  <div className="flex items-center gap-1">
                    <MessageCircle className="w-3 h-3" />
                    {formatNumber(reel.comments)}
                  </div>
                  <div className="flex items-center gap-1">
                    <Share2 className="w-3 h-3" />
                    {formatNumber(reel.shares)}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Reel Details Dialog */}
      <Dialog open={showReelDialog} onOpenChange={setShowReelDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{selectedReel?.title}</DialogTitle>
          </DialogHeader>
          {selectedReel && (
            <div className="space-y-4">
              <div className="aspect-[9/16] bg-black rounded-lg overflow-hidden">
                {selectedReel.thumbnailUrl && (
                  <img
                    src={selectedReel.thumbnailUrl}
                    alt={selectedReel.title}
                    className="w-full h-full object-cover"
                  />
                )}
              </div>

              <div className="flex items-center gap-3">
                <Avatar>
                  <AvatarImage src={selectedReel.userId.profileImage} />
                  <AvatarFallback>
                    {selectedReel.userId.name?.charAt(0)?.toUpperCase() || "U"}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <p className="font-medium">{selectedReel.userId.name}</p>
                  <p className="text-sm text-muted-foreground">
                    {formatDate(selectedReel.createdAt)}
                  </p>
                </div>
              </div>

              {selectedReel.description && (
                <p className="text-sm">{selectedReel.description}</p>
              )}

              <div className="flex items-center justify-between pt-4 border-t">
                <div className="flex items-center gap-4">
                  <div className="flex items-center gap-1">
                    <Eye className="w-4 h-4" />
                    <span className="text-sm">{formatNumber(selectedReel.views)}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Heart className="w-4 h-4" />
                    <span className="text-sm">{formatNumber(selectedReel.likes)}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <MessageCircle className="w-4 h-4" />
                    <span className="text-sm">{formatNumber(selectedReel.comments)}</span>
                  </div>
                </div>
              </div>

              <div className="flex gap-2">
                {!selectedReel.isApproved && (
                  <Button
                    className="flex-1"
                    onClick={() => {
                      handleApprove(selectedReel._id);
                      setShowReelDialog(false);
                    }}
                  >
                    <CheckCircle className="w-4 h-4 mr-2" />
                    Approve
                  </Button>
                )}
                <Button
                  variant="destructive"
                  className="flex-1"
                  onClick={() => {
                    handleDelete(selectedReel._id);
                    setShowReelDialog(false);
                  }}
                >
                  <Trash2 className="w-4 h-4 mr-2" />
                  Delete
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
