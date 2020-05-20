# Input/output

function Base.show(io::IO, ::MIME"text/plain", r::T) where {T<:SeisRequest}
    print(io, T, ":\n  ")
    println(io, join(["$f = $(repr(getfield(r, f)))" for f in fieldnames(T)], "\n  "))
end

function Base.show(io::IO, r::T) where {T<:SeisRequest}
    print(io, T, "(")
    print(io, join(["$f=$(repr(getfield(r, f)))"
                    for f in fieldnames(T) if getfield(r, f) !== missing], ", "))
    print(io, ")")
end
