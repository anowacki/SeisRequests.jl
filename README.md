# SeisRequests

Gather seismic data and metadata from web services using Julia.

[![Build Status](https://travis-ci.org/anowacki/SeisRequests.jl.svg?branch=master)](https://travis-ci.org/anowacki/SeisRequests.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/mg2cfsix16wuwq3f?svg=true)](https://ci.appveyor.com/project/AndyNowacki/seisrequests-jl)
[![Coverage Status](https://coveralls.io/repos/github/anowacki/SeisRequests.jl/badge.svg?branch=master)](https://coveralls.io/github/anowacki/SeisRequests.jl?branch=master)

## About SeisRequests

Seisrequests allows you to easily create a request for seismic data which you
can then pass to any server round the world which supports either the FDSN
or IRIS web services specifications.  Examples include [IRIS](https://iris.edu)
itself and the EU's data repository [Orfeus](https://www.orfeus-eu.org).

You can search for seismic waveform data, earthquake locations and station
information amongst other things.

## Installing

Add SeisRequests on v1 of Julia and upwards like so:

```julia
julia> ] # Type ']' to enter pkg mode

pkg> add https://github.com/anowacki/SeisRequests.jl
```

## Using

Create requests of the kind you like using one of the constructors:

- Using the FDSN Web Services standard:
  - `FDSNEvent`: Query for events
  - `FDSNStation`: Look for stations
  - `FDSNDataSelect`: Request waveform data
- Using the IRIS Web Services standard:
  - `IRISTimeSeries`: Requests waveform data

Each of these constructors has comprehensive documentation you can access
in the REPL by typing, e.g., `?FDSNEvent`.

These requests can then be passed to the `get_request` function, which returns
a `HTTP.Messages.Response` containing the information sent by the server.

SeisRequests doesn't itself yet process this information further, which is
up to the user.

For example, let's try and find information about the high-gain channels of
the UK station in Jersey:

```julia
julia> using SeisRequests

julia> req = FDSNStation(station="JSA", network="GB", channel="?H?", level="channel", format="text")
FDSNStation
  starttime: Missing missing
  endtime: Missing missing
  startbefore: Missing missing
  startafter: Missing missing
  endbefore: Missing missing
  endafter: Missing missing
  network: String "GB"
  station: String "JSY"
  ⋮
  matchtimeseries: Missing missing
  format: String "text"
  nodata: Int64 204

julia> get_request(req)
[ Info: Request status: Successful request, results follow
HTTP.Messages.Response:
"""
HTTP/1.1 200 OK
Server: Apache-Coyote/1.1
access-control-allow-origin: *
content-disposition: inline; filename="fdsnws-station_2018-08-23T13:37:35Z.txt"
Content-Type: text/plain
Content-Length: 176
Date: Thu, 23 Aug 2018 13:37:35 GMT
Connection: close

#Network | Station | Latitude | Longitude | Elevation | SiteName | StartTime | EndTime 
GB|JSA|49.1878|-2.171698|39.0|ST AUBINS, JERSEY|2007-09-06T00:00:00|2599-12-31T23:59:59
"""
```

If we want to get some data from here, we can ask for SAC data and read
the response using the [SAC](https://github.com/anowacki/SAC.jl) module,
then plot it up using [SACPlot](https://github.com/anowacki/SACPlot.jl):

```julia
julia> using Dates, SAC # `using Base.Dates` if still on Julia v0.6

julia> otime = DateTime(2018, 02, 17, 14, 31, 6) # Cymllynfell event, South Wales
2018-02-17T14:31:06

julia> response = get_request(IRISTimeSeries(network="GB", station="JSA", location="--", channel="BHZ", starttime=otime, endtime=otime+Minute(5), output="sacbb"));
[ Info: Request status: Successful request, results follow

julia> trace = SACtr(response.body)
SAC.SACtr:
    delta: 0.02
   depmin: -9348.0
   depmax: 9834.0
        b: 0.0
        e: 299.97998
   depmen: 1.023
   nzyear: 2018
   nzjday: 48
   nzhour: 14
    nzmin: 31
    nzsec: 6
   nzmsec: 5
    nvhdr: 6
     npts: 15000
   iftype: 1
    leven: true
   lpspol: true
   lovrok: true
   lcalda: true
 unused18: true
    kstnm: JSA
   kcmpnm: BHZ
   knetwk: GB

julia> using SACPlot; plot1(trace)
```
![Cwmllynfell 2018-02-17 seismic event recorded at JSA, Jersey](docs/images/Cwmllynfell_JSA.png)
