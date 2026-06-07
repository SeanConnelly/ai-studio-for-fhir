// CC-01 PatientBanner - the persistent identity strip atop a patient chart
// (an EHR "Storyboard"). Compact: a name row, a dense demographics line, and
// allergy + alert chips. A free-form `right` slot carries at-a-glance badges.
import * as React from "react";
import { TriangleAlert, Bell } from "lucide-react";
import { cn } from "@shared/lib/utils";

export interface PatientBannerProps {
  name: string;
  /** ISO birth date (YYYY-MM-DD). */
  birthDate?: string;
  gender?: string;
  /** 10-digit NHS number (unformatted). */
  nhsNo?: string;
  /** 8-digit hospital number. */
  hospitalNo?: string;
  /** Full address on one line. */
  address?: string;
  /** Registered GP display name. */
  gp?: string;
  allergies?: string[];
  alerts?: string[];
  right?: React.ReactNode;
  className?: string;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const ANCHOR = { y: 2026, m: 5, d: 25 }; // dataset reference date (2026-05-25)

// "1954-01-15" -> "15-Jan-1954"
function fmtBorn(birthDate?: string): string {
  if (!birthDate) return "-";
  const [y, m, d] = birthDate.split("-").map((p) => parseInt(p, 10));
  if (!y || !m || !d) return birthDate;
  return `${String(d).padStart(2, "0")}-${MONTHS[m - 1]}-${y}`;
}

function age(birthDate?: string): string {
  if (!birthDate) return "";
  const [y, m, d] = birthDate.split("-").map((p) => parseInt(p, 10));
  if (!y) return "";
  let a = ANCHOR.y - y;
  if (m > ANCHOR.m || (m === ANCHOR.m && d > ANCHOR.d)) a -= 1;
  return `${a}y`;
}

// "7125490964" -> "712 549 0964" (NHS number 3-3-4 grouping)
function fmtNhs(nhs?: string): string {
  if (!nhs) return "-";
  const s = nhs.replace(/\s/g, "");
  if (s.length !== 10) return nhs;
  return `${s.slice(0, 3)} ${s.slice(3, 6)} ${s.slice(6)}`;
}

function cap(s?: string): string {
  if (!s) return "-";
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <span className="inline-flex items-baseline gap-1.5 whitespace-nowrap">
      <span className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground/70">{label}</span>
      <span className="font-medium text-foreground">{value}</span>
    </span>
  );
}

export function PatientBanner({
  name, birthDate, gender, nhsNo, hospitalNo, address, gp, allergies, alerts, right, className,
}: PatientBannerProps) {
  const hasAllergies = allergies && allergies.length > 0;
  const hasAlerts = alerts && alerts.length > 0;
  const bornAge = age(birthDate);

  return (
    <div className={cn("rounded-lg border border-l-4 border-l-nhs-600 bg-card px-4 py-2.5 shadow-sm", className)}>
      <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
        <span className="text-base font-semibold leading-tight text-foreground">{name}</span>
        {right && <div className="ml-auto flex flex-wrap items-center justify-end gap-2">{right}</div>}
      </div>

      {/* Dense demographics line */}
      <div className="mt-1 flex flex-wrap items-baseline gap-x-4 gap-y-0.5 text-sm">
        <Field label="Born" value={`${fmtBorn(birthDate)}${bornAge ? ` (${bornAge})` : ""}`} />
        <Field label="Gender" value={cap(gender)} />
        <Field label="NHS No" value={fmtNhs(nhsNo)} />
        <Field label="Hosp No" value={hospitalNo || "-"} />
        {address && <Field label="Address" value={address} />}
        {gp && <Field label="GP" value={gp} />}
      </div>

      {/* Allergies + alerts */}
      <div className="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[11px] font-medium uppercase tracking-wide text-rose-600/80">Allergies</span>
          {hasAllergies ? (
            allergies!.map((a) => (
              <span key={a} className="inline-flex items-center gap-1 rounded-full bg-rose-100 px-2 py-0.5 text-[11px] font-medium text-rose-800">
                <TriangleAlert className="h-3 w-3" />
                {a}
              </span>
            ))
          ) : (
            <span className="text-[11px] text-muted-foreground">None known</span>
          )}
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[11px] font-medium uppercase tracking-wide text-amber-600/80">Alerts</span>
          {hasAlerts ? (
            alerts!.map((a) => (
              <span key={a} className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">
                <Bell className="h-3 w-3" />
                {a}
              </span>
            ))
          ) : (
            <span className="text-[11px] text-muted-foreground">None active</span>
          )}
        </div>
      </div>
    </div>
  );
}
