"use client";

import React, { useEffect, useState } from "react";
import {
  Search,
  Filter,
  MoreVertical,
  Eye,
  MessageSquare,
  Loader2,
  CheckCircle,
  XCircle,
  Phone,
  Mail,
  MapPin,
  Calendar,
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { mainApi } from "@/lib/api";
import { useToast } from "@/hooks/use-toast";

interface DeviceRegistration {
  _id: string;
  name: string;
  phone: string;
  email?: string;
  address: string;
  deviceType: "auto_pump" | "krishi_doctor";
  status: "pending" | "contacted" | "completed" | "cancelled";
  adminReply?: {
    message: string;
    repliedAt: string;
    repliedBy: {
      name: string;
      email: string;
    };
  };
  notes?: string;
  notificationSent: boolean;
  createdAt: string;
  updatedAt: string;
}

interface Stats {
  byDevice: Array<{
    _id: string;
    total: number;
    pending: number;
    contacted: number;
    completed: number;
    cancelled: number;
  }>;
  overall: {
    totalRegistrations: number;
    pending: number;
    contacted: number;
    completed: number;
    cancelled: number;
  };
}

export default function DeviceRegistrationsPage() {
  const { toast } = useToast();
  const [registrations, setRegistrations] = useState<DeviceRegistration[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [deviceTypeFilter, setDeviceTypeFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [selectedRegistration, setSelectedRegistration] = useState<DeviceRegistration | null>(null);
  const [showReplyDialog, setShowReplyDialog] = useState(false);
  const [replyMessage, setReplyMessage] = useState("");
  const [replyStatus, setReplyStatus] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    fetchRegistrations();
    fetchStats();
  }, [deviceTypeFilter, statusFilter]);

  const fetchRegistrations = async () => {
    try {
      setLoading(true);
      const params: any = {};
      if (deviceTypeFilter !== "all") params.deviceType = deviceTypeFilter;
      if (statusFilter !== "all") params.status = statusFilter;

      const response = await mainApi.get("/api/device-registration/admin", { params });
      setRegistrations(response.data.data || []);
    } catch (error: any) {
      console.error("Error fetching registrations:", error);
      toast({
        title: "Error",
        description: error.response?.data?.message || "Failed to fetch registrations",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await mainApi.get("/api/device-registration/admin/stats");
      setStats(response.data.data);
    } catch (error) {
      console.error("Error fetching stats:", error);
    }
  };

  const handleReply = async () => {
    if (!selectedRegistration || !replyMessage.trim()) {
      toast({
        title: "Error",
        description: "Please enter a reply message",
        variant: "destructive",
      });
      return;
    }

    try {
      setSubmitting(true);
      await mainApi.put(`/api/device-registration/admin/${selectedRegistration._id}/reply`, {
        message: replyMessage,
        status: replyStatus || selectedRegistration.status,
      });

      toast({
        title: "Success",
        description: "Reply sent successfully and notification delivered to user",
      });

      setShowReplyDialog(false);
      setReplyMessage("");
      setReplyStatus("");
      setSelectedRegistration(null);
      fetchRegistrations();
      fetchStats();
    } catch (error: any) {
      console.error("Error sending reply:", error);
      toast({
        title: "Error",
        description: error.response?.data?.message || "Failed to send reply",
        variant: "destructive",
      });
    } finally {
      setSubmitting(false);
    }
  };

  const handleStatusChange = async (id: string, status: string) => {
    try {
      await mainApi.patch(`/api/device-registration/admin/${id}/status`, { status });
      toast({
        title: "Success",
        description: "Status updated successfully",
      });
      fetchRegistrations();
      fetchStats();
    } catch (error: any) {
      console.error("Error updating status:", error);
      toast({
        title: "Error",
        description: error.response?.data?.message || "Failed to update status",
        variant: "destructive",
      });
    }
  };

  const getDeviceName = (type: string) => {
    return type === "auto_pump" ? "Auto Pump Starter" : "Krishi Doctor";
  };

  const getStatusBadge = (status: string) => {
    const variants: Record<string, { variant: any; icon: any }> = {
      pending: { variant: "secondary", icon: null },
      contacted: { variant: "default", icon: <Phone className="w-3 h-3" /> },
      completed: { variant: "default", icon: <CheckCircle className="w-3 h-3" /> },
      cancelled: { variant: "destructive", icon: <XCircle className="w-3 h-3" /> },
    };

    const config = variants[status] || variants.pending;

    return (
      <Badge variant={config.variant} className="capitalize flex items-center gap-1">
        {config.icon}
        {status}
      </Badge>
    );
  };

  const filteredRegistrations = registrations.filter((reg) =>
    reg.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    reg.phone.includes(searchTerm) ||
    reg.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight">IoT Device Registrations</h1>
        <p className="text-muted-foreground mt-1">
          Manage registration requests for Auto Pump and Krishi Doctor devices
        </p>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overall.totalRegistrations}</div>
              <p className="text-xs text-muted-foreground">All registrations</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Pending</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overall.pending}</div>
              <p className="text-xs text-muted-foreground">Awaiting response</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Contacted</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overall.contacted}</div>
              <p className="text-xs text-muted-foreground">In progress</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Completed</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overall.completed}</div>
              <p className="text-xs text-muted-foreground">Successfully closed</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Cancelled</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overall.cancelled}</div>
              <p className="text-xs text-muted-foreground">Not interested</p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Filters */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search by name, phone, or email..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-9"
                />
              </div>
            </div>
            <Select value={deviceTypeFilter} onValueChange={setDeviceTypeFilter}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Device Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Devices</SelectItem>
                <SelectItem value="auto_pump">Auto Pump</SelectItem>
                <SelectItem value="krishi_doctor">Krishi Doctor</SelectItem>
              </SelectContent>
            </Select>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="contacted">Contacted</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
                <SelectItem value="cancelled">Cancelled</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex justify-center items-center py-8">
              <Loader2 className="h-8 w-8 animate-spin" />
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Device</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Reply</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredRegistrations.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                      No registrations found
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredRegistrations.map((reg) => (
                    <TableRow key={reg._id}>
                      <TableCell className="font-medium">{reg.name}</TableCell>
                      <TableCell>
                        <div className="flex flex-col gap-1">
                          <div className="flex items-center gap-1 text-sm">
                            <Phone className="w-3 h-3" />
                            {reg.phone}
                          </div>
                          {reg.email && (
                            <div className="flex items-center gap-1 text-xs text-muted-foreground">
                              <Mail className="w-3 h-3" />
                              {reg.email}
                            </div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">{getDeviceName(reg.deviceType)}</Badge>
                      </TableCell>
                      <TableCell>{getStatusBadge(reg.status)}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm text-muted-foreground">
                          <Calendar className="w-3 h-3" />
                          {new Date(reg.createdAt).toLocaleDateString()}
                        </div>
                      </TableCell>
                      <TableCell>
                        {reg.adminReply ? (
                          <Badge variant="default" className="bg-green-600">
                            Replied
                          </Badge>
                        ) : (
                          <Badge variant="secondary">No reply</Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" className="h-8 w-8 p-0">
                              <MoreVertical className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuLabel>Actions</DropdownMenuLabel>
                            <DropdownMenuItem
                              onClick={() => {
                                setSelectedRegistration(reg);
                                setShowReplyDialog(true);
                                setReplyStatus(reg.status);
                                if (reg.adminReply) {
                                  setReplyMessage(reg.adminReply.message);
                                }
                              }}
                            >
                              <MessageSquare className="mr-2 h-4 w-4" />
                              {reg.adminReply ? "View/Edit Reply" : "Send Reply"}
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem onClick={() => handleStatusChange(reg._id, "contacted")}>
                              Mark as Contacted
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => handleStatusChange(reg._id, "completed")}>
                              Mark as Completed
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => handleStatusChange(reg._id, "cancelled")}>
                              Mark as Cancelled
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Reply Dialog */}
      <Dialog open={showReplyDialog} onOpenChange={setShowReplyDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Reply to Registration</DialogTitle>
            <DialogDescription>
              Send a reply message to {selectedRegistration?.name}. A notification will be sent to the user.
            </DialogDescription>
          </DialogHeader>

          {selectedRegistration && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4 p-4 bg-muted rounded-lg">
                <div>
                  <Label className="text-xs text-muted-foreground">Name</Label>
                  <p className="font-medium">{selectedRegistration.name}</p>
                </div>
                <div>
                  <Label className="text-xs text-muted-foreground">Phone</Label>
                  <p className="font-medium">{selectedRegistration.phone}</p>
                </div>
                <div>
                  <Label className="text-xs text-muted-foreground">Device</Label>
                  <p className="font-medium">{getDeviceName(selectedRegistration.deviceType)}</p>
                </div>
                <div>
                  <Label className="text-xs text-muted-foreground">Address</Label>
                  <p className="font-medium text-sm">{selectedRegistration.address}</p>
                </div>
              </div>

              <div>
                <Label htmlFor="replyMessage">Reply Message</Label>
                <Textarea
                  id="replyMessage"
                  placeholder="Enter your message to the user..."
                  value={replyMessage}
                  onChange={(e) => setReplyMessage(e.target.value)}
                  rows={4}
                  className="mt-1.5"
                />
              </div>

              <div>
                <Label htmlFor="replyStatus">Update Status</Label>
                <Select value={replyStatus} onValueChange={setReplyStatus}>
                  <SelectTrigger id="replyStatus" className="mt-1.5">
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="contacted">Contacted</SelectItem>
                    <SelectItem value="completed">Completed</SelectItem>
                    <SelectItem value="cancelled">Cancelled</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {selectedRegistration.adminReply && (
                <div className="p-4 bg-muted rounded-lg">
                  <Label className="text-xs text-muted-foreground">Previous Reply</Label>
                  <p className="text-sm mt-1">{selectedRegistration.adminReply.message}</p>
                  <p className="text-xs text-muted-foreground mt-2">
                    By {selectedRegistration.adminReply.repliedBy?.name} on{" "}
                    {new Date(selectedRegistration.adminReply.repliedAt).toLocaleString()}
                  </p>
                </div>
              )}
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowReplyDialog(false)} disabled={submitting}>
              Cancel
            </Button>
            <Button onClick={handleReply} disabled={submitting}>
              {submitting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Sending...
                </>
              ) : (
                "Send Reply"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
