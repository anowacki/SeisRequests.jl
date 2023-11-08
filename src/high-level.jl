# High-level request functions which create and send a request,
# then return Seis.Events

const _Period = Union{Dates.Period, Dates.CompoundPeriod}

#
# get_stations
#

"""
    get_stations(; server=$(DEFAULT_SERVER), verbose=true, T=Float64, kwargs...) -> stations

Query `server` for stations matching the keyword arguments in `kwargs`,
which are passed to [`FDSNStation`](@ref).  `stations` is a
`Vector{Seis.GeogStation{T}}`, where various useful fields are added to the
`.meta` field of each station.  These keyword arguments are supported by
all `get_stations` methods.

For search options and the format of `kwargs`, see [`FDSNStation`](@ref).

The element type of the `Seis.Station`s returned is set by `T`.

# Example
Find all stations in the XM network between 2012 and 2014:
```
julia> using Dates

julia> get_stations(network="XM", starttime=DateTime(2012), endtime=DateTime(2015))
[ Info: Request status: Successful request, results follow
21-element Array{Seis.Station{Float64,Seis.Geographic{Float64}},1}:
 Station: XM.A01E.., lon: 38.78384, lat: 7.78823, elev: 1921.0, meta: 5 keys
 Station: XM.A02E.., lon: 38.799709, lat: 7.86046, elev: 1643.0, meta: 5 keys
 Station: XM.A03E.., lon: 38.76218, lat: 7.81199, elev: 1952.0, meta: 5 keys
 Station: XM.A04E.., lon: 38.688702, lat: 7.76335, elev: 1640.0, meta: 5 keys
 Station: XM.A05E.., lon: 38.726269, lat: 7.84464, elev: 1652.0, meta: 5 keys
...
```

# Populated `Station` fields

The amount of information contained within each `Station` returned
depends on the `level` of information requested and the `format` of
the response (see [`FDSNStation`](@ref)).

If `format` is `"text"`, then only a limited number of extra information
is added to the `meta` field of each station.  By default, the servers returns
information in StationXML format, which may be bare or comprehensive.
The StationXML information for the network, station or channel is added
to the `meta.stationxml` field.

If `level` is `"network"`, then stations are not real 'stations' and contain
only the network fields.  Likewise, for `level="station"`, the channel code
(`cha` field) of each station is empty and no information about channel
orientation is available.  Therefore, it is usually best to specify
`level="channel"` if you plan to associate the `stations` with time series
data.

If you use the `code` keyword argument to specify the stations for which to
search (e.g., `code="XM.A*..*Z"`; see [`FDSNStation`](@ref)), then `level`
is automatically set to `"channel"`.  Override this if desired by passing
a value to `level` explicitly.
"""
function get_stations(; server=DEFAULT_SERVER, verbose=true, T=Float64, kwargs...)
    request = FDSNStation(; kwargs...)
    response = get_request(request; server=server, verbose=verbose)
    stations = parse_station_response(T, request, response, server)
end

"""
    get_stations(event::Seis.GeogEvent, starttime, endtime; longitude=event.lon, latitude=event.lat,
                 starttime=event.time, endtime=event.time, kwargs...) -> stations

Find stations relative to an `event`, typically constraining the station locations
to be a certain distance from `event`, or requiring stations to be active at
the time of the event.

This method queries `server` for stations matching the options to [`FDSNStation`](@ref)
in `kwargs`, but with the following defaults set:

- `longitude` and `latitude` are set to the event's coordinates.  This means that
  automatically, setting `minradius` and `maxradius` will search around the event.
- `starttime` and `endtime` are set to the event origin time), meaning only
  stations or channels which were active at the time of the event will be included.

To override the default behaviour of only matching stations/channels which are
active at the time of the event, set `starttime` and `endtime` to the date
range of interest.

!!! note
    To limit stations to only those with time series information for the period
    specified, use `matchtimeseries=true`.  This is especially useful when
    setting `starttime` and `endtime` using other methods of `get_stations`.

# Example
Get vertical high-gain, broadband and high broadband channels in the II and IU
networks which were active during a deep-focus earthquake on 2018-09-21,
and for which data is present in the IRIS datacentre.  (In this case,
`event` might have been obtained elsewhere or by a call to [`get_events`](@ref),
but we create the event here for simplicity.)
```
julia> using Dates, Seis

julia> event = Event(lon=-179.9776, lat=-17.9071, dep=652.35, time=DateTime(2018, 9, 21, 3, 40, 40, 550))
Seis.Event{Float64,Seis.Geographic{Float64}}:
        lon: -179.9776
        lat: -17.9071
        dep: 652.35
       time: 2018-09-21T03:40:40.55
         id: missing
       meta: 

julia> get_stations(event, network="II,IU", channel="BHZ,HHZ", matchtimeseries=true, server="IRIS", format="text")
[ Info: Request status: Successful request, results follow
331-element Array{Station{Float64,Seis.Geographic{Float64}},1}:
 Station: II.AAK.00.BHZ, lon: 74.4942, lat: 42.6375, dep: 0.03, elev: 1633.1, azi: 0.0, inc: 0.0, meta: 7 keys
 Station: II.AAK.10.BHZ, lon: 74.4942, lat: 42.6375, dep: 0.03, elev: 1633.1, azi: 0.0, inc: 0.0, meta: 7 keys
 ⋮
 Station: IU.YSS.00.BHZ, lon: 142.7604, lat: 46.9587, dep: 0.002, elev: 148.0, azi: 0.0, inc: 0.0, meta: 7 keys
 Station: IU.YSS.10.BHZ, lon: 142.7604, lat: 46.9587, dep: 0.002, elev: 148.0, azi: 0.0, inc: 0.0, meta: 7 keys
```

See also: [`FDSNStation`](@ref).
"""
function get_stations(event::GeogEvent, starttime::Union{AbstractString,DateTime}=event.time,
        endtime::Union{AbstractString,DateTime}=event.time; kwargs...)
    default_kwargs = if haskey(kwargs, :minradius) || haskey(kwargs, :maxradius)
        (longitude=event.lon, latitude=event.lat,
            starttime=starttime, endtime=endtime)
    else
        (starttime=starttime, endtime=endtime)
    end
    get_stations(; merge(default_kwargs, kwargs)...)
end

"""
    get_stations(event, start_offset, end_offset; kwargs...)

Specify the time range for data selection as a window around the event time.

`start_offset` and `end_offset` define a data selection time range as a
window around the event time.  They may be given in seconds, or using
`Dates.Period`s or `Dates.CompoundPeriod`s (e.g., `Hour(1)` or `Week(2) + Day(5)`).

Offsets are rounded down to the nearest millisecond.

!!! note
    Note that for `start_offset` and `end_offset`, all positive values indicate
    a time **later** than the event origin time.  Use negative times to mean a
    time before the event.

# Examples
Find broadand channels within 20° of the 2004-12-26 M=9 earthquake with data
between 20 s before and 1800 s after the origin:
```
julia> event = get_events(minmagnitude=8.5, starttime="2004-12-26", endtime="2004-12-27")
[ Info: Request status: Successful request, results follow
1-element Array{Seis.Event{Float64,Seis.Geographic{Float64}},1}:
 Event: lon: 95.9012, lat: 3.4125, dep: 26.1, time: 2004-12-26T00:58:52.05, id: smi:service.iris.edu/fdsnws/event/1/query?originid=3788623, meta: 7 keys

julia> stations = get_stations(first(event), -20, 1800, level="channel", channel="BH?", maxradius=20, matchtimeseries=true)
[ Info: Request status: Successful request, results follow
24-element Array{Seis.Station{Float64,Seis.Geographic{Float64}},1}:
 Station: GE.UGM..BHE, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 90.0, inc: 90.0, meta: 5 keys
 Station: GE.UGM..BHN, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 0.0, inc: 90.0, meta: 5 keys
 Station: GE.UGM..BHZ, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 0.0, inc: 0.0, meta: 5 keys
 Station: II.COCO.00.BH1, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 141.3, inc: 90.0, meta: 5 keys
 Station: II.COCO.00.BH2, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 231.3, inc: 90.0, meta: 5 keys
 Station: II.COCO.00.BHZ, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 0.0, inc: 0.0, meta: 5 keys
 Station: II.COCO.20.BHE, lon: 96.8349, lat: -12.1901, dep: 0.0013, elev: 1.0, azi: 90.0, inc: 90.0, meta: 5 keys
...
```

In this example, we used [`get_event`](@ref) to first find the event of interest,
but any existing `Seis.Event` object can be used.  The event and stations could
now be passed to [`get_data`](@ref) to download the data for these stations.

To perform the same query, but for data between one minute before and one hour
after the event:
```
julia> using Dates

julia> get_stations(first(event), -Minute(1), Hour(1), level="channel", channel="BH?", maxradius=20, matchtimeseries=true)
[ Info: Request status: Successful request, results follow
24-element Array{Seis.Station{Float64,Seis.Geographic{Float64}},1}:
 Station: GE.UGM..BHE, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 90.0, inc: 90.0, meta: 5 keys
 Station: GE.UGM..BHN, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 0.0, inc: 90.0, meta: 5 keys
 Station: GE.UGM..BHZ, lon: 110.523102, lat: -7.9125, dep: 0.0, elev: 350.0, azi: 0.0, inc: 0.0, meta: 5 keys
 Station: II.COCO.00.BH1, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 141.3, inc: 90.0, meta: 5 keys
 Station: II.COCO.00.BH2, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 231.3, inc: 90.0, meta: 5 keys
 Station: II.COCO.00.BHZ, lon: 96.8349, lat: -12.1901, dep: 0.07, elev: 1.0, azi: 0.0, inc: 0.0, meta: 5 keys
...
```
"""
get_stations(event::GeogEvent, start_seconds, end_seconds; kwargs...) =
    get_stations(event, event.time + seconds_milliseconds(start_seconds),
        event.time + seconds_milliseconds(end_seconds); kwargs...)

get_stations(event::GeogEvent, start_offset::_Period, end_offset::_Period; kwargs...) =
    get_stations(event, event.time + start_offset, event.time + end_offset; kwargs...)

"""
    get_stations!(stations; starttime=nothing, endtime=nothing, server=$(DEFAULT_SERVER), level="channel", T=Float64)

Fill in missing information about each station in `stations`, which should
be a set of `Seis.Station`s.

This function uses the `net`, `sta`, `loc` and `cha` fields of the stations
to search for metadata matching the channel code of the station by making
a [`FDSNStation`](@ref) request to `server`.  If a station contains
information about the recording period of a station in `meta.startdate`
and `meta.enddate`, then this is used to constrain the search for station
data.

If no operatng time information is available, then this can be passed with
the `starttime` and `endtime` keyword arguments.

If more than one station is a match, then an error is thrown.

If no data are found for one or more stations, a warning is printed but
the function does not throw an error.

# Example
Fill in data for two stations recording on 1 January 2000.
```
julia> using Seis: Station

julia> stas = [Station(net="II", sta="ALE", loc="00", cha="BHZ"), Station(net="IU", sta="XMAS", loc="00", cha="BHZ")]

julia> get_stations!(stas, starttime="2000-01-01", endtime="2000-01-02")
```
"""
function get_stations!(stations::AbstractArray{<:Seis.GeogStation};
        level="channel", T=Float64,
        server=DEFAULT_SERVER, verbose=true,
        kwargs...
    )
    requests = [
        FDSNStation(;
            (network=s.net,
             station=s.sta,
             location=s.loc,
             channel=s.cha,
             # Use 1800-01-01T00:00:00 and 4000-01-01T00:00:00 as impossibly small and
             # large dates, since typemax/typemin values are too large to be
             # parsed by most servers
             starttime=coalesce(s.meta.startdate, DateTime(1800)),
             endtime=coalesce(s.meta.enddate, DateTime(4000)),
             level=level,
             kwargs...)...
        ) for s in stations]
    response = post_request(requests; server=server, verbose=verbose)
    stations_response = parse_station_response(T, first(requests), response, server)
    stations = assign_stations!(stations, stations_response, requests; verbose=verbose)
    stations
end

"""
    assign_stations!(stations, stations_response, requests)

Fill in extra information in each station in `stations` with information in
`stations_response`, matching them up by channel code.  `requests` is a set of
[`FDSNStation`](@ref) requests matched to stations similarly.
"""
function assign_stations!(stations, stations_response, requests; verbose=true)
    for station in stations
        code = Seis.channel_code(station)
        inds = findall(x -> x.net == station.net && x.sta == station.sta &&
                            x.loc == station.loc && x.cha == station.cha,
            stations_response)
        # Skip stations with no matching stations_response
        if length(inds) == 0
            verbose && @warn("No matching station for $code")
            continue
        else
            # Always warn if there are more than two
            length(inds) > 1 &&
                @warn("more than one period found matching $code; taking latest")
            latest_ind = argmax(
                [coalesce(stations_response[i].meta.starttime, typemin(DateTime))
                                for i in inds])
            sta = stations_response[inds[latest_ind]]
            station.lon, station.lat, station.elev = sta.lon, sta.lat, sta.elev
            station.azi, station.inc = sta.azi, sta.inc
            merge!(station.meta, sta.meta)
            # Add corresponding request for this station, since
            # in the call to parse_station_response() we only passed
            # the first request and it will be wrong at this point
            request_ind = findfirst(x -> x.network == station.net &&
                                     x.station == station.sta &&
                                     x.location == station.loc &&
                                     x.channel == station.cha,
                requests)
            # This should be impossible since we create the requests using
            # `stations`, but just in case we are called incorrectly
            request_ind === nothing &&
                throw(ArgumentError("no request for $code"))
            station.meta.request = requests[request_ind]
        end
    end
    stations
end

"""
    parse_station_response(T, request, response, server) -> stations::Vector{Seis.Station}

Convert a `response` to an `FDSNStation` request obtained with
[`SeisRequests.post_request`](@ref) or [`SeisRequests.get_request`](@ref)
into a set of stations.

`T` is the element type of the `Vector{Seis.GeogStation{T}}` returned
and defaults to `Float64` if this function is called from
[`get_stations`](@ref).
"""
function parse_station_response(T, request::FDSNStation, response, server)
    station_type = GeogStation{T}
    # No results
    if response.status == request.nodata
        isempty(response.body) || @warn("unexpected data in response reporting no data")
        return station_type[]
    elseif isempty(response.body)
        error("empty response but server did not indicate no data")
    end
    # Parse as string
    str = String(response.body)
    # If asked for a text format, parse that internally
    if coalesce(request.format, "") == "text"
        _check_content_type(response, "text/plain")
        lines = (line for line in split(str, '\n') if !occursin(r"^(\s*#.*|\s*)$", line))
        if coalesce(request.level, "") == "network"
            fdsn_networks = [convert(FDSNNetworkTextResponse, line) for line in lines]
            stations = parse_stations(station_type, request, fdsn_networks, server)
        # Default is station level
        elseif request.level === missing || request.level == "station"
            fdsn_stations = [convert(FDSNStationTextResponse, line) for line in lines]
            stations = parse_stations(station_type, request, fdsn_stations, server)
        elseif coalesce(request.level, "") == "channel"
            fdsn_channels = [convert(FDSNChannelTextResponse, line) for line in lines]
            stations = parse_stations(station_type, request, fdsn_channels, server)
        end
    # Otherwise we get XML and parse with StationXML
    elseif request.format === missing || request.format == "xml"
        _check_content_type(response, "application/xml")
        stationxml = StationXML.readstring(str)
        stations = parse_stations(station_type, request, stationxml, server)
    end
    stations
end

"""
    parse_stations(T, request, fdsn_text_responses, server)

Convert `fdsn_text_responses`, a set of [`SeisRequests.FDSNTextResponse`](@ref)s,
into a set of `Seis.Station`s.
`T` is the type of `Seis.Station` returned.

This method is usually called by [`SeisRequests.parse_station_response`](@ref).
"""
function parse_stations(T, request, fdsn_networks::AbstractArray{FDSNNetworkTextResponse},
        server)
    stations = similar(Vector{T}, axes(fdsn_networks))
    for (i, n) in enumerate(fdsn_networks)
        stations[i] = T(
            net=n.network,
            meta=Dict{Symbol,Any}(
                :network_description=>n.description,
                :network_number_stations=>n.total_stations,
                :startdate=>n.starttime,
                :server=>server
                )
            )
        # Avoid a key with an actual missing value in station[i]'s meta SeisDict
        stations[i].meta.enddate = n.endtime
    end
    stations
end

function parse_stations(T, request, fdsn_stations::AbstractArray{FDSNStationTextResponse},
        server)
    stations = similar(Vector{T}, axes(fdsn_stations))
    for (i, s) in enumerate(fdsn_stations)
        stations[i] = T(;
            net=s.network,
            sta=s.station,
            lon=s.longitude,
            lat=s.latitude,
            elev=s.elevation,
            meta=Dict{Symbol,Any}(
                :sitename=>s.sitename,
                :startdate=>s.starttime,
                :server=>server
                )
             )
        # Avoid a key with an actual missing value in station[i]'s meta SeisDict
        stations[i].meta.enddate = s.endtime
    end
    stations
end

function parse_stations(T, request, fdsn_channels::AbstractArray{FDSNChannelTextResponse},
        server)
    stations = similar(Vector{T}, axes(fdsn_channels))
    for (i, c) in enumerate(fdsn_channels)
        stations[i] = T(;
            net=c.network,
            sta=c.station,
            loc=c.location,
            cha=c.channel,
            lon=c.longitude,
            lat=c.latitude,
            elev=c.elevation,
            dep=c.depth/1000,
            azi=c.azimuth,
            inc=c.dip+90,
            meta=Dict{Symbol,Any}(
                :sensor_description=>c.sensor_description,
                :scale=>c.scale,
                :scale_frequency=>c.scale_frequency,
                :scale_units=>c.scale_units,
                :sample_rate=>c.sample_rate,
                :startdate=>c.starttime,
                :server=>server
                )
            )
        # Avoid a key with an actual missing value in station[i]'s meta SeisDict
        stations[i].meta.enddate = c.endtime
    end
    stations
end

"""
    parse_stations(T, request, stationxml::FDSNStationXML, server)

Create stations from an FDSNStationXML object.

Several fields in each station's `.meta` field are filled, including
the `stationxml` field which contains a full `FDSNStationXML` object
for that network/channel/station (depending on the request `level`), but
only for the network/station/channel in question.

This method is usually called by [`SeisRequests.parse_station_response`](@ref).
"""
function parse_stations(T, request, stationxml::FDSNStationXML, server)
    stations = T[]
    for network in stationxml.network
        if request.level !== missing && request.level == "network"
            net = T(net=network.code)
            net.meta.startdate = network.start_date
            net.meta.enddate = network.end_date
            net.meta.stationxml = filter_stationxml(stationxml, network)
            net.meta.server = server
            net.meta.request = request
            push!(stations, net)
            continue
        end

        for station in network.station
            if request.level === missing || request.level == "station"
                sta = T(net=network.code, sta=station.code,
                    lon=station.longitude, lat=station.latitude,
                    elev=station.elevation)
                sta.meta.startdate = station.start_date
                sta.meta.enddate = station.end_date
                sta.meta.stationxml = filter_stationxml(stationxml, network, station)
                sta.meta.server = server
                sta.meta.request = request
                push!(stations, sta)
                continue
            end

            for channel in station.channel
                # Fill in information which may need adjusting first
                cha = T(net=network.code, sta=station.code,
                    loc=channel.location_code, cha=channel.code,
                    lon=channel.longitude, lat=channel.latitude,
                    elev=channel.elevation, dep=channel.depth,
                    azi=channel.azimuth, inc=channel.dip)
                # Then adjust information by converting to correct units, etc.
                cha.dep = cha.dep/1000
                cha.inc = cha.inc + 90
                cha.meta.startdate = channel.start_date
                cha.meta.enddate = channel.end_date
                cha.meta.stationxml = filter_stationxml(stationxml, network, station, channel)
                cha.meta.server = server
                cha.meta.request = request
                push!(stations, cha)
            end
        end
    end
    stations
end

"""
    filter_stationxml(sxml, network, station=nothing, channel=nothing) -> ::FDSNStationXML

Take a `FDSNStationXML` document and filter out all networks, stations
and channels apart from `network`, `station` and `channel`.
The returned copy only contains one network if the request level is `"network"`,
and maybe one station in that network if the request level is `"station"`,
and maybe one channel at that station if the request level is `"channel"`.
"""
function filter_stationxml(sxml, network, station=nothing, channel=nothing)
    filtered_sxml = deepcopy(sxml)
    empty!(filtered_sxml.network)
    push!(filtered_sxml.network, deepcopy(network))
    empty!(filtered_sxml.network[1].station)
    if station !== nothing
        push!(filtered_sxml.network[1].station, deepcopy(station))
        empty!(filtered_sxml.network[1].station[1].channel)
        if channel !== nothing
            push!(filtered_sxml.network[1].station[1].channel, channel)
        end
    end
    filtered_sxml
end

#
# get_data
#

"""
    get_data(; query_type=FDSNDataSelect, server=$(DEFAULT_SERVER), verbose=true, T=Float64, kwargs...)

Get time series data from `server`.

If `verbose` is `true` (the default), information is printed to the screen on
the success or otherwise of the request.

`T` specifies the float type of the seismic data returned and defaults to `Float64`.

In this form, a data request is created by passing `kwargs` to `query_type`,
by default creating a [`FDSNDataSelect`](@ref) request.

# Keyword arguments
- `query_type = FDSNDataSelect`: Type of request to send.
- `server = $(DEFAULT_SERVER)`: Server name or URI to which to send the request.
- `verbose = true`: If `true`, print information about a query's progress to
  the terminal.
- `T = Float64`: Specify the float type to use for the data returned.
- `kwargs...`: Remaining keyword arguments, other than the above, are passed
  to `query_type` (i.e., by default to [`FDSNDataSelect`](@ref)) to set the
  search parameters for data.

# Examples
Get 10 minutes of data for the high-gain vertical channels at station JSA
(Jersey, Channel Islands) from the beginning of the year 2020.
This sends the request to `"$DEFAULT_SERVER"` by default.
```
julia> get_data(network="GB", station="JSA", location="", channel="?HZ", starttime="2020-01-01", endtime="2020-01-01T00:10:00")
[ Info: Request status: Successful request, results follow
3-element Array{Trace{Float64,Array{Float64,1},Seis.Geographic{Float64}},1}:
 Seis.Trace(GB.JSA..BHZ: delta=0.02, b=0.0, nsamples=29737)
 Seis.Trace(GB.JSA..BHZ: delta=0.02, b=595.6801, nsamples=216)
 Seis.Trace(GB.JSA..HHZ: delta=0.01, b=0.0, nsamples=60000)
```

Get the same data but from the Orfeus server.
```
julia> using Dates

julia> start = DateTime(2020)
2020-01-01T00:00:00

julia> get_data(server="Orfeus", T=Float32, network="GB", station="JSA", location="", channel="?HZ", starttime=start, endtime=start+Minute(10))
1-element Array{Trace{Float32,Array{Float32,1},Seis.Geographic{Float32}},1}:
 Seis.Trace(GB.JSA..HHZ: delta=0.01, b=0.0, nsamples=60921)
```
"""
function get_data(; query_type=FDSNDataSelect, server=DEFAULT_SERVER, verbose=true, T=Float64, kwargs...)
    request = query_type(; kwargs...)
    post_data_request_and_parse_response(T, [request], server, verbose)
end

"""
    get_data(stations, starttime, endtime; kwargs...)

Query for data defined at a set of `Station`s `stations`.

In this form, the values for `network`, `station`, `location` and `channel`
are taken from each station in `stations`.  Keyword arguments are as for
the zero-argument method.
"""
function get_data(stations::AbstractArray{<:Seis.Station}, starttime, endtime;
        query_type=FDSNDataSelect, server=DEFAULT_SERVER, verbose=true,
        T=Float64, kwargs...)
    requests = [query_type(; (network=sta.net,
                              station=sta.sta,
                              location=sta.loc,
                              channel=sta.cha,
                              starttime=starttime,
                              endtime=endtime,
                              kwargs...)...)
                for sta in stations]
    post_data_request_and_parse_response(T, requests, server, verbose; stations=stations)
end

"""
    get_data(event, stations, start_offset, end_offset; kwargs...)

Get time series data at `stations` relative to `event`.

`event` is an `Event` whose origin time defines the time window to request.
The window is defined as `event.time + start_offset` to `event.time + end_offset`.
`start_offset` and `end_offset` can be given in real numbers of seconds, or
as a `Dates.Period`.

`stations` is a set of `Station`s whose channel codes determine which data
to request.

The returned `Trace`s have their `.sta` field set to the appropriate element
of `stations` and their `.evt` field is `event.

This method is particularly useful because Miniseed data (returned by default
from datacentres) does not contain any station metadata such as coordinates.

Keyword arguments are as for the no-argument method of `get_data`.

# Examples
Get a minute of data from stations HYB and SCZ in the G network, for the
high-gain broadand vertical channel only, at location `""`.
```
julia> stations = get_stations(code="G.HYB,SCZ..BHZ", verbose=false)
2-element Array{Station{Float64,Seis.Geographic{Float64}},1}:
 Station: G.HYB..BHZ, lon: 78.553, lat: 17.417, dep: 0.0, elev: 510.0, azi: 0.0, inc: 0.0, meta: 4 keys
 Station: G.SCZ..BHZ, lon: -121.403, lat: 36.598, dep: 0.0, elev: 261.0, azi: 0.0, inc: 0.0, meta: 5 keys

julia> traces = get_data(stations, DateTime(2001), DateTime(2001) + Minute(1))
[ Info: Request status: Successful request, results follow
2-element Array{Trace{Float64,Array{Float64,1},Seis.Geographic{Float64}},1}:
 Seis.Trace(G.HYB..BHZ: delta=0.05, b=0.0, nsamples=1200)
 Seis.Trace(G.SCZ..BHZ: delta=0.05, b=0.0, nsamples=1200)

julia> all(traces.sta .== stations)
true

julia> traces.sta.lon, traces.sta.lat
([78.553, -121.403], [17.417, 36.598])
```
"""
function get_data(event::Seis.Event, stations::AbstractArray{<:Seis.GeogStation},
        start_offset::_Period, end_offset::_Period;
        query_type=FDSNDataSelect, server=DEFAULT_SERVER, verbose=true,
        T=Float64, kwargs...)
    requests = [query_type(; (network=sta.net,
                              station=sta.sta,
                              location=sta.loc,
                              channel=sta.cha,
                              starttime=event.time + start_offset,
                              endtime=event.time + end_offset,
                              kwargs...)...)
                for sta in stations]
    post_data_request_and_parse_response(T, requests, server, verbose, event=event,
        stations=stations)
end

function get_data(event, stations, start_offset::Real, end_offset::Real; kwargs...)
    get_data(event, stations, seconds_milliseconds(start_offset),
        seconds_milliseconds(end_offset); kwargs...)
end

"""
    get_data(event, stations, start_phase, start_offset, end_phase, end_offset; kwargs...)
    get_data(event, stations, phase, start_offset, end_offset; kwargs...)

Define the data window requested by reference to a predicted seismic phase
arrival.

In the first form, specify `start_phase` and `start_offset`, and `end_phase`
and `end_offset`.  The start of the data window is the event origin time,
plus the predicted travel time for `start_phase`, plus `start_offset`.
The end time limit is defined similarly.

In the second form, both window start and end are relative to a single `phase`.

# Keyword arguments
In addition to the keyword arguments accepted for all `get_data` methods,
the following can be used with this method:

- `exact = false`: If `true`, only use phase names which are an exact match
  for `phase`, `start_phase` and `end_phase`.
- `model = "iasp91"`: Choose which model to use for travel time calculations.
  Available models are currently: `("1066a", "1066b", "ak135", "ak135f_no_mud",
  "herrin", "iasp91", "jb", "prem", "pwdk", "sp6")`

# Notes
!!! note
    To use this form of `get_data`, you must first have installed the
    [SeisTau.jl](https://github.com/anowacki/SeisTau.jl) package, and
    then done `using SeisTau` or `import SeisTau` in your session.

!!! note
    If calling this form of `get_data` from another module in which you
    have loaded `SeisTau`, pass the `SeisTau` module object to this
    method's `seistau` keyword argument, like so:
    ```
    module MyModule
    using SeisTau
    using SeisRequests

    function process(event, stations, phase, t0, t1)
        data = get_data(event, stations, phase, t0, t1; seistau=SeisTau)
        ...
    end
    end # module
    ```
"""
function get_data(event, stations, start_phase, start_offset::_Period, end_phase, end_offset::_Period;
        server=DEFAULT_SERVER, verbose=true, T=Float64,
        query_type=FDSNDataSelect,
        # SeisTau options
        seistau=nothing, exact=false, model="iasp91",
        # Query options
        kwargs...)
    # FIXME: Horrible hack to permit the use of SeisTau without actually
    #        depending on it.
    # seistau is the module SeisTau
    if seistau === nothing
        !isdefined(Main, :SeisTau) &&
            error("Using phase arrival times requires loading SeisTau.  " *
                  "Do `using SeisTau` or `import SeisTau` and try again.")
        seistau = getfield(Main, :SeisTau)
    end
    requests = query_type[]
    for sta in stations
        start_arrivals = seistau.travel_time(event, sta, start_phase; exact=exact, model=model)
        isempty(start_arrivals) &&
            throw(ArgumentError("no arrivals for start phase \"$start_phase\""))
        end_arrivals = start_phase == end_phase ? start_arrivals :
            seistau.travel_time(event, sta, end_phase; exact=exact, model=model)
        isempty(end_arrivals) &&
            throw(ArgumentError("no arrivals for end phase \"$end_phase\""))
        starttime = event.time + seconds_milliseconds(first(start_arrivals).time) +
            start_offset
        endtime = event.time + seconds_milliseconds(first(end_arrivals).time) +
            end_offset
        request = query_type(; (network=sta.net, station=sta.sta, location=sta.loc,
                    channel=sta.cha, starttime=starttime, endtime=endtime, kwargs...)...)
        push!(requests, request)
    end
    traces = post_data_request_and_parse_response(T, requests, server, verbose; event=event,
        stations=stations)
    traces
end

# Accept Real arguments and convert to DateTimes
get_data(event, stations, start_phase, start_offset::Real, end_phase, end_offset::Real; kwargs...) =
    get_data(event, stations, start_phase, seconds_milliseconds(start_offset),
        end_phase, seconds_milliseconds(end_offset); kwargs...)

# Use the same phase for start and end window time
get_data(event, stations, phase, start_offset, end_offset; kwargs...) =
    get_data(event, stations, phase, start_offset, phase, end_offset; kwargs...)

"""
    parse_data_response(T, requests, response, server; event=nothing, stations=nothing)

Convert the `response` from a data `server`, from a `request`, into
`Trace`s.  In this form, the response is from a single event recorded
at multiple stations.

If `event` is given, then assume that all traces should have this
event as their origin and shift their origin times accordingly.

If `stations` (an array of `Seis.Station`s) is given, then assume that these
stations were requested in `request`
"""
function parse_data_response(T, requests::AbstractArray{<:SeisRequest},
        response, server;
        event=nothing, stations=nothing)
    if response.status == first(requests).nodata
        isempty(response.body) || @warn("unexpected data in response reporting no data")
        return Seis.Trace{T, Vector{T}, Seis.Geographic{T}}[]
    elseif isempty(response.body)
        error("empty response but server did not indicate no data")
    end
    format = first(requests).format
    if format === missing || format == "miniseed"
        _check_content_type(response, "application/vnd.fdsn.mseed")
        traces = Seis.read_mseed(response.body,
            Seis.Trace{T, Vector{T}, Seis.Geographic{T}})
    else
        error("format \"$(format)\" is currently unsupported")
    end
    traces.meta.server = server
    if event !== nothing
        Seis.origin_time!.(traces, event.time)
        traces.evt = event
    end
    if stations !== nothing
        for station in stations
            code = Seis.channel_code(station)
            inds = findall(x -> Seis.channel_code(x) == code, traces)
            for i in inds
                new_meta = merge!(traces[i].sta.meta, station.meta)
                traces[i].sta = station
                traces[i].sta.meta = new_meta
            end
        end

    end
    traces
end

parse_data_response(T, request::SeisRequest, response, server; kwargs...) =
    parse_data_response(T, [request], response, server; kwargs...)

"""
    post_data_request_and_parse_response(T, requests, server, verbose; event=nothing, stations=nothing) -> traces

Send the vector of `SeisRequest`s `requests` to `server` via the HTTP POST method.
If `verbose` is `true`, then print information about the success of the request.

Optionally pass information about an `event` and a set of `stations` (e.g.,
from a previous call to [`get_event`](@ref) or [`get_stations`](@ref)) to fill
in the `traces`' information with this additional data.
"""
function post_data_request_and_parse_response(T, requests::AbstractArray{<:SeisRequest},
        server, verbose; event=nothing, stations=nothing)
    response = post_request(requests; server=server, verbose=verbose)
    traces = parse_data_response(T, requests, response, server, event=event,
        stations=stations)
    traces
end

#
# get_events
#

"""
    get_events(; server=$(DEFAULT_SERVER), verbose=true, T=Float64, kwargs...) -> events

Query `server` for events matching those specified in `kwargs`.
`events` is a `Vector{Seis.GeogEvent{T}}`, where various useful
fields are added to the `.meta` field of each event.

For search options, see [`FDSNEvent`](@ref).

The element type of the `Seis.Event`s returned is set by `T`.
"""
function get_events(; server=DEFAULT_SERVER, verbose=true, T=Float64, kwargs...)
    request = FDSNEvent(; kwargs...)
    response = get_request(request; server=server, verbose=verbose)
    events = parse_event_response(T, request, response, server)
end

"""
    get_events(station; longitude=station.lon, latitude=station.lat, 
        starttime=station.meta.startdate, endtime=station.meta.enddate, kwargs...)

Search for events in relation to a `station`, typically constraining the
event locations to be a certain distance from `event`, or requiring events
to occur when the station was active.

Other keyword arguments `kwargs` are passed to the zero-argument method above.

# Example
Find all events between 90° and 120° from station TA.112A, of mangitude 6 and
above, greater than 100 km deep, which occurred whilst the station was active:
```
julia> sta = first(get_stations(network="TA", station="112A"));

julia> get_events(sta, minradius=90, maxradius=120, mindepth=100, minmagnitude=6)
[ Info: Request status: Successful request, results follow
5-element Array{Seis.Event{Float64,Seis.Geographic{Float64}},1}:
 Event: lon: 130.3051, lat: -5.9259, dep: 188.5, time: 2008-08-04T20:45:15.82, id: smi:service.iris.edu/fdsnws/event/1/query?originid=4672548, meta: 7 keys
 Event: lon: 127.8966, lat: -7.5592, dep: 121.7, time: 2008-06-06T13:42:49.06, id: smi:service.iris.edu/fdsnws/event/1/query?originid=4620129, meta: 7 keys
 Event: lon: -28.0966, lat: -56.0769, dep: 112.3, time: 2008-04-14T09:45:16.97, id: smi:service.iris.edu/fdsnws/event/1/query?originid=4577607, meta: 7 keys
 Event: lon: 127.5146, lat: -7.6192, dep: 181.0, time: 2007-12-15T08:03:16.44, id: smi:service.iris.edu/fdsnws/event/1/query?originid=4494689, meta: 7 keys
 Event: lon: 151.8587, lat: -4.5977, dep: 134.3, time: 2007-05-29T01:03:28.32, id: smi:service.iris.edu/fdsnws/event/1/query?originid=4359323, meta: 7 keys
```
"""
get_events(station::Seis.GeogStation; kwargs...) =
    get_events(; (longitude=station.lon, latitude=station.lat, 
        starttime=station.meta.startdate, endtime=station.meta.enddate, kwargs...)...)

"""
    parse_event_response(T, request, response, server) -> events

Parse the output of a `get_request` or `post_request` call and return a
set of `events` containing the results.

`request` is a `FDSNEvent` request, `response` is a `HTTP.Response` with
the server's response to the request, and `server` specifies which server
the request was sent to.
"""
function parse_event_response(T::DataType, request::FDSNEvent, response, server)
    event_type = GeogEvent{T}
    # No results
    if response.status == request.nodata
        isempty(response.body) || @warn("unexpected data in response reporting no data")
        return event_type[]
    elseif isempty(response.body)
        error("empty response but server did not indicate no data")
    end
    # Parse as string
    str = String(response.body)
    # If have requested text format, then parse that internally
    if coalesce(request.format, "") == "text"
        _check_content_type(response, "text/plain")
        fdsn_events = [convert(FDSNEventTextResponse, line)
                       for line in split(str, '\n') if !occursin(r"^(\s*#.*|\s*)$", line)]
        events = parse_events(event_type, request, fdsn_events, server)
    # ISF format from the ISC
    elseif coalesce(request.format, "") == "isf"
        error("parsing of ISF responses not yet implements")
    # Otherwise in QuakeML format (XML)
    else
        _check_content_type(response, "application/xml")
        quakeml = QuakeML.readstring(str)
        events = parse_events(event_type, request, quakeml, server)
    end
    events
end

parse_event_response(request, response, server) =
    parse_event_response(Float64, request, response, server)

"""
    parse_events(T, request, fdsn_events) -> events

Convert a set of `fdsn_events` which have been parsed from a text-format
`FDSNEvent` request into a `Vector` of `Seis.Event`s.

`T` is the specific type of `Seis.Event` (e.g.,
`Seis.Event{Float32, Seis.Geographic{Float32}}`)
"""
function parse_events(T, request, fdsn_events::AbstractArray{FDSNEventTextResponse}, server)
    n = length(fdsn_events)
    events = Vector{T}(undef, n)
    for (i, e) in enumerate(fdsn_events)
        events[i] = T(;
            id=e.event_id,
            time=e.time,
            lon=e.longitude,
            lat=e.latitude,
            dep=e.depth,
            meta=Dict{Symbol,Any}(
                :author=>e.author,
                :catalog=>e.catalog,
                :contributor=>e.contributor,
                :contributor_id=>e.contributor_id,
                :mag_type=>e.mag_type,
                :mag=>e.magnitude,
                :mag_author=>e.mag_author,
                :location_name=>e.event_location_name,
                :server=>server
                )
            )
            # Possibly missing fields
            meta = events[i].meta
            meta.type = e.event_type
    end
    events
end

"""
    parse_events(T, request, quakeml_events, server) -> events

Convert a `QuakeML.EventParameters` object into a set of `T`s, where
`T <: Seis.GeogEvent`.
"""
function parse_events(T, request, quakeml_events::QuakeML.EventParameters, server)
    n = length(quakeml_events.event)
    events = Vector{T}(undef, n)
    for (i, event) in enumerate(quakeml_events.event)
        if !QuakeML.has_origin(event)
            @warn("No origin associated with event $(event.public_id)")
            events[i] = T()
        else
            origin = QuakeML.preferred_origin(event)
            events[i] = T(;
                id=origin.public_id.value,
                time=origin.time.value,
                lon=origin.longitude.value,
                lat=origin.latitude.value,
                dep=_getifnotmissing(origin.depth, :value)/1000
                )
            meta = events[i].meta
            meta.author = _getifnotmissing(origin.creation_info, :author)
            meta.catalog = request.catalog
            meta.type = _getifnotmissing(event.type, :value)
            meta.origin_type = _getifnotmissing(origin.type, :value)
            meta.server = server
            meta.quakeml = event
            if QuakeML.has_focal_mechanism(event)
                focal_mechanism = QuakeML.preferred_focal_mechanism(event)
                meta.focal_mechanism = focal_mechanism
            end
            if QuakeML.has_magnitude(event)
                magnitude = QuakeML.preferred_magnitude(event)
                meta.mag = magnitude.mag.value
                meta.mag_type = magnitude.type
                if magnitude.creation_info !== missing
                    meta.mag_author = magnitude.creation_info.author
                end
            end
            if !isempty(event.description)
                desc = event.description[1]
                meta.description = desc.text *
                    (desc.type === missing ? "" : " ("*desc.type.value*")")
            end
        end
    end
    events
end

"Return `missing` if `val.field` is `missing`, and its value otherwise."
_getifnotmissing(val, field) = val === missing ? missing : getfield(val, field)

"""
    _check_content_type(response, expected; allowempty=true) -> nothing

Log a warning if the `"Content-Type"` header of `response` is not `expected`.

If `allowempty` is `true` (the default) then empty messages do
not throw.
"""
function _check_content_type(response, expected; allowempty=true)
    content_type = HTTP.Messages.header(response, "Content-Type")
    allowempty && isempty(content_type) && return
    content_type != expected &&
        @warn("content type of response is \"$content_type\", " *
              "not \"$expected\" as expected")
    return
end
