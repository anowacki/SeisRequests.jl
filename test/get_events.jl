using Test
using SeisRequests
using Seis
using Dates: DateTime
import QuakeML

@testset "get_events" begin
    server = "http://service.example.com"
    SUCCESS = SeisRequests.CODE_SUCCESS

    @testset "parse_events" begin
        @testset "No response" begin
            request = FDSNEvent()
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_event_response(Float64, request,
                response, server) == []

            @testset "Element type $T" for T in (Float32, Float64)
                @test SeisRequests.parse_event_response(T, request, response,
                    server) isa Vector{Seis.GeogEvent{T}}
            end
            response.body = [1]
            @test (@test_logs (:warn,
                            "unexpected data in response reporting no data"
                ) SeisRequests.parse_event_response(
                            Float64, request, response, server) == [])
            request = FDSNEvent(nodata=404)
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_event_response(Float64, request, response,
                server) == []
        end

        @testset "'Success' but no data" begin
            request = FDSNEvent()
            response = HTTP.Messages.Response(SUCCESS)
            @test_throws ErrorException SeisRequests.parse_event_response(Float64,
                request, response, server)
        end

        @testset "Content-Type" begin
            @testset "Text" begin
                request = FDSNEvent(format="text")
                body = "usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|offshore Guatemala|earthquake\n"

                @testset "Wrong" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"text/plain"), body=body)
                    response_type_wrong = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"WRONG"), body=body)
                    @test (@test_logs (:warn, "content type of response is \"WRONG\", " *
                             "not \"text/plain\" as expected"
                        ) SeisRequests.parse_event_response(
                            Float64, request, response_type_wrong, server)) ==
                        SeisRequests.parse_event_response(Float64, request,
                            response_correct, server)
                end

                @testset "Empty" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"text/plain"), body=body)
                    response_type_empty = HTTP.Messages.Response(SUCCESS,
                        Dict(), body=body)
                    @test SeisRequests.parse_event_response(Float64,
                        request, response_type_empty, server) ==
                        SeisRequests.parse_event_response(Float64,
                            request, response_correct, server)
                end
            end
            @testset "XML" begin
                request = FDSNEvent()
                body = """<?xml version="1.0" encoding="UTF-8"?>
                    <quakeml xmlns="http://quakeml.org/xmlns/quakeml/1.2">
                      <eventParameters publicID="smi:local/b3918029-d67d-4a49-9b40-128a53446e0d">
                        <event publicID="smi:local/bbc44eba-f0d3-40bc-8402-798d7cdfa153">
                          <magnitude publicID="smi:local/fbb0f09d-e23a-4a2d-ac18-caeaa61d671d">
                            <mag>
                              <value>1.0</value>
                            </mag>
                          </magnitude>
                          <origin publicID="smi:local/c61861b7-eb6b-4141-8645-98dc88a71ce7">
                            <time>
                              <value>2020-05-21T10:39:23.469</value>
                            </time>
                            <longitude>
                              <value>0.0</value>
                            </longitude>
                            <latitude>
                              <value>1.0</value>
                            </latitude>
                          </origin>
                        </event>
                      </eventParameters>
                    </quakeml>
                    """
                @testset "Wrong" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"application/xml"), body=body)
                    response_type_wrong = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"WRONG"), body=body)
                    @test (@test_logs (:warn, "content type of response is \"WRONG\", " *
                                                 "not \"application/xml\" as expected"
                            ) SeisRequests.parse_event_response(
                                Float64, request, response_type_wrong, server)) ==
                        SeisRequests.parse_event_response(Float64, request,
                            response_correct, server)
                end
                @testset "Empty" begin
                    response_correct = HTTP.Messages.Response(SUCCESS,
                        Dict("Content-Type"=>"application/xml"), body=body)
                    response_type_empty = HTTP.Messages.Response(SUCCESS, 
                        Dict(), body=body)
                    @test SeisRequests.parse_event_response(
                            Float64, request, response_type_empty, server) ==
                        SeisRequests.parse_event_response(Float64, request,
                            response_correct, server)
                end
            end
        end

        @testset "Text format" begin
            request = FDSNEvent(format="text")
            body = """
                usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|offshore Guatemala|earthquake
                usp000juhz|2012-10-28T03:04:08.820|52.788|-132.101|14|us|us|us|usp000juhz|mww|7.8|us|Haida Gwaii, Canada|earthquake
                """
            @testset "Eltype $T" for T in (Float32, Float64)
                response = HTTP.Messages.Response(SUCCESS, body)
                out = SeisRequests.parse_event_response(T, request, response, server)
                @test out isa Vector{Seis.GeogEvent{T}}
                @test length(out) == 2
                @test out[1] == Seis.GeogEvent{T}(id="usp000jv5f",
                    time=DateTime("2012-11-07T16:35:46.930"), lat=13.988,
                    lon=-91.895, dep=24, meta=Dict(
                        :author=>"us", :catalog=>"us", :contributor=>"us",
                        :contributor_id=>"usp000jv5f", :mag_type=>"mww",
                        :mag=>7.4, :mag_author=>"us",
                        :location_name=>"offshore Guatemala",
                        :type=>"earthquake", :server=>server))
                @test out[2] == Seis.GeogEvent{T}(id="usp000juhz",
                    time=DateTime("2012-10-28T03:04:08.820"), lat=52.788,
                    lon=-132.101, dep=14, meta=Dict(
                        :author=>"us", :catalog=>"us", :contributor=>"us",
                        :contributor_id=>"usp000juhz", :mag_type=>"mww",
                        :mag=>7.8, :mag_author=>"us",
                        :location_name=>"Haida Gwaii, Canada",
                        :type=>"earthquake", :server=>server))
            end
        end

        @testset "QuakeML format" begin
            request = FDSNEvent()
            # Fake mashup of IRIS and ISC response.
            # First event is from IRIS; second from ISC
            body = """
                <?xml version="1.0" encoding="UTF-8"?>
                <q:quakeml xmlns:q="http://quakeml.org/xmlns/quakeml/1.2"
                    xmlns:iris="http://service.iris.edu/fdsnws/event/1/"
                    xmlns="http://quakeml.org/xmlns/bed/1.2"
                    xmlns:xsi="http://www.w3.org/2000/10/XMLSchema-instance"
                    xsi:schemaLocation="http://quakeml.org/schema/xsd http://quakeml.org/schema/xsd/QuakeML-1.2.xsd">
                <eventParameters publicID="smi:service.iris.edu/fdsnws/event/1/query">

                    <!-- IRIS event -->
                    <event publicID="smi:service.iris.edu/fdsnws/event/1/query?eventid=11041250">
                        <type>earthquake</type>
                        <description xmlns:iris="http://service.iris.edu/fdsnws/event/1/" iris:FEcode="111">
                            <type>Flinn-Engdahl region</type>
                            <text>NORTHERN PERU</text>
                        </description>
                        <preferredMagnitudeID>smi:service.iris.edu/fdsnws/event/1/query?magnitudeid=193627740</preferredMagnitudeID>
                        <preferredOriginID>smi:service.iris.edu/fdsnws/event/1/query?originid=38683486</preferredOriginID>
                        <!-- Fake non-preferred origin -->
                        <origin publicID="smi:example.com/fake/event">
                            <time>
                                <value>3000-01-01T00:00:00.000</value>
                            </time>
                            <creationInfo>
                                <author>Me</author>
                            </creationInfo>
                            <latitude>
                                <value>0</value>
                            </latitude>
                            <longitude>
                                <value>0</value>
                            </longitude>
                            <depth>
                                <value>700000.0</value>
                            </depth>
                        </origin>

                        <!-- End of fake origin -->
                        <origin xmlns:iris="http://service.iris.edu/fdsnws/event/1/"
                                publicID="smi:service.iris.edu/fdsnws/event/1/query?originid=38683486"
                                iris:contributorOriginId="pt19146001" iris:contributor="us"
                                iris:contributorEventId="us60003sc0,at00ps3pco,pt19146001"
                                iris:catalog="NEIC PDE">
                            <time>
                                <value>2019-05-26T07:41:15.058</value>
                            </time>
                            <creationInfo>
                                <author>at,pt,us</author>
                            </creationInfo>
                            <latitude>
                                <value>-5.8132</value>
                            </latitude>
                            <longitude>
                                <value>-75.2775</value>
                            </longitude>
                            <depth>
                                <value>122400.0</value>
                            </depth>
                        </origin>

                        <!-- Fake non-preferred magnitude -->
                        <magnitude publicID="smi:example.com/fake/magnitude">
                            <mag>
                                <value>15</value>
                            </mag>
                            <type>mb</type>
                            <creationInfo>
                                <author>Me</author>
                            </creationInfo>
                        </magnitude>
                        <!-- End of fake magnitude -->

                        <magnitude publicID="smi:service.iris.edu/fdsnws/event/1/query?magnitudeid=193627740">
                            <mag>
                                <value>8.0</value>
                            </mag>
                            <type>Mww</type>
                            <creationInfo>
                                <author>us</author>
                            </creationInfo>
                        </magnitude>
                    </event>

                    <!-- ISC event -->
                    <event publicID="smi:ISC/evid=618237507">
                      <preferredOriginID>smi:ISC/origid=613854533</preferredOriginID>
                      <description>
                        <text>Mozambique Channel</text>
                        <type>Flinn-Engdahl region</type>
                      </description>
                      <type>earthquake</type>
                      <typeCertainty>known</typeCertainty>
                      <origin publicID="smi:ISC/origid=613854533">
                        <time>
                          <value>2018-02-16T12:02:45.80Z</value>
                          <uncertainty>5.66</uncertainty>
                        </time>
                        <latitude>
                          <value>-25.4270</value>
                        </latitude>
                        <longitude>
                          <value>38.7170</value>
                        </longitude>
                        <depth>
                          <value>5000.0</value>
                        </depth>
                        <quality>
                          <associatedStationCount>5</associatedStationCount>
                          <standardError>18.0000</standardError>
                          <azimuthalGap>349.000</azimuthalGap>
                        </quality>
                        <creationInfo>
                          <author>NAM</author>
                        </creationInfo>
                        <originUncertainty>
                          <preferredDescription>horizontal uncertainty</preferredDescription>
                          <minHorizontalUncertainty>999900</minHorizontalUncertainty>
                          <maxHorizontalUncertainty>999900</maxHorizontalUncertainty>
                          <azimuthMaxHorizontalUncertainty>90</azimuthMaxHorizontalUncertainty>
                        </originUncertainty>
                      </origin>
                      <magnitude publicID="smi:ISC/magid=619919995">
                        <mag>
                          <value>9.90</value>
                        </mag>
                        <type>MD</type>
                        <originID>smi:ISC/origid=613854533</originID>
                        <creationInfo>
                          <author>NAM</author>
                        </creationInfo>
                      </magnitude>
                    </event>
                </eventParameters>
                </q:quakeml>
                """
            @testset "Eltype $T" for T in (Float32, Float64)
                response = HTTP.Messages.Response(SUCCESS, body)
                out = SeisRequests.parse_event_response(T, request, response, server)
                @test out isa Vector{Seis.GeogEvent{T}}
                @test length(out) == 2
                @test out[1] == Seis.GeogEvent{T}(lon=-75.2775, lat=-5.8132,
                    dep=122.4, time=DateTime(2019, 05, 26, 07, 41, 15, 058),
                    id="smi:service.iris.edu/fdsnws/event/1/query?originid=38683486",
                    meta=Dict(
                        :author=>"at,pt,us",
                        :description=>"NORTHERN PERU (Flinn-Engdahl region)",
                        :mag_type=>"Mww", :mag=>8.0, :mag_author=>"us",
                        :type=>"earthquake",
                        :quakeml=>QuakeML.readstring(body).event[1],
                        :server=>server))
                @test out[2] == Seis.GeogEvent{T}(lon=38.7170, lat=-25.427,
                    dep=5.0, time=DateTime(2018, 02, 16, 12, 02, 45, 800),
                    id="smi:ISC/origid=613854533",
                    meta=Dict(
                        :author=>"NAM",
                        :description=>"Mozambique Channel (Flinn-Engdahl region)",
                        :mag_type=>"MD", :mag=>9.9, :mag_author=>"NAM",
                        :type=>"earthquake",
                        :quakeml=>QuakeML.readstring(body).event[2],
                        :server=>server))
            end
        end
    end

    @testset "Real requests" begin
        @testset "Verbosity" begin
            @test_logs (:info, "Request status: Successful request, results follow"
                ) get_events(minmagnitude=8, starttime="2018-01-01", verbose=true)
            @test_logs get_events(minmagnitude=8, starttime="2018-01-01", verbose=false)
        end

        @testset "Eltype" begin
            @testset "$T" for T in (Float32, Float64)
                @test get_events(starttime=1990-01-01, endtime=1991-01-01,
                    minmagnitude=7.5, T=T, verbose=false) isa Vector{Seis.GeogEvent{T}}
            end
            @testset "Default eltype" begin
                @test get_events(starttime="2018-01-01", endtime="2018-01-02",
                    minmagnitude=4.7, verbose=false) isa Vector{Seis.GeogEvent{Float64}}
            end
        end

        @testset "Server" begin
            @test first(get_events(starttime="2000-01-01", endtime="2001-01-01",
                    minmagnitude=7, verbose=false, server="ISC")
                ).meta.server == "ISC"
        end

        @testset "Simple" begin
            evts = get_events(starttime="2019-01-01", endtime="2020-01-01",
                minmagnitude=7.5, format="text", verbose=false)
            @test length(evts) == 3
            @test evts[1] == Event(lon=-75.2775, lat=-5.8132, dep=122.4,
                time=DateTime(2019, 05, 26, 07, 41, 15),
                id="11041250",
                meta=Dict(
                    :catalog=>"NEIC PDE",
                    :contributor_id=>"us60003sc0,at00ps3pco,pt19146001",
                    :contributor=>"us", :author=>"at,pt,us",
                    :mag_type=>"Mww", :mag_author=>"us", :mag=>8.0,
                    :location_name=>"NORTHERN PERU", :server=>"Earthscope"))
        end

        @testset "Station" begin
            date1, date2 = DateTime(1990), DateTime(1990, 2)
            sta = Station(lon=0, lat=0, meta=Dict(:startdate=>date1, :enddate=>date2))
            evts = get_events(sta, maxradius=90, minmagnitude=5, format="text",
                verbose=false)
            @test all(e -> distance_deg(e, sta) <= 90, evts)
            @test all(e -> date1 <= e.time <= date2, evts)
        end
    end
end
