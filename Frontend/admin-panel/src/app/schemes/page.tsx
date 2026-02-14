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
  Leaf,
  ExternalLink,
  Calendar,
  IndianRupee,
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
import { formatDate, truncate } from "@/lib/utils";
import { schemeAPI } from "@/lib/api";

interface Scheme {
  _id: string;
  title: string;
  description: string;
  content?: string;
  category: string;
  eligibility?: string;
  benefits?: string;
  applicationUrl?: string;
  startDate?: string;
  endDate?: string;
  isActive: boolean;
  views: number;
  createdAt: string;
}

const categories = [
  "Central Government",
  "State Government",
  "Subsidy",
  "Loan",
  "Insurance",
  "Training",
  "Others",
];

export default function SchemesPage() {
  const [schemes, setSchemes] = useState<Scheme[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [selectedScheme, setSelectedScheme] = useState<Scheme | null>(null);
  const [showSchemeDialog, setShowSchemeDialog] = useState(false);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    content: "",
    category: "",
    eligibility: "",
    benefits: "",
    applicationUrl: "",
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchSchemes();
  }, [categoryFilter]);

  const fetchSchemes = async () => {
    try {
      setIsLoading(true);
      const response = await schemeAPI.getSchemes(1, 50);
      // API returns array directly: [...]
      if (Array.isArray(response.data)) {
        setSchemes(response.data || []);
      } else if (response.data.success) {
        setSchemes(response.data.data || []);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to fetch schemes",
        variant: "destructive",
      });
      // Mock data
      setSchemes([
        {
          _id: "1",
          title: "PM-KISAN Samman Nidhi",
          description: "Direct income support of Rs. 6000 per year to farmer families",
          content: "Full details about the scheme...",
          category: "Central Government",
          eligibility: "All land-holding farmer families",
          benefits: "Rs. 6000 per year in three installments",
          applicationUrl: "https://pmkisan.gov.in",
          isActive: true,
          views: 45600,
          createdAt: "2024-01-01",
        },
        {
          _id: "2",
          title: "Kisan Credit Card Scheme",
          description: "Easy access to credit for agricultural needs",
          category: "Loan",
          eligibility: "All farmers including tenant farmers",
          benefits: "Credit up to Rs. 3 lakh at subsidized rates",
          isActive: true,
          views: 32100,
          createdAt: "2024-01-05",
        },
        {
          _id: "3",
          title: "Pradhan Mantri Fasal Bima Yojana",
          description: "Crop insurance scheme for farmers",
          category: "Insurance",
          eligibility: "All farmers growing notified crops",
          benefits: "Insurance coverage against crop loss",
          isActive: true,
          views: 28900,
          createdAt: "2024-01-10",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.description || !formData.category) {
      toast({
        title: "Error",
        description: "Please fill all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsSubmitting(true);
      await schemeAPI.createScheme(formData);
      toast({
        title: "Success",
        description: "Scheme created successfully",
        variant: "success",
      });
      setShowCreateDialog(false);
      setFormData({
        title: "",
        description: "",
        content: "",
        category: "",
        eligibility: "",
        benefits: "",
        applicationUrl: "",
      });
      fetchSchemes();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create scheme",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this scheme?")) return;

    try {
      await schemeAPI.deleteScheme(id);
      toast({
        title: "Success",
        description: "Scheme deleted",
        variant: "success",
      });
      fetchSchemes();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete scheme",
        variant: "destructive",
      });
    }
  };

  const filteredSchemes = schemes.filter((scheme) => {
    const matchesCategory =
      categoryFilter === "all" || scheme.category === categoryFilter;
    const matchesSearch = scheme.title
      .toLowerCase()
      .includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Government Schemes</h1>
          <p className="text-muted-foreground">
            Manage agricultural schemes and benefits
          </p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Add Scheme
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>Create Scheme</DialogTitle>
              <DialogDescription>
                Add a new government scheme
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="title">Title *</Label>
                  <Input
                    id="title"
                    value={formData.title}
                    onChange={(e) =>
                      setFormData({ ...formData, title: e.target.value })
                    }
                    placeholder="Scheme title"
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
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Short Description *</Label>
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
                <Label htmlFor="content">Full Content</Label>
                <textarea
                  id="content"
                  className="w-full min-h-[120px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.content}
                  onChange={(e) =>
                    setFormData({ ...formData, content: e.target.value })
                  }
                  placeholder="Detailed information about the scheme"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="eligibility">Eligibility</Label>
                <textarea
                  id="eligibility"
                  className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.eligibility}
                  onChange={(e) =>
                    setFormData({ ...formData, eligibility: e.target.value })
                  }
                  placeholder="Who can apply for this scheme"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="benefits">Benefits</Label>
                <textarea
                  id="benefits"
                  className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background resize-none"
                  value={formData.benefits}
                  onChange={(e) =>
                    setFormData({ ...formData, benefits: e.target.value })
                  }
                  placeholder="Benefits of this scheme"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="applicationUrl">Application URL</Label>
                <Input
                  id="applicationUrl"
                  value={formData.applicationUrl}
                  onChange={(e) =>
                    setFormData({ ...formData, applicationUrl: e.target.value })
                  }
                  placeholder="https://example.gov.in/apply"
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
                  "Create Scheme"
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
            <div className="flex-1 flex gap-2">
              <Input
                placeholder="Search schemes..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="flex-1"
              />
              <Button variant="secondary">
                <Search className="w-4 h-4" />
              </Button>
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

      {/* Schemes Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filteredSchemes.map((scheme) => (
            <Card key={scheme._id} className="card-hover">
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-2 bg-primary/10 rounded-lg">
                      <Leaf className="w-5 h-5 text-primary" />
                    </div>
                    <Badge variant="outline">{scheme.category}</Badge>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon" className="h-8 w-8">
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem
                        onClick={() => {
                          setSelectedScheme(scheme);
                          setShowSchemeDialog(true);
                        }}
                      >
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
                        onClick={() => handleDelete(scheme._id)}
                      >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
                <CardTitle className="text-lg mt-3">{scheme.title}</CardTitle>
                <CardDescription>
                  {truncate(scheme.description, 100)}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {scheme.benefits && (
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">Benefits</p>
                      <p className="text-sm">{truncate(scheme.benefits, 80)}</p>
                    </div>
                  )}
                  <div className="flex items-center justify-between pt-3 border-t">
                    <div className="flex items-center gap-1 text-sm text-muted-foreground">
                      <Eye className="w-4 h-4" />
                      {scheme.views?.toLocaleString() || 0} views
                    </div>
                    {scheme.applicationUrl && (
                      <a
                        href={scheme.applicationUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sm text-primary flex items-center gap-1"
                      >
                        Apply <ExternalLink className="w-3 h-3" />
                      </a>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Scheme Details Dialog */}
      <Dialog open={showSchemeDialog} onOpenChange={setShowSchemeDialog}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{selectedScheme?.title}</DialogTitle>
            <DialogDescription>
              <Badge variant="outline">{selectedScheme?.category}</Badge>
            </DialogDescription>
          </DialogHeader>
          {selectedScheme && (
            <div className="space-y-4">
              <p>{selectedScheme.description}</p>

              {selectedScheme.content && (
                <div>
                  <h4 className="font-semibold mb-2">Details</h4>
                  <p className="text-sm text-muted-foreground">
                    {selectedScheme.content}
                  </p>
                </div>
              )}

              {selectedScheme.eligibility && (
                <div>
                  <h4 className="font-semibold mb-2">Eligibility</h4>
                  <p className="text-sm text-muted-foreground">
                    {selectedScheme.eligibility}
                  </p>
                </div>
              )}

              {selectedScheme.benefits && (
                <div>
                  <h4 className="font-semibold mb-2">Benefits</h4>
                  <p className="text-sm text-muted-foreground">
                    {selectedScheme.benefits}
                  </p>
                </div>
              )}

              {selectedScheme.applicationUrl && (
                <Button asChild className="w-full">
                  <a
                    href={selectedScheme.applicationUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Apply Now <ExternalLink className="w-4 h-4 ml-2" />
                  </a>
                </Button>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
