using Test, SeisRequests
using Dates: Second, Millisecond

@testset "Utils" begin
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
