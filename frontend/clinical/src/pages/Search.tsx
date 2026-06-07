// Patient search over the real FHIR repository (api.patientSearch). Name / sex /
// date of birth / NHS number / hospital number (MRN). Empty search lists the
// whole cohort. Click a result to open the chart.
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Search as SearchIcon, Sparkles } from "lucide-react";
import { api } from "@shared/api/client";
import type { PatientSearchResult } from "@shared/api/types";
import { Input } from "@shared/components/ui/input";
import { Button } from "@shared/components/ui/button";
import { Label } from "@shared/components/ui/label";
import { Table, THead, TBody, TR, TH, TD } from "@shared/components/ui/table";
import { DEMO_READY_PATIENTS } from "@/agents";

const idOf = (ref: string) => ref.split("/")[1];

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const ANCHOR = { y: 2026, m: 5, d: 25 };

// "1999-11-12" -> "12-Nov-1999 (26y)" — matches the patient banner.
function fmtBorn(birthDate?: string): string {
  if (!birthDate) return "-";
  const [y, m, d] = birthDate.split("-").map((p) => parseInt(p, 10));
  if (!y || !m || !d) return birthDate;
  let age = ANCHOR.y - y;
  if (m > ANCHOR.m || (m === ANCHOR.m && d > ANCHOR.d)) age -= 1;
  return `${String(d).padStart(2, "0")}-${MONTHS[m - 1]}-${y} (${age}y)`;
}

function fmtNhs(nhs?: string): string {
  if (!nhs) return "-";
  const s = nhs.replace(/\s/g, "");
  return s.length === 10 ? `${s.slice(0, 3)} ${s.slice(3, 6)} ${s.slice(6)}` : nhs;
}

export function Search() {
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [gender, setGender] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [nhs, setNhs] = useState("");
  const [mrn, setMrn] = useState("");
  const [rows, setRows] = useState<PatientSearchResult[]>([]);
  const [loading, setLoading] = useState(false);

  async function run() {
    setLoading(true);
    try {
      const r = await api.patientSearch({ name, gender, birthDate, nhs, mrn });
      setRows(r.patients);
    } finally {
      setLoading(false);
    }
  }

  // List the whole cohort on first open.
  useEffect(() => {
    run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Patient search</h1>
        <p className="text-sm text-muted-foreground">Find a patient by name, sex, date of birth, NHS number, or hospital number. Search with no criteria to list every patient.</p>
      </div>

      <form
        className="flex flex-wrap items-end gap-3 rounded-lg border bg-card p-4"
        onSubmit={(e) => { e.preventDefault(); run(); }}
      >
        <div className="space-y-1"><Label>Name</Label><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="family or given" className="w-48" /></div>
        <div className="space-y-1">
          <Label>Sex</Label>
          <select value={gender} onChange={(e) => setGender(e.target.value)} className="flex h-9 w-28 rounded-md border border-input bg-card px-3 text-sm">
            <option value="">any</option><option value="female">female</option><option value="male">male</option>
          </select>
        </div>
        <div className="space-y-1"><Label>Born</Label><Input value={birthDate} onChange={(e) => setBirthDate(e.target.value)} placeholder="YYYY or YYYY-MM-DD" className="w-40" /></div>
        <div className="space-y-1"><Label>NHS No</Label><Input value={nhs} onChange={(e) => setNhs(e.target.value)} placeholder="10 digits" className="w-36" /></div>
        <div className="space-y-1"><Label>Hospital No</Label><Input value={mrn} onChange={(e) => setMrn(e.target.value)} placeholder="8 digits" className="w-32" /></div>
        <Button type="submit" disabled={loading}><SearchIcon className="mr-1 h-4 w-4" />{loading ? "Searching…" : "Search"}</Button>
      </form>

      {loading ? (
        <p className="text-sm text-muted-foreground">Searching…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No patients matched.</p>
      ) : (
        <>
          <p className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
            {rows.length} patient{rows.length === 1 ? "" : "s"}
            <span className="inline-flex items-center gap-1 rounded-full bg-nhs-50 px-2 py-0.5 text-xs font-medium text-nhs-700">
              <Sparkles className="h-3 w-3" /> = full AI decision support pre-loaded for the demo
            </span>
          </p>
          <Table>
            <THead><TR><TH>Name</TH><TH>Sex</TH><TH>Born</TH><TH>NHS No</TH><TH>Hospital No</TH></TR></THead>
            <TBody>
              {rows.map((p) => (
                <TR key={p.ref} className="cursor-pointer" onClick={() => navigate(`/patient/${idOf(p.ref)}`)}>
                  <TD className="font-medium">
                    <span className="inline-flex items-center gap-1.5">
                      {p.label}
                      {DEMO_READY_PATIENTS.has(idOf(p.ref)) && (
                        <Sparkles className="h-3.5 w-3.5 shrink-0 text-nhs-600" aria-label="Demo-ready: full AI decision support pre-loaded" />
                      )}
                    </span>
                  </TD>
                  <TD className="capitalize text-muted-foreground">{p.gender}</TD>
                  <TD className="text-muted-foreground">{fmtBorn(p.birthDate)}</TD>
                  <TD className="font-mono text-xs text-muted-foreground">{fmtNhs(p.nhs)}</TD>
                  <TD className="font-mono text-xs text-muted-foreground">{p.mrn || "-"}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </>
      )}
    </div>
  );
}
