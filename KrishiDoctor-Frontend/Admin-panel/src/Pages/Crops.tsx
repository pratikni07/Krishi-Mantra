// pages/CropPage.tsx
import React, { useState, useRef, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { getAllCrops } from "../service/operations/cropAPI.js";
import { Crop } from "../types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Search, Plus, X, Loader2 } from "lucide-react";
import addcrop
// import { cn } from "@/lib/utils";

const CropPage: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedSeason, setSelectedSeason] = useState<string>("");
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const searchInputRef = useRef<HTMLInputElement>(null);

  const { data: response, isLoading } = useQuery(["crops"], getAllCrops);
  const crops = response?.data || [];

  // Keyboard shortcut for search
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  // Get unique seasons from all crops
  const uniqueSeasons = React.useMemo(() => {
    const seasons = new Set<string>();
    crops.forEach((crop: Crop) => {
      crop.seasons.forEach((season) => seasons.add(season.type));
    });
    return Array.from(seasons);
  }, [crops]);

  // Filter crops based on search and season
  const filteredCrops = React.useMemo(() => {
    return crops.filter((crop: Crop) => {
      const matchesSearch =
        crop.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        crop.scientificName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        crop.description.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesSeason =
        !selectedSeason ||
        crop.seasons.some((season) => season.type === selectedSeason);

      return matchesSearch && matchesSeason;
    });
  }, [crops, searchTerm, selectedSeason]);

  const clearFilters = () => {
    setSearchTerm("");
    setSelectedSeason("");
    searchInputRef.current?.focus();
  };

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header Section */}
      <div className="bg-gradient-to-r from-green-600 to-green-700 rounded-lg shadow-lg mb-8 p-6 text-white">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold">Crop Management</h1>
            <p className="mt-2 text-green-100">
              Manage and monitor your crop database
            </p>
          </div>
          <Button
            onClick={() => setIsAddModalOpen(true)}
            className="bg-white text-green-700 hover:bg-green-50"
          >
            <Plus className="mr-2 h-4 w-4" />
            Add New Crop
          </Button>
        </div>
      </div>

      {/* Filters Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Search & Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col md:flex-row gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
              <Input
                ref={searchInputRef}
                placeholder="Search crops..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10 pr-10"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm("")}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X size={16} />
                </button>
              )}
            </div>

            <Select value={selectedSeason} onValueChange={setSelectedSeason}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filter by season" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">All Seasons</SelectItem>
                {uniqueSeasons.map((season) => (
                  <SelectItem key={season} value={season}>
                    {season}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {(searchTerm || selectedSeason) && (
              <Button
                variant="outline"
                onClick={clearFilters}
                className="whitespace-nowrap"
              >
                Clear Filters
              </Button>
            )}
          </div>

          <div className="mt-2 text-sm text-gray-500 flex items-center gap-1">
            <span>Press</span>
            <kbd className="px-2 py-1 bg-gray-100 border rounded-md">⌘</kbd>
            <span>+</span>
            <kbd className="px-2 py-1 bg-gray-100 border rounded-md">K</kbd>
            <span>to search</span>
          </div>
        </CardContent>
      </Card>

      {/* Data Table */}
      <Card>
        <CardContent className="p-0">
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Scientific Name</TableHead>
                  <TableHead>Description</TableHead>
                  <TableHead>Growing Period</TableHead>
                  <TableHead>Seasons</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading ? (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center">
                      <div className="flex items-center justify-center text-gray-500">
                        <Loader2 className="h-6 w-6 animate-spin mr-2" />
                        Loading crops...
                      </div>
                    </TableCell>
                  </TableRow>
                ) : filteredCrops.length === 0 ? (
                  <TableRow>
                    <TableCell
                      colSpan={5}
                      className="h-24 text-center text-gray-500"
                    >
                      No crops found
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredCrops.map((crop: Crop) => (
                    <TableRow key={crop._id} className="hover:bg-gray-50">
                      <TableCell className="font-medium">{crop.name}</TableCell>
                      <TableCell className="italic text-gray-600">
                        {crop.scientificName}
                      </TableCell>
                      <TableCell className="max-w-md">
                        {crop.description.length > 100
                          ? `${crop.description.substring(0, 100)}...`
                          : crop.description}
                      </TableCell>
                      <TableCell>{crop.growingPeriod} days</TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          {crop.seasons.map((season) => (
                            <span
                              key={season.type}
                              className={cn(
                                "px-2 py-1 rounded-full text-xs font-medium",
                                selectedSeason === season.type
                                  ? "bg-green-100 text-green-700"
                                  : "bg-gray-100 text-gray-700"
                              )}
                            >
                              {season.type}
                            </span>
                          ))}
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      {/* Add Crop Modal */}
      <AddCropModal open={isAddModalOpen} onOpenChange={setIsAddModalOpen} />
    </div>
  );
};

export default CropPage;
