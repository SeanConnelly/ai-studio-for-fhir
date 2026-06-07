// Type declarations for the shared question-catalogue expansion module.
export interface AskTemplate {
  id: string;
  text: string;
  // JSON imports infer optional-undefined members across the template union,
  // so the index signature must tolerate undefined values
  slots?: { [slot: string]: string[] | undefined };
}
export interface AskCatalogue {
  description?: string;
  templates: AskTemplate[];
  exclusions?: string[];
}
export function allQuestions(catalogue: AskCatalogue): string[];
export function randomQuestion(catalogue: AskCatalogue): string;
