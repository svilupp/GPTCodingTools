objectschema(any::Any, label="", prefix="") = "$prefix- `$label`: $(typeof(any))"
# For any string variables
objectschema(s::AbstractString, label, prefix="") = "$prefix- `$label`: $(typeof(s)) of length $(length(s))"
# pass directly
# objectschema(s::String) = s
# objectschema("ahoj", "s")
objectschema(v::AbstractVector{T}, label="", prefix="") where {T} = "$prefix- `$label`: $(typeof(v)) with total of $(length(v)) elements of type $(eltype(v)) ($(unique(v)|>length) of which are unique)"
# objectschema(ones(3), "ones")
# objectschema(["a", "b"], "ones")
function objectschema(df::AbstractDataFrame, label="")
    ["- `$label`: $(typeof(df)) with $(size(df,1)) rows and $(size(df,2)) columns like this",
        [objectschema(val, col, "  ") for (col, val) in pairs(eachcol(df))]...
    ]
end
# for testing: df = DataFrame(a=repeat(1:5, outer=20),
#     b=repeat(["a", "b", "c", "d"], inner=25), c=repeat(1:20, inner=5))


struct FunctionString
    code::String
end
code(fstr::FunctionString) = fstr.code
objectschema(fstr::FunctionString, label="", prefix="") = "$prefix- Function: $(wrap_code_block(code(fstr)))"
function Base.show(io::IO, mime::MIME"text/plain", fstr::FunctionString)
    Base.show(io, mime, fstr |> code |> wrap_code_block |> Markdown.parse)
end

