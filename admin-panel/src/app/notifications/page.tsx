"use client";

import React, { useEffect, useState } from "react";
import {
  Plus,
  Search,
  Bell,
  Send,
  Users,
  Clock,
  Loader2,
  CheckCircle,
  XCircle,
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
import { notificationAPI } from "@/lib/api";

interface Notification {
  _id: string;
  title: string;
  body: string;
  type: string;
  targetAudience: string;
  sentCount: number;
  deliveredCount: number;
  readCount: number;
  status: string;
  scheduledAt?: string;
  sentAt?: string;
  createdAt: string;
}

const notificationTypes = [
  { value: "general", label: "General" },
  { value: "news", label: "News Update" },
  { value: "scheme", label: "Scheme Alert" },
  { value: "weather", label: "Weather Alert" },
  { value: "price", label: "Price Update" },
  { value: "promotional", label: "Promotional" },
];

const audiences = [
  { value: "all", label: "All Users" },
  { value: "premium", label: "Premium Users" },
  { value: "free", label: "Free Users" },
  { value: "state", label: "By State" },
];

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("sent");
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: "",
    body: "",
    type: "general",
    targetAudience: "all",
    scheduleTime: "",
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchNotifications();
  }, [activeTab]);

  const fetchNotifications = async () => {
    try {
      setIsLoading(true);
      const response = await notificationAPI.getNotifications(1, 50);
      // Notification API may not be available - handle gracefully
      if (response.data.success) {
        setNotifications(response.data.notifications || response.data.data || []);
      } else if (Array.isArray(response.data)) {
        setNotifications(response.data || []);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch notifications",
        variant: "destructive",
      });
      // Mock data
      setNotifications([
        {
          _id: "1",
          title: "New Scheme Alert: PM-KISAN",
          body: "New installment of PM-KISAN is now available. Check your eligibility.",
          type: "scheme",
          targetAudience: "all",
          sentCount: 12500,
          deliveredCount: 11800,
          readCount: 8900,
          status: "sent",
          sentAt: "2024-01-20T10:30:00Z",
          createdAt: "2024-01-20T10:00:00Z",
        },
        {
          _id: "2",
          title: "Weather Alert: Heavy Rainfall",
          body: "Heavy rainfall expected in Maharashtra and Gujarat. Take precautions.",
          type: "weather",
          targetAudience: "state",
          sentCount: 5600,
          deliveredCount: 5200,
          readCount: 4100,
          status: "sent",
          sentAt: "2024-01-19T08:00:00Z",
          createdAt: "2024-01-19T07:30:00Z",
        },
        {
          _id: "3",
          title: "Market Price Update",
          body: "Wheat prices have increased by 5% in major mandis.",
          type: "price",
          targetAudience: "premium",
          sentCount: 2100,
          deliveredCount: 2000,
          readCount: 1500,
          status: "sent",
          sentAt: "2024-01-18T14:00:00Z",
          createdAt: "2024-01-18T13:30:00Z",
        },
        {
          _id: "4",
          title: "New Feature: Crop Calendar",
          body: "Check out our new crop calendar feature for better planning.",
          type: "general",
          targetAudience: "all",
          sentCount: 0,
          deliveredCount: 0,
          readCount: 0,
          status: "scheduled",
          scheduledAt: "2024-01-25T10:00:00Z",
          createdAt: "2024-01-20T15:00:00Z",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSend = async () => {
    if (!formData.title || !formData.body) {
      toast({
        title: "Error",
        description: "Please fill title and message",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      await notificationAPI.sendNotification(formData);
      toast({
        title: "Success",
        description: formData.scheduleTime
          ? "Notification scheduled successfully"
          : "Notification sent successfully",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        title: "",
        body: "",
        type: "general",
        targetAudience: "all",
        scheduleTime: "",
      });
      fetchNotifications();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to send notification",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "sent":
        return (
          <Badge variant="success">
            <CheckCircle className="w-3 h-3 mr-1" />
            Sent
          </Badge>
        );
      case "scheduled":
        return (
          <Badge variant="warning">
            <Clock className="w-3 h-3 mr-1" />
            Scheduled
          </Badge>
        );
      case "failed":
        return (
          <Badge variant="destructive">
            <XCircle className="w-3 h-3 mr-1" />
            Failed
          </Badge>
        );
      default:
        return <Badge variant="secondary">{status}</Badge>;
    }
  };

  const getDeliveryRate = (sent: number, delivered: number) => {
    if (sent === 0) return "N/A";
    return ((delivered / sent) * 100).toFixed(1) + "%";
  };

  const getReadRate = (delivered: number, read: number) => {
    if (delivered === 0) return "N/A";
    return ((read / delivered) * 100).toFixed(1) + "%";
  };

  const filteredNotifications = notifications.filter((n) => {
    if (activeTab === "sent") return n.status === "sent";
    if (activeTab === "scheduled") return n.status === "scheduled";
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Notifications</h1>
          <p className="text-muted-foreground">
            Send push notifications to users
          </p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Send className="w-4 h-4 mr-2" />
              Send Notification
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Send Notification</DialogTitle>
              <DialogDescription>
                Create and send a push notification to users
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
                  placeholder="Notification title"
                  maxLength={60}
                />
                <p className="text-xs text-muted-foreground">
                  {formData.title.length}/60 characters
                </p>
              </div>
              <div className="space-y-2">
                <Label htmlFor="body">Message *</Label>
                <textarea
                  id="body"
                  className="w-full min-h-[100px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.body}
                  onChange={(e) =>
                    setFormData({ ...formData, body: e.target.value })
                  }
                  placeholder="Notification message"
                  maxLength={200}
                />
                <p className="text-xs text-muted-foreground">
                  {formData.body.length}/200 characters
                </p>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Type</Label>
                  <Select
                    value={formData.type}
                    onValueChange={(value) =>
                      setFormData({ ...formData, type: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {notificationTypes.map((type) => (
                        <SelectItem key={type.value} value={type.value}>
                          {type.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Target Audience</Label>
                  <Select
                    value={formData.targetAudience}
                    onValueChange={(value) =>
                      setFormData({ ...formData, targetAudience: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {audiences.map((audience) => (
                        <SelectItem key={audience.value} value={audience.value}>
                          {audience.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="scheduleTime">Schedule (Optional)</Label>
                <Input
                  id="scheduleTime"
                  type="datetime-local"
                  value={formData.scheduleTime}
                  onChange={(e) =>
                    setFormData({ ...formData, scheduleTime: e.target.value })
                  }
                />
                <p className="text-xs text-muted-foreground">
                  Leave empty to send immediately
                </p>
              </div>
            </div>
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setShowCreateDialog(false)}
              >
                Cancel
              </Button>
              <Button onClick={handleSend} disabled={isSubmitting}>
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    {formData.scheduleTime ? "Scheduling..." : "Sending..."}
                  </>
                ) : (
                  <>
                    <Send className="w-4 h-4 mr-2" />
                    {formData.scheduleTime ? "Schedule" : "Send Now"}
                  </>
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-blue-100 rounded-lg">
                <Bell className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{notifications.length}</p>
                <p className="text-sm text-muted-foreground">Total Sent</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-green-100 rounded-lg">
                <CheckCircle className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {notifications.reduce((acc, n) => acc + (n.deliveredCount || 0), 0).toLocaleString()}
                </p>
                <p className="text-sm text-muted-foreground">Delivered</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-purple-100 rounded-lg">
                <Users className="w-6 h-6 text-purple-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {notifications.reduce((acc, n) => acc + (n.readCount || 0), 0).toLocaleString()}
                </p>
                <p className="text-sm text-muted-foreground">Read</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-yellow-100 rounded-lg">
                <Clock className="w-6 h-6 text-yellow-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {notifications.filter((n) => n.status === "scheduled").length}
                </p>
                <p className="text-sm text-muted-foreground">Scheduled</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="all">All</TabsTrigger>
          <TabsTrigger value="sent">Sent</TabsTrigger>
          <TabsTrigger value="scheduled">Scheduled</TabsTrigger>
        </TabsList>

        <TabsContent value={activeTab} className="mt-6">
          <Card>
            <CardHeader>
              <CardTitle>Notification History</CardTitle>
              <CardDescription>
                {filteredNotifications.length} notifications found
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
                        <TableHead>Notification</TableHead>
                        <TableHead>Type</TableHead>
                        <TableHead>Audience</TableHead>
                        <TableHead>Sent</TableHead>
                        <TableHead>Delivery Rate</TableHead>
                        <TableHead>Read Rate</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Date</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredNotifications.map((notification) => (
                        <TableRow key={notification._id} className="table-row-hover">
                          <TableCell>
                            <div className="max-w-[250px]">
                              <p className="font-medium">{notification.title}</p>
                              <p className="text-sm text-muted-foreground truncate">
                                {notification.body}
                              </p>
                            </div>
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline">{notification.type}</Badge>
                          </TableCell>
                          <TableCell>
                            <Badge variant="secondary">
                              {notification.targetAudience === "all"
                                ? "All Users"
                                : notification.targetAudience}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            {notification.sentCount?.toLocaleString() || 0}
                          </TableCell>
                          <TableCell>
                            {getDeliveryRate(
                              notification.sentCount || 0,
                              notification.deliveredCount || 0
                            )}
                          </TableCell>
                          <TableCell>
                            {getReadRate(
                              notification.deliveredCount || 0,
                              notification.readCount || 0
                            )}
                          </TableCell>
                          <TableCell>
                            {getStatusBadge(notification.status)}
                          </TableCell>
                          <TableCell className="text-sm text-muted-foreground">
                            {notification.status === "scheduled"
                              ? formatDate(notification.scheduledAt!)
                              : formatDate(notification.sentAt || notification.createdAt)}
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
      </Tabs>
    </div>
  );
}
