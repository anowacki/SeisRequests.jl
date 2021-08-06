"""
# SeisRequests

Request seismic data via the FDSN or IRIS web services interfaces.

Currently implemented schemes are the FDSN Web Services specification, and IRIS's
web services specification for data (timeseries).  Further specifications will
be added in the future.

Use one of the following high-level functions to get information on seismic stations,
seismic events and data:
- [`get_events`](@ref)
- [`get_stations`](@ref)
- [`get_data`](@ref)

See the docstrings for more information.

### Servers
Inbuilt servers can be listed using [`server_list`](@ref).  Not all servers
will return all kinds of information; for instance `"ISC"` only holds earthquake
catalogues.

### Specifications

FDSN Web Services request specification:
    http://www.fdsn.org/webservices/FDSN-WS-Specifications-1.1.pdf

Details on IRISWS timeseries can be found at:
    https://service.iris.edu/irisws/timeseries/1/
"""
module SeisRequests

export
    FDSNDataSelect,
    FDSNEvent,
    FDSNStation,
    IRISTimeSeries,
    add_server!,
    get_data,
    get_events,
    get_request,
    get_stations,
    server_list

using Dates

using HTTP
using DataStructures: OrderedDict
using Parameters
import QuakeML
import Seis
using Seis: GeogEvent, GeogStation
import StationXML
using StationXML: FDSNStationXML


"URIs of servers to which requests can be sent by key"
const SERVERS = Dict{String,String}(
    "Geofon" => "http://geofon.gfz-potsdam.de",
    "INGV" => "http://webservices.ingv.it",
    "IPGP" => "http://ws.ipgp.fr",
    "IRIS" => "http://service.iris.edu",
    "ISC" => "http://www.isc.ac.uk",
    "NCEDC" => "http://service.ncedc.org",
    "NEIC" => "http://earthquake.usgs.gov",
    "Orfeus" => "http://www.orfeus-eu.org",
    "SCEDC" => "http://service.scedc.caltech.edu",
    )

const DEFAULT_SERVER = "IRIS"

"Dict describing the common HTTP status codes returned by FDSN services"
const STATUS_CODES = Dict{Int,String}(
    200 => "Successful request, results follow",
    204 => "Request was properly formatted and submitted but no data matches the selection",
    400 => "Bad request due to improper specification, unrecognized parameter, parameter value out of range, etc.",
    401 => "Unauthorized, authentication required",
    403 => "Authentication failed or access blocked to restricted data",
    404 => "Alternate to 204 (set via the ‘nodata’ parameter), normally used for results returned to a web browser.",
    413 => "Request would result in too much data being returned or the request itself is too large, returned error message should include the service limitations in the detailed description. Service limits should also be documented in the service WADL.",
    414 => "Request URI too large",
    500 => "Internal server error",
    503 => "Service temporarily unavailable, used in maintenance and error conditions")
const CODE_SUCCESS = 200
const CODES_FAILURE = (400, 401, 403, 404, 413, 414, 500, 503)

# Types which accept missing values
const MBool = Union{Missing,Bool}
const MDateTime = Union{Missing,DateTime}
const MFloat = Union{Missing,Float64}
const MInt = Union{Missing,Int}
const MString = Union{Missing,String}

"""
    SeisRequest

An abstract type representing any kind of web request for seismic data.

Current subtypes of `SeisRequest`:
- `FDSNRequest`
- `IRISRequest`
"""
abstract type SeisRequest end

include("compat.jl")
include("util.jl")
include("fdsnws.jl")
include("fdsnws-formats.jl")
include("irisws.jl")
include("high-level.jl")
include("io.jl")

"""Default version string for all requests."""
version_string(::SeisRequest) = "1"

"""
    request_uri(r::SeisRequest; server=$(DEFAULT_SERVER)) -> uri

Return a URI for the request `r`, which can then be obtained via HTTP GET.

`server` can either be a URI or one of the available servers.  (See [`server_list`](@ref).)
"""
function request_uri(r::SeisRequest; server=DEFAULT_SERVER)
    uri = base_uri(r, server=server) * "?"
    firstfield = true
    for f in fieldnames(typeof(r))
        v = getfield(r, f)
        if !ismissing(v)
            if firstfield
                uri *= "$(f)=$(v)"
                firstfield = false
            else
                uri = join((uri, "$(f)=$(v)"), "&")
            end
        end
    end
    uri
end

"""
    post_uri(rs::AbstractArray{SeisRequest}; server=$(DEFAULT_SERVER)) -> uri

Return a URI for the requests `rs`, which can then be obtained via HTTP POST.

`server` can either be a URI or one of the available servers.  (See [`server_list`](@ref).)
"""
post_uri(r::SeisRequest; server=DEFAULT_SERVER) = base_uri(r, server=server)

"""
    base_uri(request::SeisRequest, server=$(DEFAULT_SERVER)) -> uri

Return the base URI for the `request`, which will look something like
`http://service.iris.edu/fdsnws/station/1/query`.

Note that the `query` part is included.
"""
function base_uri(request::SeisRequest; server=DEFAULT_SERVER)
    server = server in keys(SERVERS) ? SERVERS[server] : server
    protocol = protocol_string(request)
    service = service_string(request)
    version = version_string(request)
    uri = join((server, protocol, service, version, "query"), "/")
    uri
end

"""
    add_server!(label, uri)

Add a server with key `label` to the global list of servers.

See also: [`server_list`](@ref)
"""
function add_server!(label, uri)
    label ∈ keys(SERVERS) && throw(ArgumentError("A server with label `$label` already exists"))
    SERVERS[label] = uri
end

"""
    server_list() -> servers

Return a list of available servers for use with a `SeisRequest`.

See also: [`add_server!`](@ref)
"""
server_list() = collect(keys(SERVERS))

"""
    get_request(r::SeisRequest; server=$(DEFAULT_SERVER), verbose=true) -> response::HTTP.Message.Response

Return `response`, the result of requesting `r` via the HTTP GET command.  Optionally specify
the server either by URI or one of the available servers.  (See [`server_list`](@ref).)
"""
function get_request(r::SeisRequest; server=DEFAULT_SERVER, verbose=true)
    uri = request_uri(r; server=server)
    response = HTTP.request("GET", uri)
    status_text = STATUS_CODES[response.status]
    if verbose
        @info("Request status: " * status_text)
    else
        response.status in CODES_FAILURE && @warn("Request status: " * status_text)
    end 
    response
end

"""
    post_request(requests::AbstractArray{<:SeisRequest}; server=$(DEFAULT_SERVER), verbose=true) -> response::HTTP.Message.Response

Send a set of `requests` to `server` using the HTTP POST method, returning
the `response`.

This requires that all the options apart from channel, start time and
end time are the same for all the `requests`.
"""
function post_request(rs::AbstractArray{T};
        server=DEFAULT_SERVER, verbose=true) where {T<:FDSNRequest}
    if !requests_can_be_posted(rs)
        throw(ArgumentError("all requests must be identical apart from their " *
            "channel, start time and end time"))
    end
    body = post_string(rs)
    uri = post_uri(first(rs); server=server)
    # FIXME: Currently IRIS doesn't support a `nodata` line in POST requests
    #        so do not include that for compatibility and simply warn
    #        if nodata != 204.
    #        Other datacentres *do* allow this.
    if server == "IRIS" || server == SERVERS["IRIS"]
        first(rs).nodata != 204 &&
            @warn("IRIS does not support setting the nodata field in POST " *
                  "requests, but it has a non-default value for this request.")
        body = replace(body, r"^\s*nodata=.*\n"=>"")
    end
    response = HTTP.request("POST", uri, [], body)
    status_text = STATUS_CODES[response.status]
    if verbose
        @info("Request status: " * status_text)
    else
        response.status in CODES_FAILURE && @warn("Request status: " * status_text)
    end
    response
end

post_request(::AbstractArray{T}; kwargs...) where {T<:IRISTimeSeries} =
    throw(ArgumentError("$T requests cannot be posted"))

"List of fields which are written in the body of a POST request"
const POST_FIELDS = (:network, :station, :location, :channel, :starttime, :endtime)

"""
    requests_can_be_posted(requests::AbstractArray{<:SeisRequest}) -> ::Bool

Return `true` if the `requests` have options which are consistent (i.e., they
are all the same apart from the channel code, start time and end time),
and hence can be sent via a POST request.
"""
function requests_can_be_posted(rs::AbstractArray{T}) where {T<:SeisRequest}
    for field in fieldnames(T)
        field in POST_FIELDS && continue
        all(getfield(x, field) === getfield(first(rs), field) for x in rs) ||
            return false
    end
    true
end

"Return the full string to be sent as part of a POST request."
post_string(rs) = join((post_string_header(first(rs)), post_string_body(rs)), '\n')

"Return the header part of a POST request."
function post_string_header(r::T) where {T<:SeisRequest}
    join([String(f)*"="*string(getfield(r, f)) for f in fieldnames(T)
          if f ∉ POST_FIELDS && getfield(r, f) !== missing], '\n')
end

"Return the body part of a POST request for a set of `SeisRequest`s."
function post_string_body(rs::AbstractArray{<:SeisRequest})
    s = ""
    for r in rs
        for field in POST_FIELDS
            if field !== :network
                s *= " "
            end
            val = getfield(r, field)
            if val === missing
                throw(ArgumentError("$field field cannot be missing"))
            end
            if field === :location && val == ""
                val = "--"
            end
            s *= string(val)
        end
        s *= "\n"
    end
    s
end

# FDSNEvents can be POSTed in theory, though I don't know of any
# servers which allow this.
post_string_body(rs::AbstractArray{FDSNEvent}) = ""

end # module
