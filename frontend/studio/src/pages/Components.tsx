// Generic reusable-component manager: powers the Evidence Source and Output
// Schema managers. Full CRUD over /components/:entity, with a create/edit dialog
// and a (system-protected) delete. The :entity route param selects which
// component type is managed. (Prompt and ActionTemplate managers were retired
// with the step builder: an agent's prompt is assembled from its definition and
// previewed live in the builder; its draft action is configured inline.)
import { useEffect, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { api, type ComponentEntity } from "@shared/api/client";
import { Button } from "@shared/components/ui/button";
import { Badge } from "@shared/components/ui/badge";
import { Input } from "@shared/components/ui/input";
import { Textarea } from "@shared/components/ui/textarea";
import { Label } from "@shared/components/ui/label";
import { Dialog } from "@shared/components/ui/dialog";
import { Table, THead, TBody, TR, TH, TD } from "@shared/components/ui/table";

type FieldType = "text" | "textarea" | "select";
interface FieldDef {
  key: string;
  label: string;
  type: FieldType;
  options?: string[];
  placeholder?: string;
  mono?: boolean;
}

interface EntityConfig {
  entity: ComponentEntity;
  title: string;
  blurb: string;
  primary: string; // the column to show alongside name
  fields: FieldDef[];
}

const CONFIGS: Record<string, EntityConfig> = {
  "evidence-sources": {
    entity: "evidence-sources",
    title: "Evidence Sources",
    blurb: "Reusable, parameter-bound evidence steps. The generic engine runs these to gather real FHIR / SQL / vector / terminology evidence for an agent.",
    primary: "kind",
    fields: [
      { key: "slug", label: "Slug", type: "text", placeholder: "active-conditions" },
      { key: "name", label: "Name", type: "text" },
      { key: "kind", label: "Kind", type: "select", options: ["fhir-gather", "fhir-search", "sql", "vector", "terminology", "everything"] },
      { key: "spec", label: "Spec (JSON)", type: "textarea", mono: true, placeholder: '{"sql":"SELECT ... WHERE patient = \'{{patientRef}}\'"}' },
      { key: "description", label: "Description", type: "text" },
    ],
  },
  "output-schemas": {
    entity: "output-schemas",
    title: "Output Schemas",
    blurb: "The structured result contract an agent's output must satisfy, plus the renderer that displays it in the clinician view.",
    primary: "rendererKey",
    fields: [
      { key: "slug", label: "Slug", type: "text", placeholder: "results-followup-result" },
      { key: "name", label: "Name", type: "text" },
      { key: "rendererKey", label: "Renderer key", type: "text", placeholder: "summary" },
      { key: "schemaJson", label: "Schema JSON", type: "textarea", mono: true },
      { key: "description", label: "Description", type: "text" },
    ],
  },
};

export function Components() {
  const { entity = "evidence-sources" } = useParams();
  const cfg = CONFIGS[entity] ?? CONFIGS["evidence-sources"];
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [editing, setEditing] = useState<any | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [saving, setSaving] = useState(false);

  async function load() {
    setLoading(true);
    setErr("");
    try {
      const r = await api.components(cfg.entity);
      setItems(r.items);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cfg.entity]);

  function openNew() {
    const blank: any = {};
    cfg.fields.forEach((f) => (blank[f.key] = ""));
    setEditing(blank);
    setIsNew(true);
  }
  function openEdit(row: any) {
    setEditing({ ...row });
    setIsNew(false);
  }

  async function save() {
    if (!editing?.slug) {
      setErr("A slug is required.");
      return;
    }
    setSaving(true);
    setErr("");
    try {
      if (isNew) await api.createComponent(cfg.entity, editing);
      else await api.updateComponent(cfg.entity, editing.slug, editing);
      setEditing(null);
      await load();
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function del(row: any) {
    if (!confirm(`Delete ${row.slug}?`)) return;
    setErr("");
    try {
      await api.deleteComponent(cfg.entity, row.slug);
      await load();
    } catch (e: any) {
      setErr(e.message);
    }
  }

  const header = useMemo(() => cfg.primary.charAt(0).toUpperCase() + cfg.primary.slice(1), [cfg.primary]);

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">{cfg.title}</h1>
          <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{cfg.blurb}</p>
        </div>
        <Button onClick={openNew}>
          <Plus className="mr-1 h-4 w-4" /> New
        </Button>
      </div>

      {err && <div className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">{err}</div>}

      {loading ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : items.length === 0 ? (
        <p className="text-sm text-muted-foreground">No {cfg.title.toLowerCase()} yet. Create one to get started.</p>
      ) : (
        <Table>
          <THead>
            <TR>
              <TH>Name</TH>
              <TH>{header}</TH>
              <TH>Slug</TH>
              <TH className="w-px"></TH>
            </TR>
          </THead>
          <TBody>
            {items.map((row) => (
              <TR key={row.slug}>
                <TD className="font-medium">
                  {row.name || row.slug}
                  {row.isSystem && <Badge variant="secondary" className="ml-2">system</Badge>}
                </TD>
                <TD className="text-muted-foreground">{row[cfg.primary] || "—"}</TD>
                <TD className="font-mono text-xs text-muted-foreground">{row.slug}</TD>
                <TD>
                  <div className="flex justify-end gap-1">
                    <Button variant="ghost" size="icon" onClick={() => openEdit(row)} title="Edit">
                      <Pencil className="h-4 w-4" />
                    </Button>
                    {!row.isSystem && (
                      <Button variant="ghost" size="icon" onClick={() => del(row)} title="Delete">
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    )}
                  </div>
                </TD>
              </TR>
            ))}
          </TBody>
        </Table>
      )}

      <Dialog
        open={!!editing}
        onClose={() => setEditing(null)}
        title={isNew ? `New ${cfg.title.replace(/s$/, "")}` : `Edit ${editing?.slug ?? ""}`}
        description={cfg.blurb}
        footer={
          <>
            <Button variant="outline" onClick={() => setEditing(null)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={save} disabled={saving}>
              {saving ? "Saving…" : "Save"}
            </Button>
          </>
        }
      >
        {editing && (
          <div className="space-y-3">
            {cfg.fields.map((f) => (
              <div key={f.key} className="space-y-1">
                <Label>{f.label}</Label>
                {f.type === "textarea" ? (
                  <Textarea
                    value={editing[f.key] ?? ""}
                    placeholder={f.placeholder}
                    className={f.mono ? "font-mono text-xs min-h-[120px]" : "min-h-[80px]"}
                    onChange={(e) => setEditing({ ...editing, [f.key]: e.target.value })}
                  />
                ) : f.type === "select" ? (
                  <select
                    value={editing[f.key] ?? ""}
                    className="flex h-9 w-full rounded-md border border-input bg-card px-3 text-sm"
                    onChange={(e) => setEditing({ ...editing, [f.key]: e.target.value })}
                  >
                    <option value="">—</option>
                    {f.options?.map((o) => (
                      <option key={o} value={o}>
                        {o}
                      </option>
                    ))}
                  </select>
                ) : (
                  <Input
                    value={editing[f.key] ?? ""}
                    placeholder={f.placeholder}
                    disabled={f.key === "slug" && !isNew}
                    onChange={(e) => setEditing({ ...editing, [f.key]: e.target.value })}
                  />
                )}
              </div>
            ))}
          </div>
        )}
      </Dialog>
    </div>
  );
}
