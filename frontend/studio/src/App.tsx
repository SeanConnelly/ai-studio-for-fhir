import { Routes, Route, Navigate } from "react-router-dom";
import { PortalLayout } from "@/components/PortalLayout";
import { Agents } from "@/pages/Agents";
import { AgentWorkspace } from "@/pages/AgentWorkspace";
import { Admin } from "@/pages/Admin";
import { Components } from "@/pages/Components";
import { CareRules } from "@/pages/CareRules";
import { AiHub } from "@/pages/AiHub";
import { Help } from "@/pages/Help";
import { Walkthrough } from "@/pages/Walkthrough";

export default function App() {
  return (
    <Routes>
      <Route element={<PortalLayout />}>
        <Route index element={<Navigate to="/agents" replace />} />
        <Route path="/agents" element={<Agents />} />
        <Route path="/agent/:slug" element={<AgentWorkspace />} />
        <Route path="/agent/:slug/:tab" element={<AgentWorkspace />} />
        <Route path="/components/:entity" element={<Components />} />
        <Route path="/care-rules" element={<CareRules />} />
        <Route path="/ai-hub" element={<AiHub />} />
        <Route path="/admin" element={<Admin />} />
        <Route path="/help" element={<Help />} />
        <Route path="/walkthrough" element={<Walkthrough />} />
        {/* Retired managers: prompts live on each agent's Reason step; actions inline on the agent. */}
        <Route path="/components/prompts" element={<Navigate to="/agents" replace />} />
        <Route path="/components/actions" element={<Navigate to="/agents" replace />} />
        {/* Retired lifecycle pages now live inside the agent workspace. */}
        <Route path="/templates" element={<Navigate to="/agents" replace />} />
        <Route path="/flows" element={<Navigate to="/agents" replace />} />
        <Route path="/designer" element={<Navigate to="/agents" replace />} />
        <Route path="/compile" element={<Navigate to="/agents" replace />} />
        <Route path="/test" element={<Navigate to="/agents" replace />} />
        <Route path="/mapping" element={<Navigate to="/agents" replace />} />
        <Route path="/import-export" element={<Navigate to="/agents" replace />} />
        <Route path="*" element={<Navigate to="/agents" replace />} />
      </Route>
    </Routes>
  );
}
