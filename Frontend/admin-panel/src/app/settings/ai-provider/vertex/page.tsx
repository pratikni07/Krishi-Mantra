"use client";

import React, { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowLeft, Loader2, Save, Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { aiProviderApi, ProviderConfigSummary } from "@/lib/ai-provider.api";

function VertexForm() {
  const router = useRouter();
  const search = useSearchParams();
  const editingId = search?.get("id") || undefined;
  const { toast } = useToast();

  const [existing, setExisting] = useState<ProviderConfigSummary | null>(null);
  const [displayName, setDisplayName] = useState("Google Vertex AI");
  const [serviceAccountJson, setServiceAccountJson] = useState("");
  const [project, setProject] = useState("");
  const [regionsCsv, setRegionsCsv] = useState("asia-south1,us-central1");
  const [chatModel, setChatModel] = useState("gemini-2.5-flash");
  const [visionModel, setVisionModel] = useState("gemini-2.5-flash");
  const [embedModel, setEmbedModel] = useState("text-embedding-005");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [jsonError, setJsonError] = useState<string | null>(null);

  useEffect(() => {
    if (!editingId) return;
    setLoading(true);
    aiProviderApi
      .getOne(editingId)
      .then((r) => {
        const cfg = r.config;
        setExisting(cfg);
        setDisplayName(cfg.displayName);
        setChatModel(cfg.models.chat);
        setVisionModel(cfg.models.vision);
        setEmbedModel(cfg.models.embed);
        const extras = (cfg.extras || {}) as {
          project?: string;
          regions?: string[];
        };
        setProject(extras.project || "");
        setRegionsCsv((extras.regions || []).join(","));
      })
      .catch((err) => {
        toast({
          title: "Error",
          description: err?.message || "Failed to load config",
          variant: "destructive",
        });
      })
      .finally(() => setLoading(false));
  }, [editingId, toast]);

  function validateJson(txt: string): boolean {
    if (!txt.trim()) {
      setJsonError(null);
      return true;
    }
    try {
      JSON.parse(txt);
      setJsonError(null);
      return true;
    } catch (err) {
      setJsonError(err instanceof Error ? err.message : "Invalid JSON");
      return false;
    }
  }

  async function handleFile(file: File) {
    const text = await file.text();
    setServiceAccountJson(text);
    validateJson(text);
  }

  async function onSave(activate: boolean) {
    if (!displayName.trim()) {
      toast({ title: "Display name required", variant: "destructive" });
      return;
    }
    if (!editingId && !serviceAccountJson.trim()) {
      toast({
        title: "Service-account JSON required",
        variant: "destructive",
      });
      return;
    }
    if (serviceAccountJson.trim() && !validateJson(serviceAccountJson)) {
      toast({
        title: "Invalid JSON",
        description: jsonError || "Please paste valid service-account JSON",
        variant: "destructive",
      });
      return;
    }

    const regions = regionsCsv
      .split(",")
      .map((r) => r.trim())
      .filter(Boolean);

    if (!editingId && !project.trim()) {
      try {
        const parsed = JSON.parse(serviceAccountJson);
        if (!parsed.project_id) {
          toast({
            title: "Project required",
            description:
              "Either set extras.project or upload a service-account JSON that contains project_id.",
            variant: "destructive",
          });
          return;
        }
      } catch {
        toast({
          title: "Project required",
          variant: "destructive",
        });
        return;
      }
    }

    setSaving(true);
    try {
      const payload: Parameters<typeof aiProviderApi.upsertVertex>[0] = {
        id: editingId,
        displayName,
        serviceAccountJson: serviceAccountJson.trim() || existing ? serviceAccountJson : "",
        models: { chat: chatModel, vision: visionModel, embed: embedModel },
        extras: {
          project: project.trim() || undefined,
          regions,
          location: regions[0],
        },
      };
      if (editingId && !serviceAccountJson.trim()) {
        // Editing without rotation — server requires SA JSON, so surface the need
        toast({
          title: "Service account required to edit",
          description:
            "Paste or upload the current service-account JSON to rotate it, or delete and recreate to change models without rotating.",
          variant: "destructive",
        });
        setSaving(false);
        return;
      }
      const { config } = await aiProviderApi.upsertVertex(payload);
      toast({ title: "Saved", description: config.displayName });
      if (activate && config._id) {
        await aiProviderApi.activate(config._id);
        toast({ title: "Activated", description: config.displayName });
      }
      router.push("/settings/ai-provider");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Save failed";
      toast({ title: "Error", description: message, variant: "destructive" });
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="p-6 flex gap-2 items-center text-gray-500">
        <Loader2 className="w-4 h-4 animate-spin" /> Loading…
      </div>
    );
  }

  return (
    <div className="p-6 max-w-2xl space-y-6">
      <Link href="/settings/ai-provider" className="flex items-center text-sm text-gray-500">
        <ArrowLeft className="w-4 h-4 mr-1" /> Back
      </Link>
      <div>
        <h1 className="text-2xl font-bold">
          {editingId ? "Edit" : "Add"} Google Vertex AI configuration
        </h1>
        <p className="text-gray-500 text-sm">
          Service-account JSON is encrypted with AES-256-GCM. The SA needs
          <code className="bg-gray-100 px-1 mx-1">roles/aiplatform.user</code> on the project.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Basics</CardTitle>
        </CardHeader>
        <CardContent>
          <div>
            <Label htmlFor="displayName">Display name</Label>
            <Input
              id="displayName"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Service account</CardTitle>
          <CardDescription>
            Upload or paste the JSON. It&apos;s validated locally before send.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="saFile" className="flex items-center gap-2 cursor-pointer">
              <Upload className="w-4 h-4" />
              <span>Upload JSON file</span>
            </Label>
            <input
              id="saFile"
              type="file"
              accept=".json,application/json"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) handleFile(f);
              }}
            />
          </div>
          <div>
            <Label htmlFor="saJson">Or paste JSON</Label>
            <Textarea
              id="saJson"
              rows={8}
              value={serviceAccountJson}
              onChange={(e) => {
                setServiceAccountJson(e.target.value);
                validateJson(e.target.value);
              }}
              placeholder={existing ? "(leave blank to keep existing)" : '{"type":"service_account",...}'}
              className="font-mono text-xs"
              autoComplete="off"
            />
            {jsonError && <p className="text-red-600 text-xs mt-1">{jsonError}</p>}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Project & regions</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="project">Project ID</Label>
            <Input
              id="project"
              value={project}
              onChange={(e) => setProject(e.target.value)}
              placeholder="(defaults to the JSON's project_id)"
            />
          </div>
          <div>
            <Label htmlFor="regions">Regions (comma-separated, first is primary)</Label>
            <Input
              id="regions"
              value={regionsCsv}
              onChange={(e) => setRegionsCsv(e.target.value)}
              placeholder="asia-south1,us-central1"
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Models</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="chatModel">Chat model</Label>
            <Input id="chatModel" value={chatModel} onChange={(e) => setChatModel(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="visionModel">Vision model</Label>
            <Input id="visionModel" value={visionModel} onChange={(e) => setVisionModel(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="embedModel">Embedding model</Label>
            <Input id="embedModel" value={embedModel} onChange={(e) => setEmbedModel(e.target.value)} />
          </div>
        </CardContent>
      </Card>

      <div className="flex gap-2 justify-end">
        <Button variant="outline" onClick={() => onSave(false)} disabled={saving}>
          {saving ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <Save className="w-4 h-4 mr-2" />}
          Save
        </Button>
        <Button onClick={() => onSave(true)} disabled={saving}>
          Save &amp; Activate
        </Button>
      </div>
    </div>
  );
}

export default function Page() {
  return (
    <Suspense fallback={<div className="p-6 text-gray-500">Loading…</div>}>
      <VertexForm />
    </Suspense>
  );
}
