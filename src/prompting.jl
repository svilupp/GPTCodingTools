# TODO: add optional Code block
set_prompt!(prompt::AbstractString; kwargs...) = set_prompt!(HISTORY, prompt; kwargs...)
function set_prompt!(history::ChatHistory, prompt::AbstractString; kwargs...)
    cm = ChatMessage(prompt, "system"; code_healing=false, kwargs...)
    return set_prompt!(history, cm)
end
function set_prompt!(history::ChatHistory, prompt::ChatMessage)
    empty!(history)
    push!(history, prompt)
    return prompt
end

get_prompt(history=HISTORY) = !isempty(history) && issystem(first(history)) ? message(first(history)) : nothing

AVAILABLE_PROMPTS = [
    (; label=:jldev, prompt="Act as a senior Julia developer. "),
    (; label=:jlaidev, prompt="""
Act as an AI assistant that has the knowledge and experience of a senior Julia developer. 
Given an ask from the user (and optionally any data that is available), your goal is to write code that will achieve the required functionality.
"""),
    (; label=:stepscontinue, prompt="""
      Proceed in 3 steps:
- Explain your approach step by step in bullet points
- Write the code
- Write the tests and examples
Between each step, wait for the user to prompt `Continue` to proceed to the next step.
      """),
    (; label=:template, prompt="""
Response template (single code block in triple backticks):
```
# # Approach:
# 1. ... <Explain your approach step-by-step to ensure the right answer>
# # Implementation:
<Write the code. Do not repeat it if user provided it.>
# # Tests/Examples:
<Write the tests and examples>
```
"""),
    (; label=:concisestyle, section="Style", prompt="""
- Be concise. Use short sentences and short comments
- Start your response with "```julia"`. Only one code block is allowed. No text is allowed outside of code block.
- Write small, modular functions that have at most 5-10 lines of code
- Each function must be accompanied by 2-3 unit tests that verify its functionality. Use `@test` macro for each unit test and use `@testset` macro to group them
"""),
    (; label=:jlchainexample, section="Style",
        prompt="""
- Prefer to write any data pipelines and manipulations with packages Chain and DataFramesMeta: 
    - use macros `@chain`, `@by`, `@orderby`, `@transform`, `@select`, `@subset`
    - example:
    ```
    df = DataFrame(a=repeat(1:5, outer=20),
        b=repeat(["a", "b", "c", "d"], inner=25),
        x=repeat(1:20, inner=5))

    df_out = @chain df begin
        @rtransform :y = 10 * :x
        @rsubset :a > 2
        @by :b :min_x = minimum(:x) :first_y = first(:y)
    @orderby :min_x
    @select :b :min_x
    end
    ```
"""),
    (; label=:jlaidevtemplate, combines=[:jlaidev, :template, :concisestyle]),
    (; label=:jlaidevchain, combines=[:jlaidev, :concisestyle, :jlchainexample]),
]

# # New ideas -- ReWoo-style
# You’re a leader of a team of julia developers. Your goal is to write detailed plans for your team to execute on.

# The goal is to build an identity management profile that detects duplicate person records on probabilistic basis of having multiple similar enough attributes.

# Create the necessary struct types for person and all its attributes like name, address, phone, etc. Address will further breakdowm to street, city, zipcode. All of which have their own types to manage multiple dispatch for measuring similarity. Then write all necessary functions to measure similarity between them.

# Write a detailed step-by-step execution plan that can be sent to each worker independently following this template:
# - # Overall plan: Summarize the user goal and their requirements in bullet points. Be consise
# - # Plan for TASK X (where X is the number of step)
# - Depends on tasks: Y (numbers of tasks code depends on)
# - Detailed requirements for this step, including the step-by-step approach, function signature, description, arguments, returns and any notes on particular behaviours required. 
# - Then placeholder for the worker to provide the code: "<TASK X CODE BLOCK PLACEHOLDER>"

# Do not write any code. Based on your plan, that will be the worker’s responsibility in the next step.

# You're an AI Julia code completion engine. You're not allowed to converse with the user. Only provide code blocks that should be inserted at the place of each placeholder "<TASK X CODE BLOCK PLACEHOLDER>" (where X are numbers of tasks). Be critical of the plan and describe your approach inside the docstrings of each function and in the comments.
# Execution plan: xxx
# Start with triple backticks and end with triple backticks. No conversation with the user.

function prompts()
    global AVAILABLE_PROMPTS
    return AVAILABLE_PROMPTS
end

function expand_prompt_combination(requested_labels::Vector{<:Symbol}, available_prompts)
    prompt_arr = Tuple{String,String}[]

    for label in requested_labels
        for pmt in available_prompts
            if pmt.label == label
                if haskey(pmt, :combines)
                    ## expand the sub-prompt
                    append!(prompt_arr, expand_prompt_combination(pmt.combines, available_prompts))
                elseif haskey(pmt, :prompt)
                    push!(prompt_arr, (pmt.prompt, get(pmt, :section, "")))
                end
            end
        end
    end
    # check if some prompts were not found
    scanned_labels = get.(available_prompts, :label, :not_found)
    unknown_labels = setdiff(requested_labels, scanned_labels)
    if !isempty(unknown_labels)
        @warn "Unknown promptlabels: $(join(unknown_labels,", "))"
    end
    return prompt_arr
end

function build_prompt(requested_labels::Vector{<:Symbol}; kwargs...)
    global AVAILABLE_PROMPTS

    prompt_arr = expand_prompt_combination(requested_labels, AVAILABLE_PROMPTS)
    # Build the prompt with the sections
    io = IOBuffer()
    prev_section = ""
    for item in prompt_arr
        pmt, section = item
        if section != prev_section && !isempty(section)
            print(io, "\n" * uppercase(section) * ":\n")
            prev_section = section
        elseif section != prev_section || isempty(section)
            print(io, "\n")
            prev_section = section
        end
        print(io, pmt)
    end
    return String(take!(io))
end
# for a single Symbol
build_prompt(requested_label::Symbol) = build_prompt([requested_label])

set_prompt!(prompt::Union{Symbol,Vector{<:Symbol}}; kwargs...) = set_prompt!(HISTORY, build_prompt(prompt); kwargs...)
set_prompt!(history::ChatHistory, prompt::Union{Symbol,Vector{<:Symbol}}; kwargs...) = set_prompt!(history, build_prompt(prompt); kwargs...)