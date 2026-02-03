"use client";

import React, { useEffect, useState } from "react";
import {
  Plus,
  Search,
  MoreVertical,
  Edit,
  Trash2,
  Loader2,
  Calendar,
  Leaf,
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
import { cropCalendarAPI } from "@/lib/api";

interface CropEntry {
  _id: string;
  cropName: string;
  season: string;
  sowingStart: string;
  sowingEnd: string;
  harvestStart: string;
  harvestEnd: string;
  region: string;
  tips?: string;
  isActive: boolean;
  createdAt: string;
}

const seasons = ["Kharif", "Rabi", "Zaid", "Year-round"];
const regions = [
  "North India",
  "South India",
  "East India",
  "West India",
  "Central India",
  "All India",
];
const months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

export default function CropCalendarPage() {
  const [entries, setEntries] = useState<CropEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [seasonFilter, setSeasonFilter] = useState("all");
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    cropName: "",
    season: "",
    sowingStart: "",
    sowingEnd: "",
    harvestStart: "",
    harvestEnd: "",
    region: "",
    tips: "",
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchEntries();
  }, [seasonFilter]);

  const fetchEntries = async () => {
    try {
      setIsLoading(true);
      const response = await cropCalendarAPI.getCalendar();
      // API returns: { success, count, data: [...] }
      if (response.data.success) {
        setEntries(response.data.data || []);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch crop calendar",
        variant: "destructive",
      });
      // Mock data
      setEntries([
        {
          _id: "1",
          cropName: "Rice (Paddy)",
          season: "Kharif",
          sowingStart: "June",
          sowingEnd: "July",
          harvestStart: "October",
          harvestEnd: "November",
          region: "All India",
          tips: "Transplant seedlings when 25-30 days old",
          isActive: true,
          createdAt: "2024-01-01",
        },
        {
          _id: "2",
          cropName: "Wheat",
          season: "Rabi",
          sowingStart: "October",
          sowingEnd: "November",
          harvestStart: "March",
          harvestEnd: "April",
          region: "North India",
          tips: "Irrigate 5-6 times during crop period",
          isActive: true,
          createdAt: "2024-01-01",
        },
        {
          _id: "3",
          cropName: "Cotton",
          season: "Kharif",
          sowingStart: "April",
          sowingEnd: "May",
          harvestStart: "October",
          harvestEnd: "December",
          region: "Central India",
          tips: "Maintain proper plant spacing",
          isActive: true,
          createdAt: "2024-01-01",
        },
        {
          _id: "4",
          cropName: "Sugarcane",
          season: "Year-round",
          sowingStart: "February",
          sowingEnd: "March",
          harvestStart: "December",
          harvestEnd: "March",
          region: "All India",
          tips: "Provide adequate irrigation during summer",
          isActive: true,
          createdAt: "2024-01-01",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.cropName || !formData.season || !formData.sowingStart || !formData.harvestStart) {
      toast({
        title: "Error",
        description: "Please fill all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      await cropCalendarAPI.createEntry(formData);
      toast({
        title: "Success",
        description: "Crop calendar entry created",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        cropName: "",
        season: "",
        sowingStart: "",
        sowingEnd: "",
        harvestStart: "",
        harvestEnd: "",
        region: "",
        tips: "",
      });
      fetchEntries();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create entry",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this entry?")) return;

    try {
      await cropCalendarAPI.deleteEntry(id);
      toast({
        title: "Success",
        description: "Entry deleted",
        variant: "success",
      });
      fetchEntries();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete entry",
        variant: "destructive",
      });
    }
  };

  const getSeasonColor = (season: string) => {
    switch (season) {
      case "Kharif":
        return "bg-green-100 text-green-700 border-green-200";
      case "Rabi":
        return "bg-yellow-100 text-yellow-700 border-yellow-200";
      case "Zaid":
        return "bg-orange-100 text-orange-700 border-orange-200";
      default:
        return "bg-blue-100 text-blue-700 border-blue-200";
    }
  };

  const filteredEntries = entries.filter((entry) => {
    if (seasonFilter === "all") return true;
    return entry.season === seasonFilter;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Crop Calendar</h1>
          <p className="text-muted-foreground">
            Manage sowing and harvesting schedules
          </p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Add Entry
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Add Crop Entry</DialogTitle>
              <DialogDescription>
                Add a new crop to the calendar
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="cropName">Crop Name *</Label>
                  <Input
                    id="cropName"
                    value={formData.cropName}
                    onChange={(e) =>
                      setFormData({ ...formData, cropName: e.target.value })
                    }
                    placeholder="e.g., Rice, Wheat"
                  />
                </div>
                <div className="space-y-2">
                  <Label>Season *</Label>
                  <Select
                    value={formData.season}
                    onValueChange={(value) =>
                      setFormData({ ...formData, season: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {seasons.map((s) => (
                        <SelectItem key={s} value={s}>
                          {s}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Sowing Start *</Label>
                  <Select
                    value={formData.sowingStart}
                    onValueChange={(value) =>
                      setFormData({ ...formData, sowingStart: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Month" />
                    </SelectTrigger>
                    <SelectContent>
                      {months.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Sowing End</Label>
                  <Select
                    value={formData.sowingEnd}
                    onValueChange={(value) =>
                      setFormData({ ...formData, sowingEnd: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Month" />
                    </SelectTrigger>
                    <SelectContent>
                      {months.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Harvest Start *</Label>
                  <Select
                    value={formData.harvestStart}
                    onValueChange={(value) =>
                      setFormData({ ...formData, harvestStart: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Month" />
                    </SelectTrigger>
                    <SelectContent>
                      {months.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Harvest End</Label>
                  <Select
                    value={formData.harvestEnd}
                    onValueChange={(value) =>
                      setFormData({ ...formData, harvestEnd: value })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Month" />
                    </SelectTrigger>
                    <SelectContent>
                      {months.map((m) => (
                        <SelectItem key={m} value={m}>
                          {m}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2">
                <Label>Region</Label>
                <Select
                  value={formData.region}
                  onValueChange={(value) =>
                    setFormData({ ...formData, region: value })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select region" />
                  </SelectTrigger>
                  <SelectContent>
                    {regions.map((r) => (
                      <SelectItem key={r} value={r}>
                        {r}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="tips">Tips</Label>
                <textarea
                  id="tips"
                  className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.tips}
                  onChange={(e) =>
                    setFormData({ ...formData, tips: e.target.value })
                  }
                  placeholder="Cultivation tips and advice"
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
                  "Add Entry"
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
              <Input placeholder="Search crops..." className="w-full" />
            </div>
            <Select value={seasonFilter} onValueChange={setSeasonFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filter by season" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Seasons</SelectItem>
                {seasons.map((s) => (
                  <SelectItem key={s} value={s}>
                    {s}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Calendar Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filteredEntries.map((entry) => (
            <Card key={entry._id} className="card-hover">
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-2 bg-green-100 rounded-lg">
                      <Leaf className="w-5 h-5 text-green-600" />
                    </div>
                    <Badge className={getSeasonColor(entry.season)}>
                      {entry.season}
                    </Badge>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon" className="h-8 w-8">
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>
                        <Edit className="w-4 h-4 mr-2" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem
                        className="text-destructive"
                        onClick={() => handleDelete(entry._id)}
                      >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
                <CardTitle className="text-lg mt-3">{entry.cropName}</CardTitle>
                {entry.region && (
                  <CardDescription>{entry.region}</CardDescription>
                )}
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  <div className="flex items-center gap-2 p-2 bg-green-50 rounded-lg">
                    <Calendar className="w-4 h-4 text-green-600" />
                    <div>
                      <p className="text-xs text-muted-foreground">Sowing</p>
                      <p className="text-sm font-medium">
                        {entry.sowingStart}
                        {entry.sowingEnd && ` - ${entry.sowingEnd}`}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 p-2 bg-yellow-50 rounded-lg">
                    <Calendar className="w-4 h-4 text-yellow-600" />
                    <div>
                      <p className="text-xs text-muted-foreground">Harvest</p>
                      <p className="text-sm font-medium">
                        {entry.harvestStart}
                        {entry.harvestEnd && ` - ${entry.harvestEnd}`}
                      </p>
                    </div>
                  </div>
                  {entry.tips && (
                    <div className="pt-2 border-t">
                      <p className="text-xs text-muted-foreground mb-1">Tips</p>
                      <p className="text-sm">{entry.tips}</p>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
