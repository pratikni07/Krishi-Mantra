"use client";

import React, { useEffect, useState } from "react";
import {
  Search,
  MoreVertical,
  Eye,
  Crown,
  XCircle,
  RefreshCw,
  TrendingUp,
  Users,
  CreditCard,
  IndianRupee,
  Loader2,
  Wifi,
  Download,
  RotateCcw,
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useToast } from "@/hooks/use-toast";
import { formatDate, formatCurrency } from "@/lib/utils";
import { subscriptionAPI, iotAddonAPI } from "@/lib/api";
import { Label } from "@/components/ui/label";

interface Subscription {
  _id: string;
  userId: {
    _id: string;
    name: string;
    phone: string;
    email: string;
    avatar?: string;
  };
  planId: {
    _id: string;
    name: string;
    displayName: string;
  };
  planName: string;
  status: string;
  billingCycle: string;
  startDate: string;
  endDate: string;
  autoRenew: boolean;
  lastPaymentAmount: number;
  createdAt: string;
}

interface UserIotAddon {
  _id: string;
  userId: {
    _id: string;
    name: string;
    phone: string;
    email: string;
  };
  addonId: {
    _id: string;
    name: string;
    displayName: string;
  };
  addonName: string;
  status: string;
  billingCycle: string;
  startDate: string;
  endDate: string;
  linkedDevices: Array<{
    deviceId: string;
    deviceType: string;
    deviceName: string;
    isActive: boolean;
  }>;
}

interface SubscriptionStats {
  overview: {
    totalSubscriptions: number;
    activeSubscriptions: number;
    freeUsers: number;
    conversionRate: string;
  };
  planDistribution: {
    KISAN: number;
    KISAN_PRO: number;
    KISAN_PLUS: number;
    KISAN_MEGA: number;
  };
  monthlyRevenue: number;
  recentPayments: Array<{
    _id: string;
    amount: number;
    status: string;
    createdAt: string;
    userId: {
      name: string;
      phone: string;
    };
  }>;
}

interface IotStats {
  overview: {
    totalIotSubscriptions: number;
    activeIotSubscriptions: number;
    totalDevices: number;
  };
  addonDistribution: {
    WATER_PUMP: number;
    CROP_IOT: number;
    IOT_BUNDLE: number;
  };
}

export default function SubscriptionsPage() {
  const [activeTab, setActiveTab] = useState("subscriptions");
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [iotAddons, setIotAddons] = useState<UserIotAddon[]>([]);
  const [stats, setStats] = useState<SubscriptionStats | null>(null);
  const [iotStats, setIotStats] = useState<IotStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [planFilter, setPlanFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  // Dialog states
  const [selectedSubscription, setSelectedSubscription] = useState<Subscription | null>(null);
  const [showDetailsDialog, setShowDetailsDialog] = useState(false);
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [showUpdateDialog, setShowUpdateDialog] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelImmediately, setCancelImmediately] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);

  // Update form state
  const [updateForm, setUpdateForm] = useState({
    planName: "",
    status: "",
    endDate: "",
    autoRenew: true,
  });

  const { toast } = useToast();

  useEffect(() => {
    fetchData();
  }, [activeTab, page, statusFilter, planFilter]);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      if (activeTab === "subscriptions") {
        const [subsResponse, statsResponse] = await Promise.allSettled([
          subscriptionAPI.getAllSubscriptions(page, 20, {
            status: statusFilter !== "all" ? statusFilter : undefined,
            planName: planFilter !== "all" ? planFilter : undefined,
          }),
          subscriptionAPI.getStats(),
        ]);

        if (subsResponse.status === "fulfilled" && subsResponse.value.data.success) {
          setSubscriptions(subsResponse.value.data.data.subscriptions);
          setTotalPages(subsResponse.value.data.data.pagination.pages);
        }

        if (statsResponse.status === "fulfilled" && statsResponse.value.data.success) {
          setStats(statsResponse.value.data.data);
        }
      } else if (activeTab === "iot") {
        const [addonsResponse, iotStatsResponse] = await Promise.allSettled([
          iotAddonAPI.getAllUserAddons(page, 20),
          iotAddonAPI.getIotStats(),
        ]);

        if (addonsResponse.status === "fulfilled" && addonsResponse.value.data.success) {
          setIotAddons(addonsResponse.value.data.data.addons);
          setTotalPages(addonsResponse.value.data.data.pagination.pages);
        }

        if (iotStatsResponse.status === "fulfilled" && iotStatsResponse.value.data.success) {
          setIotStats(iotStatsResponse.value.data.data);
        }
      }
    } catch (error) {
      console.error("Error fetching data:", error);
      toast({
        title: "Error",
        description: "Failed to fetch data",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancelSubscription = async () => {
    if (!selectedSubscription) return;

    setIsProcessing(true);
    try {
      await subscriptionAPI.cancelUserSubscription(selectedSubscription.userId._id, {
        reason: cancelReason,
        cancelImmediately,
      });

      toast({
        title: "Success",
        description: cancelImmediately
          ? "Subscription cancelled immediately"
          : "Subscription will be cancelled at period end",
        variant: "success",
      });

      setShowCancelDialog(false);
      fetchData();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to cancel subscription",
        variant: "destructive",
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleUpdateSubscription = async () => {
    if (!selectedSubscription) return;

    setIsProcessing(true);
    try {
      await subscriptionAPI.updateUserSubscription(selectedSubscription.userId._id, updateForm);

      toast({
        title: "Success",
        description: "Subscription updated successfully",
        variant: "success",
      });

      setShowUpdateDialog(false);
      fetchData();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to update subscription",
        variant: "destructive",
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleResetUsage = async (userId: string) => {
    try {
      await subscriptionAPI.resetUserUsage(userId);
      toast({
        title: "Success",
        description: "User usage reset successfully",
        variant: "success",
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to reset usage",
        variant: "destructive",
      });
    }
  };

  const getPlanBadge = (planName: string) => {
    const colors: Record<string, string> = {
      KISAN: "bg-gray-500",
      KISAN_PRO: "bg-blue-500",
      KISAN_PLUS: "bg-purple-500",
      KISAN_MEGA: "bg-gradient-to-r from-yellow-400 to-yellow-600",
    };
    return (
      <Badge className={`${colors[planName] || "bg-gray-500"} text-white`}>
        {planName.replace("_", " ")}
      </Badge>
    );
  };

  const getStatusBadge = (status: string) => {
    const variants: Record<string, "success" | "destructive" | "secondary" | "default"> = {
      active: "success",
      cancelled: "destructive",
      expired: "secondary",
      past_due: "destructive",
      trialing: "default",
    };
    return <Badge variant={variants[status] || "secondary"}>{status}</Badge>;
  };

  const openUpdateDialog = (subscription: Subscription) => {
    setSelectedSubscription(subscription);
    setUpdateForm({
      planName: subscription.planName,
      status: subscription.status,
      endDate: subscription.endDate?.split("T")[0] || "",
      autoRenew: subscription.autoRenew,
    });
    setShowUpdateDialog(true);
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Subscriptions</h1>
          <p className="text-muted-foreground">
            Manage user subscriptions and IoT add-ons
          </p>
        </div>
        <Button variant="outline" onClick={fetchData}>
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Stats Cards */}
      {activeTab === "subscriptions" && stats && (
        <div className="grid gap-4 md:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Total Subscriptions</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overview.totalSubscriptions}</div>
              <p className="text-xs text-muted-foreground">
                {stats.overview.freeUsers} on free plan
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Active Paid</CardTitle>
              <Crown className="h-4 w-4 text-yellow-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.overview.activeSubscriptions}</div>
              <p className="text-xs text-muted-foreground">
                {stats.overview.conversionRate}% conversion
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Monthly Revenue</CardTitle>
              <IndianRupee className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                ₹{(stats.monthlyRevenue / 100).toLocaleString()}
              </div>
              <p className="text-xs text-muted-foreground">This month</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Plan Distribution</CardTitle>
              <TrendingUp className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="flex gap-2 flex-wrap">
                <Badge variant="outline">Pro: {stats.planDistribution.KISAN_PRO}</Badge>
                <Badge variant="outline">Plus: {stats.planDistribution.KISAN_PLUS}</Badge>
                <Badge variant="outline">Mega: {stats.planDistribution.KISAN_MEGA}</Badge>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {activeTab === "iot" && iotStats && (
        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Total IoT Subscriptions</CardTitle>
              <Wifi className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{iotStats.overview.totalIotSubscriptions}</div>
              <p className="text-xs text-muted-foreground">
                {iotStats.overview.activeIotSubscriptions} active
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Linked Devices</CardTitle>
              <CreditCard className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{iotStats.overview.totalDevices}</div>
              <p className="text-xs text-muted-foreground">Connected devices</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Add-on Distribution</CardTitle>
              <TrendingUp className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="flex gap-2 flex-wrap">
                <Badge variant="outline">Pump: {iotStats.addonDistribution.WATER_PUMP}</Badge>
                <Badge variant="outline">Crop: {iotStats.addonDistribution.CROP_IOT}</Badge>
                <Badge variant="outline">Bundle: {iotStats.addonDistribution.IOT_BUNDLE}</Badge>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="subscriptions">
            <Crown className="w-4 h-4 mr-2" />
            Subscriptions
          </TabsTrigger>
          <TabsTrigger value="iot">
            <Wifi className="w-4 h-4 mr-2" />
            IoT Add-ons
          </TabsTrigger>
        </TabsList>

        <TabsContent value="subscriptions" className="space-y-4">
          {/* Filters */}
          <Card>
            <CardContent className="p-4">
              <div className="flex flex-col md:flex-row gap-4">
                <div className="flex-1 flex gap-2">
                  <Input
                    placeholder="Search by name, phone..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="flex-1"
                  />
                  <Button variant="secondary">
                    <Search className="w-4 h-4" />
                  </Button>
                </div>
                <Select value={statusFilter} onValueChange={setStatusFilter}>
                  <SelectTrigger className="w-[150px]">
                    <SelectValue placeholder="Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="active">Active</SelectItem>
                    <SelectItem value="cancelled">Cancelled</SelectItem>
                    <SelectItem value="expired">Expired</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={planFilter} onValueChange={setPlanFilter}>
                  <SelectTrigger className="w-[150px]">
                    <SelectValue placeholder="Plan" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Plans</SelectItem>
                    <SelectItem value="KISAN">KISAN (Free)</SelectItem>
                    <SelectItem value="KISAN_PRO">KISAN PRO</SelectItem>
                    <SelectItem value="KISAN_PLUS">KISAN PLUS</SelectItem>
                    <SelectItem value="KISAN_MEGA">KISAN MEGA</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          {/* Subscriptions Table */}
          <Card>
            <CardHeader>
              <CardTitle>All Subscriptions</CardTitle>
              <CardDescription>
                Manage user subscription plans
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
                        <TableHead>User</TableHead>
                        <TableHead>Plan</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Billing</TableHead>
                        <TableHead>End Date</TableHead>
                        <TableHead>Last Payment</TableHead>
                        <TableHead className="w-[50px]"></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {subscriptions.map((sub) => (
                        <TableRow key={sub._id}>
                          <TableCell>
                            <div className="flex items-center gap-3">
                              <Avatar>
                                <AvatarImage src={sub.userId?.avatar} />
                                <AvatarFallback>
                                  {sub.userId?.name?.charAt(0)?.toUpperCase() || "U"}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p className="font-medium">{sub.userId?.name || "Unknown"}</p>
                                <p className="text-sm text-muted-foreground">
                                  {sub.userId?.phone}
                                </p>
                              </div>
                            </div>
                          </TableCell>
                          <TableCell>{getPlanBadge(sub.planName)}</TableCell>
                          <TableCell>{getStatusBadge(sub.status)}</TableCell>
                          <TableCell>
                            <span className="capitalize">{sub.billingCycle}</span>
                            {sub.autoRenew && (
                              <RefreshCw className="w-3 h-3 inline ml-1 text-green-500" />
                            )}
                          </TableCell>
                          <TableCell className="text-sm">
                            {formatDate(sub.endDate)}
                          </TableCell>
                          <TableCell>
                            ₹{((sub.lastPaymentAmount || 0) / 100).toLocaleString()}
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
                                <DropdownMenuItem
                                  onClick={() => {
                                    setSelectedSubscription(sub);
                                    setShowDetailsDialog(true);
                                  }}
                                >
                                  <Eye className="w-4 h-4 mr-2" />
                                  View Details
                                </DropdownMenuItem>
                                <DropdownMenuItem onClick={() => openUpdateDialog(sub)}>
                                  <Crown className="w-4 h-4 mr-2" />
                                  Update Plan
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                  onClick={() => handleResetUsage(sub.userId._id)}
                                >
                                  <RotateCcw className="w-4 h-4 mr-2" />
                                  Reset Usage
                                </DropdownMenuItem>
                                <DropdownMenuSeparator />
                                {sub.status === "active" && (
                                  <DropdownMenuItem
                                    className="text-destructive"
                                    onClick={() => {
                                      setSelectedSubscription(sub);
                                      setShowCancelDialog(true);
                                    }}
                                  >
                                    <XCircle className="w-4 h-4 mr-2" />
                                    Cancel Subscription
                                  </DropdownMenuItem>
                                )}
                              </DropdownMenuContent>
                            </DropdownMenu>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}

              {/* Pagination */}
              {!isLoading && subscriptions.length > 0 && (
                <div className="flex items-center justify-between mt-4">
                  <p className="text-sm text-muted-foreground">
                    Page {page} of {totalPages}
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === 1}
                      onClick={() => setPage(page - 1)}
                    >
                      Previous
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === totalPages}
                      onClick={() => setPage(page + 1)}
                    >
                      Next
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="iot" className="space-y-4">
          {/* IoT Add-ons Table */}
          <Card>
            <CardHeader>
              <CardTitle>IoT Add-on Subscriptions</CardTitle>
              <CardDescription>
                Manage user IoT device subscriptions
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
                        <TableHead>User</TableHead>
                        <TableHead>Add-on</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Devices</TableHead>
                        <TableHead>End Date</TableHead>
                        <TableHead className="w-[50px]"></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {iotAddons.map((addon) => (
                        <TableRow key={addon._id}>
                          <TableCell>
                            <div className="flex items-center gap-3">
                              <Avatar>
                                <AvatarFallback>
                                  {addon.userId?.name?.charAt(0)?.toUpperCase() || "U"}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p className="font-medium">{addon.userId?.name || "Unknown"}</p>
                                <p className="text-sm text-muted-foreground">
                                  {addon.userId?.phone}
                                </p>
                              </div>
                            </div>
                          </TableCell>
                          <TableCell>
                            <Badge className="bg-cyan-500 text-white">
                              {addon.addonName?.replace("_", " ")}
                            </Badge>
                          </TableCell>
                          <TableCell>{getStatusBadge(addon.status)}</TableCell>
                          <TableCell>
                            <Badge variant="outline">
                              {addon.linkedDevices?.length || 0} devices
                            </Badge>
                          </TableCell>
                          <TableCell className="text-sm">
                            {formatDate(addon.endDate)}
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
                                  View Devices
                                </DropdownMenuItem>
                                {addon.status === "active" && (
                                  <DropdownMenuItem className="text-destructive">
                                    <XCircle className="w-4 h-4 mr-2" />
                                    Cancel Add-on
                                  </DropdownMenuItem>
                                )}
                              </DropdownMenuContent>
                            </DropdownMenu>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}

              {/* Pagination */}
              {!isLoading && iotAddons.length > 0 && (
                <div className="flex items-center justify-between mt-4">
                  <p className="text-sm text-muted-foreground">
                    Page {page} of {totalPages}
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === 1}
                      onClick={() => setPage(page - 1)}
                    >
                      Previous
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === totalPages}
                      onClick={() => setPage(page + 1)}
                    >
                      Next
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Cancel Subscription Dialog */}
      <Dialog open={showCancelDialog} onOpenChange={setShowCancelDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel Subscription</DialogTitle>
            <DialogDescription>
              Cancel subscription for {selectedSubscription?.userId?.name}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>Reason for cancellation</Label>
              <Input
                placeholder="Enter reason..."
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
              />
            </div>
            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="cancelImmediately"
                checked={cancelImmediately}
                onChange={(e) => setCancelImmediately(e.target.checked)}
                className="rounded border-gray-300"
              />
              <Label htmlFor="cancelImmediately">
                Cancel immediately (otherwise cancels at period end)
              </Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCancelDialog(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleCancelSubscription}
              disabled={isProcessing}
            >
              {isProcessing && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
              Confirm Cancellation
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Update Subscription Dialog */}
      <Dialog open={showUpdateDialog} onOpenChange={setShowUpdateDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Update Subscription</DialogTitle>
            <DialogDescription>
              Update subscription for {selectedSubscription?.userId?.name}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>Plan</Label>
              <Select
                value={updateForm.planName}
                onValueChange={(value) => setUpdateForm({ ...updateForm, planName: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="KISAN">KISAN (Free)</SelectItem>
                  <SelectItem value="KISAN_PRO">KISAN PRO (₹99/mo)</SelectItem>
                  <SelectItem value="KISAN_PLUS">KISAN PLUS (₹299/mo)</SelectItem>
                  <SelectItem value="KISAN_MEGA">KISAN MEGA (₹999/mo)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Status</Label>
              <Select
                value={updateForm.status}
                onValueChange={(value) => setUpdateForm({ ...updateForm, status: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="cancelled">Cancelled</SelectItem>
                  <SelectItem value="expired">Expired</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>End Date</Label>
              <Input
                type="date"
                value={updateForm.endDate}
                onChange={(e) => setUpdateForm({ ...updateForm, endDate: e.target.value })}
              />
            </div>
            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="autoRenew"
                checked={updateForm.autoRenew}
                onChange={(e) => setUpdateForm({ ...updateForm, autoRenew: e.target.checked })}
                className="rounded border-gray-300"
              />
              <Label htmlFor="autoRenew">Auto-renew subscription</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowUpdateDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleUpdateSubscription} disabled={isProcessing}>
              {isProcessing && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
              Update Subscription
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Details Dialog */}
      <Dialog open={showDetailsDialog} onOpenChange={setShowDetailsDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Subscription Details</DialogTitle>
          </DialogHeader>
          {selectedSubscription && (
            <div className="grid gap-6 py-4">
              <div className="flex items-center gap-4">
                <Avatar className="w-16 h-16">
                  <AvatarImage src={selectedSubscription.userId?.avatar} />
                  <AvatarFallback className="text-xl">
                    {selectedSubscription.userId?.name?.charAt(0)?.toUpperCase() || "U"}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <h3 className="text-xl font-semibold">{selectedSubscription.userId?.name}</h3>
                  <p className="text-muted-foreground">{selectedSubscription.userId?.email}</p>
                  <p className="text-muted-foreground">{selectedSubscription.userId?.phone}</p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-muted-foreground">Plan</p>
                  {getPlanBadge(selectedSubscription.planName)}
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Status</p>
                  {getStatusBadge(selectedSubscription.status)}
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Billing Cycle</p>
                  <p className="font-medium capitalize">{selectedSubscription.billingCycle}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Auto Renew</p>
                  <p className="font-medium">{selectedSubscription.autoRenew ? "Yes" : "No"}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Start Date</p>
                  <p className="font-medium">{formatDate(selectedSubscription.startDate)}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">End Date</p>
                  <p className="font-medium">{formatDate(selectedSubscription.endDate)}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Last Payment</p>
                  <p className="font-medium">
                    ₹{((selectedSubscription.lastPaymentAmount || 0) / 100).toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Created</p>
                  <p className="font-medium">{formatDate(selectedSubscription.createdAt)}</p>
                </div>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
