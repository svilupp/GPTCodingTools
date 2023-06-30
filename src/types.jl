## Model Object
abstract type AbstractAIModel end
struct MockModel <: AbstractAIModel
    label::String
    cost_prompt::Float64
    cost_completion::Float64
    response::String
end
struct AIModel <: AbstractAIModel
    label::String
    cost_prompt::Float64
    cost_completion::Float64
end
function AIModel(label::String; cost_prompt::Float64=0.0, cost_completion::Float64=0.0)
    return AIModel(label, cost_prompt, cost_completion)
end
label(m::AbstractAIModel) = m.label
cost_prompt(m::AbstractAIModel) = m.cost_prompt
cost_completion(m::AbstractAIModel) = m.cost_completion

## Chat Object
abstract type AbstractChatElements end
Base.show(io::IO, c::AbstractChatElements; kwargs...) = Base.show(io, MIME"text/plain"(), c; kwargs...)

struct ChatMessageCode <: AbstractChatElements
    code::Union{String,SubString{String}}
    imports::Vector{<:Symbol}
    isvalidcode::Bool
    isunsafecode::Bool
    error::String
end
function ChatMessageCode(code::Union{String,SubString{String}}; isvalidcode::Union{Bool,Nothing}=nothing,
    previous_code::String="", break_if_unsafe::Bool=true)

    # override isvalid if any "unsafe signal" is triggered
    imports = extract_julia_imports(code)
    unsafecode, out = is_code_unsafe(code, imports)
    if !break_if_unsafe && unsafecode
        # at least warn the user there migth be an issue
        @warn out
    end

    # continue the evaluation
    if break_if_unsafe && unsafecode
        success = !unsafecode
    elseif isnothing(isvalidcode)
        success, out = safe_parse_and_eval(previous_code * "\n" * code)
    else
        success = isvalidcode
        out = nothing
    end
    error = isnothing(out) ? "" : out
    return ChatMessageCode(code, imports, success, unsafecode, error)
end

code(c::ChatMessageCode) = c.code
imports(c::ChatMessageCode) = c.imports
isvalidcode(c::ChatMessageCode) = c.isvalidcode
isunsafecode(c::ChatMessageCode) = c.isunsafecode
codeerror(c::ChatMessageCode) = c.error
function Base.show(io::IO, mime::MIME"text/plain", c::ChatMessageCode)
    Base.show(io, mime, code(c) |> wrap_code_block |> Markdown.parse)
end
Base.var"=="(c1::ChatMessageCode, c2::ChatMessageCode) = code(c1) == code(c2)

struct ChatMessage <: AbstractChatElements
    message::String
    role::String
    code::ChatMessageCode
    cost::Float64
    duration::Float64
end

function ChatMessage(message::String, role::String="user", code::Union{ChatMessageCode,Nothing}=nothing;
    cost::Float64=0.0, duration::Float64=0.0, code_healing::Bool=true,
    isvalidcode::Union{Bool,Nothing}=nothing, previous_code::String="",
    break_if_unsafe::Bool=true)

    code_healing && (message = heal_code_block(message))
    if isnothing(code)
        success, code_str = extract_code_block(message)
        isvalidcode = (isnothing(isvalidcode) && (success == false)) ? success : isvalidcode
        code = ChatMessageCode(code_str; isvalidcode, previous_code, break_if_unsafe)
    end
    ChatMessage(message, role, code, cost, duration)
end
preview(c::ChatMessage) = """# Chat Message from: $(role(c)) (Valid Code: $(hasvalidcode(c)|>string|>uppercase))\n$(message(c))\n\n"""
function Base.show(io::IO, mime::MIME"text/plain", c::ChatMessage; code_only::Bool=false)
    if code_only
        Base.show(io, code(c))
    else
        Base.show(io, mime, Markdown.parse(preview(c)))
    end
end

role(c::ChatMessage) = c.role
isuser(c::ChatMessage) = c.role == "user"
issystem(c::ChatMessage) = c.role == "system"
message(c::ChatMessage) = c.message
code(c::ChatMessage) = c.code
codeerror(c::ChatMessage) = codeerror(code(c))
hasvalidcode(c::ChatMessage) = isvalidcode(code(c))
hasunsafecode(c::ChatMessage) = isunsafecode(code(c))
cost(c::ChatMessage) = c.cost
duration(c::ChatMessage) = c.duration
Base.var"=="(c1::ChatMessage, c2::ChatMessage) = message(c1) == message(c2) && role(c1) == role(c2) && code(c1) == code(c2)

struct ChatHistory <: AbstractChatElements
    messages::Vector{<:ChatMessage}
    messagethreads::Vector{<:Int}
    visibility::BitVector
end
ChatHistory() = ChatHistory(Vector{ChatMessage}(), Int[], trues(0))
messages(c::ChatHistory) = c.messages
messagethreads(c::ChatHistory) = c.messagethreads
visibility(c::ChatHistory) = c.visibility

Base.getindex(c::ChatHistory, i::Int) = messages(c)[i]
Base.getindex(c::ChatHistory, vect::AbstractVector{<:Int}) = ChatHistory(messages(c)[vect])
Base.setindex!(c::ChatHistory, m::ChatMessage, i::Int) = messages(c)[i] = m
Base.firstindex(c::ChatHistory) = firstindex(messages(c))
Base.lastindex(c::ChatHistory) = lastindex(messages(c))
Base.size(c::ChatHistory) = size(messages(c))
Base.length(c::ChatHistory) = length(messages(c))
Base.show(io::IO, mime::MIME"text/plain", c::ChatHistory) = Base.show(io, mime, "ChatHistory with $(length(c)) messages")
Base.iterate(c::ChatHistory, i::Int=1) = i > length(c) ? nothing : (c[i], i + 1)
function Base.push!(c::ChatHistory, m::ChatMessage; isvisible::Bool=true, thread::Int=1)
    push!(visibility(c), isvisible)
    push!(messagethreads(c), thread)
    push!(messages(c), m)
end
Base.pop!(c::ChatHistory) = (pop!(visibility(c)); pop!(messagethreads(c)); pop!(messages(c)))
Base.copy(c::ChatHistory) = ChatHistory(copy(messages(c)), copy(messagethreads(c)), copy(visibility(c)))
Base.empty!(c::ChatHistory) = (empty!(visibility(c)); empty!(messagethreads(c)); empty!(messages(c)))
Base.var"=="(c1::ChatHistory, c2::ChatHistory) = all(messages(c1) .== messages(c2) .&& messagethreads(c1) .== messagethreads(c2) .&& visibility(c1) .== visibility(c2))

countlines_string(s::AbstractString) = countlines(IOBuffer(s))
"Opens the chat history in a preview window formatted as markdown"
function InteractiveUtils.edit(c::ChatHistory, bookmark::Int=-1)
    filename = tempname() * ".md"
    line = bookmark
    line_count = 0
    io = IOBuffer()
    ## write all messages into IO
    for (i, msg) in enumerate(c)
        txt = preview(msg)
        if i == bookmark
            line = line_count + 1
        end
        print(io, txt)
        line_count += countlines_string(txt)
    end
    open(filename, "w") do f
        write(f, String(take!(io)))
    end
    # which line to open on, if negative, open on last line
    line = line < 0 ? line_count : line
    # open the file in a preview window in a default editor
    edit(filename, line)
end
#
to_dict(c::ChatHistory, visibility=trues(length(c))) = messages(c)[visibility] .|> to_dict
to_openai(c::ChatHistory, visibility::BitVector=visibility(c)) = messages(c)[visibility] .|> to_openai

# change to `to_openai` // dict to be general
to_openai(c::ChatMessage) = Dict("role" => role(c), "content" => message(c))
to_dict(c::ChatMessageCode) = Dict("code" => code(c), "isvalidcode" => isvalidcode(c), "isunsafecode" => isunsafecode(c),
    "error" => codeerror(c), "imports" => imports(c))
to_dict(c::ChatMessage) = Dict("message" => message(c), "role" => role(c), "code" => to_dict(code(c)), "cost" => cost(c), "duration" => duration(c))

# Conversions to de-serialize via JSON3
StructTypes.StructType(::Type{ChatMessage}) = StructTypes.Struct()
StructTypes.StructType(::Type{ChatMessageCode}) = StructTypes.Struct()
StructTypes.StructType(::Type{ChatHistory}) = StructTypes.Struct()
Vector{<:ChatMessage}(x::Vector{Any}) = ChatMessage.(x)
ChatMessage(d::Dict{String,Any}) = ChatMessage(d["message"], d["role"], ChatMessageCode(d["code"]), d["cost"], d["duration"])
ChatMessageCode(d::Dict{String,Any}) = ChatMessageCode(get(d, "code", ""), get(d, "imports", Symbol[]),
    get(d, "isvalidcode", false), get(d, "isunsafecode", false), get(d, "error", ""))