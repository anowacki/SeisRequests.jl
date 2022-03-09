# Plain text formats returned by FDSN web services

"""
    text_response_tokens_and_throw(T, s, n) -> tokens

Split the string `s` into tokens separated by `'|'` characters and
return them, unless there are not exactly `n` tokens, in which
case throw an `ArgumentError`.

`n` may also be an iterable of `Integers`, in which case an error
is thrown if none of the values in `n` equal the length of `tokens.
"""
function text_response_tokens_and_throw(T, s, n)
    tokens = split(s, '|')
    N = length(tokens)
    # N.B.: This relies on scalars being iterable
    N in n || throw(ArgumentError("incorrect number of tokens in $T " *
        "line '$s'.  (Expecting $n; found $N.)"))
    tokens
end

"Local parsing function to throw helpful error when failing to parse"
function _parse(T, s)
    v = tryparse(T, s)
    v === nothing && throw(ArgumentError("error parsing 's' as $T"))
    v
end

"Parsing of `DateTime`s truncates the timestamp to the nearest millisecond."
function _parse(::Type{DateTime}, s)
    # Handle the fact that empty strings are always parsed as valid and
    # give you the date 0001-01-01!
    isempty(s) && return missing
    # Remove any extra precision on the date; e.g. "2000-01-01T00:00:00.00000" -> "2000-01-01T00:00:00.000"
    # Valid dates must be ASCII so an error on the following indexing expression is okay
    # since it indicates invalid input
    s′ = length(s) > 23 ? @view(s[begin:(begin+22)]) : s
    DateTime(s′)
end

_parse(::Type{String}, s) = s
_parse(::Type{Union{Missing,T}}, s) where T = isempty(s) ? missing : _parse(T, s)

abstract type FDSNTextResponse end

"""
    FDSNNetworkTextResponse

Struct containing the fields returned from a `FDSNStation` request where
the `level` is `"network"` and the `format` is `"text"`.
"""
struct FDSNNetworkTextResponse <: FDSNTextResponse
    network::String
    description::String
    starttime::DateTime
    endtime::MDateTime
    total_stations::Int
end

function Base.convert(::Type{FDSNNetworkTextResponse}, s::AbstractString)
    tokens = text_response_tokens_and_throw(FDSNNetworkTextResponse, s, 5)
    network = strip(tokens[1])
    description = tokens[2]
    starttime = _parse(DateTime, tokens[3])
    endtime = _parse(DateTime, tokens[4])
    total_stations = _parse(Int, tokens[5])
    FDSNNetworkTextResponse(network, description, starttime, endtime, total_stations)
end

"""
    FDSNStationTextResponse

Struct containing the fields returned from a `FDSNStation` request where
the `level` is `"station"` and the `format` is `"text"`.
"""
struct FDSNStationTextResponse <: FDSNTextResponse
    network::String
    station::String
    latitude::Float64
    longitude::Float64
    elevation::Float64
    sitename::String
    starttime::DateTime
    endtime::MDateTime
end

function Base.convert(::Type{FDSNStationTextResponse}, s::AbstractString)
    tokens = text_response_tokens_and_throw(FDSNStationTextResponse, s, 8)
    network = strip(tokens[1])
    station = tokens[2]
    latitude = _parse(Float64, tokens[3])
    longitude = _parse(Float64, tokens[4])
    elevation = _parse(Float64, tokens[5])
    sitename = tokens[6]
    starttime = _parse(DateTime, tokens[7])
    endtime = _parse(DateTime, tokens[8])
    FDSNStationTextResponse(network, station, latitude, longitude, elevation,
        sitename, starttime, endtime)
end

"""
    FDSNChannelTextResponse

Struct containing the fields returned from a `FDSNStation` request where
the `level` is `"channel"` and the `format` is `"text"`.
"""
struct FDSNChannelTextResponse <: FDSNTextResponse
    network::String
    station::String
    location::String
    channel::String
    latitude::Float64
    longitude::Float64
    elevation::Float64
    depth::Float64
    azimuth::Float64
    dip::Float64
    sensor_description::String
    scale::MFloat
    scale_frequency::MFloat
    scale_units::MString
    sample_rate::Float64
    starttime::DateTime
    endtime::MDateTime
end

function Base.convert(::Type{FDSNChannelTextResponse}, s::AbstractString)
    tokens = text_response_tokens_and_throw(FDSNChannelTextResponse, s, 17)
    network = strip(tokens[1])
    station = strip(tokens[2])
    location = strip(tokens[3])
    channel = strip(tokens[4])
    latitude = _parse(Float64, tokens[5])
    longitude = _parse(Float64, tokens[6])
    elevation = _parse(Float64, tokens[7])
    depth = _parse(Float64, tokens[8])
    azimuth = _parse(Float64, tokens[9])
    dip = _parse(Float64, tokens[10])
    sensor_description = tokens[11]
    scale = _parse(MFloat, tokens[12])
    scale_frequency = _parse(MFloat, tokens[13])
    scale_units = scale === missing ? _parse(MString, tokens[14]) : tokens[14]
    sample_rate = _parse(Float64, tokens[15])
    starttime = _parse(DateTime, tokens[16])
    endtime = _parse(DateTime, tokens[17])
    FDSNChannelTextResponse(network, station, location, channel,
        latitude, longitude, elevation, depth, azimuth, dip,
        sensor_description, scale, scale_frequency, scale_units,
        sample_rate, starttime, endtime)
end

"""
    FDSNEventTextResponse

Struct containing the fields returned from a `FDSNEvent` request where
the format is "text".
"""
struct FDSNEventTextResponse
    event_id::String
    time::DateTime
    latitude::Float64
    longitude::Float64
    depth::Float64
    author::String
    catalog::String
    contributor::String
    contributor_id::String
    mag_type::String
    magnitude::Float64
    mag_author::String
    event_location_name::String
    event_type::Union{Missing,String}
end

function Base.convert(::Type{FDSNEventTextResponse}, s::AbstractString)
    # Version 1.2 adds a 14th column, event_type.  Allow either 13 or 14 columns
    tokens = text_response_tokens_and_throw(FDSNEventTextResponse, s, (13, 14))
    event_id = tokens[1]
    time = _parse(DateTime, tokens[2])
    latitude = _parse(Float64, tokens[3])
    longitude = _parse(Float64, tokens[4])
    depth = _parse(Float64, tokens[5])
    author = tokens[6]
    catalog = tokens[7]
    contributor = tokens[8]
    contributor_id = tokens[9]
    mag_type = tokens[10]
    mangitude = _parse(Float64, tokens[11])
    mag_author = tokens[12]
    event_location_name = tokens[13]
    # Account for FDSNWS v1.1 and below lacking the event_type field
    event_type = length(tokens) == 14 ? tokens[14] : missing
    FDSNEventTextResponse(event_id, time, latitude, longitude, depth, author,
        catalog, contributor, contributor_id, mag_type, mangitude, mag_author,
        event_location_name, event_type)
end

"""
    ISFTextResponse

Struct containing **some of** the fields returned from a `FDSNEvent` request where
the format is "isf" (IASPEI Seismic Format, as returned by the ISC).
"""
struct ISFTextResponse
    isprime::Bool
    iscentroid::Bool

end
