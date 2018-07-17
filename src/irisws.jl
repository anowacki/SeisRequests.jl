abstract type IRISRequest <: SeisRequest end

protocol_string(::IRISRequest) = "irisws"

"Available processing filters and allowable types for them"
const IRISTimeSeries_PROCESSING_FIELDS = Dict(
    :taper => Real,
    :taper_type => AbstractString,
    :envelope => Bool,
    :lpfilter => Real,
    :hpfilter => Real,
    :bpfilter => Tuple{Number,Number},
    :demean => Bool,
    :scale => Union{Real,AbstractString},
    :divscale => Real,
    :correct => Bool,
    :freqlimits => Tuple{Number,Number,Number,Number},
    :autolimits => Union{AbstractString,Tuple{Number,Number}},
    :units => AbstractString,
    :diff => Bool,
    :int => Bool,
    :decimate => Real)

struct IRISTimeSeries <: IRISRequest
    network::String
    station::String
    location::String
    channel::String
    starttime::DateTime
    endtime::DateTime
    duration::MFloat
    antialias::MBool
    width::MInt
    height::MInt
    audiosamplerate::MInt
    audiocompress::MBool
    output::String
    process::OrderedDict{Symbol,Any} # Because order matters for processing

    function IRISTimeSeries(network, station, location, channel, starttime, endtime, duration,
                            antialias, width, height, audiosamplerate, audiocompress, output,
                            process)
        location == "  " && (location = "--")
        !ismissing(starttime) && !ismissing(endtime) && starttime > endtime &&
            throw(ArgumentError("`starttime` must be before endtime"))
        coalesce(duration, 1) > 0 || throw(ArgumentError("`duration` must be positive"))
        0 <= get(process, :taper, 0.1) <= 1 || throw(ArgumentError("`taper` length must be between 0 and 1"))
        # Check types for processing
        for (f, T) in IRISTimeSeries_PROCESSING_FIELDS
            if haskey(process, f)
                try
                    process[f] = convert(T, process[f])
                catch err
                    err isa MethodError || err isa InexactError &&
                        throw(ArgumentError("field `$f` must be of type $T"))
                    rethrow(err)
                end
            end
        end
        if haskey(process, :taper_type)
            haskey(process, :taper) || throw(ArgumentError("`taper_type` must be specficied with taper"))
            taper_type = uppercase(process[:taper_type])
            taper_type in ("HANNING", "HAMMING", "COSINE") ||
            throw(ArgumentError("taper_type must be one of \"HANNING\", \"HAMMING\" or \"COSINE\""))
        end
        haskey(process, :scale) && haskey(process, :divscale) &&
            throw(ArgumentError("Cannot specify both `scale` and `divscale`"))
        if haskey(process, :scale)
            if process[:scale] isa AbstractString
                process[:scale] = uppercase(process[:scale])
                process[:scale] == "AUTO" || throw(ArgumentError("`scale` must be a float or \"AUTO\""))
            end
        end
        if haskey(process, :units)
            !haskey(process, :correct) || !process[:correct] &&
                throw(ArgumentError("`units` can only be used when correct is true"))
            process[:units] in ("DIS", "VEL", "ACC", "DEF") ||
                throw(ArgumentError("`units` must be one of \"DIS\", \"VEL\", \"ACC\" or \"DEF\""))
        end
        haskey(process, :autolimits) && haskey(process, :freqlimits) &&
            throw(ArgumentError("Cannot specify both `autolimits` and `freqlimits`"))
        
        coalesce(audiocompress, false) || !ismissing(audiosamplerate) && output != "audio" &&
            throw(ArgumentError("Cannot specify `audiocompress` if `output` is not \"audio\""))
        
        new(network, station, location, channel, starttime, endtime, duration,
            antialias, width, height, audiosamplerate, audiocompress, output, process)
    end
end

function IRISTimeSeries(;
                        network=missing, station=missing, location=missing, channel=missing,
                        starttime=missing, endtime=missing, duration=missing, antialias=missing,
                        width=missing, height=missing, audiosamplerate=missing,
                        audiocompress=missing, output=missing, kwargs...)
    any(ismissing, (network, station, location, channel, starttime, endtime, output)) &&
        throw(ArgumentError("network, station, location, channel, starttime, endtime " *
                            "and output must all be specified"))
    process = OrderedDict{Symbol,Any}()
    for (k, v) in kwargs
        k in keys(IRISTimeSeries_PROCESSING_FIELDS) ||
            throw(ArgumentError("Field `$k` is not a valid IRISTimeSeries processing field"))
        process[k] = v
    end
    IRISTimeSeries(network, station, location, channel, starttime, endtime, duration,
                   antialias, width, height, audiosamplerate, audiocompress, output,
                   process)
end

# To be the same as the structs which use Parameters.@with_kw
Base.show(io::IO, p::SeisRequests.IRISTimeSeries) = dump(IOContext(io, :limit => true), p, maxdepth=1)

service_string(::IRISTimeSeries) = "timeseries"

function request_uri(r::IRISTimeSeries; server=DEFAULT_SERVER)
    server = server in keys(SERVERS) ? SERVERS[server] : server
    protocol = protocol_string(r)
    service = service_string(r)
    version = version_string(r)
    uri = join((server, protocol, service, version, "query?"), "/")
    firstfield = true
    for f in fieldnames(typeof(r))
        if f == :process
            for (field, v) in r.process
                field_val = if field == :taper
                    value = "$v"
                    if haskey(r.process, :taper_type)
                        value = join((value, uppercase(r.process[:taper_type])), ",")
                    end
                    "$field=$value"
                elseif field == :taper_type
                    continue
                elseif field in (:bpfilter, :freqlimits, :autolimits)
                    "$field=$(join(v, "-"))"
                else
                    "$field=$v"
                end
                @assert !firstfield # process is the last field
                uri = join((uri, field_val), "&")
            end
        else
            v = getfield(r, f)
            if !ismissing(v)
                if firstfield
                    uri *= "$f=$v"
                    firstfield = false
                else
                    uri = join((uri, "$f=$v"), "&")
                end
            end
        end
    end
    uri
end
