# chat, chat!, achat!
# chatcopy, chatedit (preview)

function prepare_chat_from_args(@nospecialize(labels), @nospecialize(args...); reset::Bool=true, historyrequired::Bool=false)
    @assert length(args) >= 1 "Length of args must be >=1 (provided: $(length(args)))"

    history = get_history()
    prompt = nothing
    message = nothing
    kwargs = (; user_schemas=Any[])

    for (idx, arg) in enumerate(args)
        ## Get ChatHistory to write to
        if idx == 1 && arg isa ChatHistory
            history = arg
            continue
        elseif idx == 1 && historyrequired
            error("ChatHistory must be provided")
        end
        ## Get other args and kwargs
        if arg isa Symbol || arg isa Vector{<:Symbol}
            prompt = arg
            set_prompt!(history, prompt)
        elseif arg isa AbstractString && isnothing(message)
            ## first string is considered to be the message
            message = arg
        elseif arg isa ChatMessageCode
            kwargs = merge(kwargs, (; user_code=arg))
        else
            # anything else goes to the user-provided data
            label = replace(labels[idx], ":" => "")
            push!(kwargs.user_schemas, (arg, label))
        end
    end
    ## reset chat if requested
    isnothing(prompt) && reset && reset_chat!(history)
    ## error if missing
    @assert !isnothing(message) "Message cannot be empty - provide a String-based message!"

    return history, message, kwargs
end

"""
Starts a new Chat and sends a message towards the selected model
"""
macro chat(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=true, historyrequired=false)
        get_response!($tmp_hist, $tmp_msg; $tmp_kwarg...)
    end |> esc
end

"""
Continues the provided ChatHistory and sends a message towards the selected model
"""
macro chat!(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=false, historyrequired=true)
        get_response!($tmp_hist, $tmp_msg; $tmp_kwarg...)
    end |> esc
end

"""
Continues the provided ChatHistory and sends an ASYNCHRONOUS message towards the selected model

Note: 
- use `istaskdone(m)` to check if the task is ready
- use `fetch(m)` to get the result (a blocking call!) 
"""
macro achat!(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=false, historyrequired=true)
        @async get_response!($tmp_hist, $tmp_msg; $tmp_kwarg...)
    end |> esc
end

## Fixes
macro chatfix()
    quote
        get_fix!($(get_history()))
    end |> esc
end
macro chatfix!(tmp_hist)
    quote
        get_fix!($tmp_hist)
    end |> esc
end


## Reflection strategy

"""
Starts a new Chat Reflection loop by sends a message towards the selected model.

Note: Uses at most 3 loops (`n_cycles=3`) at the moment
"""
macro chatreflect(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=true, historyrequired=false)
        reflection_cycle!($tmp_hist, $tmp_msg; n_cycles=3, $tmp_kwarg...)
    end |> esc
end

"""
Starts a Chat Reflection loop in the provided Chat History by sending a message towards the selected model.

Note: Uses at most 3 loops (`n_cycles=3`) at the moment
"""
macro chatreflect!(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=false, historyrequired=true)
        reflection_cycle!($tmp_hist, $tmp_msg; n_cycles=3, $tmp_kwarg...)
    end |> esc
end

"""
Starts a Chat Reflection loop in the provided Chat History by sending an ASYNCHRONOUS message towards the selected model.

Note: Uses at most 3 loops (`n_cycles=3`) at the moment
"""
macro achatreflect!(args...)
    tmp_labels = string.(args)
    tmp_hist = gensym("hist")
    tmp_msg = gensym("msg")
    tmp_kwarg = gensym("kwarg")
    quote
        $tmp_hist, $tmp_msg, $tmp_kwarg = $prepare_chat_from_args($tmp_labels, $(args...); reset=false, historyrequired=true)
        @async reflection_cycle!($tmp_hist, $tmp_msg; n_cycles=3, $tmp_kwarg...)
    end |> esc
end