"""
    FDSNRequest

An abstract type representing requests conforming to the FDSN Web Services specification.

Current subtypes of `FDSNRequest`:
- [`FDSNDataSelect`](@ref)
- [`FDSNEvent`](@ref)
- [`FDSNStation`](@ref)
"""
abstract type FDSNRequest <: SeisRequest end

protocol_string(::FDSNRequest) = "fdsnws"

Base.broadcastable(request::FDSNRequest) = Ref(request)

"""
    FDSNEvent(kwargs...)

Create a FDSN web services event query which can be sent to a datacentre which implements
the FDSN Web Services specification.

## Examples
A request asking for events above magnitude 3 within 5° distance of the
Eiffel Tower in the last five years:
```
julia> using Dates

julia> FDSNEvent(starttime=now()-Year(5), longitude=2.295, latitude=48.858, maxradius=5, minmagnitude=3)
```

## Available options

|Parameter|Description|
|:--------|:----------|
|`starttime`|Limit to events on or after the specified start time.|
|`endtime`|Limit to events on or before the specified end time.|
|`minlatitude`|Limit to events with a latitude larger than or equal to the specified minimum.|
|`maxlatitude`|Limit to events with a latitude smaller than or equal to the specified maximum.|
|`minlongitude`|Limit to events with a longitude larger than or equal to the specified minimum.|
|`maxlongitude`|Limit to events with a longitude smaller than or equal to the specified maximum.|
|`latitude`|Specify the latitude to be used for a radius search.|
|`longitude`|Specify the longitude to the used for a radius search.|
|`minradius`|Limit to events within the specified minimum number of degrees from the geographi point defined by the latitude and longitude parameters.|
|`maxradius`|Limit to events within the specified maximum number of degrees from the geographic point defined by the latitude and longitude parameters.|
|`mindepth`|Limit to events with depth more than the specified minimum.|
|`maxdepth`|Limit to events with depth less than the specified maximum.|
|`minmagnitude`|Limit to events with a magnitude larger than the specified minimum.|
|`maxmagnitude`|Limit to events with a magnitude smaller than the specified maximum.|
|`magnitudetype`|Specify a magnitude type to use for testing the minimum and maximum limits.|
|`includeallorigins`|Specify if all origins for the event should be included, default is data center dependent but is suggested to be the preferred origin only.|
|`includeallmagnitudes`|Specify if all magnitudes for the event should be included, default is data center dependent but is suggested to be the preferred magnitude only.|
|`includearrivals`|Specify if phase arrivals should be included.|
|`eventid`|Select a specific event by ID; event identifiers are data center specific.|
|`limit`|Limit the results to the specified number of events.|
|`offset`|Return results starting at the event count specified, starting at 1.|
|`orderby`|Order the result by time or magnitude with the following possibilities: `"time"`: order by origin descending time; `"time-asc"`: order by origin ascending time; `"magnitude"`: order by descending magnitude; `"magnitude-asc"`: order by ascending magnitude|
|`catalog`|Limit to events from a specified catalog|
|`contributor`|Limit to events contributed by a specified contributor.|
|`updatedafter`|Limit to events updated after the specified time.|
|`format`|Specify format of result, either `"xml"` (default) or `"text"` (`"isf"` from the ISC).  If this parameter is not specified the service must return QuakeML.|
|`nodata`|Select status code for “no data”, either `204` (default) or `404`.|

## Specifying dates
Both `Dates.DateTime` objects and `String`s can be passed as values to the
`starttime`, `endtime` and `updatedafter` keywords so long as they are valid.
Examples include `"2000-01-01"` and `"2008-02-03T00:00:30"`.
"""
@with_kw struct FDSNEvent <: FDSNRequest
    starttime::MDateTime = missing
    endtime::MDateTime = missing
    minlatitude::MFloat = missing
    maxlatitude::MFloat = missing
    minlongitude::MFloat = missing
    maxlongitude::MFloat = missing
    latitude::MFloat = missing
    longitude::MFloat = missing
    minradius::MFloat = missing
    maxradius::MFloat = missing
    mindepth::MFloat = missing
    maxdepth::MFloat = missing
    minmagnitude::MFloat = missing
    maxmagnitude::MFloat = missing
    magnitudetype::MString = missing
    includeallorigins::MBool = missing
    includeallmagnitudes::MBool = missing
    includearrivals::MBool = missing
    eventid::MString = missing
    limit::MInt = missing
    offset::MInt = missing
    orderby::MString = missing
    catalog::MString = missing
    contributor::MString = missing
    updatedafter::MDateTime = missing
    format::MString = missing
    nodata::Int = 204
    function FDSNEvent(st, et, minlat, maxlat, minlon, maxlon, lat, lon, minr, maxr, mind, maxd,
                       minmag, maxmag, magtype, allorigins, allmags, arrs, id, limit, offset,
                       orderby, catalog, contributor, updatedafter, format, nodata)
        !ismissing(st) && (st = DateTime(st))
        !ismissing(et) && (et = DateTime(et))
        !ismissing(updatedafter) && (updatedafter = DateTime(updatedafter))
        !ismissing(st) && !ismissing(et) && st > et &&
           throw(ArgumentError("`starttime` must be before endtime"))
        (!ismissing(minr) || !ismissing(maxr)) && (ismissing(lat) || ismissing(lon)) &&
            throw(ArgumentError("Both `latitude` and `longitude` must be present if " *
                                "specifying `minradius` or `maxradius`"))
        coalesce(limit, 1) > 0 || throw(ArgumentError("`limit` cannot be less than 1"))
        coalesce(offset, 1) > 0 || throw(ArgumentError("`offset` cannot be less than 1"))
        !ismissing(orderby) && orderby ∉ ("time", "time-asc", "magnitude", "magnitude-asc")
        -90 ≤ coalesce(minlat, -90) ≤ 90 || throw(ArgumentError("`minlatitude` must be in range -90 to 90"))
        -90 ≤ coalesce(maxlat, 90) ≤ 90 || throw(ArgumentError("`maxlatitude` must be in range -90 to 90"))
        -180 ≤ coalesce(minlon, -180) ≤ 180 || throw(ArgumentError("`minlongitude` must be in range -180 to 180"))
        -180 ≤ coalesce(maxlon, 180) ≤ 180 || throw(ArgumentError("`maxlongitude` must be in range -180 to 180"))
        -90 ≤ coalesce(lat, 0) ≤ 90 || throw(ArgumentError("`latitude` must be in range -90 to 90"))
        -180 ≤ coalesce(lon, 0) ≤ 180 || throw(ArgumentError("`longitude` must be in range -180 to 180"))
        0 ≤ coalesce(minr, 0) ≤ 180 || throw(ArgumentError("`minradius` must be in range 0 to 180"))
        0 ≤ coalesce(maxr, 180) ≤ 180 || throw(ArgumentError("`maxradius` must be in range 0 to 180"))
        coalesce(format, "xml") ∈ ("xml", "isf", "miniseed", "text") ||
            throw(ArgumentError("`format` must be one of \"xml\", \"isf\" \"miniseed\" or \"text\""))
        nodata ∈ (204, 404) || throw(ArgumentError("`nodata` must be 204 or 404"))
        new(st, et, minlat, maxlat, minlon, maxlon, lat, lon, minr, maxr, mind, maxd,
            minmag, maxmag, magtype, allorigins, allmags, arrs, id, limit, offset,
            orderby, catalog, contributor, updatedafter, format, nodata)
    end
end

"""
    FDSNDataSelect(kwargs...)

Create a FDSN web services data selection query which can be sent to a datacentre which
implements the FDSN Web Services specification.

Set options with keyword arguments.

## Example
Request for data in miniseed format (the default) for station A07E in network XM
for all channels on the first day of 2013.
```
julia> using Dates

julia> FDSNDataSelect(network="XM", station="A07E", starttime=DateTime(2013), endtime=DateTime(2013)+Day(1))

## Available options

|Parameter|Description|
|:--------|:----------|
|`starttime`|Limit results to time series samples on or after the specified start time.|
|`endtime`|Limit results to time series samples on or before the specified end time.|
|`network`|Select one or more network codes.  Can be SEED network codes or data center defined codes.  Multiple codes are comma-separated.|
|`station`|Select one or more SEED station codes.  Multiple codes are comma-separated.|
|`location`|Select one or more SEED location identifiers.  Multiple identifiers are comma-separated.  As a special case “--“ (two dashes) will be translated to a string of two space characters to match blank location IDs.|
|`channel`|Select one or more SEED channel codes.  Multiple codes are comma-separated.|
|`code`|SEED-style code, used instead of `network`, `station`, `location` and `channel`.  (Addition to standard in this package.)|
|`quality`|Select a specific SEED quality indicator, handling is data center dependent.|
|`minimumlength`|Limit results to continuous data segments of a minimum length specified in seconds.|
|`longestonly`|Limit results to the longest continuous segment per channel.|
|`format`|Specify format of result, the default value is `"miniseed"`.|
|`nodata`|Select status code for “no data”, either ‘204’ (default) or ‘404’.|

## Specifying dates
Both `Dates.DateTime` objects and `String`s can be passed as values to the
`starttime` and `endtime` keywords so long as they are valid.
Examples include `"2000-01-01"` and `"2008-02-03T00:00:30"`.

## Specifying station channel codes
As well as the options specified by the FDSN standard, the additional option
`code` is provided for ease of use.  This accepts channel codes in the SEED
convention `"⟨network⟩.⟨station⟩.⟨channel⟩.⟨location⟩"`, where each `.`-separated
field can contain wildcards and `,`-separated lists of codes.
"""
struct FDSNDataSelect <: FDSNRequest
    starttime::MDateTime
    endtime::MDateTime
    network::MString
    station::MString
    location::MString
    channel::MString
    quality::MString
    minimumlength::MFloat
    longestonly::MBool
    format::MString
    nodata::Int
    function FDSNDataSelect(st, et, net, sta, loc, cha, q, minlength, longestonly, format, nodata)
        !ismissing(st) && (st = DateTime(st))
        !ismissing(et) && (et = DateTime(et))
        !ismissing(st) && !ismissing(et) && st > et &&
            throw(ArgumentError("`starttime` must be before endtime"))
        !ismissing(net) && !isascii(net) && throw(ArgumentError("`network` must be ASCII"))
        !ismissing(sta) && !isascii(sta) && throw(ArgumentError("`station` must be ASCII"))
        if !ismissing(loc)
            !isascii(loc) && throw(ArgumentError("`location` must be ASCII"))
            loc == "  " && (loc = "--")
        end
        !ismissing(cha) && !isascii(cha) && throw(ArgumentError("`channel` must be ASCII"))
        coalesce(q, "B") ∈ ("D", "R", "Q", "M", "B") ||
            throw(ArgumentError("`quality` must be one of \"D\", \"R\", \"Q\", \"M\" or \"B\""))
        coalesce(minlength, 0) >= 0 || throw(ArgumentError("`minimumlength` must be 0 or more"))
        nodata ∈ (204, 404) || throw(ArgumentError("`nodata` must be 204 or 404"))
        new(st, et, net, sta, loc, cha, q, minlength, longestonly, format, nodata)
    end
end

function FDSNDataSelect(; code=missing, starttime=missing, endtime=missing,
        network=missing, station=missing, location=missing, channel=missing,
        quality=missing, minimumlength=missing, longestonly=missing, format=missing,
        nodata=204)
    if !ismissing(code)
        any(!ismissing, (network, station, location, channel)) &&
            throw(ArgumentError("`code` cannot be provided with any of " *
                                "`network`, `station`, `location`, or `channel`"))
        network, station, location, channel = split_channel_code(code)
    end
    FDSNDataSelect(starttime, endtime, network, station, location, channel, quality,
        minimumlength, longestonly, format, nodata)
end

"""
    FDSNStation(kwargs...)

Create a FDSN web services station query which can be sent to a datacentre which implements
the FDSN Web Services specification.

## Example

Information about all stations called `"ANMO"`, in all networks, at the
default `"station"` level.
```
julia> FDSNStation(station="ANMO")
```

Information about the channels, including sensor response information,
for the broadband, high-sensitivity channels of station JSA in Jersey,
Channel Islands
```
julia> FDSNStation(network="GB", station="JSA", channel="BH?", level="response")
```

Every station known by the datacentre.  Here we use the `format="text"` option
to get only the basic information on where stations are.  (Note that as of
2020, sending this to the default datacentre, IRIS, returns 50,000 stations.
Amazingly, the entire thing takes only a few seconds.)
```
julia> FDSNStation(format="text")
```

Use the `code` option to find all very long period channels in the
Global Seismograph Network active since 2018.
```
julia> using Dates

julia> FDSNStation(code="II,IU.*.*.V??", starttime=DateTime(2018))
```

## Default information level

`FDSNStation` requests by default are returned with detail on the level of
individual stations.  (See table below.)  However, if the `channel` keyword
is specified, then it is assumed that information on the channel level is
desired and the `level` option is set to `"channel"` upon construction.
Set `level` manually to override this default.

## Available options

|Parameter|Description|
|:--------|:----------|
|`starttime`|Limit to metadata epochs starting on or after the specified start time.|
|`endtime`|Limit to metadata epochs ending on or before the specified end time.|
|`startbefore`|Limit to metadata epochs starting before specified time.|
|`startafter`|Limit to metadata epochs starting after specified time.|
|`endbefore`|Limit to metadata epochs ending before specified time.|
|`endafter`|Limit to metadata epochs ending after specified time.|
|`network`|Select one or more network codes.  Can be SEED network codes or data center defined codes.  Multiple codes are comma-separated.|
|`station`|Select one or more SEED station codes.  Multiple codes are comma-separated.|
|`location`|Select one or more SEED location identifiers.  Multiple identifiers are comma-separated.  As a special case “--“ (two dashes) will be translated to a string of two space characters to match blank location IDs.|
|`channel`|Select one or more SEED channel codes.  Multiple codes are comma-separated.|
|`code`|SEED-style code, used instead of `network`, `station`, `location` and `channel`.  (Addition to standard in this package.)|
|`minlatitude`|Limit to stations with a latitude larger than or equal to the specified minimum.|
|`maxlatitude`|Limit to stations with a latitude smaller than or equal to the specified maximum.|
|`minlongitude`|Limit to stations with a longitude larger than or equal to the specified minimum.|
|`maxlongitude`|Limit to stations with a longitude smaller than or equal to the specified maximum.|
|`latitude`|Specify the latitude to be used for a radius search.|
|`longitude`|Specify the longitude to the used for a radius search.|
|`minradius`|Limit results to stations within the specified minimum number of degrees from the geographic point defined by the latitude and longitude parameters.|
|`maxradius`|Limit results to stations within the specified maximum number of degrees from the geographic point defined by the latitude and longitude parameters.|
|`level`|Specify the level of detail for the results, one of `"network`, `"station"` (default), `"channel"` or `"response"`.  If `channel` option is supplied, then `"channel"` is the default.|
|`includerestricted`|Specify if results should include information for restricted stations.|
|`includeavailability`|Specify if results should include information about time series data availability.|
|`updatedafter`|Limit to metadata updated after specified time; updates are data center specific.|
|`matchtimeseries`|Limit to metadata where selection criteria matches time series data availability.|
|`format`|Specify format of result, either `"xml"` (default) or `"text"`.|
|`nodata`|Select status code for “no data”, either `204` (default) or `404`.|

## Specifying dates
Both `Dates.DateTime` objects and `String`s can be passed as values to the
`starttime`, `endtime`, `startbefore`, `startafter`, `endbefore`, `endafter`
and `updatedafter` keywords so long as they are valid.
Examples include `"2000-01-01"` and `"2008-02-03T00:00:30"`.

## Specifying station channel codes
As well as the options specified by the FDSN standard, the additional option
`code` is provided for ease of use.  This accepts channel codes in the SEED
convention `"⟨network⟩.⟨station⟩.⟨channel⟩.⟨location⟩"`, where each `.`-separated
field can contain wildcards and `,`-separated lists of codes.
"""
struct FDSNStation <: FDSNRequest
    starttime::MDateTime
    endtime::MDateTime
    startbefore::MDateTime
    startafter::MDateTime
    endbefore::MDateTime
    endafter::MDateTime
    network::MString
    station::MString
    location::MString
    channel::MString
    minlatitude::MFloat
    maxlatitude::MFloat
    minlongitude::MFloat
    maxlongitude::MFloat
    latitude::MFloat
    longitude::MFloat
    minradius::MFloat
    maxradius::MFloat
    level::MString
    includerestricted::MBool
    includeavailability::MBool
    updatedafter::MDateTime
    matchtimeseries::MBool
    format::MString
    nodata::Int
    function FDSNStation(st, et, sb, sa, eb, ea, net, sta, loc, cha, minlat, maxlat,
                         minlon, maxlon, lat, lon, minr, maxr, level, restricted,
                         availability, updatedafter, matchtimeseries, format, nodata)
        !ismissing(st) && (st = DateTime(st))
        !ismissing(et) && (et = DateTime(et))
        !ismissing(sb) && (sb = DateTime(sb))
        !ismissing(sa) && (sa = DateTime(sa))
        !ismissing(eb) && (eb = DateTime(eb))
        !ismissing(ea) && (ea = DateTime(ea))
        !ismissing(updatedafter) && (updatedafter = DateTime(updatedafter))
        !ismissing(st) && !ismissing(et) && st > et &&
            throw(ArgumentError("`starttime` must be before endtime"))
        !ismissing(sb) && !ismissing(sa) && sb > sa &&
            throw(ArgumentError("`startbefore` must be before startafter"))
        !ismissing(eb) && !ismissing(ea) && eb > ea &&
            throw(ArgumentError("`endbefore` must be before endafter"))
        !ismissing(net) && !isascii(net) && throw(ArgumentError("`network` must be ASCII"))
        !ismissing(sta) && !isascii(sta) && throw(ArgumentError("`station` must be ASCII"))
        if !ismissing(loc)
            !isascii(loc) && throw(ArgumentError("`channel` must be ASCII"))
            loc == "  " && (loc = "--")
        end
        !ismissing(cha) && !isascii(cha) && throw(ArgumentError("`channel` must be ASCII"))
        (!ismissing(minr) || !ismissing(maxr)) && (ismissing(lat) || ismissing(lon)) &&
            throw(ArgumentError("Both `latitude` and `longitude` must be present if " *
                                "specifying `minradius` or `maxradius`"))
        -90 ≤ coalesce(minlat, -90) ≤ 90 || throw(ArgumentError("`minlatitude` must be in range -90 to 90"))
        -90 ≤ coalesce(maxlat, 90) ≤ 90 || throw(ArgumentError("`maxlatitude` must be in range -90 to 90"))
        -180 ≤ coalesce(minlon, -180) ≤ 180 || throw(ArgumentError("`minlongitude` must be in range -180 to 180"))
        -180 ≤ coalesce(maxlon, 180) ≤ 180 || throw(ArgumentError("`maxlongitude` must be in range -180 to 180"))
        -90 ≤ coalesce(lat, 0) ≤ 90 || throw(ArgumentError("`latitude` must be in range -90 to 90"))
        -180 ≤ coalesce(lon, 0) ≤ 180 || throw(ArgumentError("`longitude` must be in range -180 to 180"))
        0 ≤ coalesce(minr, 0) ≤ 180 || throw(ArgumentError("`minradius` must be in range 0 to 180"))
        0 ≤ coalesce(maxr, 180) ≤ 180 || throw(ArgumentError("`maxradius` must be in range 0 to 180"))
        if !ismissing(level)
            !isascii(level) && throw(ArgumentError("`level` must be ASCII"))
            level ∉ ("network", "station", "channel", "response") &&
                throw(ArgumentError("`level` must be one of \"network\", \"station\", \"channel\" or \"response\""))
        else
            # Default to channel level if a channel pattern is given
            ismissing(level) && !ismissing(cha) && (level = "channel")
        end
        nodata ∈ (204, 404) || throw(ArgumentError("`nodata` must be 204 or 404"))
        new(st, et, sb, sa, eb, ea, net, sta, loc, cha, minlat, maxlat,
            minlon, maxlon, lat, lon, minr, maxr, level, restricted,
            availability, updatedafter, matchtimeseries, format, nodata)
    end
end

function FDSNStation(; code=missing,
        starttime=missing, endtime=missing, startbefore=missing, startafter=missing,
        endbefore=missing, endafter=missing, network=missing, station=missing,
        location=missing, channel=missing, minlatitude=missing, maxlatitude=missing,
        minlongitude=missing, maxlongitude=missing, latitude=missing, longitude=missing,
        minradius=missing, maxradius=missing, level=missing, includerestricted=missing,
        includeavailability=missing, updatedafter=missing, matchtimeseries=missing,
        format=missing, nodata=204)
    if !ismissing(code)
        any(!ismissing, (network, station, location, channel)) &&
            throw(ArgumentError("`code` cannot be provided with any of " *
                                "`network`, `station`, `location`, or `channel`"))
        network, station, location, channel = split_channel_code(code)
    end
    FDSNStation(starttime, endtime, startbefore, startafter, endbefore, endafter,
        network, station, location, channel, minlatitude, maxlatitude, minlongitude,
        maxlongitude, latitude, longitude, minradius, maxradius, level,
        includerestricted, includeavailability, updatedafter, matchtimeseries,
        format, nodata)
end

service_string(::FDSNEvent) = "event"
service_string(::FDSNDataSelect) = "dataselect"
service_string(::FDSNStation) = "station"
