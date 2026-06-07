import * as React from "react";
import { cn } from "@shared/lib/utils";

export const Label = ({ className, ...props }: React.LabelHTMLAttributes<HTMLLabelElement>) => (
  <label className={cn("text-xs font-medium text-foreground", className)} {...props} />
);
