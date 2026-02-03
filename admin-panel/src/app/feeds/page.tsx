"use client";

import React, { useEffect, useState } from "react";
import {
  Search,
  MoreVertical,
  Eye,
  Trash2,
  Loader2,
  Heart,
  MessageCircle,
  Share2,
  Flag,
  CheckCircle,
  XCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  DialogHeader,
  DialogTitle,
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
import { formatDate, truncate } from "@/lib/utils";
import { feedsAPI } from "@/lib/api";

interface Feed {
  _id: string;
  userId: {
    _id: string;
    name: string;
    profileImage?: string;
  };
  content: string;
  media?: string[];
  likes: number;
  comments: number;
  shares: number;
  isReported: boolean;
  isApproved: boolean;
  createdAt: string;
}

export default function FeedsPage() {
  const [feeds, setFeeds] = useState<Feed[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedFeed, setSelectedFeed] = useState<Feed | null>(null);
  const [showFeedDialog, setShowFeedDialog] = useState(false);
  const [page, setPage] = useState(1);
  const { toast } = useToast();

  useEffect(() => {
    fetchFeeds();
  }, [page, statusFilter]);

  const fetchFeeds = async () => {
    try {
      setIsLoading(true);
      const response = await feedsAPI.getFeeds(page, 20);
      // API returns: { success, data: [...], pagination: { total, page, limit, pages } }
      if (response.data.success) {
        setFeeds(response.data.data || []);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch feeds",
        variant: "destructive",
      });
      // Mock data
      setFeeds([
        {
          _id: "1",
          userId: { _id: "u1", name: "Rajesh Kumar", profileImage: "" },
          content: "Just harvested my wheat crop! Great yield this season. The new irrigation system really helped improve the quality.",
          media: ["https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b"],
          likes: 245,
          comments: 32,
          shares: 15,
          isReported: false,
          isApproved: true,
          createdAt: "2024-01-20T10:30:00Z",
        },
        {
          _id: "2",
          userId: { _id: "u2", name: "Priya Sharma" },
          content: "Looking for advice on pest control for cotton crop. Any recommendations?",
          likes: 89,
          comments: 45,
          shares: 5,
          isReported: false,
          isApproved: true,
          createdAt: "2024-01-19T15:45:00Z",
        },
        {
          _id: "3",
          userId: { _id: "u3", name: "Amit Patel" },
          content: "This post has been reported for inappropriate content.",
          likes: 12,
          comments: 3,
          shares: 0,
          isReported: true,
          isApproved: false,
          createdAt: "2024-01-18T09:20:00Z",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleApprove = async (feedId: string) => {
    try {
      await feedsAPI.approveFeed(feedId);
      toast({
        title: "Success",
        description: "Feed approved",
        variant: "success",
      });
      fetchFeeds();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to approve feed",
        variant: "destructive",
      });
    }
  };

  const handleDelete = async (feedId: string) => {
    if (!confirm("Are you sure you want to delete this feed?")) return;

    try {
      await feedsAPI.deleteFeed(feedId);
      toast({
        title: "Success",
        description: "Feed deleted",
        variant: "success",
      });
      fetchFeeds();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete feed",
        variant: "destructive",
      });
    }
  };

  const filteredFeeds = feeds.filter((feed) => {
    if (statusFilter === "all") return true;
    if (statusFilter === "reported") return feed.isReported;
    if (statusFilter === "pending") return !feed.isApproved;
    if (statusFilter === "approved") return feed.isApproved;
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Feeds</h1>
          <p className="text-muted-foreground">
            Manage user posts and content moderation
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="warning" className="px-3 py-1">
            <Flag className="w-3 h-3 mr-1" />
            {feeds.filter((f) => f.isReported).length} Reported
          </Badge>
          <Badge variant="info" className="px-3 py-1">
            {feeds.filter((f) => !f.isApproved).length} Pending
          </Badge>
        </div>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input placeholder="Search feeds..." className="w-full" />
            </div>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Feeds</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="reported">Reported</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Feeds Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filteredFeeds.map((feed) => (
            <Card key={feed._id} className="card-hover">
              <CardContent className="p-4">
                {/* Header */}
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <Avatar className="w-10 h-10">
                      <AvatarImage src={feed.userId.profileImage} />
                      <AvatarFallback>
                        {feed.userId.name?.charAt(0)?.toUpperCase() || "U"}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <p className="font-medium text-sm">{feed.userId.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {formatDate(feed.createdAt)}
                      </p>
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon">
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuLabel>Actions</DropdownMenuLabel>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem
                        onClick={() => {
                          setSelectedFeed(feed);
                          setShowFeedDialog(true);
                        }}
                      >
                        <Eye className="w-4 h-4 mr-2" />
                        View Details
                      </DropdownMenuItem>
                      {!feed.isApproved && (
                        <DropdownMenuItem onClick={() => handleApprove(feed._id)}>
                          <CheckCircle className="w-4 h-4 mr-2" />
                          Approve
                        </DropdownMenuItem>
                      )}
                      <DropdownMenuSeparator />
                      <DropdownMenuItem
                        className="text-destructive"
                        onClick={() => handleDelete(feed._id)}
                      >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>

                {/* Status Badges */}
                <div className="flex gap-2 mb-3">
                  {feed.isReported && (
                    <Badge variant="destructive" className="text-xs">
                      <Flag className="w-3 h-3 mr-1" />
                      Reported
                    </Badge>
                  )}
                  {!feed.isApproved && (
                    <Badge variant="warning" className="text-xs">
                      Pending
                    </Badge>
                  )}
                  {feed.isApproved && !feed.isReported && (
                    <Badge variant="success" className="text-xs">
                      Approved
                    </Badge>
                  )}
                </div>

                {/* Content */}
                <p className="text-sm mb-3">{truncate(feed.content, 150)}</p>

                {/* Media */}
                {feed.media && feed.media.length > 0 && (
                  <div className="mb-3">
                    <img
                      src={feed.media[0]}
                      alt="Feed media"
                      className="w-full h-40 object-cover rounded-lg"
                    />
                    {feed.media.length > 1 && (
                      <p className="text-xs text-muted-foreground mt-1">
                        +{feed.media.length - 1} more images
                      </p>
                    )}
                  </div>
                )}

                {/* Stats */}
                <div className="flex items-center gap-4 text-sm text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Heart className="w-4 h-4" />
                    {feed.likes}
                  </div>
                  <div className="flex items-center gap-1">
                    <MessageCircle className="w-4 h-4" />
                    {feed.comments}
                  </div>
                  <div className="flex items-center gap-1">
                    <Share2 className="w-4 h-4" />
                    {feed.shares}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Feed Details Dialog */}
      <Dialog open={showFeedDialog} onOpenChange={setShowFeedDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Feed Details</DialogTitle>
            <DialogDescription>Full view of the feed post</DialogDescription>
          </DialogHeader>
          {selectedFeed && (
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <Avatar className="w-12 h-12">
                  <AvatarImage src={selectedFeed.userId.profileImage} />
                  <AvatarFallback>
                    {selectedFeed.userId.name?.charAt(0)?.toUpperCase() || "U"}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <p className="font-semibold">{selectedFeed.userId.name}</p>
                  <p className="text-sm text-muted-foreground">
                    {formatDate(selectedFeed.createdAt)}
                  </p>
                </div>
              </div>

              <p>{selectedFeed.content}</p>

              {selectedFeed.media && selectedFeed.media.length > 0 && (
                <div className="grid gap-2">
                  {selectedFeed.media.map((url, index) => (
                    <img
                      key={index}
                      src={url}
                      alt={`Media ${index + 1}`}
                      className="w-full rounded-lg"
                    />
                  ))}
                </div>
              )}

              <div className="flex items-center justify-between pt-4 border-t">
                <div className="flex items-center gap-6">
                  <div className="flex items-center gap-2">
                    <Heart className="w-5 h-5 text-red-500" />
                    <span>{selectedFeed.likes} likes</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <MessageCircle className="w-5 h-5 text-blue-500" />
                    <span>{selectedFeed.comments} comments</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Share2 className="w-5 h-5 text-green-500" />
                    <span>{selectedFeed.shares} shares</span>
                  </div>
                </div>
              </div>

              <div className="flex gap-2 pt-4">
                {!selectedFeed.isApproved && (
                  <Button
                    className="flex-1"
                    onClick={() => {
                      handleApprove(selectedFeed._id);
                      setShowFeedDialog(false);
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
                    handleDelete(selectedFeed._id);
                    setShowFeedDialog(false);
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
