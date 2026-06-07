/// A reusable agent prompt — the entity the Studio's Prompt Manager edits.
/// A prompt carries a system template (with {{variables}} bound at run time from
/// the gathered evidence + inputs) and a reference to the output contract it
/// expects. Agents reference a Prompt by slug (agent.promptRef); inline prompts in
/// a flow definition remain valid for backward compatibility.
/// JSON field names are camelCase to match the rest of the REST API.
Class FAST.Data.Prompt Extends (%Persistent, %JSON.Adaptor)
{

Parameter %JSONIGNORENULL = 1;

Index SlugIdx On Slug [ Unique ];

/// Stable identifier, e.g. "results-followup-clinician".
Property Slug As %String(%JSONFIELDNAME = "slug", MAXLEN = 100) [ Required ];

Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 200);

/// Persona/audience this prompt addresses, e.g. "clinician", "patient", "developer".
Property Role As %String(%JSONFIELDNAME = "role", MAXLEN = 60);

/// The system-message template. May contain {{variable}} placeholders.
Property SystemTemplate As %String(%JSONFIELDNAME = "systemTemplate", MAXLEN = "");

/// The user-message template (evidence + inputs are interpolated here). Optional;
/// agents may assemble the user message from evidence directly.
Property UserTemplate As %String(%JSONFIELDNAME = "userTemplate", MAXLEN = "");

/// Slug of the OutputSchema describing the JSON contract this prompt must satisfy.
Property OutputContractRef As %String(%JSONFIELDNAME = "outputContractRef", MAXLEN = 100);

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 2000);

Property Version As %String(%JSONFIELDNAME = "version", MAXLEN = 20) [ InitialExpression = "1.0.0" ];

/// Seeded system prompts are protected from deletion in the UI.
Property IsSystem As %Boolean(%JSONFIELDNAME = "isSystem") [ InitialExpression = 0 ];

Property CreatedAt As %TimeStamp(%JSONFIELDNAME = "createdAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

Property UpdatedAt As %TimeStamp(%JSONFIELDNAME = "updatedAt") [ InitialExpression = {$zdatetime($ztimestamp, 3)} ];

}
