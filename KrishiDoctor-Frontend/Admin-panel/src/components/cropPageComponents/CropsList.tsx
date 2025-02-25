import React from "react";
import { useQuery } from "@tanstack/react-query";
// @ts-ignore
import { getAllCrops } from "../../service/operations/cropAPI";
import { Crop } from "../../types/index";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";

export const CropsList: React.FC = () => {
  const [search, setSearch] = React.useState("");

  const { data: response, isLoading } = useQuery<{ data: Crop[] }>({
    queryKey: ["crops"],
    queryFn: getAllCrops,
  });

  const filteredCrops = React.useMemo(() => {
    if (!response?.data) return [];
    return response.data.filter(
      (crop: Crop) =>
        crop.name.toLowerCase().includes(search.toLowerCase()) ||
        crop.scientificName.toLowerCase().includes(search.toLowerCase())
    );
  }, [response, search]);

  if (isLoading) return <div>Loading...</div>;

  return (
    <Card>
      <CardContent className="p-6">
        <div className="flex items-center space-x-2 mb-6">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
            <Input
              placeholder="Search crops..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Scientific Name</TableHead>
              <TableHead>Growing Period</TableHead>
              <TableHead>Seasons</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredCrops.map((crop: Crop) => (
              <TableRow key={crop._id}>
                <TableCell className="font-medium">{crop.name}</TableCell>
                <TableCell className="italic">{crop.scientificName}</TableCell>
                <TableCell>{crop.growingPeriod} days</TableCell>
                <TableCell>
                  {crop.seasons.map((season) => season.type).join(", ")}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
};
