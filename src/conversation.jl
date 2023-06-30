function response_cost(usage_stats::Dict{Symbol,Int64}, model::AbstractAIModel)
    return (cost_prompt(model) * get(usage_stats, :prompt_tokens, 0) / 1000
            +
            cost_completion(model) * get(usage_stats, :completion_tokens, 0) / 1000
    )
end
function response_stats(elapsed_time::Number=0.0, cost::Float64=0.0, usage_stats::Dict{Symbol,Int64}=Dict{Symbol,Int64}())
    if !isempty(usage_stats)
        usage = join(["$(string(k)): $(round(v/1000;digits=1))K" for (k, v) in pairs(usage_stats)], ", ")
    else
        usage = "N/A"
    end
    msg = "Finished: Duration: $(round(elapsed_time;digits=1))s, Cost: $(round(cost;digits=1)) with $usage"
    return msg
end

function call_model_api(provider::OpenAI.AbstractOpenAIProvider, model::AbstractAIModel, history::ChatHistory;
    pop_last_msg_on_fail::Bool=true)

    # TODO: check if context is already at 8000 tokens!
    r = OpenAI.create_chat(provider, label(model), to_openai(history); http_kwargs=(; readtimeout=300))
    if r.status != 200
        pop_last_msg_on_fail && pop!(history)
        error("OpenAI API call failed with status code $(r.status)")
    end
    response = r.response[:choices][begin][:message][:content]
    usage_stats = get(r.response, "usage", Dict{Symbol,Int64}()) |> Dict{Symbol,Int64}
    return response, usage_stats
end

function build_user_message(message::AbstractString; user_schemas=[],
    user_code::Union{Nothing,ChatMessageCode}=nothing, errors::AbstractString="", role::String="user", skipcode::Bool=false)
    # Add any user_data provided
    messages = []
    if skipcode
        user_code = ChatMessageCode(""; isvalidcode=false)
    elseif !isnothing(user_code)
        push!(messages, "User Provided Code:\n")
        push!(messages, code(user_code) |> wrap_code_block)
        push!(messages, "\n")
    end
    if !isempty(user_schemas)
        schemas = [item isa Tuple ? objectschema(item...) : objectschema(item) for item in user_schemas]
        if !isempty(schemas)
            push!(messages, "User Provided Data:\n")
            append!(messages, schemas)
            push!(messages, "\n")
        end
    end
    if !isempty(errors)
        push!(messages, "Errors found:\n")
        push!(messages, errors)
        push!(messages, "\n")
    end
    push!(messages, message)
    message_with_data = join(messages, "\n")

    return ChatMessage(message_with_data, role, user_code; code_healing=false)
end

# extract any previously sent valid code blocks
past_code_blocks(hist::ChatHistory) = filter(x -> hasvalidcode(x), messages(hist)) .|> code .|> code |> x -> join(x, "\n")

"""
    get_response!(history::ChatHistory, message::AbstractString;
        code_healing::Bool=true, user_schemas=Any[], user_code::Union{Nothing,ChatMessageCode}=nothing, 
        errors::AbstractString="",
        skipcode::Bool=false, mockrun::Bool=false, break_if_unsafe::Bool=true)

Sends `message` towards the API including the `history` (which includes the prompt etc.)

See also: `get_fix!` and `chatreflect!`
"""
function get_response!(history::ChatHistory, message::AbstractString;
    code_healing::Bool=true, user_schemas=Any[], user_code::Union{Nothing,ChatMessageCode}=nothing, errors::AbstractString="",
    skipcode::Bool=false, mockrun::Bool=false, break_if_unsafe::Bool=true)

    global MODEL, PROVIDER

    # Inputs to the model
    input_msg = build_user_message(message; user_schemas, user_code, errors, skipcode)
    push!(history, input_msg)
    @info "User message built..."

    if mockrun
        @info "Mock run - Returning input message..."
        return input_msg
    end

    t = @elapsed response, usage_stats = call_model_api(PROVIDER[1], MODEL[1], history; pop_last_msg_on_fail=true)
    @info "Response received..."

    cost = response_cost(usage_stats, MODEL[1])

    output_msg = ChatMessage(response, "assistant"; code_healing, cost, duration=t,
        previous_code=past_code_blocks(history), break_if_unsafe)
    push!(history, output_msg)

    @info response_stats(t, cost, usage_stats)

    ## throw error
    if break_if_unsafe && hasunsafecode(output_msg)
        error(codeerror(output_msg) * " -> Inspect the last message in the history to get more details")
    end

    return output_msg
end

# Dispatch to global conversation
get_response(message::AbstractString; kwargs...) = get_response!(HISTORY, message; kwargs...)

"""
    get_fix!(history::ChatHistory, message::AbstractString=""; skipcode::Bool=true)

Requests a fix of the last message in the ChatHistory (it has have an error to provide!)

See also: `codeerror`, `hasvalidcode`
"""
function get_fix!(history::ChatHistory, message::AbstractString=""; skipcode::Bool=true)
    @assert !isempty(history) "History is empty. Please provide a message to fix."

    errors = history |> last |> codeerror
    @assert !isempty(errors) "Last message did not throw an error. Please provide a message to fix."

    if isempty(message)
        message = "Explain the errors and provide new code that works and satisfies the original requirements.\nErrors can be fixed by:\n"
    end

    return get_response!(history, message; errors, skipcode)
end

"""
    reflection_cycle!(history::ChatHistory, message::AbstractString; n_cycles::Int=3, break_if_unsafe::Bool=true, kwargs...)

Pass `message` to the API. Starts a `n_cycles` loop that will ask the model to fix its response if it fails to execute (or fails its tests)
"""
function reflection_cycle!(history::ChatHistory, message::AbstractString; n_cycles::Int=3, break_if_unsafe::Bool=true, kwargs...)
    local msg = get_response!(history, message; break_if_unsafe, kwargs...)
    for i in 1:n_cycles
        @info ">>> Reflection cycle $i"
        if !hasvalidcode(msg) && !isempty(codeerror(msg))
            @info ">>> Errors found. Requesting fix..."
            msg = get_fix!(history)
        else
            @info ">>> Reflection finished in cycle $i"
            break
        end
    end
    return last(history)
end

"""
    reset_chat!()
    reset_chat!(history::ChatHistory

Resets the chat to the initial state, but remembers the previous prompt.

If no argument is provided, it resets the global history 
"""
function reset_chat!(history::ChatHistory=HISTORY)
    global HISTORY_PREVIOUS

    prompt = get_prompt(history)

    # Remember the previous conversation
    empty!(HISTORY_PREVIOUS)
    for msg in history
        push!(HISTORY_PREVIOUS, msg)
    end

    # Set up a new conversation
    empty!(history)
    !isnothing(prompt) && set_prompt!(prompt)

    return history
end

"""
    get_history()

Get global ChatHistory (will be overwritten with the next chat)
"""
get_history(hist::ChatHistory=HISTORY) = hist
"""
    set_model!(model::AbstractAIModel)

Replaces the `model` to be used for API calls
"""
set_model!(model::AbstractAIModel) = (global MODEL[1] = model)
"""
    set_provider!(provider::OpenAI.AbstractOpenAIProvider)

Replaces the OpenAI-like provider. See `https://juliaml.github.io/OpenAI.jl/dev/`
"""
set_provider!(provider::OpenAI.AbstractOpenAIProvider) = (global PROVIDER[1] = provider)


# Saving
timestamp_json(str::String) = replace(str, ".json" => "_$(Dates.format(now(), "yyyymmdd_HHMMSSsss")).json")
"""
    save_chat(hist::ChatHistory, fname=joinpath("history", timestamp_json("chat.json")))

Saves a provided history to a file `fname` (defaults to a timestamped JSON file in "history/" folder, which will be auto-created)
"""
function save_chat(hist::ChatHistory, fname=joinpath("history", timestamp_json("chat.json")))
    mkpath(dirname(fname))
    open(fname, "w") do io
        JSON3.write(io, hist)
    end
end
"""
    load_chat(fname::String)

Loads a past conversation history from a file `fname`
"""
function load_chat(fname::String)
    open(fname, "r") do io
        JSON3.read(io, ChatHistory)
    end
end