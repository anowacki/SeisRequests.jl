"""
    FDSNRequest

An abstract type representing requests conforming to the FDSN Web Services specification.

Current subtypes of `FDSNRequest`:
- `FDSNDataSelect`
- `FDSNEvent`
- `FDSNStation`
"""
abstract type FDSNRequest <: SeisRequest end

protocol_string(::FDSNRequest) = "fdsnws"

"""
    FDSNEvent(kwargs...)

Create a FDSN web services event query which can be sent to a datacentre which implements
the FDSN Web Services specification.

## Available options:

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
|`format`|Specify format of result, either `"xml"` (default) or `"text"`. If this parameter is not specified the service must return QuakeML.|
|`nodata`|Select status code for “no data”, either `204` (default) or `404`.|"""
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
        -180 ≤ coalesce(minlon, 180) ≤ 180 || throw(ArgumentError("`maxlongitude` must be in range -180 to 180"))
        -90 ≤ coalesce(lat, 0) ≤ 90 || throw(ArgumentError("`latitude` must be in range -90 to 90"))
        -180 ≤ coalesce(lon, 0) ≤ 180 || throw(ArgumentError("`longitude` must be in range -180 to 180"))
        0 ≤ coalesce(minr, 0) ≤ 180 || throw(ArgumentError("`minradius` must be in range 0 to 180"))
        0 ≤ coalesce(maxr, 180) ≤ 180 || throw(ArgumentError("`maxradius` must be in range 0 to 180"))
        coalesce(format, "xml") ∈ ("xml", "miniseed", "text") ||
            throw(ArgumentError("`format` must be one of \"xml\" or \"text\""))
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

Set options with keyword arguments, e.g.:

```
julia> FDSNDataSelect(station="ANMO", starttime=)
```

## Available options:

|Parameter|Description|
|:--------|:----------|
|`starttime`|Limit results to time series samples on or after the specified start time.|
|`endtime`|Limit results to time series samples on or before the specified end time.|
|`network`|Select one or more network codes.  Can be SEED network codes or data center defined codes.  Multiple codes are comma-separated.|
|`station`|Select one or more SEED station codes.  Multiple codes are comma-separated.|
|`location`|Select one or more SEED location identifiers.  Multiple identifiers are comma-separated.  As a special case “--“ (two dashes) will be translated to a string of two space characters to match blank location IDs.|
|`channel`|Select one or more SEED channel codes.  Multiple codes are comma-separated.|
|`quality`|Select a specific SEED quality indicator, handling is data center dependent.|
|`minimumlength`|Limit results to continuous data segments of a minimum length specified in seconds.|
|`longestonly`|Limit results to the longest continuous segment per channel.|
|`format`|Specify format of result, the default value is `"miniseed"`.|
|`nodata`|Select status code for “no data”, either ‘204’ (default) or ‘404’.|
"""
@with_kw struct FDSNDataSelect <: FDSNRequest
    starttime::MDateTime = missing
    endtime::MDateTime = missing
    network::MString = missing
    station::MString = missing
    location::MString = missing
    channel::MString = missing
    quality::MString = missing
    minimumlength::MFloat = missing
    longestonly::MBool = missing
    format::MString = missing
    nodata::Int = 204
    function FDSNDataSelect(st, et, net, sta, loc, cha, q, minlength, longestonly, format, nodata)
        !ismissing(st) && !ismissing(et) && st > et &&
            throw(ArgumentError("`starttime` must be before endtime"))
        !ismissing(net) && !isascii(net) && throw(ArgumentError("`network` must be ASCII"))
        !ismissing(sta) && !isascii(sta) && throw(ArgumentError("`station` must be ASCII"))
        if !ismissing(loc)
            !isascii(loc) && throw(ArgumentError("`channel` must be ASCII"))
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

"""
    FDSNStation(kwargs...)

Create a FDSN web services station query which can be sent to a datacentre which implements
the FDSN Web Services specification.

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
|`minlatitude`|Limit to stations with a latitude larger than or equal to the specified minimum.|
|`maxlatitude`|Limit to stations with a latitude smaller than or equal to the specified maximum.|
|`minlongitude`|Limit to stations with a longitude larger than or equal to the specified minimum.|
|`maxlongitude`|Limit to stations with a longitude smaller than or equal to the specified maximum.|
|`latitude`|Specify the latitude to be used for a radius search.|
|`longitude`|Specify the longitude to the used for a radius search.|
|`minradius`|Limit results to stations within the specified minimum number of degrees from the geographic point defined by the latitude and longitude parameters.|
|`maxradius`|Limit results to stations within the specified maximum number of degrees from the geographic point defined by the latitude and longitude parameters.|
|`level`|Specify the level of detail for the results.|
|`includerestricted`|Specify if results should include information for restricted stations.|
|`includeavailability`|Specify if results should include information about time series data availability.|
|`updatedafter`|Limit to metadata updated after specified time; updates are data center specific.|
|`matchtimeseries`|Limit to metadata where selection criteria matches time series data availability.|
|`format`|Specify format of result, either `"xml"` (default) or `"text"`.|
|`nodata`|Select status code for “no data”, either `204` (default) or `404`.|
"""
@with_kw struct FDSNStation <: FDSNRequest
    starttime::MDateTime = missing
    endtime::MDateTime = missing
    startbefore::MDateTime = missing
    startafter::MDateTime = missing
    endbefore::MDateTime = missing
    endafter::MDateTime = missing
    network::MString = missing
    station::MString = missing
    location::MString = missing
    channel::MString = missing
    minlatitude::MFloat = missing
    maxlatitude::MFloat = missing
    minlongitude::MFloat = missing
    maxlongitude::MFloat = missing
    latitude::MFloat = missing
    longitude::MFloat = missing
    minradius::MFloat = missing
    maxradius::MFloat = missing
    level::MString = missing
    includerestricted::MBool = missing
    includeavailability::MBool = missing
    updatedafter::MDateTime = missing
    matchtimeseries::MBool = missing
    format::MString = missing
    nodata::Int = 204
    function FDSNStation(st, et, sb, sa, eb, ea, net, sta, loc, cha, minlat, maxlat,
                         minlon, maxlon, lat, lon, minr, maxr, level, restricted,
                         availability, updatedafter, matchtimeseries, format, nodata)
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
        -90 ≤ coalesce(minlat, -90) ≤ 90 || throw(ArgumentError("`minlatitude` must be in range -90 to 90"))
        -90 ≤ coalesce(maxlat, 90) ≤ 90 || throw(ArgumentError("`maxlatitude` must be in range -90 to 90"))
        -180 ≤ coalesce(minlon, -180) ≤ 180 || throw(ArgumentError("`minlongitude` must be in range -180 to 180"))
        -180 ≤ coalesce(minlon, 180) ≤ 180 || throw(ArgumentError("`maxlongitude` must be in range -180 to 180"))
        -90 ≤ coalesce(lat, 0) ≤ 90 || throw(ArgumentError("`latitude` must be in range -90 to 90"))
        -180 ≤ coalesce(lon, 0) ≤ 180 || throw(ArgumentError("`longitude` must be in range -180 to 180"))
        0 ≤ coalesce(minr, 0) ≤ 180 || throw(ArgumentError("`minradius` must be in range 0 to 180"))
        0 ≤ coalesce(maxr, 180) ≤ 180 || throw(ArgumentError("`maxradius` must be in range 0 to 180"))
        if !ismissing(level)
            !isascii(level) && throw(ArgumentError("`level` must be ASCII"))
            level ∉ ("network", "station", "channel", "response") &&
                throw(ArgumentError("`level` must be one of \"network\", \"station\", \"channel\" or \"response\""))
        end
        nodata ∈ (204, 404) || throw(ArgumentError("`nodata` must be 204 or 404"))
        new(st, et, sb, sa, eb, ea, net, sta, loc, cha, minlat, maxlat,
            minlon, maxlon, lat, lon, minr, maxr, level, restricted,
            availability, updatedafter, matchtimeseries, format, nodata)
    end
end

service_string(::FDSNEvent) = "event"
service_string(::FDSNDataSelect) = "dataselect"
service_string(::FDSNStation) = "station"
