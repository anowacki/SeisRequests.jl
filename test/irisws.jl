# IRIS web service specification tests

using Test
import Dates
using SeisRequests

@testset "IRISWS" begin
    @testset "IRISTimeSeries" begin
        # Subtyping
        @test IRISTimeSeries <: SeisRequests.IRISRequest
        # Construction
        @test_throws ArgumentError IRISTimeSeries()
        let 
            kwargs = Dict(:network => "IU",
                          :station => "ANMO",
                          :location => "--",
                          :channel => "BHZ",
                          :starttime => Dates.DateTime(2000, 1, 1),
                          :endtime => Dates.DateTime(2000, 1, 1, 0, 0, 30),
                          )
            # Missing required parameters
            for arg in keys(kwargs)
                kwargs2 = delete!(deepcopy(kwargs), arg)
                @test_throws ArgumentError IRISTimeSeries(; kwargs2...)
            end
            # Duplication of endtime with duration
            @test_throws ArgumentError IRISTimeSeries(; duration=30, kwargs...)
            
            req = IRISTimeSeries(; kwargs...)
            for field in fieldnames(IRISTimeSeries)
                if field in keys(kwargs)
                    @test getfield(req, field) == kwargs[field]
                elseif field == :process
                    @test isempty(getfield(req, field))
                elseif field == :format
                    # Default is for `format = "miniseed"`
                    @test getfield(req, field) == "miniseed"
                else
                    @test getfield(req, field) === missing
                end
            end
            
            # Replacement of missing location with '--'
            kwargs2 = delete!(deepcopy(kwargs), :location)
            @test IRISTimeSeries(; location="", kwargs2...).location == "--"

            # Processing limitations
            for taper in (-1, 2)
                @test_throws ArgumentError IRISTimeSeries(; taper=taper, kwargs...)
            end
            @test_throws ArgumentError IRISTimeSeries(; taper_type="HAMMING", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; taper=0.1, taper_type="weird_taper_type")
            @test_throws ArgumentError IRISTimeSeries(; lpfilter=-1, kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; hpfilter=-1, kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; bpfilter=(2,1), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; bpfilter=(-1,2), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; bpfilter="1;2", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; bpfilter=(1,2,3), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; scale="auto", correct=true, kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; scale="weird_scale", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; freqlimits=[1,2,3,4], kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, freqlimits=[1,2,3,1], kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, freqlimits=(-1,2,3,4), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, freqlimits=(1,2,3), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, freqlimits=(1,2,3,4),
                autolimits=(3,3), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, autolimits=(1,), kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; units="VEL", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; correct=true, units="weird_units", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; units="VEL", kwargs...)
            @test_throws ArgumentError IRISTimeSeries(; format="weird_format",
                delete!(deepcopy(kwargs), :format)...)
            @test_throws ArgumentError IRISTimeSeries(; weird_processing="val", kwargs...)

            # Preservation of processing order
            req = IRISTimeSeries(; diff=true, demean=true, int=true, bpfilter=(1,2), kwargs...)
            @test findall.(isequal.((:diff, :demean, :int, :bpfilter)),
                           Ref(collect(keys(req.process)))) |> x -> issorted(first.(x))

            # Methods
            let req = IRISTimeSeries(network="IU", station="ANMO", location="00",
                                     channel="BHZ", starttime=Dates.DateTime(2000),
                                     endtime=Dates.DateTime(2000)+Dates.Second(1),
                                     format="miniseed", int=true)
                @test SeisRequests.protocol_string(req) == "irisws"
                @test SeisRequests.service_string(req) == "timeseries"
                @test SeisRequests.request_uri(req) == 
                    "https://service.earthscope.org/irisws/timeseries/1/query?" *
                    "network=IU&station=ANMO&location=00&channel=BHZ&" *
                    "starttime=2000-01-01T00:00:00&endtime=2000-01-01T00:00:01&" *
                    "format=miniseed&int=true"
                # Get request: will fail if IRISWS not working for some reason
                response = get_request(req, verbose=false)
                @test response.status in keys(SeisRequests.STATUS_CODES)
            end

            @testset "Code conversion" begin
                st = Dates.DateTime(2000)
                et = st + Dates.Hour(1)
                fmt = "miniseed"
                @test_throws ArgumentError IRISTimeSeries(code="A.B.C.D",
                    network="A", station="B", location="C", channel="D",
                    starttime=st, endtime=et, format=fmt)
                @test IRISTimeSeries(code="A.B..D", starttime=st, endtime=et, format=fmt) ==
                    IRISTimeSeries(network="A", station="B", location="", channel="D",
                        starttime=st, endtime=et, format=fmt)
            end

            # Conversion of strings to dates
            @test IRISTimeSeries(network="AN", station="XYZ", location="",
                channel="LHZ", format="miniseed",
                starttime=Dates.DateTime(2000),
                endtime=Dates.DateTime(2000, 01, 01, 01, 02, 03, 400)) ==
                IRISTimeSeries(network="AN", station="XYZ", location="",
                channel="LHZ", format="miniseed",
                starttime="2000-01-01", endtime="2000-01-01T01:02:03.4")
        end
    end
end