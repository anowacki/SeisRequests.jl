# Tests for helper functions in src/high_level.jl.
# Tests for get_* functions are in test/get_*.jl.

using SeisRequests, Test

import StationXML

@testset "High-level" begin
    @testset "filter_xml" begin
        sxml = StationXML.FDSNStationXML(source="Me", created=DateTime("2000-01-01"),
        schema_version="1.1")
        net1 = StationXML.Network(code="AN")
        net2 = StationXML.Network(code="BO")
        sta1 = StationXML.Station(code="FAKE", longitude=1, latitude=2, elevation=3,
            site=StationXML.Site(name="Fake site"))
        sta2 = StationXML.Station(code="FAKE2", longitude=2, latitude=3, elevation=4,
            site=StationXML.Site(name="Fake site 2"))
        cha1 = StationXML.Channel(code="UHT", longitude=10, latitude=20, elevation=30,
            depth=40, location_code="")
        cha2 = StationXML.Channel(code="XYZ", longitude=20, latitude=30, elevation=40,
            depth=50, location_code="00")

        # sxml′ is the filtered version, sxml″ is the correct one
        @testset "Network" begin
            sxml′ = deepcopy(sxml)
            sxml″ = deepcopy(sxml)
            append!(sxml′.network, deepcopy([net1, net2]))
            push!(sxml″.network, deepcopy(net1))
            @test SeisRequests.filter_stationxml(sxml′, net1) == sxml″
        end

        @testset "Station" begin
            sxml′ = deepcopy(sxml)
            sxml″ = deepcopy(sxml)
            append!(sxml′.network, deepcopy([net1, net2]))
            for n in sxml′.network
                append!(n.station, deepcopy([sta1, sta2]))
            end
            push!(sxml″.network, deepcopy(net1))
            push!(sxml″.network[1].station, deepcopy(sta1))
            @test SeisRequests.filter_stationxml(sxml′, net1, sta1) == sxml″
        end

        @testset "Channel" begin
            sxml′ = deepcopy(sxml)
            sxml″ = deepcopy(sxml)
            append!(sxml′.network, deepcopy([net1, net2]))
            for n in sxml′.network
                append!(n.station, deepcopy([sta1, sta2]))
                for s in n.station
                    append!(s.channel, deepcopy([cha1, cha2]))
                end
            end
            push!(sxml″.network, deepcopy(net1))
            push!(sxml″.network[1].station, deepcopy(sta1))
            push!(sxml″.network[1].station[1].channel, deepcopy(cha1))
            @test SeisRequests.filter_stationxml(sxml′, net1, sta1, cha1) == sxml″
        end
    end

    @testset "_getifnotmissing" begin
        @test SeisRequests._getifnotmissing((a=1, b=missing), :a) == 1
        @test SeisRequests._getifnotmissing(missing, :a) === missing
    end
end