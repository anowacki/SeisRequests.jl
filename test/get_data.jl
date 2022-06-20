using SeisRequests, Test
using Seis
using Dates: DateTime, Minute, Second

@testset "get_data" begin
    server = "http://service.example.com"
    SUCCESS = SeisRequests.CODE_SUCCESS
    mseed_file = joinpath(dirname(pathof(Seis)), "..", "test", "test_data", "io",
        "miniseed_GB.CWF.single_sample_gaps.mseed")
    data = read(mseed_file)

    @testset "parse_data_response" begin
        @testset "No response" begin
            request = FDSNDataSelect()
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_data_response(Float64, request, response, server) == []

            @testset "Eltype $T" for T in (Float32, Float64)
                @test SeisRequests.parse_data_response(T, request, response, server) isa
                    Vector{Seis.Trace{T, Vector{T}, Seis.Geographic{T}}}
            end

            response.body = [1]
            @test (@test_logs (:warn, "unexpected data in response reporting no data"
                ) SeisRequests.parse_data_response(Float64, request, response, server) == [])

            request = FDSNDataSelect(nodata=404)
            response = HTTP.Messages.Response(request.nodata)
            @test SeisRequests.parse_data_response(Float64, request, response, server) == []
        end
    end

    @testset "'Success' but no data" begin
        request = FDSNDataSelect()
        response = HTTP.Messages.Response(SUCCESS)
        @test_throws ErrorException SeisRequests.parse_data_response(Float64, request,
            response, server)
    end
    
    @testset "Content-Type" begin
        @testset "Miniseed" begin
            request = FDSNDataSelect()

            @testset "Wrong" begin
                response_correct = HTTP.Messages.Response(SUCCESS,
                    Dict("Content-Type"=>"application/vnd.fdsn.mseed"), body=data)
                response_type_wrong = HTTP.Messages.Response(SUCCESS,
                    Dict("Content-Type"=>"WRONG"), body=data)
                @test (@test_logs (:warn, "content type of response is \"WRONG\", " *
                                          "not \"application/vnd.fdsn.mseed\" as expected"
                        ) SeisRequests.parse_data_response(Float64, request, response_type_wrong, server)) ==
                    SeisRequests.parse_data_response(Float64, request, response_correct, server)
            end

            @testset "Empty" begin
                response_correct = HTTP.Messages.Response(SUCCESS,
                    Dict("Content-Type"=>"application/vnd.fdsn.mseed"), body=data)
                response_type_empty = HTTP.Messages.Response(SUCCESS,
                    Dict(), body=data)
                @test SeisRequests.parse_data_response(Float64, request,
                        response_type_empty, server) ==
                    SeisRequests.parse_data_response(Float64, request, response_correct, server)
            end
        end
    end

    @testset "Format" begin
        @testset "Miniseed" begin
            request = FDSNDataSelect()
            @testset "Eltype $T" for T in (Float32, Float64)
                response = HTTP.Messages.Response(SUCCESS,
                    Dict("Content-Type"=>"application/vnd.fdsn.mseed"), body=data)
                out = SeisRequests.parse_data_response(T, request, response, server)
                @test out isa Vector{Seis.Trace{T, Vector{T}, Seis.Geographic{T}}}
                @test length(out) == 2
                @test channel_code(out[1]) == "GB.CWF..BHZ"
                @test channel_code(out[2]) == "GB.CWF..HHZ"
                @test all(out.meta.server .== server)
                t = Seis.read_mseed(mseed_file,
                    Seis.Trace{T, Vector{T}, Seis.Geographic{T}})
                t.meta.mseed_file = missing
                t.meta.server = server
                @test out == t
            end
        end
    end

    @testset "Real requests" begin
        @testset "Verbosity" begin
            @testset "No data" begin
                @test (@test_logs (:info, "Request status: Request was properly " *
                    "formatted and submitted but no data matches the selection"
                    ) get_data(code="XX.XXX.XX.BHZ", starttime="2000-01-01",
                               endtime="2000-01-02")) == []
                @test_logs get_data(code="XX.XXX.XX.BHZ", starttime="2000-01-01",
                               endtime="2000-01-02", verbose=false)
            end
            @testset "Data" begin
                @test_logs (:info, "Request status: Successful request, results follow"
                    ) get_data(code="GB.JSA..BHZ",
                    starttime="2015-01-01", endtime="2015-01-01T00:00:01")
            end
        end
    end

    @testset "Simple" begin
        code = "IU.ANMO..BHZ"
        stime = DateTime(1990)
        etime = stime + Second(1)
        @testset "Eltype $T" for T in (Float32, Float64)
            t = get_data(code=code, starttime=stime, endtime=etime,
                T=T, verbose=false)
            @test t isa Vector{Seis.Trace{T, Vector{T}, Seis.Geographic{T}}}
        end
        @testset "Default eltype" begin
            t = get_data(code=code, starttime=stime, endtime=etime, verbose=false)
            @test t isa Vector{Seis.Trace{Float64, Vector{Float64}, Seis.Geographic{Float64}}}
            # These should never change, but rely on the IRIS data centre
            @test length(t) == 1
            @test all(x -> channel_code(x) == "IU.ANMO..BHZ", t)
            # Should be 1 second of data
            @test nsamples(first(t)) ≈ 1/first(t).delta
        end
    end

    @testset "Station" begin
        @testset "Trace eltype $Tt" for Tt in (Float32, Float64)
            @testset "Station eltype $Ts" for Ts in (Float32, Float64)
                stas = [Station{Ts}(net="G", sta="HYB", loc="", cha="BHZ",
                                    lon=78.553, lat=17.417, elev=510, azi=0, inc=0),
                        Station{Ts}(net="G", sta="SCZ", loc="", cha="BHZ",
                                    lon=-121.403, lat=36.598, elev=261, azi=0, inc=0)]
                t = get_data(stas, DateTime(2001), DateTime(2001)+Second(1), T=Tt,
                    verbose=false)
                @test t isa Vector{Seis.Trace{Tt,Vector{Tt},Seis.Geographic{Tt}}}
                # Assume data is returned; will fail if datacentre fails
                if isempty(t)
                    @warn("No data returned for Trace $Tt Station $Ts")
                else
                    @test all(x -> channel_code(x) in channel_code.(stas), t)
                    for tt in t
                        @test tt.sta in convert.(GeogStation{Tt}, stas)
                    end
                end
            end
        end
    end

    @testset "Event and stations" begin
        types = (Float32,  Float64)
        @testset "Trace eltype $Tt" for Tt in types
            @testset "Station eltype $Ts" for Ts in types
                stas = [Station{Ts}(net="IU", sta="FURI", loc="00", cha=comp,
                                    lon=-62.35, lat=82.5033, elev=60, azi=azi, inc=inc)
                        for (comp, azi, inc) in zip(
                            ("BHE", "BHN", "BHZ"), (90, 0, 0), (90, 90, 0))]
                @testset "Event eltype $Te" for Te in types
                    evt = Event{Te}(lon=-88.729, lat=-12.997, dep=82.9,
                                    time=DateTime("2001-01-13T17:33:34.58"))
                    t = get_data(evt, stas, Second(5), Minute(1) + Second(1),
                        verbose=false, T=Tt)
                    @test t isa Vector{Trace{Tt,Vector{Tt},Seis.Geographic{Tt}}}
                    if isempty(t)
                        @warn("No data returned for Event $Te Station $Ts Trace $Tt")
                    else
                        # Ensure correction conversion so that comparison with
                        # trace fields isn't wrong due to loss of precision
                        mintype = any((Tt, Ts, Tt) .== Float32) ? Float32 : Float64
                        for tt in t
                            @test channel_code(tt) in channel_code.(stas)
                            @test convert(GeogStation{mintype}, tt.sta) in
                                convert.(GeogStation{mintype}, stas)
                            @test convert(GeogEvent{mintype}, tt.evt) ==
                                convert(GeogEvent{mintype}, evt)
                            @test starttime(tt) ≈ 5 atol=0.1
                            @test endtime(tt) ≈ 61 atol=0.1
                        end
                    end
                    t′ = get_data(evt, stas, 5, 61, verbose=false, T=Tt)
                    @test t == t′
                end
            end
        end
    end
end
