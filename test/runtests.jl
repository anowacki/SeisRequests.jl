using SeisRequests
using Test

@testset "All tests" begin
    include("util.jl")
    include("fdsnws.jl")
    include("irisws.jl")
    include("high_level.jl")
    include("get_stations.jl")
    include("get_events.jl")
    include("get_data.jl")
end
