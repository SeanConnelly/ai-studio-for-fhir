// Orders + Prior Authorisation, in-chart. Lists the patient's orders, lets the
// clinician raise a new order from a small catalogue; high-cost items require
// prior authorisation, which the AI assembles (criteria met / still needed /
// justification). The clinician submits it and a simulated payer decision comes
// back, updating the order's status.
import { useCallback, useEffect, useState } from "react";
import {
  Plus, Pill, FlaskConical, Loader2, CheckCircle2, XCircle, Sparkles, ShieldCheck, Clock, X,
} from "lucide-react";
import { api } from "@shared/api/client";
import type { OrderCatalogueItem, OrderRow, PlaceOrderResult, SubmitPaResult } from "@shared/api/types";

function OrderStatusBadge({ status }: { status: string }) {
  const s = (status || "").toLowerCase();
  const cls =
    s === "active" ? "bg-emerald-100 text-emerald-800"
    : s === "on-hold" ? "bg-amber-100 text-amber-800"
    : "bg-slate-100 text-slate-700";
  const label = s === "active" ? "Active" : s === "on-hold" ? "On hold" : status;
  return <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${cls}`}>{label}</span>;
}

function PaBadge({ status }: { status: string }) {
  const s = (status || "").toLowerCase();
  const map: Record<string, string> = {
    approved: "bg-emerald-100 text-emerald-800",
    pended: "bg-amber-100 text-amber-800",
    submitted: "bg-sky-100 text-sky-800",
    draft: "bg-slate-100 text-slate-700",
  };
  const label = s === "approved" ? "PA approved" : s === "pended" ? "PA: action needed" : s === "submitted" ? "PA submitted" : "PA draft";
  return <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${map[s] || map.draft}`}>{label}</span>;
}

export function OrdersSection({ patientId }: { patientId: string }) {
  const [orders, setOrders] = useState<OrderRow[]>([]);
  const [catalogue, setCatalogue] = useState<OrderCatalogueItem[]>([]);
  const [picking, setPicking] = useState(false);
  const [placing, setPlacing] = useState<string | null>(null);
  const [draft, setDraft] = useState<PlaceOrderResult | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [decision, setDecision] = useState<SubmitPaResult | null>(null);

  const load = useCallback(() => api.patientOrders(patientId).then((r) => setOrders(r.orders || [])), [patientId]);

  useEffect(() => {
    setDraft(null); setDecision(null); setPicking(false);
    load();
    api.ordersCatalogue().then((r) => setCatalogue(r.catalogue || []));
  }, [patientId, load]);

  async function place(itemId: string) {
    setPlacing(itemId); setDraft(null); setDecision(null);
    try {
      const r = await api.placeOrder(patientId, itemId);
      setDraft(r);
      setPicking(false);
      await load();
    } finally {
      setPlacing(null);
    }
  }

  async function submit() {
    if (!draft?.claimId) return;
    setSubmitting(true);
    try {
      setDecision(await api.submitPa(draft.claimId));
      await load();
    } finally {
      setSubmitting(false);
    }
  }

  const pa = draft?.pa;

  return (
    <div className="rounded-lg border bg-card shadow-sm">
      <div className="flex items-center gap-2 border-b px-4 py-2.5 text-sm font-semibold text-foreground">
        <FlaskConical className="h-4 w-4 text-nhs-600" />
        Orders
        <span className="ml-auto" />
        <button
          onClick={() => { setPicking((v) => !v); setDraft(null); setDecision(null); }}
          className="inline-flex items-center gap-1.5 rounded-md bg-nhs-600 px-2.5 py-1 text-xs font-medium text-white hover:bg-nhs-700"
        >
          <Plus className="h-3.5 w-3.5" /> New order
        </button>
      </div>

      {/* Catalogue picker */}
      {picking && (
        <div className="border-b bg-nhs-50/40 px-4 py-3">
          <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">Order catalogue</div>
          <div className="grid gap-2 sm:grid-cols-2">
            {catalogue.map((c) => (
              <button
                key={c.id}
                onClick={() => place(c.id)}
                disabled={!!placing}
                className="flex items-center gap-2 rounded-md border bg-card px-3 py-2 text-left text-sm hover:border-nhs-400 disabled:opacity-60"
              >
                {c.kind === "medication" ? <Pill className="h-4 w-4 text-nhs-600" /> : <FlaskConical className="h-4 w-4 text-nhs-600" />}
                <span className="flex-1">
                  <span className="font-medium">{c.display}</span>
                  <span className="mt-0.5 block text-[11px] text-amber-700">Prior authorisation required</span>
                </span>
                {placing === c.id && <Loader2 className="h-4 w-4 animate-spin text-nhs-600" />}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Assembled PA packet for a just-placed order */}
      {draft && pa && (
        <div className="border-b px-4 py-3">
          <div className="mb-2 flex items-center gap-2">
            <span className="font-medium text-foreground">Prior authorisation - {draft.display}</span>
            <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-nhs-600 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white">
              <Sparkles className="h-3 w-3" /> AI generated
            </span>
            <button onClick={() => { setDraft(null); setDecision(null); }} className="text-muted-foreground hover:text-foreground"><X className="h-4 w-4" /></button>
          </div>
          {pa.summary && <p className="mb-3 text-sm leading-relaxed text-foreground">{pa.summary}</p>}
          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <div className="mb-1 text-sm font-medium text-emerald-700">Criteria met</div>
              <div className="space-y-1 text-sm">
                {(pa.policyCriteriaMatched || []).length ? (pa.policyCriteriaMatched || []).map((c, i) => (
                  <div key={i} className="flex gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600" />{c}</div>
                )) : <p className="text-muted-foreground">None recorded.</p>}
              </div>
            </div>
            <div>
              <div className="mb-1 text-sm font-medium text-amber-700">Still needed</div>
              <div className="space-y-1 text-sm">
                {(pa.missingEvidenceChecklist || []).length ? (pa.missingEvidenceChecklist || []).map((c, i) => (
                  <div key={i} className="flex gap-2"><XCircle className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />{c}</div>
                )) : <p className="text-muted-foreground">Nothing outstanding.</p>}
              </div>
            </div>
          </div>
          {pa.draftJustification && (
            <div className="mt-3 rounded-md border bg-muted/30 p-3 text-sm text-muted-foreground">{pa.draftJustification}</div>
          )}
          <p className="mt-2 text-[11px] text-muted-foreground">AI-generated from this patient's chart and the payer policy - review before submitting.</p>

          {/* Submit / decision */}
          {!decision ? (
            <button
              onClick={submit}
              disabled={submitting}
              className="mt-3 inline-flex items-center gap-2 rounded-md bg-nhs-600 px-3 py-2 text-sm font-medium text-white hover:bg-nhs-700 disabled:opacity-60"
            >
              {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <ShieldCheck className="h-4 w-4" />}
              {submitting ? "Submitting…" : "Submit to payer"}
            </button>
          ) : (
            <div className={"mt-3 rounded-md border p-3 " + (decision.decision === "approved" ? "border-emerald-300 bg-emerald-50/50" : "border-amber-300 bg-amber-50/50")}>
              <div className="flex items-center gap-2 text-sm font-medium">
                {decision.decision === "approved" ? <CheckCircle2 className="h-4 w-4 text-emerald-600" /> : <Clock className="h-4 w-4 text-amber-600" />}
                {decision.decision === "approved" ? "Prior authorisation approved" : "Pended - more information required"}
                <span className="ml-auto text-[11px] font-normal text-muted-foreground">Simulated payer response · {decision.payer}</span>
              </div>
              <p className="mt-1 text-sm text-muted-foreground">{decision.disposition}</p>
              {decision.decision !== "approved" && decision.missing && decision.missing.length > 0 && (
                <ul className="mt-1.5 space-y-0.5 text-sm text-muted-foreground">
                  {decision.missing.map((m, i) => <li key={i}>• {m}</li>)}
                </ul>
              )}
            </div>
          )}
        </div>
      )}

      {/* Orders list */}
      <div className="px-4 py-3">
        {orders.length ? (
          <ul className="divide-y">
            {orders.map((o) => (
              <li key={o.id} className="flex items-center gap-2 py-2 text-sm first:pt-0 last:pb-0">
                {o.kind === "medication" ? <Pill className="h-4 w-4 shrink-0 text-muted-foreground" /> : <FlaskConical className="h-4 w-4 shrink-0 text-muted-foreground" />}
                <span className="min-w-0 flex-1 truncate">{o.display}{o.date ? <span className="text-muted-foreground"> · {o.date}</span> : null}</span>
                {o.pa && <PaBadge status={o.pa.status} />}
                <OrderStatusBadge status={o.status} />
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-muted-foreground">No orders yet. Use "New order" to raise one.</p>
        )}
      </div>
    </div>
  );
}
