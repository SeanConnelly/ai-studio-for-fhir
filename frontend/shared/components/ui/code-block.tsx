import { useState } from "react";
import { Check, Copy } from "lucide-react";
import hljs from "highlight.js/lib/core";
import json from "highlight.js/lib/languages/json";
import xml from "highlight.js/lib/languages/xml";
import markdown from "highlight.js/lib/languages/markdown";
import sql from "highlight.js/lib/languages/sql";
import "highlight.js/styles/github-dark.css";
import { cn } from "@shared/lib/utils";

hljs.registerLanguage("json", json);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("markdown", markdown);
hljs.registerLanguage("sql", sql);

function escapeHtml(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Syntax-highlighted code/JSON viewer with a copy button. */
export function CodeBlock({ content, language, className }: { content: string; language?: string; className?: string }) {
  const [copied, setCopied] = useState(false);
  let display = content;
  if (language === "json") {
    try {
      display = JSON.stringify(JSON.parse(content), null, 2);
    } catch {
      /* leave as-is */
    }
  }
  const html = language && hljs.getLanguage(language) ? hljs.highlight(display, { language }).value : escapeHtml(display);

  return (
    <div className={cn("relative rounded-md border bg-[#0d1117] text-slate-100", className)}>
      <button
        onClick={() => {
          navigator.clipboard.writeText(display);
          setCopied(true);
          setTimeout(() => setCopied(false), 1200);
        }}
        className="absolute right-2 top-2 z-10 rounded p-1.5 text-slate-400 hover:bg-slate-800 hover:text-slate-100"
        title="Copy"
      >
        {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
      </button>
      <pre className="overflow-auto p-4 text-xs leading-relaxed">
        <code dangerouslySetInnerHTML={{ __html: html }} />
      </pre>
    </div>
  );
}
