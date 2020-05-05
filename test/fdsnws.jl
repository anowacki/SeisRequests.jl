# FDSN web service specification tests

using Test
import Dates
using Dates: DateTime
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
        # Conversion of strings to dates
        @testset "Date conversion: $f" for f in (:starttime, :endtime, :updatedafter)
            str = "2000-01-02T03:04:05.678"
            dat = DateTime(2000, 1, 2, 3, 4, 5, 678)
            @test FDSNEvent(; f=>str) == FDSNEvent(; f=>dat)
        end
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
        # Conversion of strings to dates
        @test FDSNDataSelect(starttime=Dates.DateTime(2000, 01, 01, 01, 02, 03, 456),
            endtime=Dates.DateTime(3000, 03, 04, 05, 06, 07, 890)) ==
            FDSNDataSelect(starttime="2000-01-01T01:02:03.456",
                endtime="3000-03-04T05:06:07.89")
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
        # Conversion of strings to dates
        @testset "Date conversion: $f" for f in (:starttime, :endtime, :startbefore,
                :endbefore, :startafter, :endafter, :updatedafter)
            str = "2000-01-02T03:04:05.678"
            dat = DateTime(2000, 1, 2, 3, 4, 5, 678)
            @test FDSNStation(; f=>str) == FDSNStation(; f=>dat)
        end

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

    @testset "FDSN text formats" begin
        # Correct parsing
        @testset "FDSNNetworkTextResponse" begin
            @test convert(SeisRequests.FDSNNetworkTextResponse,
                "II|Global Seismograph Network (GSN - IRIS/IDA)|1986-01-01T00:00:00|2500-12-12T23:59:59|50") ==
                SeisRequests.FDSNNetworkTextResponse("II",
                    "Global Seismograph Network (GSN - IRIS/IDA)",
                    DateTime(1986), DateTime(2500, 12, 12, 23, 59, 59), 50)
        end
        @testset "FDSNStationTextResponse" begin
            @test convert(SeisRequests.FDSNStationTextResponse,
                "IU|ANMO|34.9459|-106.4572|1850.0|Albuquerque, New Mexico, USA|1989-08-29T00:00:00|1995-07-14T00:00:00") ==
                SeisRequests.FDSNStationTextResponse("IU", "ANMO", 34.9459,
                    -106.4572, 1850.0, "Albuquerque, New Mexico, USA",
                    DateTime(1989, 08, 29), DateTime(1995, 07, 14))
        end
        @testset "FDSNChannelTextResponse" begin
            @test convert(SeisRequests.FDSNChannelTextResponse,
                "IU|COLA|20|HNE|64.873599|-147.8616|200.0|0.0|90.0|0.0|Kinemetrics FBA-23 Low-GainSensor|53687.1|1.0|M/S**2|80.0|2005-09-28T22:00:00|2009-07-08T22:00:00") ==
                SeisRequests.FDSNChannelTextResponse("IU", "COLA", "20", "HNE",
                    64.873599, -147.8616, 200.0, 0.0, 90.0, 0.0,
                    "Kinemetrics FBA-23 Low-GainSensor", 53687.1,
                    1.0, "M/S**2", 80.0, DateTime(2005, 9, 28, 22),
                    DateTime(2009, 7, 8, 22))
        end
        @testset "FDSNEventTextResponse" begin
            @test convert(SeisRequests.FDSNEventTextResponse,
                "usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|offshore Guatemala|earthquake") ==
                SeisRequests.FDSNEventTextResponse("usp000jv5f",
                    DateTime(2012, 11, 7, 16, 35, 46, 930), 13.988, -91.895,
                    24.0, "us", "us", "us", "usp000jv5f", "mww", 7.4, "us",
                    "offshore Guatemala", "earthquake")
            @test convert(SeisRequests.FDSNEventTextResponse,
                "usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|offshore Guatemala") ==
                SeisRequests.FDSNEventTextResponse("usp000jv5f",
                    DateTime(2012, 11, 7, 16, 35, 46, 930), 13.988, -91.895,
                    24.0, "us", "us", "us", "usp000jv5f", "mww", 7.4, "us",
                    "offshore Guatemala", "")
        end
        @testset "Error throwing" begin
            # Field counting
            @test SeisRequests.text_response_tokens_and_throw(Int, "1|2", 2) == ["1", "2"]
            # Multiple permissible number of fields
            @test SeisRequests.text_response_tokens_and_throw(Float32, "1|2|3", (3,4)) == ["1", "2", "3"]
            @test_throws ArgumentError SeisRequests.text_response_tokens_and_throw(Int, "1|2", 3)
            # Too few/many fields
            @test_throws ArgumentError convert(SeisRequests.FDSNNetworkTextResponse,
                "SY|Desc|2000-01-01T|2000-01-02T|10|__XXX__")
            @test_throws ArgumentError convert(SeisRequests.FDSNNetworkTextResponse,
                "SY|Desc|2000-01-01T|2000-01-02T")
            @test_throws ArgumentError convert(SeisRequests.FDSNStationTextResponse,
                "SY|STA|0.0|0.0|1000.0|Desc.|2000-01-01T|2001-01-01T|__XXX__")
            @test_throws ArgumentError convert(SeisRequests.FDSNStationTextResponse,
                "SY|STA|0.0|0.0|1000.0|Desc.|2000-01-01T")
            @test_throws ArgumentError convert(SeisRequests.FDSNChannelTextResponse,
                "SY|STA|00|LHZ|1|2|300|0|0|90|Seismometer|1234|2|M/S|-2|2000-01-01T")
            @test_throws ArgumentError convert(SeisRequests.FDSNChannelTextResponse,
                "SY|STA|00|LHZ|1|2|300|0|0|90|Seismometer|1234|2|M/S|-2|2000-01-01T|2001-01-01T|__XXX__")
            @test_throws ArgumentError convert(SeisRequests.FDSNEventTextResponse,
                "usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|offshoreGuatemala|earthquake|__XXX__")
            @test_throws ArgumentError convert(SeisRequests.FDSNEventTextResponse,
                "usp000jv5f|2012-11-07T16:35:46.930|13.988|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us")
            # Wrong type of field
            @test_throws ArgumentError convert(SeisRequests.FDSNNetworkTextResponse,
                "SY|Desc|2000-01-01T|2000-01-02T|__XXX__")
            @test_throws ArgumentError convert(SeisRequests.FDSNStationTextResponse,
                "SY|STA|__XXX__|0.0|1000.0|Desc.|2000-01-01T|2001-01-01T")
            @test_throws ArgumentError convert(SeisRequests.FDSNChannelTextResponse,
                "SY|STA|00|LHZ|__XXX__|2|300|0|0|90|Seismometer|1234|2|M/S|-2|2000-01-01T|2001-01-01T")
            @test_throws ArgumentError convert(SeisRequests.FDSNEventTextResponse,
                "usp000jv5f|2012-11-07T16:35:46.930|__XXX__|-91.895|24|us|us|us|usp000jv5f|mww|7.4|us|earthquake")
        end
    end
end
