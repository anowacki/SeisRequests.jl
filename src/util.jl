# Utility functions

"""
    seconds_milliseconds(x) -> ::Dates.CompoundPeriod

Convert a real value `x` into a `Dates.CompoundPeriod` of seconds and
milliseconds, truncating to the nearest millisecond.

# Example
julia> using SeisRequests

julia> SeisRequests.seconds_milliseconds(5.1019)
5 seconds, 101 milliseconds
"""
function seconds_milliseconds(x)
    s, ms = divrem(x, 1)
    ms *= 1000
    Second(floor(Int, s)) + Millisecond(floor(Int, ms))
end

"""
    split_channel_code(code) -> (network, station, location, channel)

Split up a single string `code` giving a channel code in the form
`"⟨network⟩.⟨station⟩.⟨channel⟩.⟨location⟩"` into its component parts,
and return a named tuple.
"""
function split_channel_code(code)
    tokens = split(code, '.')
    length(tokens) == 4 ||
        throw(ArgumentError("incorrect number of fields in code \"$code\""))
    (network=tokens[1], station=tokens[2], location=tokens[3], channel=tokens[4])
end

"""
    _error_on_control_characters(uri)

Throws an `ArgumentError` if the string `uri` contains an illegal control
character, and otherwise returns `nothing`.
"""
function _error_on_control_characters(uri)
    for control_char in ('\r', '\n')
        if control_char in uri
            throw(ArgumentError(
                "string contains illegal control character '$control_char'"
            ))
        end
    end

    nothing
end
