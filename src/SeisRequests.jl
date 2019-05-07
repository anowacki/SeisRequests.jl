"""
# SeisRequests

Basic implementation of seismic web requests, returning only the raw results
of a request.

Currently implemented schemes are the FDSN Web Services specification, and IRIS's
web services specification for data (timeseries).  Further specifications will
be added in the future.

To request data, create a one of the [FDSNRequest](@ref) types and use the
[get_request](@ref) method on it.  This method returns a `HTTP.Message.Response`
containing the raw response in the field `body`.

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
    get_request,
    server_list

using Dates

using HTTP
using Parameters
import DataStructures: OrderedDict


"URIs of servers to which requests can be sent by key"
const SERVERS = Dict{String,String}(
    "IRIS" => "http://service.iris.edu",
    "INGV" => "http://webservices.ingv.it",
    "Orfeus" => "http://www.orfeus-eu.org")

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

include("fdsnws.jl")
include("irisws.jl")

"""Default version string for all requests."""
version_string(::SeisRequest) = "1"

"""
    request_uri(r::SeisRequest; server=$(DEFAULT_SERVER)) -> uri

Return a URI for the request `r`, which can then be obtained via HTTP GET.

`server` can either be a URI or one of the available servers.  (See [server_list](@ref).)
"""
function request_uri(r::SeisRequest; server=DEFAULT_SERVER)
    server = server in keys(SERVERS) ? SERVERS[server] : server
    protocol = protocol_string(r)
    service = service_string(r)
    version = version_string(r)
    uri = join((server, protocol, service, version, "query?"), "/")
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
    add_server!(label, uri)

Add a server with key `label` to the global list of servers.

See also [server_list](@ref).
"""
function add_server!(label, uri)
    label ∈ keys(SERVERS) && throw(ArgumentError("A server with label `$label` already exists"))
    SERVERS[label] = uri
end

"""
    server_list() -> servers

Return a list of available servers for use with a `SeisRequest`.

See also [add_server!](@ref).
"""
server_list() = collect(keys(SERVERS))

"""
    get_request(r::SeisRequest; server=$(DEFAULT_SERVER)) -> response::HTTP.Message.Response

Return `response`, the result of requesting `r` via the HTTP GET command.  Optionally specify
the server either by URI or one of the available servers.  (See [server_list](@ref).)
"""
function get_request(r::SeisRequest; server=DEFAULT_SERVER, verbose=true)
    uri = request_uri(r; server=server)
    response = HTTP.request("GET", uri)
    status_text = STATUS_CODES[response.status]
    if verbose
        @info("Request status: " * status_text)
    else
        response.status in CODES_FAILURE && warn("Request status: " * status_text)
    end 
    response
end



end # module
