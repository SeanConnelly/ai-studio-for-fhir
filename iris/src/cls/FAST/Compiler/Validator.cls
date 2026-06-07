/// Validates a flow/template definition before compilation.
Class FAST.Compiler.Validator [ Abstract ]
{

/// Returns $$$OK if valid; otherwise an error status. Fills errors (a
/// %DynamicArray) with human-readable problems.
ClassMethod Validate(def As %DynamicObject, Output errors As %DynamicArray) As %Status
{
    set errors = []
    if '$isobject(def) {
        do errors.%Push("Definition is not a valid JSON object")
        return $$$ERROR($$$GeneralError, "invalid definition")
    }
    if (def.id = "") do errors.%Push("Missing 'id'")
    if (def.name = "") do errors.%Push("Missing 'name'")
    if '$isobject(def.trigger) do errors.%Push("Missing 'trigger' object")
    if '$isobject(def.evidence) do errors.%Push("Missing 'evidence' object")
    if '$isobject(def.agent) {
        do errors.%Push("Missing 'agent' object")
    } else {
        if (def.agent.instruction = "") do errors.%Push("Missing 'agent.instruction'")
        if (def.agent.outputSchema = "") do errors.%Push("Missing 'agent.outputSchema'")
    }
    if '$isobject(def.action) do errors.%Push("Missing 'action' object")
    // `inputs` is optional, but if present each entry needs a key + a known type.
    if $isobject(def.inputs) {
        set known = ",patient,fhir-reference,text,enum,"
        set it = def.inputs.%GetIterator()
        while it.%GetNext(.k, .inp) {
            if '$isobject(inp) || (inp.key = "") { do errors.%Push("Each input needs a 'key'")  continue }
            if (inp.type = "") || (known '[ (","_inp.type_",")) do errors.%Push("Input '"_inp.key_"' has an unknown type '"_inp.type_"'")
            if (inp.type = "enum") && ('$isobject(inp.options) || (inp.options.%Size() = 0)) do errors.%Push("Enum input '"_inp.key_"' needs 'options'")
        }
    }
    if (errors.%Size() > 0) return $$$ERROR($$$GeneralError, "validation failed")
    return $$$OK
}

}
