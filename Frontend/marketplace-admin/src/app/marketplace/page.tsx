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
  Store,
  Star,
  MessageCircle,
  Filter,
  X,
  ImageIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";
import { marketplaceAPI } from "@/lib/api";

interface MarketplaceProduct {
  _id: string;
  title: string;
  shortDescription: string;
  detailedDescription?: string;
  priceRange: { min: number; max: number; currency?: string };
  images?: string[];
  media?: Array<{ type: string; url: string; isYoutubeVideo?: boolean }>;
  sellerInfo?: {
    userId: string;
    userName: string;
    profilePhoto?: string;
    contactNumber?: string;
  };
  sellerName?: string;
  rating: number;
  views?: number;
  status?: "active" | "sold" | "unavailable";
  category?: string;
  condition?: "New" | "Used" | "Refurbished";
  location?: string;
  tags?: string[];
  comments?: Array<{
    _id: string;
    user: string;
    userName: string;
    text: string;
    createdAt: string;
    replies?: Array<{
      _id: string;
      user: string;
      userName: string;
      text: string;
      createdAt: string;
    }>;
  }>;
  createdAt?: string;
  updatedAt?: string;
}

interface FormData {
  title: string;
  shortDescription: string;
  detailedDescription: string;
  priceMin: string;
  priceMax: string;
  category: string;
  condition: string;
  location: string;
  tags: string;
  mediaUrls: string;
  contactNumber: string;
  userId: string;
  status: string;
}

const categories = [
  "Agriculture Equipment",
  "Seeds & Plants",
  "Fertilizers",
  "Pesticides",
  "Irrigation",
  "Farm Machinery",
  "Livestock",
  "Dairy Products",
  "Organic Products",
  "Tools & Accessories",
  "Others",
];

const conditions = ["New", "Used", "Refurbished"];
const statuses = ["active", "sold", "unavailable"];

export default function MarketplacePage() {
  const [products, setProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [conditionFilter, setConditionFilter] = useState("all");
  const [selectedProduct, setSelectedProduct] = useState<MarketplaceProduct | null>(null);
  const [showViewDialog, setShowViewDialog] = useState(false);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState<FormData>({
    title: "",
    shortDescription: "",
    detailedDescription: "",
    priceMin: "",
    priceMax: "",
    category: "",
    condition: "New",
    location: "",
    tags: "",
    mediaUrls: "",
    contactNumber: "",
    userId: "",
    status: "active",
  });

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      setIsLoading(true);
      const response = await marketplaceAPI.getAll(1, 100);
      if (response.data.success) {
        setProducts(response.data.data || []);
      }
    } catch (error) {
      console.error("Fetch error:", error);
      toast.error("Failed to fetch marketplace products");
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      fetchProducts();
      return;
    }

    try {
      setIsLoading(true);
      const response = await marketplaceAPI.search({
        keyword: searchQuery,
        category: categoryFilter !== "all" ? categoryFilter : undefined,
        condition: conditionFilter !== "all" ? conditionFilter : undefined,
      });
      if (response.data.success) {
        setProducts(response.data.data || []);
      }
    } catch (error) {
      toast.error("Search failed");
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.shortDescription || !formData.priceMin || !formData.priceMax) {
      toast.error("Please fill all required fields");
      return;
    }

    try {
      setIsSubmitting(true);
      const media = formData.mediaUrls
        .split("\n")
        .filter((url) => url.trim())
        .map((url) => ({
          type: url.includes("youtube") ? "video" : "image" as "image" | "video",
          url: url.trim(),
          isYoutubeVideo: url.includes("youtube"),
        }));

      await marketplaceAPI.create({
        userId: formData.userId || "admin",
        title: formData.title,
        shortDescription: formData.shortDescription,
        detailedDescription: formData.detailedDescription,
        media,
        priceRange: {
          min: parseFloat(formData.priceMin),
          max: parseFloat(formData.priceMax),
        },
        contactNumber: formData.contactNumber,
        category: formData.category,
        condition: formData.condition as "New" | "Used" | "Refurbished",
        location: formData.location,
        tags: formData.tags.split(",").map((t) => t.trim()).filter(Boolean),
      });

      toast.success("Product created successfully");
      setShowCreateDialog(false);
      resetForm();
      fetchProducts();
    } catch (error) {
      toast.error("Failed to create product");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleUpdate = async () => {
    if (!selectedProduct) return;

    try {
      setIsSubmitting(true);
      const media = formData.mediaUrls
        .split("\n")
        .filter((url) => url.trim())
        .map((url) => ({
          type: url.includes("youtube") ? "video" : "image" as "image" | "video",
          url: url.trim(),
          isYoutubeVideo: url.includes("youtube"),
        }));

      await marketplaceAPI.update(selectedProduct._id, {
        title: formData.title,
        shortDescription: formData.shortDescription,
        detailedDescription: formData.detailedDescription,
        media,
        priceRange: {
          min: parseFloat(formData.priceMin),
          max: parseFloat(formData.priceMax),
        },
        contactNumber: formData.contactNumber,
        category: formData.category,
        condition: formData.condition as "New" | "Used" | "Refurbished",
        location: formData.location,
        tags: formData.tags.split(",").map((t) => t.trim()).filter(Boolean),
        status: formData.status as "active" | "sold" | "unavailable",
      });

      toast.success("Product updated successfully");
      setShowEditDialog(false);
      resetForm();
      fetchProducts();
    } catch (error) {
      toast.error("Failed to update product");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this product?")) return;

    try {
      await marketplaceAPI.delete(id);
      toast.success("Product deleted successfully");
      fetchProducts();
    } catch (error) {
      toast.error("Failed to delete product");
    }
  };

  const handleViewProduct = async (product: MarketplaceProduct) => {
    try {
      const response = await marketplaceAPI.getById(product._id);
      if (response.data.success) {
        setSelectedProduct(response.data.data);
        setShowViewDialog(true);
      }
    } catch (error) {
      toast.error("Failed to fetch product details");
    }
  };

  const handleEditProduct = (product: MarketplaceProduct) => {
    setSelectedProduct(product);
    setFormData({
      title: product.title,
      shortDescription: product.shortDescription,
      detailedDescription: product.detailedDescription || "",
      priceMin: product.priceRange.min.toString(),
      priceMax: product.priceRange.max.toString(),
      category: product.category || "",
      condition: product.condition || "New",
      location: product.location || "",
      tags: product.tags?.join(", ") || "",
      mediaUrls: product.media?.map((m) => m.url).join("\n") || product.images?.join("\n") || "",
      contactNumber: product.sellerInfo?.contactNumber || "",
      userId: product.sellerInfo?.userId || "",
      status: product.status || "active",
    });
    setShowEditDialog(true);
  };

  const resetForm = () => {
    setFormData({
      title: "",
      shortDescription: "",
      detailedDescription: "",
      priceMin: "",
      priceMax: "",
      category: "",
      condition: "New",
      location: "",
      tags: "",
      mediaUrls: "",
      contactNumber: "",
      userId: "",
      status: "active",
    });
    setSelectedProduct(null);
  };

  const filteredProducts = products.filter((product) => {
    const matchesSearch = product.title.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = categoryFilter === "all" || product.category === categoryFilter;
    const matchesStatus = statusFilter === "all" || product.status === statusFilter;
    const matchesCondition = conditionFilter === "all" || product.condition === conditionFilter;
    return matchesSearch && matchesCategory && matchesStatus && matchesCondition;
  });

  const getStatusColor = (status?: string) => {
    switch (status) {
      case "active":
        return "bg-emerald-100 text-emerald-700";
      case "sold":
        return "bg-blue-100 text-blue-700";
      case "unavailable":
        return "bg-gray-100 text-gray-700";
      default:
        return "bg-emerald-100 text-emerald-700";
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Marketplace Products</h1>
          <p className="text-gray-500">Manage marketplace product listings</p>
        </div>
        <Button onClick={() => setShowCreateDialog(true)} className="bg-emerald-600 hover:bg-emerald-700">
          <Plus className="w-4 h-4 mr-2" />
          Add Product
        </Button>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-emerald-100 rounded-lg">
                <Store className="w-6 h-6 text-emerald-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{products.length}</p>
                <p className="text-sm text-gray-500">Total Products</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-green-100 rounded-lg">
                <Store className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {products.filter((p) => p.status === "active" || !p.status).length}
                </p>
                <p className="text-sm text-gray-500">Active</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-blue-100 rounded-lg">
                <Store className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {products.filter((p) => p.status === "sold").length}
                </p>
                <p className="text-sm text-gray-500">Sold</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="p-2 bg-orange-100 rounded-lg">
                <Eye className="w-6 h-6 text-orange-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {products.reduce((acc, p) => acc + (p.views || 0), 0).toLocaleString()}
                </p>
                <p className="text-sm text-gray-500">Total Views</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 flex gap-2">
              <Input
                placeholder="Search products..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                className="flex-1"
              />
              <Button variant="secondary" onClick={handleSearch}>
                <Search className="w-4 h-4" />
              </Button>
            </div>
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Category" />
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
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[140px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                {statuses.map((s) => (
                  <SelectItem key={s} value={s}>
                    {s.charAt(0).toUpperCase() + s.slice(1)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={conditionFilter} onValueChange={setConditionFilter}>
              <SelectTrigger className="w-[140px]">
                <SelectValue placeholder="Condition" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Conditions</SelectItem>
                {conditions.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Products Table */}
      <Card>
        <CardHeader>
          <CardTitle>All Products</CardTitle>
          <CardDescription>{filteredProducts.length} products found</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="w-8 h-8 animate-spin text-emerald-600" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Product</TableHead>
                    <TableHead>Price Range</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>Condition</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Rating</TableHead>
                    <TableHead>Views</TableHead>
                    <TableHead className="w-[50px]"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredProducts.map((product) => (
                    <TableRow key={product._id} className="cursor-pointer hover:bg-gray-50">
                      <TableCell>
                        <div className="flex items-center gap-3">
                          <div className="w-12 h-12 rounded-lg bg-gray-100 flex items-center justify-center overflow-hidden">
                            {product.images?.[0] || product.media?.[0]?.url ? (
                              <img
                                src={product.images?.[0] || product.media?.[0]?.url}
                                alt={product.title}
                                className="w-full h-full object-cover"
                              />
                            ) : (
                              <ImageIcon className="w-5 h-5 text-gray-400" />
                            )}
                          </div>
                          <div>
                            <p className="font-medium text-gray-900 truncate max-w-[200px]">
                              {product.title}
                            </p>
                            <p className="text-sm text-gray-500 truncate max-w-[200px]">
                              {product.shortDescription}
                            </p>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="font-medium">
                          ₹{product.priceRange.min.toLocaleString()} - ₹{product.priceRange.max.toLocaleString()}
                        </span>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">{product.category || "N/A"}</Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">{product.condition || "N/A"}</Badge>
                      </TableCell>
                      <TableCell>
                        <Badge className={getStatusColor(product.status)}>
                          {product.status || "active"}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                          <span>{product.rating || 0}</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Eye className="w-4 h-4 text-gray-400" />
                          <span>{product.views || 0}</span>
                        </div>
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
                            <DropdownMenuItem onClick={() => handleViewProduct(product)}>
                              <Eye className="w-4 h-4 mr-2" />
                              View Details
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => handleEditProduct(product)}>
                              <Edit className="w-4 h-4 mr-2" />
                              Edit
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                              className="text-red-600"
                              onClick={() => handleDelete(product._id)}
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

      {/* Create Product Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Create Marketplace Product</DialogTitle>
            <DialogDescription>Add a new product listing to the marketplace</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="title">Title *</Label>
                <Input
                  id="title"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="Product title"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="category">Category *</Label>
                <Select
                  value={formData.category}
                  onValueChange={(value) => setFormData({ ...formData, category: value })}
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
              <Label htmlFor="shortDescription">Short Description *</Label>
              <Textarea
                id="shortDescription"
                value={formData.shortDescription}
                onChange={(e) => setFormData({ ...formData, shortDescription: e.target.value })}
                placeholder="Brief description (shown in listings)"
                rows={2}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="detailedDescription">Detailed Description</Label>
              <Textarea
                id="detailedDescription"
                value={formData.detailedDescription}
                onChange={(e) => setFormData({ ...formData, detailedDescription: e.target.value })}
                placeholder="Full product description"
                rows={4}
              />
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div className="space-y-2">
                <Label htmlFor="priceMin">Min Price (INR) *</Label>
                <Input
                  id="priceMin"
                  type="number"
                  value={formData.priceMin}
                  onChange={(e) => setFormData({ ...formData, priceMin: e.target.value })}
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="priceMax">Max Price (INR) *</Label>
                <Input
                  id="priceMax"
                  type="number"
                  value={formData.priceMax}
                  onChange={(e) => setFormData({ ...formData, priceMax: e.target.value })}
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="condition">Condition</Label>
                <Select
                  value={formData.condition}
                  onValueChange={(value) => setFormData({ ...formData, condition: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {conditions.map((c) => (
                      <SelectItem key={c} value={c}>
                        {c}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="location">Location</Label>
                <Input
                  id="location"
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                  placeholder="City, State"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="contactNumber">Contact Number</Label>
                <Input
                  id="contactNumber"
                  value={formData.contactNumber}
                  onChange={(e) => setFormData({ ...formData, contactNumber: e.target.value })}
                  placeholder="+91 9876543210"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="tags">Tags (comma separated)</Label>
              <Input
                id="tags"
                value={formData.tags}
                onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
                placeholder="organic, premium, sale"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="mediaUrls">Media URLs (one per line)</Label>
              <Textarea
                id="mediaUrls"
                value={formData.mediaUrls}
                onChange={(e) => setFormData({ ...formData, mediaUrls: e.target.value })}
                placeholder="https://example.com/image1.jpg&#10;https://example.com/image2.jpg"
                rows={3}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="userId">Seller User ID</Label>
              <Input
                id="userId"
                value={formData.userId}
                onChange={(e) => setFormData({ ...formData, userId: e.target.value })}
                placeholder="User ID of the seller"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => { setShowCreateDialog(false); resetForm(); }}>
              Cancel
            </Button>
            <Button onClick={handleCreate} disabled={isSubmitting} className="bg-emerald-600 hover:bg-emerald-700">
              {isSubmitting ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Creating...
                </>
              ) : (
                "Create Product"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Product Dialog */}
      <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Edit Product</DialogTitle>
            <DialogDescription>Update product information</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit-title">Title *</Label>
                <Input
                  id="edit-title"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="Product title"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-category">Category *</Label>
                <Select
                  value={formData.category}
                  onValueChange={(value) => setFormData({ ...formData, category: value })}
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
              <Label htmlFor="edit-shortDescription">Short Description *</Label>
              <Textarea
                id="edit-shortDescription"
                value={formData.shortDescription}
                onChange={(e) => setFormData({ ...formData, shortDescription: e.target.value })}
                placeholder="Brief description"
                rows={2}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="edit-detailedDescription">Detailed Description</Label>
              <Textarea
                id="edit-detailedDescription"
                value={formData.detailedDescription}
                onChange={(e) => setFormData({ ...formData, detailedDescription: e.target.value })}
                placeholder="Full product description"
                rows={4}
              />
            </div>

            <div className="grid grid-cols-4 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit-priceMin">Min Price *</Label>
                <Input
                  id="edit-priceMin"
                  type="number"
                  value={formData.priceMin}
                  onChange={(e) => setFormData({ ...formData, priceMin: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-priceMax">Max Price *</Label>
                <Input
                  id="edit-priceMax"
                  type="number"
                  value={formData.priceMax}
                  onChange={(e) => setFormData({ ...formData, priceMax: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-condition">Condition</Label>
                <Select
                  value={formData.condition}
                  onValueChange={(value) => setFormData({ ...formData, condition: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {conditions.map((c) => (
                      <SelectItem key={c} value={c}>
                        {c}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-status">Status</Label>
                <Select
                  value={formData.status}
                  onValueChange={(value) => setFormData({ ...formData, status: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {statuses.map((s) => (
                      <SelectItem key={s} value={s}>
                        {s.charAt(0).toUpperCase() + s.slice(1)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit-location">Location</Label>
                <Input
                  id="edit-location"
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-contactNumber">Contact Number</Label>
                <Input
                  id="edit-contactNumber"
                  value={formData.contactNumber}
                  onChange={(e) => setFormData({ ...formData, contactNumber: e.target.value })}
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="edit-tags">Tags (comma separated)</Label>
              <Input
                id="edit-tags"
                value={formData.tags}
                onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="edit-mediaUrls">Media URLs (one per line)</Label>
              <Textarea
                id="edit-mediaUrls"
                value={formData.mediaUrls}
                onChange={(e) => setFormData({ ...formData, mediaUrls: e.target.value })}
                rows={3}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => { setShowEditDialog(false); resetForm(); }}>
              Cancel
            </Button>
            <Button onClick={handleUpdate} disabled={isSubmitting} className="bg-emerald-600 hover:bg-emerald-700">
              {isSubmitting ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Updating...
                </>
              ) : (
                "Update Product"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* View Product Dialog */}
      <Dialog open={showViewDialog} onOpenChange={setShowViewDialog}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-hidden">
          <DialogHeader>
            <DialogTitle>Product Details</DialogTitle>
          </DialogHeader>
          {selectedProduct && (
            <Tabs defaultValue="details" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="details">Details</TabsTrigger>
                <TabsTrigger value="comments">
                  Comments ({selectedProduct.comments?.length || 0})
                </TabsTrigger>
              </TabsList>
              <TabsContent value="details" className="space-y-4">
                <ScrollArea className="h-[60vh] pr-4">
                  {/* Images */}
                  {(selectedProduct.media?.length || selectedProduct.images?.length) && (
                    <div className="grid grid-cols-3 gap-2 mb-4">
                      {(selectedProduct.media || selectedProduct.images?.map(url => ({ type: 'image', url })))?.slice(0, 6).map((m, i) => (
                        <div key={i} className="aspect-square rounded-lg overflow-hidden bg-gray-100">
                          <img
                            src={typeof m === 'string' ? m : m.url}
                            alt={`${selectedProduct.title} ${i + 1}`}
                            className="w-full h-full object-cover"
                          />
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Basic Info */}
                  <div className="space-y-4">
                    <div>
                      <h3 className="text-xl font-semibold">{selectedProduct.title}</h3>
                      <p className="text-gray-500">{selectedProduct.shortDescription}</p>
                    </div>

                    <div className="flex gap-2 flex-wrap">
                      <Badge className={getStatusColor(selectedProduct.status)}>
                        {selectedProduct.status || "active"}
                      </Badge>
                      <Badge variant="outline">{selectedProduct.category}</Badge>
                      <Badge variant="secondary">{selectedProduct.condition}</Badge>
                    </div>

                    <div className="text-2xl font-bold text-emerald-600">
                      ₹{selectedProduct.priceRange.min.toLocaleString()} - ₹{selectedProduct.priceRange.max.toLocaleString()}
                    </div>

                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <p className="text-gray-500">Rating</p>
                        <div className="flex items-center gap-1">
                          <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                          <span className="font-medium">{selectedProduct.rating}/5</span>
                        </div>
                      </div>
                      <div>
                        <p className="text-gray-500">Views</p>
                        <p className="font-medium">{selectedProduct.views || 0}</p>
                      </div>
                      <div>
                        <p className="text-gray-500">Location</p>
                        <p className="font-medium">{selectedProduct.location || "N/A"}</p>
                      </div>
                      <div>
                        <p className="text-gray-500">Seller</p>
                        <p className="font-medium">{selectedProduct.sellerInfo?.userName || selectedProduct.sellerName || "N/A"}</p>
                      </div>
                    </div>

                    {selectedProduct.detailedDescription && (
                      <div>
                        <p className="text-gray-500 mb-2">Description</p>
                        <p className="text-gray-700">{selectedProduct.detailedDescription}</p>
                      </div>
                    )}

                    {selectedProduct.tags && selectedProduct.tags.length > 0 && (
                      <div>
                        <p className="text-gray-500 mb-2">Tags</p>
                        <div className="flex gap-2 flex-wrap">
                          {selectedProduct.tags.map((tag, i) => (
                            <Badge key={i} variant="outline" className="text-emerald-600">
                              #{tag}
                            </Badge>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </ScrollArea>
              </TabsContent>
              <TabsContent value="comments">
                <ScrollArea className="h-[60vh] pr-4">
                  {selectedProduct.comments && selectedProduct.comments.length > 0 ? (
                    <div className="space-y-4">
                      {selectedProduct.comments.map((comment) => (
                        <div key={comment._id} className="p-4 bg-gray-50 rounded-lg">
                          <div className="flex items-center gap-2 mb-2">
                            <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
                              <span className="text-sm font-medium text-emerald-600">
                                {comment.userName?.charAt(0)?.toUpperCase() || "U"}
                              </span>
                            </div>
                            <div>
                              <p className="font-medium text-sm">{comment.userName}</p>
                              <p className="text-xs text-gray-500">
                                {new Date(comment.createdAt).toLocaleDateString()}
                              </p>
                            </div>
                          </div>
                          <p className="text-gray-700">{comment.text}</p>

                          {/* Replies */}
                          {comment.replies && comment.replies.length > 0 && (
                            <div className="mt-3 ml-6 space-y-3">
                              {comment.replies.map((reply) => (
                                <div key={reply._id} className="p-3 bg-white rounded-lg border">
                                  <div className="flex items-center gap-2 mb-1">
                                    <span className="font-medium text-sm">{reply.userName}</span>
                                    <span className="text-xs text-gray-500">
                                      {new Date(reply.createdAt).toLocaleDateString()}
                                    </span>
                                  </div>
                                  <p className="text-sm text-gray-700">{reply.text}</p>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="flex flex-col items-center justify-center py-12 text-gray-500">
                      <MessageCircle className="w-12 h-12 mb-4 text-gray-300" />
                      <p>No comments yet</p>
                    </div>
                  )}
                </ScrollArea>
              </TabsContent>
            </Tabs>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
