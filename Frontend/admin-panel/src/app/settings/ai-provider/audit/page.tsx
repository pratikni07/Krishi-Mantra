"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowLeft, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { aiProviderApi, AuditEntry } from "@/lib/ai-provider.api";

const ACTION_COLOR: Record<AuditEntry["action"], string> = {
  create: "bg-blue-600",
  update: "bg-amber-600",
  validate: "bg-gray-600",
  activate: "bg-green-600",
  deactivate: "bg-gray-500",
  rotate: "bg-purple-600",
  delete: "bg-red-600",
};

export default function AuditPage() {
  const { toast } = useToast();
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    aiProviderApi
      .audit()
      .then((r) => setEntries(r.audit || []))
      .catch((err) => {
        const message = err instanceof Error ? err.message : "Failed to load audit";
        toast({ title: "Error", description: message, variant: "destructive" });
      })
      .finally(() => setLoading(false));
  }, [toast]);

  return (
    <div className="p-6 max-w-3xl space-y-4">
      <Link href="/settings/ai-provider" className="flex items-center text-sm text-gray-500">
        <ArrowLeft className="w-4 h-4 mr-1" /> Back
      </Link>
      <h1 className="text-2xl font-bold">AI provider audit log</h1>
      <p className="text-gray-500 text-sm">
        Last 100 changes to AI provider configurations. Ordered newest first.
      </p>

      {loading ? (
        <div className="flex items-center gap-2 text-gray-500">
          <Loader2 className="w-4 h-4 animate-spin" /> Loading…
        </div>
      ) : entries.length === 0 ? (
        <div className="text-gray-500">No audit entries yet.</div>
      ) : (
        <div className="space-y-2">
          {entries.map((e) => (
            <Card key={e._id}>
              <CardHeader className="flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2">
                  <Badge className={ACTION_COLOR[e.action]}>{e.action}</Badge>
                  <span className="text-gray-500">({e.provider})</span>
                </CardTitle>
                <span className="text-xs text-gray-500">
                  {new Date(e.at).toLocaleString()}
                </span>
              </CardHeader>
              <CardContent className="text-xs text-gray-600 space-y-1">
                {e.configId && (
                  <div>
                    config: <code>{String(e.configId).slice(-6)}</code>
                  </div>
                )}
                {e.actor && (
                  <div>
                    actor: <code>{String(e.actor).slice(-6)}</code>
                  </div>
                )}
                {e.ip && <div>ip: {e.ip}</div>}
                {e.diff && (
                  <pre className="bg-gray-50 p-2 rounded text-[10px] overflow-x-auto">
                    {JSON.stringify(e.diff, null, 2)}
                  </pre>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
