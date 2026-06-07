import { useEffect, useState } from "react";
import { User, FileSearch } from "lucide-react";
import { api } from "@shared/api/client";
import type { InputField, PatientOption, ResourceOption } from "@shared/api/types";

const selectCls =
  "h-9 w-full rounded-md border border-input bg-card px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring";

function prettyRole(v: string) {
  return v.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Renders a control per declared input. Patient + fhir-reference pickers are
 *  backed by the real FHIR repository via /options/*. */
export function InputPanel({
  inputs,
  values,
  onChange,
}: {
  inputs: InputField[];
  values: Record<string, string>;
  onChange: (key: string, value: string) => void;
}) {
  const [patients, setPatients] = useState<PatientOption[]>([]);
  const [refOptions, setRefOptions] = useState<Record<string, ResourceOption[]>>({});

  const needsPatients = inputs.some((i) => i.type === "patient");
  useEffect(() => {
    if (needsPatients) api.optionsPatients().then((r) => setPatients(r.patients)).catch(() => {});
  }, [needsPatients]);

  // For each fhir-reference input, (re)load options when its patient changes.
  useEffect(() => {
    inputs
      .filter((i) => i.type === "fhir-reference")
      .forEach((i) => {
        const patient = values[i.dependsOn || "patient"];
        if (!patient || !i.resourceType) return;
        api
          .optionsResources(i.resourceType, patient)
          .then((r) => setRefOptions((prev) => ({ ...prev, [i.key]: r.resources })))
          .catch(() => {});
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify(values), JSON.stringify(inputs)]);

  if (inputs.length === 0) {
    return <p className="text-sm text-muted-foreground">This agent takes no inputs — just run it.</p>;
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {inputs.map((inp) => (
        <div key={inp.key} className={inp.type === "text" ? "sm:col-span-2" : ""}>
          <label className="mb-1.5 flex items-center gap-1.5 text-sm font-medium">
            {inp.type === "patient" && <User className="h-3.5 w-3.5 text-muted-foreground" />}
            {inp.type === "fhir-reference" && <FileSearch className="h-3.5 w-3.5 text-muted-foreground" />}
            {inp.label}
            {inp.required && <span className="text-destructive">*</span>}
          </label>

          {inp.type === "patient" && (
            <select className={selectCls} value={values[inp.key] || ""} onChange={(e) => onChange(inp.key, e.target.value)}>
              {patients.length === 0 && <option value="">Loading patients…</option>}
              {patients.map((p) => (
                <option key={p.ref} value={p.ref}>
                  {p.label}
                  {p.sex || p.birthDate ? ` — ${[p.sex, p.birthDate].filter(Boolean).join(", ")}` : ""}
                </option>
              ))}
            </select>
          )}

          {inp.type === "fhir-reference" && (
            <select className={selectCls} value={values[inp.key] || ""} onChange={(e) => onChange(inp.key, e.target.value)}>
              {(refOptions[inp.key] ?? []).length === 0 && <option value="">No matching {inp.resourceType} for this patient</option>}
              {(refOptions[inp.key] ?? []).map((r) => (
                <option key={r.ref} value={r.ref}>
                  {r.label}
                </option>
              ))}
            </select>
          )}

          {inp.type === "enum" && (
            <select className={selectCls} value={values[inp.key] || ""} onChange={(e) => onChange(inp.key, e.target.value)}>
              {(inp.options ?? []).map((o) => (
                <option key={o} value={o}>
                  {prettyRole(o)}
                </option>
              ))}
            </select>
          )}

          {inp.type === "text" && (
            <input
              type="text"
              className={selectCls}
              value={values[inp.key] || ""}
              placeholder={inp.placeholder}
              onChange={(e) => onChange(inp.key, e.target.value)}
            />
          )}
        </div>
      ))}
    </div>
  );
}
