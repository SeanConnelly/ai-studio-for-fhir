import { Outlet } from "react-router-dom";
import { TopHeader } from "./TopHeader";
import { SideNav } from "./SideNav";

/** Fixed header + fixed left nav + internally scrollable main content. */
export function PortalLayout() {
  return (
    <div className="flex h-screen flex-col overflow-hidden">
      <TopHeader />
      <div className="flex min-h-0 flex-1">
        <SideNav />
        <main className="min-w-0 flex-1 overflow-y-auto bg-background p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
