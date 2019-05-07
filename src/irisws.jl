"""
    IRISRequest

An abstract type representing requests conforming to the IRIS Web Services specification.

Current subtypes of `IRISRequest`:
- `IRISTimeSeries`
"""
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

const IRISTimeSeries_OUTPUT_TYPES = ("ascii1", "ascii2", "ascii", "geocsv", "geocsv.tspair",
    "geocsv.slist", "audio", "miniseed", "plot", "saca", "sacbb", "sacbl")

const IRISTimeSeries_FORMAT_TYPES = ("ascii1", "ascii2", "ascii", "geocsv", "geocsv.tspair",
    "geocsv.slist", "audio", "miniseed", "plot", "sac.zip")

"""
    IRISTimeSeries

Create an data query which can be sent to a datacentre which implements the IRIS
Web Services timeseries specification.

## Available options

### Channel Options (required)
The four SCNL parameters (Station – Channel – Network – Location) are used to determine
the channel of interest, and are all required. Wildcards are not accepted.

- `network`: Seismic network name
- `station`: Station name
- `location`: Location code. Use `loc=--` for empty location codes
- `channel`: Channel Code

### Date-Range Options (required)
Time ranges must be defined by specifying a start time with either an end time or a duration
in seconds.

For example, the following two time specifications are valid, and are equivalent.

#### Examples

    IRISTimeSeries([SCNL]..., starttime=Dates.DateTime(2005, 02, 23, 12), endtime=Dates.DateTime(2005, 02, 23, 12, 05))
    IRISTimeSeries([SCNL]..., starttime=Dates.DateTime("2005-02-23T12:00:00"), duration=300)

- `starttime`: Start time
- `endtime`: End time
- `duration`: Duration of requested data, in seconds

### Time Series Processing Options
The following parameters act as filters upon the timeseries. Parameter order matters
because each filter operation is performed in the order given.

#### Examples

    IRISTimeSeries(..., demean=true, lpfilter=2.0) # will demean and then apply a low-pass filter
    IRISTimeSeries(..., lpfilter=2.0, demean=true) # will apply a low-pass filter, and then demean

- `taper`: Apply a time domain symmetric tapering function to the timeseries data. The
  width is specified as a fraction of the trace length from 0 to 0.5.
- `taper_type`: Form of taper to apply.  Supported types: "HANNING" (default), "HAMMING", "COSINE".
  Note that all input is uppercased automatically.
- `envelope`: Calculate the envelope of the time series. This calculation uses a Hilbert
  transform approximated by a time domain filter
- `lpfilter`: Low-pass filter the time-series using an IIR 4th order filter, using this value
  (in Hertz) as the cutoff
- `hpfilter`: High-pass filter the time-series using an IIR 4th order filter, using this value
  (in Hertz) as the cutoff
- `bpfilter`: Band pass frequencies, in Hz.  This may be given as a length-2 tuple or AbstractArray,
  or as an AbstractString. (If the latter, then two values must be separated by either `-`, `/`, `,` or `;`.)
- `demean`: Remove mean value from data. `true` or `false` (default `false`).
- `scale`: Scale data samples by specified factor. When `scale="AUTO"` scales by the stage-zero gain.
  Mutually exclusive with `divscale`.
- `divscale`: Scale data samples by the inverse of the specified factor.  Mutually exclusive with
  `scale`.
- `correct`: Apply instrument correction to convert to earth units. `true` or `false`. Uses
  either deconvolution3,4 or polynomial response correction. (default `false`).
  Mutually exclusive with `scale="AUTO"`.
- `freqlimits`: Specify an envelope for a spectrum taper for deconvolution. Frequencies are
  specified in Hertz. This cosine taper scales the spectrum from 0 to 1 between f1 and f2 and
  from 1 to 0 between f3 and f4. Can only be used with the correct option. Cannot be used in
  combination with the autolimits option.
- `autolimits`: Automatically determine frequency limits for deconvolution. A pass band is
  determined for all frequencies with the lower and upper corner cutoffs defined in terms of
  dB down from the maximum amplitude. This algorithm is designed to work with flat responses,
  i.e. a response in velocity for an instrument which is flat to velocity. Other combinations
  will likely result in unsatisfactory results. Cannot be used in combination with the
  `freqlimits` option.
- `units`: Specify output units. Can be "DIS", "VEL", "ACC" or "DEF", where "DEF" results in no unit
  conversion.  `units` can only be used with `correct`.
- `diff`: Differentiate using 2 point (uncentered) method. `true` or `false` (default `false`)
- `int`: Integrate using trapezoidal (midpoint) method. `true` or `false` (default `false`)
- `decimate`: Sample-rate to decimate to. See [online help](http://service.iris.edu/irisws/timeseries/docs/1/help/#deci)
  for more details. A linear-phase, anti-alias filter is applied during decimation.

### Plot Options
- `antialias`: If true, the created image will have anti-aliasing used. Can only be specified
  with the `output=plot` option
- `width`: Width of the output plot (pixels). Can only be specified with the `output=plot` option
- `height`: Height of the output plot (pixels). Can only be specified with the `output=plot` option

### Audio Options
- `audiosamplerate`: The sample rate of the output wav file in Hz. Defaults to 16000.
  Can only be specified with the output=audio option
- `audiocompress`: Apply dynamic range compression to waveform data. This makes more of the
  signal audible. Can only be specified with the output=audio option

## Format options (required)

Provide one of the following to determine the output format with the `format` option:

|Value|Description|
|:----|:----------|
|`ascii1`|ASCII data format, 1 column (values)|
|`ascii2`|ASCII data format, 2 columns (time, value)|
|`ascii`|Same as `ascii2`|
|`geocsv`, `geocsv.tspair`|ASCII GeoCSV data format, 2 columns (time, values)|
|`geocsv.slist`|ASCII geocsv data format, 1 column (value)|
|`audio`|Audio WAV file|
|`miniseed`|FDSN miniSEED format [default]|
|`plot`|A simple plot of the timeseries in PNG format|
|`sac.zip`|SAC Zipped binary traces|

The following are deprecated and can only be used with the `output` option, which cannot
be combined with the `format` option:

|Value|Description|
|:----|:----------|
|`saca`|SAC – ASCII format [deprecated and used with `output`]|
|`sacbb`|SAC – binary big-endian format [deprecated and used with `output`]|
|`sacbl`|SAC – binary little-endian format [deprecated and used with `output`]|

As these outputs are deprecated, they may stop working in the future.
"""
struct IRISTimeSeries <: IRISRequest
    network::String
    station::String
    location::String
    channel::String
    starttime::DateTime
    endtime::MDateTime
    duration::MFloat
    antialias::MBool
    width::MInt
    height::MInt
    audiosamplerate::MInt
    audiocompress::MBool
    output::MString
    format::MString
    process::OrderedDict{Symbol,Any} # Because order matters for processing

    function IRISTimeSeries(network, station, location, channel, starttime, endtime, duration,
                            antialias, width, height, audiosamplerate, audiocompress, output,
                            format, process)
        location in ("  ", "") && (location = "--")
        !ismissing(starttime) && !ismissing(endtime) && starttime > endtime &&
            throw(ArgumentError("`starttime` must be before endtime"))
        coalesce(duration, 1) > 0 || throw(ArgumentError("`duration` must be positive"))
        0 <= get(process, :taper, 0.1) <= 0.5 ||
            throw(ArgumentError("`taper` length must be between 0 and 0.5"))
        # Check types for processing
        for (f, T) in IRISTimeSeries_PROCESSING_FIELDS
            if haskey(process, f)
                try
                    if T <: Tuple
                        # Convert arrays
                        process[f] = convert(T, tuple(process[f]...))
                    else
                        process[f] = convert(T, process[f])
                    end
                catch err
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
        haskey(process, :lpfilter) && process[:lpfilter] <= 0 &&
            throw(ArgumentError("Low-pass filter cutoff must be greater than 0 Hz"))
        haskey(process, :hpfilter) && process[:hpfilter] <= 0 &&
            throw(ArgumentError("High-pass filter cutoff must be greater than 0 Hz"))
        if haskey(process, :bpfilter)
            0 < process[:bpfilter][1] < process[:bpfilter][2] ||
                throw(ArgumentError("Low-pass corner of band-pass filter must be above high-pass corner"))
        end
        if haskey(process, :scale)
            haskey(process, :divscale) &&
                        throw(ArgumentError("Cannot specify both `scale` and `divscale`"))
            if process[:scale] isa AbstractString
                process[:scale] = uppercase(process[:scale])
                process[:scale] == "AUTO" || throw(ArgumentError("`scale` must be a float or \"AUTO\""))
                get(process, :correct, false) &&
                    throw(ArgumentError("Cannot specify both `correct` and `scale=\"AUTO\"`"))
            end
        end
        if haskey(process, :freqlimits)
            get(process, :correct, false) ||
                throw(ArgumentError("`freqlimits` can only be used when `correct`=`true`"))
            f1, f2, f3, f4 = process[:freqlimits]
            0 < f1 < f2 < f3 < f4 || 
                throw(ArgumentError("`freqlimits` must increase monotonically and all be positive"))
        end
        if haskey(process, :units)
            get(process, :correct, false) ||
                throw(ArgumentError("`units` can only be used when `correct` is `true`"))
            process[:units] in ("DIS", "VEL", "ACC", "DEF") ||
                throw(ArgumentError("`units` must be one of \"DIS\", \"VEL\", \"ACC\" or \"DEF\""))
        end
        haskey(process, :autolimits) && haskey(process, :freqlimits) &&
            throw(ArgumentError("Cannot specify both `autolimits` and `freqlimits`"))
        
        # Disallowed combinations
        coalesce(audiocompress, false) || !ismissing(audiosamplerate) && output != "audio" &&
            throw(ArgumentError("Cannot specify `audiocompress` if `output` is not \"audio\""))
        count(ismissing, (output, format)) == 1 ||
            throw(ArgumentError("One and only one of `output` and `format` must be specified"))
        
        # Disallowed values
        (!ismissing(output) && output ∉ IRISTimeSeries_OUTPUT_TYPES) &&
            throw(ArgumentError("`output` ($output) must be one of $(IRISTimeSeries_OUTPUT_TYPES)"))
        (!ismissing(format) && format ∉ IRISTimeSeries_FORMAT_TYPES) &&
            throw(ArgumentError("`format` ($output) must be one of $(IRISTimeSeries_FORMAT_TYPES)"))

        new(network, station, location, channel, starttime, endtime, duration,
            antialias, width, height, audiosamplerate, audiocompress, output, format, process)
    end
end

function IRISTimeSeries(;
                        network=missing, station=missing, location=missing, channel=missing,
                        starttime=missing, endtime=missing, duration=missing, antialias=missing,
                        width=missing, height=missing, audiosamplerate=missing,
                        audiocompress=missing, output=missing, format=missing, kwargs...)
    any(ismissing, (network, station, location, channel, starttime)) &&
        throw(ArgumentError("network, station, location, channel and starttime, plus one of " *
                            "endtime or duration, must all be specified"))
    count(ismissing, (endtime, duration)) == 1 ||
        throw(ArgumentError("One and only one of `endtime` or `duration` must be specified"))
    process = OrderedDict{Symbol,Any}()
    for (k, v) in kwargs
        k in keys(IRISTimeSeries_PROCESSING_FIELDS) ||
            throw(ArgumentError("Field `$k` is not a valid IRISTimeSeries processing field"))
        process[k] = v
    end
    IRISTimeSeries(network, station, location, channel, starttime, endtime, duration,
                   antialias, width, height, audiosamplerate, audiocompress, output,
                   format, process)
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
