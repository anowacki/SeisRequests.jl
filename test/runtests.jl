using SeisRequests
using Test

@testset "All tests" begin
    include("fdsnws.jl")
    include("irisws.jl")
end
