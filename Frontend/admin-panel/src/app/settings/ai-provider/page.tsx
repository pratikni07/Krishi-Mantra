"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { CheckCircle2, AlertCircle, Plus, Power, Loader2, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import {
  aiProviderApi,
  aiStats,
  ProviderConfigSummary,
  UsageSummary,
} from "@/lib/ai-provider.api";

function StatusBadge({ status }: { status: ProviderConfigSummary["status"] }) {
  switch (status) {
    case "valid":
      return <Badge className="bg-green-600">Valid</Badge>;
    case "credential_invalid":
      return <Badge variant="destructive">Invalid credentials</Badge>;
    case "error":
      return <Badge variant="destructive">Error</Badge>;
    default:
      return <Badge variant="outline">Unvalidated</Badge>;
  }
}

export default function AiProviderListPage() {
  const { toast } = useToast();
  const [configs, setConfigs] = useState<ProviderConfigSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [activating, setActivating] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);
  const [confirmActivate, setConfirmActivate] = useState<ProviderConfigSummary | null>(
    null
  );
  const [usage, setUsage] = useState<UsageSummary | null>(null);
  const [usageError, setUsageError] = useState<string | null>(null);

  async function refresh() {
    setLoading(true);
    try {
      const r = await aiProviderApi.list();
      setConfigs(r.configs || []);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to load configs";
      toast({ title: "Error", description: message, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refresh();
    aiStats
      .summary()
      .then((r) => setUsage(r))
      .catch((err) => setUsageError(err?.message || "Failed to load usage"));
  }, []);

  async function onActivate(cfg: ProviderConfigSummary) {
    setActivating(cfg._id);
    try {
      await aiProviderApi.activate(cfg._id);
      toast({ title: "Activated", description: `${cfg.displayName} is now the active provider.` });
      await refresh();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Activation failed";
      toast({ title: "Error", description: message, variant: "destructive" });
    } finally {
      setActivating(null);
      setConfirmActivate(null);
    }
  }

  async function onDelete(cfg: ProviderConfigSummary) {
    if (cfg.isActive) {
      toast({
        title: "Cannot delete active config",
        description: "Deactivate another config first, then retry.",
        variant: "destructive",
      });
      return;
    }
    setDeleting(cfg._id);
    try {
      await aiProviderApi.remove(cfg._id);
      toast({ title: "Deleted", description: cfg.displayName });
      await refresh();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Delete failed";
      toast({ title: "Error", description: message, variant: "destructive" });
    } finally {
      setDeleting(null);
    }
  }

  const active = configs.find((c) => c.isActive) || null;

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold">AI Provider Configuration</h1>
          <p className="text-gray-500 text-sm">
            Pick the active AI provider for all users. Credentials are encrypted at rest.
          </p>
        </div>
        <div className="flex gap-2">
          <Link href="/settings/ai-provider/openai">
            <Button variant="outline">
              <Plus className="w-4 h-4 mr-2" /> OpenAI
            </Button>
          </Link>
          <Link href="/settings/ai-provider/vertex">
            <Button variant="outline">
              <Plus className="w-4 h-4 mr-2" /> Vertex
            </Button>
          </Link>
        </div>
      </div>

      {active ? (
        <Card className="border-green-500 border-2">
          <CardHeader className="flex-row items-start justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-green-600" />
                Active: {active.displayName}
              </CardTitle>
              <CardDescription>
                Provider: <code>{active.provider}</code> · Chat model:{" "}
                <code>{active.models.chat}</code>
              </CardDescription>
            </div>
            <StatusBadge status={active.status} />
          </CardHeader>
          <CardContent className="text-sm space-y-1">
            <div>
              Vision model: <code>{active.models.vision}</code>
            </div>
            <div>
              Embed model: <code>{active.models.embed}</code>
            </div>
            {active.credentials?.fingerprint && (
              <div className="text-gray-500">
                Credential fingerprint: <code>{active.credentials.fingerprint.slice(0, 12)}…</code>
                {active.credentials.keyCount
                  ? ` · ${active.credentials.keyCount} key${active.credentials.keyCount > 1 ? "s" : ""}`
                  : null}
              </div>
            )}
            {active.lastError && (
              <div className="text-red-600 flex gap-2 items-center">
                <AlertCircle className="w-4 h-4" /> {active.lastError}
              </div>
            )}
          </CardContent>
        </Card>
      ) : (
        <Card className="border-dashed">
          <CardContent className="p-8 text-center text-gray-500">
            No active AI provider. Create a config and activate it.
          </CardContent>
        </Card>
      )}

      <UsageCard usage={usage} error={usageError} />

      <div>
        <h2 className="text-lg font-semibold mb-3">All configurations</h2>
        {loading ? (
          <div className="flex items-center gap-2 text-gray-500">
            <Loader2 className="w-4 h-4 animate-spin" /> Loading…
          </div>
        ) : configs.length === 0 ? (
          <div className="text-gray-500">No configurations yet.</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {configs.map((cfg) => (
              <Card key={cfg._id} className={cfg.isActive ? "ring-2 ring-green-500" : ""}>
                <CardHeader className="flex-row items-start justify-between">
                  <div>
                    <CardTitle className="text-base">
                      {cfg.displayName}{" "}
                      <span className="text-xs text-gray-400 font-normal">({cfg.provider})</span>
                    </CardTitle>
                    <CardDescription>
                      Chat: <code>{cfg.models.chat}</code>
                    </CardDescription>
                  </div>
                  <StatusBadge status={cfg.status} />
                </CardHeader>
                <CardContent className="text-xs text-gray-500 space-y-1">
                  <div>
                    Updated:{" "}
                    {cfg.updatedAt ? new Date(cfg.updatedAt).toLocaleString() : "—"}
                  </div>
                  {cfg.credentials?.lastRotatedAt && (
                    <div>
                      Rotated: {new Date(cfg.credentials.lastRotatedAt).toLocaleString()}
                    </div>
                  )}
                  <div className="flex gap-2 pt-3">
                    <Link
                      href={`/settings/ai-provider/${cfg.provider}?id=${cfg._id}`}
                      className="flex-1"
                    >
                      <Button variant="outline" size="sm" className="w-full">
                        Edit
                      </Button>
                    </Link>
                    {cfg.isActive ? (
                      <Badge className="bg-green-600 flex items-center">Active</Badge>
                    ) : (
                      <Button
                        size="sm"
                        onClick={() => setConfirmActivate(cfg)}
                        disabled={activating === cfg._id}
                      >
                        {activating === cfg._id ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : (
                          <Power className="w-3 h-3 mr-1" />
                        )}
                        Activate
                      </Button>
                    )}
                    <Button
                      variant="destructive"
                      size="icon"
                      onClick={() => onDelete(cfg)}
                      disabled={cfg.isActive || deleting === cfg._id}
                      title={cfg.isActive ? "Deactivate first" : "Delete"}
                    >
                      {deleting === cfg._id ? (
                        <Loader2 className="w-3 h-3 animate-spin" />
                      ) : (
                        <Trash2 className="w-3 h-3" />
                      )}
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>

      <Dialog
        open={!!confirmActivate}
        onOpenChange={(open) => !open && setConfirmActivate(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Activate {confirmActivate?.displayName}?</DialogTitle>
            <DialogDescription>
              This immediately routes ALL user AI traffic to{" "}
              <strong>{confirmActivate?.provider}</strong>. In-flight chats will complete
              on the old provider; new chats use the new one. Switch is zero-downtime.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmActivate(null)}>
              Cancel
            </Button>
            <Button
              onClick={() => confirmActivate && onActivate(confirmActivate)}
              disabled={activating !== null}
            >
              {activating !== null ? (
                <Loader2 className="w-4 h-4 animate-spin mr-2" />
              ) : null}
              Activate
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function UsageCard({
  usage,
  error,
}: {
  usage: UsageSummary | null;
  error: string | null;
}) {
  if (error) {
    return (
      <Card className="border-amber-300">
        <CardContent className="p-4 text-amber-700 text-sm">
          Usage stats unavailable: {error}
        </CardContent>
      </Card>
    );
  }
  if (!usage) {
    return (
      <Card>
        <CardContent className="p-4 text-gray-500 text-sm flex items-center gap-2">
          <Loader2 className="w-4 h-4 animate-spin" /> Loading usage…
        </CardContent>
      </Card>
    );
  }
  const cacheHitPct = (usage.cacheHitRate * 100).toFixed(1);
  return (
    <Card>
      <CardHeader>
        <CardTitle>Usage (last 7 days)</CardTitle>
        <CardDescription>
          Tracks the active provider&apos;s aggregated chat traffic since {" "}
          {new Date(usage.since).toLocaleDateString()}.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Stat label="Chats" value={usage.chats.toLocaleString()} />
          <Stat label="Turns" value={usage.turns.toLocaleString()} />
          <Stat
            label="Total cost"
            value={`$${usage.estimatedUsdCost.toFixed(2)}`}
          />
          <Stat label="Cache hit" value={`${cacheHitPct}%`} />
          <Stat
            label="Prompt tokens"
            value={usage.tokens.prompt.toLocaleString()}
          />
          <Stat
            label="Cached tokens"
            value={usage.tokens.cached.toLocaleString()}
          />
          <Stat
            label="Completion tokens"
            value={usage.tokens.completion.toLocaleString()}
          />
          <Stat
            label="Last min cost"
            value={`$${usage.globalMinuteCostUsd.toFixed(3)}`}
          />
        </div>
      </CardContent>
    </Card>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-semibold text-gray-900">{value}</div>
    </div>
  );
}
