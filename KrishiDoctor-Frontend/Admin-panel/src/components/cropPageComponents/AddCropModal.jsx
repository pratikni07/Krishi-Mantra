// components/modals/AddCropModal.tsx
import React, { useState } from "react";
import { useForm } from "react-hook-form";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createCrop } from "../../service/operations/cropAPI";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";

export const AddCropModal = ({ open, onOpenChange }) => {
  const queryClient = useQueryClient();
  const { register, handleSubmit, reset } = useForm();
  const [message, setMessage] = useState < string > "";

  const { mutate, isLoading } = useMutation(
    (newCrop) => createCrop(newCrop), // Mutation function
    {
      onSuccess: () => {
        queryClient.invalidateQueries(["crops"]); // Correctly structured query key
        setMessage("Crop added successfully!");
        onOpenChange(false);
        reset();
      },
      onError: (error) => {
        setMessage(`Failed to add crop: ${error.message}`);
      },
    }
  );

  const onSubmit = (data) => {
    setMessage(""); // Clear any previous message
    mutate({
      ...data,
      seasons: [
        {
          type: data.seasonType,
          startMonth: data.startMonth,
          endMonth: data.endMonth,
        },
      ],
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Add New Crop</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Crop Name</Label>
            <Input id="name" {...register("name")} required />
          </div>

          <div className="space-y-2">
            <Label htmlFor="scientificName">Scientific Name</Label>
            <Input
              id="scientificName"
              {...register("scientificName")}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Textarea id="description" {...register("description")} required />
          </div>

          <div className="space-y-2">
            <Label htmlFor="growingPeriod">Growing Period (days)</Label>
            <Input
              id="growingPeriod"
              type="number"
              {...register("growingPeriod")}
              required
            />
          </div>

          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label htmlFor="seasonType">Season</Label>
              <Input id="seasonType" {...register("seasonType")} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="startMonth">Start Month</Label>
              <Input
                id="startMonth"
                type="number"
                min="1"
                max="12"
                {...register("startMonth")}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="endMonth">End Month</Label>
              <Input
                id="endMonth"
                type="number"
                min="1"
                max="12"
                {...register("endMonth")}
                required
              />
            </div>
          </div>

          {message && (
            <div
              className={`p-4 mt-4 text-center ${
                message.includes("successfully")
                  ? "bg-green-100 text-green-800"
                  : "bg-red-100 text-red-800"
              }`}
            >
              {message}
            </div>
          )}

          <div className="flex justify-end gap-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? "Adding..." : "Add Crop"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};
// components/modals/AddCropModal.jsx
import React, { useState } from "react";
import { useForm } from "react-hook-form";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createCrop } from "../../service/operations/cropAPI";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";

const AddCropModal = ({ open, onOpenChange }) => {
  const queryClient = useQueryClient();
  const { register, handleSubmit, reset } = useForm();
  const [message, setMessage] = useState("");

  const { mutate, isLoading } = useMutation(
    (newCrop) => createCrop(newCrop), // Mutation function
    {
      onSuccess: () => {
        queryClient.invalidateQueries(["crops"]); // Correctly structured query key
        setMessage("Crop added successfully!");
        onOpenChange(false);
        reset();
      },
      onError: (error) => {
        setMessage(`Failed to add crop: ${error.message}`);
      },
    }
  );

  const onSubmit = (data) => {
    setMessage(""); // Clear any previous message
    mutate({
      ...data,
      seasons: [
        {
          type: data.seasonType,
          startMonth: data.startMonth,
          endMonth: data.endMonth,
        },
      ],
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Add New Crop</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Crop Name</Label>
            <Input id="name" {...register("name")} required />
          </div>

          <div className="space-y-2">
            <Label htmlFor="scientificName">Scientific Name</Label>
            <Input
              id="scientificName"
              {...register("scientificName")}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Textarea id="description" {...register("description")} required />
          </div>

          <div className="space-y-2">
            <Label htmlFor="growingPeriod">Growing Period (days)</Label>
            <Input
              id="growingPeriod"
              type="number"
              {...register("growingPeriod")}
              required
            />
          </div>

          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label htmlFor="seasonType">Season</Label>
              <Input id="seasonType" {...register("seasonType")} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="startMonth">Start Month</Label>
              <Input
                id="startMonth"
                type="number"
                min="1"
                max="12"
                {...register("startMonth")}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="endMonth">End Month</Label>
              <Input
                id="endMonth"
                type="number"
                min="1"
                max="12"
                {...register("endMonth")}
                required
              />
            </div>
          </div>

          {message && (
            <div
              className={`p-4 mt-4 text-center ${
                message.includes("successfully")
                  ? "bg-green-100 text-green-800"
                  : "bg-red-100 text-red-800"
              }`}
            >
              {message}
            </div>
          )}

          <div className="flex justify-end gap-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? "Adding..." : "Add Crop"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default AddCropModal;
