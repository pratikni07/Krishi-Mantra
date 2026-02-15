"use client";

import React, { useEffect, useState } from "react";
import {
  Search,
  Filter,
  MoreVertical,
  Eye,
  Edit,
  Trash2,
  Download,
  Loader2,
  UserPlus,
  Crown,
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
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useToast } from "@/hooks/use-toast";
import { formatDate } from "@/lib/utils";
import { userAPI } from "@/lib/api";

interface DeviceStatus {
  purchased: boolean;
  enabled: boolean;
}

interface User {
  _id: string;
  name: string;
  email: string;
  phone: string;
  profileImage?: string;
  state?: string;
  district?: string;
  subscription: {
    type: string;
    expiresAt?: string;
  };
  deviceAccess: {
    pump: DeviceStatus;
    krishiDoctor: DeviceStatus;
  };
  isActive: boolean;
  createdAt: string;
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [subscriptionFilter, setSubscriptionFilter] = useState("all");
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [showUserDialog, setShowUserDialog] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const { toast } = useToast();

  useEffect(() => {
    fetchUsers();
  }, [page, subscriptionFilter]);

  const normalizeDeviceStatus = (value?: Partial<DeviceStatus>): DeviceStatus => ({
    purchased: Boolean(value?.purchased),
    enabled: Boolean(value?.enabled),
  });

  const mapUser = (user: any): User => ({
    _id: user._id,
    name: user.name || "Unknown",
    email: user.email || "-",
    phone: user.phoneNo || user.phone || "-",
    profileImage: user.image || user.profileImage,
    state: user.additionalDetails?.state || user.state,
    district: user.additionalDetails?.district || user.district,
    subscription: {
      type: user.additionalDetails?.subscription?.type?.toLowerCase() || user.subscription?.type || "free",
      expiresAt: user.additionalDetails?.subscription?.endDate || user.subscription?.expiresAt,
    },
    deviceAccess: {
      pump: normalizeDeviceStatus(user.additionalDetails?.deviceAccess?.pump),
      krishiDoctor: normalizeDeviceStatus(user.additionalDetails?.deviceAccess?.krishiDoctor),
    },
    isActive: user.isActive ?? true,
    createdAt: user.createdAt,
  });

  const fetchUsers = async () => {
    try {
      setIsLoading(true);
      const response = await userAPI.getUsers(page, 20);
      // API returns: { success, users, pagination: { currentPage, totalPages, totalUsers, hasNextPage, hasPreviousPage } }
      if (response.data.success) {
        setUsers((response.data.users || []).map(mapUser));
        setTotalPages(response.data.pagination?.totalPages || 1);
      }
    } catch (error: any) {
      toast({
        title: "Error",
        description: "Failed to fetch users",
        variant: "destructive",
      });
      // Mock data for demo
      setUsers([
        {
          _id: "1",
          name: "Rajesh Kumar",
          email: "rajesh@example.com",
          phone: "+91 9876543210",
          state: "Maharashtra",
          district: "Pune",
          subscription: { type: "premium", expiresAt: "2024-12-31" },
          deviceAccess: { pump: { purchased: true, enabled: true }, krishiDoctor: { purchased: true, enabled: true } },
          isActive: true,
          createdAt: "2024-01-15",
        },
        {
          _id: "2",
          name: "Priya Sharma",
          email: "priya@example.com",
          phone: "+91 9876543211",
          state: "Gujarat",
          district: "Ahmedabad",
          subscription: { type: "free" },
          deviceAccess: { pump: { purchased: false, enabled: false }, krishiDoctor: { purchased: false, enabled: false } },
          isActive: true,
          createdAt: "2024-02-20",
        },
        {
          _id: "3",
          name: "Amit Patel",
          email: "amit@example.com",
          phone: "+91 9876543212",
          state: "Rajasthan",
          district: "Jaipur",
          subscription: { type: "premium", expiresAt: "2024-06-30" },
          deviceAccess: { pump: { purchased: true, enabled: false }, krishiDoctor: { purchased: false, enabled: false } },
          isActive: false,
          createdAt: "2024-03-10",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      fetchUsers();
      return;
    }
    try {
      setIsLoading(true);
      const response = await userAPI.searchUsers(searchQuery);
      if (response.data.success) {
        setUsers((response.data.data || []).map(mapUser));
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Search failed",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateSubscription = async (userId: string, type: string) => {
    try {
      await userAPI.updateSubscription(userId, {
        type,
        expiresAt: type === "premium" ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString() : undefined,
      });
      toast({
        title: "Success",
        description: "Subscription updated successfully",
        variant: "success",
      });
      fetchUsers();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to update subscription",
        variant: "destructive",
      });
    }
  };


  const updateDeviceAccess = async (
    user: User,
    device: "pump" | "krishiDoctor",
    field: "purchased" | "enabled",
    value: boolean
  ) => {
    try {
      await userAPI.updateDeviceAccess(user._id, {
        deviceAccess: {
          [device]: {
            [field]: value,
          },
        },
      });
      toast({
        title: "Success",
        description: "Device access updated",
        variant: "success",
      });
      fetchUsers();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to update device access",
        variant: "destructive",
      });
    }
  };

  const getDeviceBadge = (name: string, status: DeviceStatus) => (
    <Badge variant={status.enabled ? "success" : "secondary"}>
      {name}: {status.purchased ? (status.enabled ? "Enabled" : "Purchased") : "Not Purchased"}
    </Badge>
  );

  const getSubscriptionBadge = (subscription: User["subscription"]) => {
    if (subscription?.type === "premium") {
      return (
        <Badge className="bg-gradient-to-r from-yellow-400 to-yellow-600 text-white">
          <Crown className="w-3 h-3 mr-1" />
          Premium
        </Badge>
      );
    }
    return <Badge variant="secondary">Free</Badge>;
  };

  const filteredUsers = users.filter((user) => {
    if (subscriptionFilter === "all") return true;
    return user.subscription?.type === subscriptionFilter;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Users</h1>
          <p className="text-muted-foreground">
            Manage and monitor platform users
          </p>
        </div>
        <Button className="w-fit">
          <Download className="w-4 h-4 mr-2" />
          Export Users
        </Button>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 flex gap-2">
              <Input
                placeholder="Search by name, email or phone..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                className="flex-1"
              />
              <Button variant="secondary" onClick={handleSearch}>
                <Search className="w-4 h-4" />
              </Button>
            </div>
            <Select
              value={subscriptionFilter}
              onValueChange={setSubscriptionFilter}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filter by subscription" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Users</SelectItem>
                <SelectItem value="premium">Premium</SelectItem>
                <SelectItem value="free">Free</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Users Table */}
      <Card>
        <CardHeader>
          <CardTitle>All Users</CardTitle>
          <CardDescription>
            Total {filteredUsers.length} users found
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
                    <TableHead>Contact</TableHead>
                    <TableHead>Location</TableHead>
                    <TableHead>Subscription</TableHead>
                    <TableHead>Devices</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Joined</TableHead>
                    <TableHead className="w-[50px]"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredUsers.map((user) => (
                    <TableRow key={user._id} className="table-row-hover">
                      <TableCell>
                        <div className="flex items-center gap-3">
                          <Avatar>
                            <AvatarImage src={user.profileImage} />
                            <AvatarFallback>
                              {user.name?.charAt(0)?.toUpperCase() || "U"}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <p className="font-medium">{user.name}</p>
                            <p className="text-sm text-muted-foreground">
                              ID: {user._id.slice(-6)}
                            </p>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="text-sm">{user.email}</p>
                          <p className="text-sm text-muted-foreground">
                            {user.phone}
                          </p>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="text-sm">{user.district || "-"}</p>
                          <p className="text-sm text-muted-foreground">
                            {user.state || "-"}
                          </p>
                        </div>
                      </TableCell>
                      <TableCell>{getSubscriptionBadge(user.subscription)}</TableCell>
                      <TableCell>
                        <div className="flex flex-col gap-1">
                          {getDeviceBadge("Pump", user.deviceAccess.pump)}
                          {getDeviceBadge("Krishi Doctor", user.deviceAccess.krishiDoctor)}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={user.isActive ? "success" : "destructive"}>
                          {user.isActive ? "Active" : "Inactive"}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {formatDate(user.createdAt)}
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
                                setSelectedUser(user);
                                setShowUserDialog(true);
                              }}
                            >
                              <Eye className="w-4 h-4 mr-2" />
                              View Details
                            </DropdownMenuItem>
                            <DropdownMenuItem
                              onClick={() =>
                                handleUpdateSubscription(
                                  user._id,
                                  user.subscription?.type === "premium"
                                    ? "free"
                                    : "premium"
                                )
                              }
                            >
                              <Crown className="w-4 h-4 mr-2" />
                              {user.subscription?.type === "premium"
                                ? "Remove Premium"
                                : "Make Premium"}
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem className="text-destructive">
                              <Trash2 className="w-4 h-4 mr-2" />
                              Delete User
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

          {/* Pagination */}
          {!isLoading && filteredUsers.length > 0 && (
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

      {/* User Details Dialog */}
      <Dialog open={showUserDialog} onOpenChange={setShowUserDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>User Details</DialogTitle>
            <DialogDescription>
              Complete information about the user
            </DialogDescription>
          </DialogHeader>
          {selectedUser && (
            <div className="grid gap-6 py-4">
              <div className="flex items-center gap-4">
                <Avatar className="w-20 h-20">
                  <AvatarImage src={selectedUser.profileImage} />
                  <AvatarFallback className="text-2xl">
                    {selectedUser.name?.charAt(0)?.toUpperCase() || "U"}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <h3 className="text-xl font-semibold">{selectedUser.name}</h3>
                  <p className="text-muted-foreground">{selectedUser.email}</p>
                  {getSubscriptionBadge(selectedUser.subscription)}
                </div>
              </div>

              <div className="space-y-3">
                <p className="font-medium">Device Access (Admin Control)</p>
                <div className="grid grid-cols-2 gap-3">
                  <Button
                    variant={selectedUser.deviceAccess.pump.purchased ? "default" : "outline"}
                    onClick={() =>
                      updateDeviceAccess(
                        selectedUser,
                        "pump",
                        "purchased",
                        !selectedUser.deviceAccess.pump.purchased
                      )
                    }
                  >
                    Pump Purchased: {selectedUser.deviceAccess.pump.purchased ? "Yes" : "No"}
                  </Button>
                  <Button
                    variant={selectedUser.deviceAccess.pump.enabled ? "default" : "outline"}
                    onClick={() =>
                      updateDeviceAccess(
                        selectedUser,
                        "pump",
                        "enabled",
                        !selectedUser.deviceAccess.pump.enabled
                      )
                    }
                  >
                    Pump Enabled: {selectedUser.deviceAccess.pump.enabled ? "Yes" : "No"}
                  </Button>
                  <Button
                    variant={selectedUser.deviceAccess.krishiDoctor.purchased ? "default" : "outline"}
                    onClick={() =>
                      updateDeviceAccess(
                        selectedUser,
                        "krishiDoctor",
                        "purchased",
                        !selectedUser.deviceAccess.krishiDoctor.purchased
                      )
                    }
                  >
                    Krishi Doctor Purchased: {selectedUser.deviceAccess.krishiDoctor.purchased ? "Yes" : "No"}
                  </Button>
                  <Button
                    variant={selectedUser.deviceAccess.krishiDoctor.enabled ? "default" : "outline"}
                    onClick={() =>
                      updateDeviceAccess(
                        selectedUser,
                        "krishiDoctor",
                        "enabled",
                        !selectedUser.deviceAccess.krishiDoctor.enabled
                      )
                    }
                  >
                    Krishi Doctor Enabled: {selectedUser.deviceAccess.krishiDoctor.enabled ? "Yes" : "No"}
                  </Button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-muted-foreground">Phone</p>
                  <p className="font-medium">{selectedUser.phone}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Status</p>
                  <Badge variant={selectedUser.isActive ? "success" : "destructive"}>
                    {selectedUser.isActive ? "Active" : "Inactive"}
                  </Badge>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">State</p>
                  <p className="font-medium">{selectedUser.state || "-"}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">District</p>
                  <p className="font-medium">{selectedUser.district || "-"}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Joined</p>
                  <p className="font-medium">{formatDate(selectedUser.createdAt)}</p>
                </div>
                {selectedUser.subscription?.expiresAt && (
                  <div>
                    <p className="text-sm text-muted-foreground">
                      Subscription Expires
                    </p>
                    <p className="font-medium">
                      {formatDate(selectedUser.subscription.expiresAt)}
                    </p>
                  </div>
                )}
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
