/// Shared JSON helpers: pretty serialise + safe parse.
Class FAST.Util.JSON [ Abstract ]
{

/// Serialise a dynamic object/array to a JSON string (pretty by default).
ClassMethod ToString(obj As %DynamicAbstractObject, pretty As %Boolean = 1) As %String
{
    if '$isobject(obj) return ""
    if pretty {
        try {
            set fmt = ##class(%JSON.Formatter).%New()
            set st = ##class(%Stream.GlobalCharacter).%New()
            do fmt.FormatToStream(obj, st)
            return ..StreamToString(st)
        } catch {}
    }
    set st = ##class(%Stream.GlobalCharacter).%New()
    do obj.%ToJSON(st)
    return ..StreamToString(st)
}

/// Parse a JSON string into a dynamic object, or "" on empty/invalid.
ClassMethod Parse(json As %String) As %DynamicAbstractObject
{
    if json = "" return ""
    try { return ##class(%DynamicAbstractObject).%FromJSON(json) } catch { return "" }
}

/// Size of a dynamic array property, tolerant of missing/non-array values.
ClassMethod ArrSize(arr As %DynamicAbstractObject) As %Integer
{
    if '$isobject(arr) return 0
    return arr.%Size()
}

ClassMethod StreamToString(st As %Stream.Object) As %String
{
    do st.Rewind()
    set s = ""
    while 'st.AtEnd { set s = s _ st.Read(32000) }
    return s
}

}
