import { Routes, Route, Navigate } from "react-router-dom";
import { ClinicalShell } from "@/components/ClinicalShell";
import { Worklist } from "@/pages/Worklist";
import { Search } from "@/pages/Search";
import { PatientChart } from "@/pages/PatientChart";
import { PriorAuth } from "@/pages/PriorAuth";
import { Trials } from "@/pages/Trials";
import { Ask } from "@/pages/Ask";
import { Triage } from "@/pages/Triage";
import { PatientPortal } from "@/pages/PatientPortal";
import { DemoGuide } from "@/pages/DemoGuide";

export default function App() {
  return (
    <Routes>
      {/* Patient-facing portal (simulated phone app) — no clinician shell. */}
      <Route path="/portal" element={<PatientPortal />} />
      <Route element={<ClinicalShell />}>
        <Route index element={<Worklist />} />
        <Route path="/demo" element={<DemoGuide />} />
        <Route path="/search" element={<Search />} />
        <Route path="/prior-auth" element={<PriorAuth />} />
        <Route path="/trials" element={<Trials />} />
        <Route path="/ask" element={<Ask />} />
        <Route path="/triage" element={<Triage />} />
        <Route path="/patient/:id" element={<PatientChart />} />
        <Route path="/patient/:id/:section" element={<PatientChart />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
