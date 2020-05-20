using SeisRequests
using Test

@testset "All tests" begin
    include("util.jl")
    include("fdsnws.jl")
    include("irisws.jl")
end
