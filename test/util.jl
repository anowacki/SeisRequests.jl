using Test, SeisRequests
using Dates: Second, Millisecond

@testset "Utils" begin
    @testset "_default_server" begin
        @testset "Instances" begin                
            @test SeisRequests._default_server(FDSNEvent()) == SeisRequests.DEFAULT_EVENT_SERVER
            @test SeisRequests._default_server(FDSNStation()) == SeisRequests.DEFAULT_SERVER
            @test SeisRequests._default_server(FDSNDataSelect()) == SeisRequests.DEFAULT_SERVER
            @test SeisRequests._default_server(IRISTimeSeries(
                network="XX", station="AA",  location="", channel="BHZ",
                starttime="2000-01-01", endtime="2000-01-01",
            )) == SeisRequests.DEFAULT_SERVER
        end

        @testset "Types" begin
            @test SeisRequests._default_server(FDSNEvent) == SeisRequests.DEFAULT_EVENT_SERVER
            @test SeisRequests._default_server(FDSNStation) == SeisRequests.DEFAULT_SERVER
            @test SeisRequests._default_server(FDSNDataSelect) == SeisRequests.DEFAULT_SERVER
            @test SeisRequests._default_server(IRISTimeSeries) == SeisRequests.DEFAULT_SERVER            
        end
    end

    @testset "seconds_milliseconds" begin
        @test SeisRequests.seconds_milliseconds(5.9019) == Second(5) + Millisecond(901)
    end

    @testset "split_channel_code" begin
        @test SeisRequests.split_channel_code("AB,CD.*..BH?") ==
            (network="AB,CD", station="*", location="", channel="BH?")
        @test_throws ArgumentError SeisRequests.split_channel_code("A.B.C.D.")
        @test_throws ArgumentError SeisRequests.split_channel_code("A.B.C")
    end

    @testset "_error_on_control_characters" begin
        @test_throws ArgumentError SeisRequests._error_on_control_characters("https://example.com/\r")
        @test_throws ArgumentError SeisRequests._error_on_control_characters("https://example.com/\n")
        @test_throws ArgumentError SeisRequests._error_on_control_characters("https://example.com/\r\nHTTP")
        @test isnothing(SeisRequests._error_on_control_characters("https://example.com/HTTP"))
    end
end
