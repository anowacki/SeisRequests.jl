using SeisRequests, Test
using Seis
using Dates: DateTime, Second, Millisecond
import HTTP
import StationXML

"""
Compare two Seis.Stations and return `true` if they are equal
apart from the `created` property of any StationXML in their `meta` fields.
"""
function stations_equal(s1, s2)
    # First test the StationXML apart from `created`
    if all(x->hasproperty(x.meta, :stationxml), (s1, s2))
        if !all(getproperty(s1.meta.stationxml, p) ==
                    getproperty(s2.meta.stationxml, p)
                for p in propertynames(s1.meta.stationxml) if p !== :created)
            return false
        end
    elseif any(x->hasproperty(x, :stationxml), (s1, s2))
        return false
    end
    # Remove stationxml field if any
    s1, s2 = deepcopy(s1), deepcopy(s2)
    s1.meta.stationxml = s2.meta.stationxml
    # Remove the request field if any
    # s1.meta.request = s2.meta.request = missing
    # Test remaining parts
    s1 == s2
end

@testset "get_stations" begin
    server = "http://service.example.com"
    SUCCESS = SeisRequests.CODE_SUCCESS

    @testset "parse_station_response" begin
        @testset "No response" begin
            request = FDSNStation(nodata=204)
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_station_response(Float64, request,
                response, server) == []

            @testset "Element type $T" for T in (Float32, Float64)
                @test SeisRequests.parse_station_response(T, request, response,
                    server) isa Vector{Seis.GeogStation{T}}
            end
            response.body = [1]
            @test (@test_logs (:warn,
                            "unexpected data in response reporting no data") SeisRequests.parse_station_response(
                            Float64, request, response, server) == [])
            request = FDSNStation(nodata=404)
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_station_response(Float64, request, response,
                server) == []
        end

        @testset "'Success' but no data" begin
            request = FDSNStation()
            response = HTTP.Messages.Response(SUCCESS)
            @test_throws ErrorException SeisRequests.parse_station_response(Float64,
                request, response, server)
        end

        @testset "Content-Type" begin
            @testset "Text" begin
                request = FDSNStation(network="AB", level="network", format="text")
                body = "AB|XXX|2000-01-01|3000-01-01|2\n"

                @testset "Wrong" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"text/plain"), body=body)
                    response_type_wrong = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"WRONG"), body=body)
                    @test (@test_logs (:warn, "content type of response is \"WRONG\", " *
                             "not \"text/plain\" as expected"
                        ) SeisRequests.parse_station_response(
                            Float64, request, response_type_wrong, server)) ==
                        SeisRequests.parse_station_response(Float64, request,
                            response_correct, server)
                end

                @testset "Empty" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"text/plain"), body=body)
                    response_type_empty = HTTP.Messages.Response(SUCCESS,
                        Dict(), body=body)
                    @test SeisRequests.parse_station_response(Float64,
                        request, response_type_empty, server) ==
                        SeisRequests.parse_station_response(Float64,
                            request, response_correct, server)
                end
            end
            @testset "XML" begin
                request = FDSNStation(network="AB", level="network")
                body = """<?xml version="1.0" encoding="UTF-8"?>
                    <FDSNStationXML xmlns="http://www.fdsn.org/xml/station/1" schemaVersion="1.0">
                    <Source>Me</Source>
                    <Created>2000-01-01T00:00:00</Created>
                    <Network code="AN">
                    </Network>
                    </FDSNStationXML>"""
                @testset "Wrong" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"application/xml"), body=body)
                    response_type_wrong = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"WRONG"), body=body)
                    @test_logs (:warn, "content type of response is \"WRONG\", " *
                            "not \"application/xml\" as expected"
                        ) SeisRequests.parse_station_response(
                            Float64, request, response_type_wrong, server) ==
                        SeisRequests.parse_station_response(Float64, request,
                            response_correct, server)
                end
                @testset "Empty" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"application/xml"), body=body)
                    response_type_empty = HTTP.Messages.Response(SUCCESS, body)
                    @test SeisRequests.parse_station_response(
                            Float64, request, response_type_empty, server) ==
                        SeisRequests.parse_station_response(Float64, request,
                            response_correct, server)
                end
            end
        end

        @testset "Text format" begin
            @testset "Network level" begin
                request = FDSNStation(network="?N", level="network",
                    format="text")
                body = """
                    # Network|Description|StartTime|EndTime|TotalStations
                    # Arbitrary comment
                    AN|Network 1|2000-01-01T00:00:00.123|2002-02-03T04:05:06.789|99
                    # Another arbitrary comment
                    BN|Network 2|3000-01-02T03:04:05.678||101
                    """
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"text/plain"), body=body)
                    out = SeisRequests.parse_station_response(T, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{T}}
                    @test length(out) == 2
                    @test out[1] == Seis.GeogStation{T}(net="AN",
                        meta=Dict{Symbol,Any}(:network_description=>"Network 1",
                            :startdate=>DateTime(2000, 1, 1, 0, 0, 0, 123),
                            :enddate=>DateTime(2002, 2, 3, 4, 5, 6, 789),
                            :network_number_stations=>99,
                            :server=>server))
                    @test out[2] == Seis.GeogStation{T}(net="BN",
                        meta=Dict{Symbol,Any}(:network_description=>"Network 2",
                            :startdate=>DateTime(3000, 1, 2, 3, 4, 5, 678),
                            :network_number_stations=>101,
                            :server=>server))
                end
            end
            @testset "Station level" begin
                request = FDSNStation(network="IU", station="ANMO", level="station",
                    format="text")
                body = """
                    IU|ANMO|34.9459|-106.4572|1850.0|Albuquerque, New Mexico, USA|1989-08-29T00:00:00|1995-07-14T00:00:00
                    IU|ANMO|34.9459|-106.4572|1850.0|Albuquerque, New Mexico, USA|1995-07-14T00:00:00|
                    """
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Messages.Response(SUCCESS, body)
                    out = SeisRequests.parse_station_response(T, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{T}}
                    @test length(out) == 2
                    @test out[1] == Seis.GeogStation{T}(net="IU", sta="ANMO",
                        lat=34.9459, lon=-106.4572, elev=1850, meta=Dict(
                            :sitename=>"Albuquerque, New Mexico, USA",
                            :startdate=>DateTime(1989, 8, 29),
                            :enddate=>DateTime(1995, 7, 14), :server=>server))
                    @test out[2] == Seis.GeogStation{T}(net="IU", sta="ANMO",
                        lat=34.9459, lon=-106.4572, elev=1850, meta=Dict(
                            :sitename=>"Albuquerque, New Mexico, USA",
                            :startdate=>DateTime(1995, 7, 14), :server=>server))
                end
            end
            @testset "Channel level" begin
                request = FDSNStation(network="?N", station="FA*", channel="*",
                    level="channel", format="text")
                body = """
                    IU|COLA|20|HNE|64.873599|-147.8616|200.0|0.0|90.0|0.0|Kinemetrics FBA-23 Low-GainSensor|53687.1|1.0|M/S**2|80.0|2005-09-28T22:00:00|2009-07-08T22:00:00
                    IU|COLA|20|HNN|64.873599|-147.8616|200.0|0.0|0.0|0.0|Kinemetrics FBA-23 Low-GainSensor|53687.1|1.0|M/S**2|80.0|2005-09-28T22:00:00|
                    """
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Messages.Response(SUCCESS, body)
                    out = SeisRequests.parse_station_response(Float64, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{Float64}}
                    @test length(out) == 2
                    out_true = [Seis.GeogStation{Float64}(net="IU", sta="COLA",
                            loc="20", cha="HNE", lat=64.873599, lon=-147.8616, elev=200,
                            dep=0, azi=90, inc=90, meta=Dict(
                                :sensor_description=>"Kinemetrics FBA-23 Low-GainSensor",
                                :scale=>53687.1, :scale_frequency=>1.0,
                                :scale_units=>"M/S**2", :sample_rate=>80.0,
                                :startdate=>DateTime(2005, 9, 28, 22),
                                :enddate=>DateTime(2009, 7, 8, 22),
                                :server=>server)),
                        Seis.GeogStation{Float64}(net="IU", sta="COLA",
                            loc="20", cha="HNN", lat=64.873599, lon=-147.8616, elev=200,
                            dep=0, azi=0, inc=90, meta=Dict(
                                :sensor_description=>"Kinemetrics FBA-23 Low-GainSensor",
                                :scale=>53687.1, :scale_frequency=>1.0,
                                :scale_units=>"M/S**2", :sample_rate=>80.0,
                                :startdate=>DateTime(2005, 9, 28, 22),
                                :server=>server))]
                    for (o, ot) in zip(out, out_true)
                        # `collect(propertynames(o))` for compatibility with Julia v1.2
                        @testset "Field: $f" for f in filter(x->x∉(:pos, :meta), collect(propertynames(o)))
                            @test getproperty(o, f) === getproperty(ot, f)
                        end
                        @testset "Key: $k" for (k, v) in o.meta
                            @test o.meta[k] === ot.meta[k]
                        end
                    end
                end
            end
        end

        @testset "StationXML format" begin
            sxml = StationXML.FDSNStationXML(source="Me", created=DateTime(1000),
                schema_version="1.1")
            net = StationXML.Network(code="AN", start_date=DateTime(2000), end_date=DateTime(3000))
            sta = StationXML.Station(code="FAKE",
                longitude=1, latitude=2, elevation=3, site=StationXML.Site(name="Fake site"),
                start_date=DateTime(2000), end_date=DateTime(2001))
            cha1 = StationXML.Channel(code="UHT", longitude=10, latitude=20, elevation=30,
                depth=40, location_code="", start_date=DateTime(2002), azimuth=100,
                dip=10)
            cha2 = StationXML.Channel(code="UHU", longitude=10, latitude=20, elevation=30,
                depth=0, location_code="00", start_date=DateTime(2003))

            @testset "Network level" begin
                request = FDSNStation(network="?N", level="network")
                sxml′ = deepcopy(sxml)
                push!(sxml′.network, net)
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Messages.Response(SUCCESS, Dict(),
                        body=string(StationXML.xmldoc(sxml′)))
                    out = SeisRequests.parse_station_response(T, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{T}}
                    @test length(out) == 1
                    @test out[1] == Seis.GeogStation{T}(net="AN", meta=Dict(
                            :startdate=>DateTime(2000),
                            :enddate=>DateTime(3000),
                            :stationxml=>sxml′,
                            :server=>server,
                            :request=>request))
                end
            end

            @testset "Station level" begin
                request = FDSNStation(network="?N", station="FAKE", level="station")
                sxml′ = deepcopy(sxml)
                push!(sxml′.network, deepcopy(net))
                push!(sxml′.network[1].station, deepcopy(sta))
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Response(SUCCESS, Dict(),
                        body=string(StationXML.xmldoc(sxml′)))
                    out = SeisRequests.parse_station_response(T, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{T}}
                    @test length(out) == 1
                    @test out[1] == Seis.GeogStation{T}(net="AN", sta="FAKE",
                        lon=1, lat=2, elev=3, meta=Dict(
                            :startdate=>DateTime(2000), :enddate=>DateTime(2001),
                            :stationxml=>sxml′, :server=>server, :request=>request))
                end
            end

            @testset "Channel level" begin
                request = FDSNStation(network="?N", station="FAKE", channel="*",
                    level="channel")
                sxml′ = deepcopy(sxml)
                push!(sxml′.network, net)
                push!(sxml′.network[1].station, deepcopy(sta))
                append!(sxml′.network[1].station[1].channel, deepcopy([cha1, cha2]))
                @testset "Eltype $T" for T in (Float32, Float64)
                    response = HTTP.Messages.Response(SUCCESS, Dict(),
                        body=string(StationXML.xmldoc(sxml′)))
                    out = SeisRequests.parse_station_response(T, request, response,
                        server)
                    @test out isa Vector{Seis.GeogStation{T}}
                    @test length(out) == 2
                    # Remove the other channel from the StationXML, as done by
                    # SeisRequests.filter_stationxml
                    sxml′_filtered = deepcopy(sxml′)
                    pop!(sxml′_filtered.network[1].station[1].channel)
                    @test out[1] == Seis.GeogStation{T}(net="AN", sta="FAKE",
                        loc="", cha="UHT", lon=10, lat=20, elev=30, dep=0.04,
                        azi=100, inc=100,
                        meta=Dict(:startdate=>DateTime(2002), :stationxml=>sxml′_filtered,
                            :server=>server, :request=>request))
                end
            end            
        end
    end

    @testset "Real requests" begin
        @testset "Verbosity" begin
            @test_logs (:info, "Request status: Successful request, results follow"
                ) get_stations(network="GB", station="J*", channel="?HZ",
                    level="station", verbose=true)
            @test_logs get_stations(network="GB", station="JSA", level="station",
                verbose=false)
        end

        @testset "Eltype" begin
            @testset "$T" for T in (Float32, Float64)
                @test get_stations(network="GB", station="J*", channel="?HZ",
                    level="channel", format="text", T=T,
                    verbose=false) isa Vector{Seis.GeogStation{T}}
            end
            @testset "Default eltype" begin
                @test get_stations(network="GB", level="network",
                    verbose=false) isa Vector{Seis.GeogStation{Float64}}
            end
        end

        # Request with only keyword arguments forwarded to FDSNStation
        @testset "Simple" begin
            stas = get_stations(network="GB", station="J*", channel="?HZ",
                    level="channel", format="text", verbose=false)
            @test length(stas) == 2
            @test stas[1] == Seis.GeogStation{Float64}(net="GB", sta="JSA", loc="",
                cha="BHZ", lon=-2.171698, lat=49.187801, elev=39.0,
                azi=0, inc=0, dep=0, meta=Dict(
                    :startdate=>DateTime(2007, 9, 6),
                    :sensor_description=>"TR-240", :sample_rate=>50.0,
                    :scale_units=>"M/S", :scale_frequency=>1,
                    :scale=>4.79174e8, :server=>"IRIS"))
        end

        @testset "Event" begin
            evt = Seis.Event(lon=-90, lat=45, time=DateTime(2000))
            @testset "No period" begin
                stas = get_stations(evt, network="US", maxradius=10, verbose=false)
                stas′ = get_stations(network="US", longitude=evt.lon, latitude=evt.lat,
                    maxradius=10, starttime=evt.time, endtime=evt.time, verbose=false)
                @test length(stas) == length(stas′)
                # Use custom comparison function because StationXML 'created' date
                # will be different regardless
                for (s, s′) in zip(stas, stas′)
                    @test stations_equal(s, s′)
                end
                # Stations definitely were active when the event occurred
                @test all(x -> x.meta.startdate <= evt.time <=
                    coalesce(x.meta.enddate, typemax(DateTime)), stas)
                # Stations are within 10 degrees of event
                @test all(x -> distance_deg(evt, x) <= 10, stas)
            end

            @testset "Date/time range" begin
                stas = get_stations(evt, -0.1, 60, network="US", maxradius=10,
                    verbose=false)
                stas′ = get_stations(evt, -Millisecond(100), Second(60), network="US",
                    maxradius=10, verbose=false)
                @test all(stations_equal.(stas, stas′))
            end
        end
    end
end
