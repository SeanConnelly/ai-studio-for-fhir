import { useEffect, useState } from "react";
import { Activity, Boxes, ExternalLink } from "lucide-react";
import { Badge } from "@shared/components/ui/badge";
import { api } from "@shared/api/client";

// In production IRIS serves the SPA, so the portal is same-origin. During dev
// the SPA runs on the Vite port (5173) while IRIS is on 42773 — point straight
// at IRIS so the Management Portal loads on its own origin (it doesn't proxy cleanly).
const MGMT_PORTAL_URL =
  window.location.port === "5173"
    ? `${window.location.protocol}//${window.location.hostname}:42773/csp/sys/UtilHome.csp`
    : "/csp/sys/UtilHome.csp";

export function TopHeader() {
  const [connected, setConnected] = useState<boolean | null>(null);

  useEffect(() => {
    api.status().then(() => setConnected(true)).catch(() => setConnected(false));
  }, []);

  return (
    <header className="flex h-14 shrink-0 items-center justify-between border-b bg-card px-5">
      <div className="flex items-center gap-2.5">
        <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
          <Boxes className="h-5 w-5" />
        </div>
        <div className="leading-tight">
          <div className="font-semibold">FHIR Agent Studio</div>
          <div className="text-xs text-muted-foreground">AI-agent workflows for HealthConnect</div>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <a
          href={MGMT_PORTAL_URL}
          target="iris-portal"
          rel="noopener noreferrer"
          title="Open the IRIS Management Portal in a new tab"
          className="inline-flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground"
        >
          <ExternalLink className="h-4 w-4" />
          Management Portal
        </a>
        <Badge variant={connected ? "success" : connected === false ? "warning" : "secondary"} className="gap-1.5">
          <Activity className="h-3 w-3" />
          {connected === null ? "Connecting…" : connected ? "IRIS Runtime Connected" : "IRIS Offline"}
        </Badge>
      </div>
    </header>
  );
}
