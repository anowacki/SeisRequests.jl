# FDSN web service specification tests

using Compat.Test
import Compat.Dates
@static if VERSION < v"0.7"
    using Missings
end
using SeisRequests

@testset "FDSNWS" begin
    @testset "FDSNEvent" begin
        # Subtyping
        @test FDSNEvent <: SeisRequests.FDSNRequest
        # Construction
        @test_throws ArgumentError FDSNEvent(starttime=Dates.now(),
                                             endtime=Dates.now()-Dates.Second(1))
        @test_throws ArgumentError FDSNEvent(maxradius=20, longitude=0)
        @test_throws ArgumentError FDSNEvent(limit=-1)
        @test_throws ArgumentError FDSNEvent(offset=-5.0)
        @test_throws ArgumentError FDSNEvent(minlatitude=100)
        @test_throws ArgumentError FDSNEvent(maxlatitude=-100)
        @test_throws ArgumentError FDSNEvent(minlongitude=200)
        @test_throws ArgumentError FDSNEvent(maxlongitude=-181)
        @test_throws ArgumentError FDSNEvent(latitude=100)
        @test_throws ArgumentError FDSNEvent(longitude=360)
        @test_throws ArgumentError FDSNEvent(longitude=0, latitude=0, minradius=-5)
        @test_throws ArgumentError FDSNEvent(longitude=0, latitude=0, maxradius=181)
        @test_throws ArgumentError FDSNEvent(format="weird_format_please")
        @test_throws ArgumentError FDSNEvent(nodata=101)
        let req = FDSNEvent()
            for field in fieldnames(FDSNEvent)
                if field == :nodata
                    @test getfield(req, field) == 204
                else
                    @test getfield(req, field) === missing
                end
            end
        end
        # Methods
        let req = FDSNEvent(longitude=45, latitude=15, maxradius=5, minmagnitude=4,
                            starttime=Dates.DateTime(2000),
                            endtime=Dates.DateTime(2000)+Dates.Day(1))
            @test SeisRequests.protocol_string(req) == "fdsnws"
            @test SeisRequests.service_string(req) == "event"
            @test SeisRequests.request_uri(req) == 
                "http://service.iris.edu/fdsnws/event/1/query?" *
                "starttime=2000-01-01T00:00:00&endtime=2000-01-02T00:00:00&" *
                "latitude=15.0&longitude=45.0&maxradius=5.0&minmagnitude=4.0&" *
                "nodata=204"
            # Get request: will fail if IRISWS not working for some reason
            response = get_request(req, verbose=false)
            @test response.status in keys(SeisRequests.STATUS_CODES)
        end
    end

    @testset "FDSNDataSelect" begin
        # Subtyping
        @test FDSNDataSelect <: SeisRequests.FDSNRequest
        # Construction
        @test_throws ArgumentError FDSNDataSelect(starttime=Dates.now(),
                                                  endtime=Dates.now()-Dates.Second(1))
        for field in (:network, :station, :location, :channel)
            @test_throws ArgumentError FDSNDataSelect(; field=>"β is not ASCII")
        end
        @test_throws ArgumentError FDSNDataSelect(quality="A")
        @test_throws ArgumentError FDSNDataSelect(minimumlength=-2.0)
        @test_throws ArgumentError FDSNDataSelect(nodata=101)
        let req = FDSNDataSelect()
            for field in fieldnames(FDSNDataSelect)
                if field == :nodata
                    @test getfield(req, field) == 204
                else
                    @test getfield(req, field) === missing
                end
            end
        end
        let req = FDSNDataSelect(location="  ")
            @test req.location == "--"
        end
        # Methods
        let req = FDSNDataSelect(network="IU", station="ANMO", location="*",
                                 channel="BH?", starttime=Dates.DateTime(2000),
                                 endtime=Dates.DateTime(2000)+Dates.Second(1))
            @test SeisRequests.protocol_string(req) == "fdsnws"
            @test SeisRequests.service_string(req) == "dataselect"
            @test SeisRequests.request_uri(req) == 
                "http://service.iris.edu/fdsnws/dataselect/1/query?" *
                "starttime=2000-01-01T00:00:00&endtime=2000-01-01T00:00:01&" *
                "network=IU&station=ANMO&location=*&channel=BH?&nodata=204"
            # Get request: will fail if IRISWS not working for some reason
            response = get_request(req, verbose=false)
            @test response.status in keys(SeisRequests.STATUS_CODES)
        end
    end
    
    @testset "FDSNStation" begin
        # Subtyping
        @test FDSNStation <: SeisRequests.FDSNRequest
        # Construction
        @test_throws ArgumentError FDSNStation(starttime=Dates.now(),
                                               endtime=Dates.now()-Dates.Second(1))
        @test_throws ArgumentError FDSNStation(maxradius=20, longitude=0)
        @test_throws ArgumentError FDSNStation(minlatitude=100)
        @test_throws ArgumentError FDSNStation(maxlatitude=-100)
        @test_throws ArgumentError FDSNStation(minlongitude=200)
        @test_throws ArgumentError FDSNStation(maxlongitude=-181)
        @test_throws ArgumentError FDSNStation(latitude=100)
        @test_throws ArgumentError FDSNStation(longitude=360)
        @test_throws ArgumentError FDSNStation(longitude=0, latitude=0, minradius=-5)
        @test_throws ArgumentError FDSNStation(longitude=0, latitude=0, maxradius=181)
        @test_throws ArgumentError FDSNStation(level="weird_level_please")
        @test_throws ArgumentError FDSNStation(nodata=101)
        for field in (:network, :station, :location, :channel)
            @test_throws ArgumentError FDSNStation(; field=>"β is not ASCII")
        end
        let req = FDSNStation()
            for field in fieldnames(FDSNStation)
                if field == :nodata
                    @test getfield(req, field) == 204
                else
                    @test getfield(req, field) === missing
                end
            end
        end
        # Methods
        let req = FDSNStation(network="GB", station="JSA", location="--", channel="?H?",
                              level="channel", format="text")
            @test SeisRequests.protocol_string(req) == "fdsnws"
            @test SeisRequests.service_string(req) == "station"
            @test SeisRequests.request_uri(req) == 
                "http://service.iris.edu/fdsnws/station/1/query?" *
                "network=GB&station=JSA&location=--&channel=?H?&level=channel&" *
                "format=text&nodata=204"
            # Get request: will fail if IRISWS not working for some reason
            response = get_request(req, verbose=false)
            @test response.status in keys(SeisRequests.STATUS_CODES)
        end
    end
end