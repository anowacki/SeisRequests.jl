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
end
