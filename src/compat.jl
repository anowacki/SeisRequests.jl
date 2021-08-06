# Compatibility with older Julia versions

# TODO: Remove when we drop support for v1.0
@static if VERSION < v"1.2"
    hasproperty(x, p) = p in propertynames(x)
end
