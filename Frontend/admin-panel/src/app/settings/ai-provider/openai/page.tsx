"use client";

import React, { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowLeft, Loader2, Save } from "lucide-react";
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

function OpenAIForm() {
  const router = useRouter();
  const search = useSearchParams();
  const editingId = search?.get("id") || undefined;
  const { toast } = useToast();

  const [existing, setExisting] = useState<ProviderConfigSummary | null>(null);
  const [displayName, setDisplayName] = useState("OpenAI");
  const [apiKeys, setApiKeys] = useState("");
  const [chatModel, setChatModel] = useState("gpt-4.1-mini");
  const [visionModel, setVisionModel] = useState("gpt-4o-mini");
  const [embedModel, setEmbedModel] = useState("text-embedding-3-small");
  const [orgId, setOrgId] = useState("");
  const [baseUrl, setBaseUrl] = useState("");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);

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
        const extras = (cfg.extras || {}) as { orgId?: string; baseUrl?: string };
        setOrgId(extras.orgId || "");
        setBaseUrl(extras.baseUrl || "");
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

  async function onSave(activate: boolean) {
    if (!displayName.trim()) {
      toast({ title: "Display name required", variant: "destructive" });
      return;
    }
    if (!editingId && !apiKeys.trim()) {
      toast({ title: "At least one API key required", variant: "destructive" });
      return;
    }
    if (editingId && !apiKeys.trim()) {
      toast({
        title: "Enter the key(s) to rotate",
        description:
          "For security we never display stored keys. Leave blank and only model changes will save.",
        variant: "destructive",
      });
      return;
    }

    const keys = apiKeys
      .split(/[\n,]/)
      .map((k) => k.trim())
      .filter(Boolean);

    setSaving(true);
    try {
      const payload = {
        id: editingId,
        displayName,
        apiKeys: keys,
        models: { chat: chatModel, vision: visionModel, embed: embedModel },
        extras: {
          orgId: orgId.trim() || undefined,
          baseUrl: baseUrl.trim() || undefined,
        },
      };
      const { config } = await aiProviderApi.upsertOpenAI(payload);
      toast({ title: "Saved", description: config.displayName });
      if (activate && config._id) {
        await aiProviderApi.activate(config._id);
        toast({ title: "Activated", description: config.displayName });
      }
      router.push("/settings/ai-provider");
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Save failed";
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
          {editingId ? "Edit" : "Add"} OpenAI configuration
        </h1>
        <p className="text-gray-500 text-sm">
          Keys are encrypted with AES-256-GCM before storage. They are never returned to
          this UI after save.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Basics</CardTitle>
          <CardDescription>Name shown in the admin panel only.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="displayName">Display name</Label>
            <Input
              id="displayName"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              placeholder="e.g. OpenAI (prod)"
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Credentials</CardTitle>
          <CardDescription>
            One key per line, or comma-separated. Multiple keys rotate on 429 errors.
            {existing && (
              <span className="block mt-1 text-amber-600">
                Entering keys here will ROTATE the stored credentials. Leave blank to keep
                them.
              </span>
            )}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="apiKeys">OpenAI API keys</Label>
            <Textarea
              id="apiKeys"
              rows={4}
              value={apiKeys}
              onChange={(e) => setApiKeys(e.target.value)}
              placeholder={existing ? "(leave blank to keep existing)" : "sk-..."}
              autoComplete="off"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="orgId">Organization ID (optional)</Label>
              <Input
                id="orgId"
                value={orgId}
                onChange={(e) => setOrgId(e.target.value)}
                placeholder="org-…"
              />
            </div>
            <div>
              <Label htmlFor="baseUrl">Base URL (optional)</Label>
              <Input
                id="baseUrl"
                value={baseUrl}
                onChange={(e) => setBaseUrl(e.target.value)}
                placeholder="https://…"
              />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Models</CardTitle>
          <CardDescription>Applied on next turn after save/activate.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="chatModel">Chat model</Label>
            <Input
              id="chatModel"
              value={chatModel}
              onChange={(e) => setChatModel(e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="visionModel">Vision model</Label>
            <Input
              id="visionModel"
              value={visionModel}
              onChange={(e) => setVisionModel(e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="embedModel">Embedding model</Label>
            <Input
              id="embedModel"
              value={embedModel}
              onChange={(e) => setEmbedModel(e.target.value)}
            />
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
      <OpenAIForm />
    </Suspense>
  );
}
