# GPTCodingTools.jl

Set of useful routines and types for coding with OpenAI's conversational models.

BEWARE: Experimental, messy, and probably wrong. Used since April, but not tested extensively.

## Motivation

I didn't like re-writing my long prompts (in-context learning), copy-pasting to and from the playground, extracting errors stack traces and describing various objects in my active REPL session. So I wrote a few scripts to help me with that.

My favorite workflow is inspired by [Reflexion paper](https://arxiv.org/abs/2303.11366) with macro `@chatreflect`, where each message is automatically evaluated and errors are scrubbed for private information and sent back to the model for fixing.

And macros are really convenient when working on your phone's keyboard... Go JuliaHub!

## Quick Starter Guide

Let's have GPT4 write a @chain pipeline in the style we like (see the `prompts()` for what I mean)

```julia
using GPTCodingTools
@chat :jlaidevchain "I have a dataset with weather data. Write a @chain that filters for states NY, CA, PA and then calculates average precipitation by month"
```

Macro `@chat` will do the heavy-lifting, inject the respective prompts (see `prompts()`) and send the whole conversation to OpenAI's API. 

The result is a `ChatMessage` with the response from the model:
```julia
# [ Info: User message built...
# [ Info: Response received...
# [ Info: Finished: Duration: 19.8s, Cost: 0.0 with prompt_tokens: 0.4K, completion_tokens: 0.3K, total_tokens: 0.6K
#   Chat Message from: assistant (Valid Code: FALSE)
#   ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

  using Chain
  using DataFramesMeta
  using Test
  
  # Here assumes the DataFrame has 'state', 'month', and 'precipitation' columns
  
  function average_precip_by_state_month(df::DataFrame)
      return @chain df begin
          @rsubset in(["NY", "CA", "PA"]).(:state)
          @by([:state, :month], AveragePrecipitation = mean(:precipitation))
          @orderby(:state, :month)
      end
  end
  
  # Unit Tests
  
  @testset "average_precip_by_state_month tests" begin
      data = DataFrame(state = repeat(["NY", "CA", "PA", "NJ"], outer=3), 
                       month = repeat([1, 2, 3], inner=4),
                       precipitation = rand(12))
      
      @test begin
          result = average_precip_by_state_month(data)
          size(result)[2] == 3 && all(in(["NY", "CA", "PA"]).(result.state))
      end
  
      @test begin
          result = average_precip_by_state_month(data)
          all(result.month .>= 1) && all(result.month .<= 3)
      end
  end
```

The response pretty-prints in Markdown in REPL, so it's easy to read. The code is not valid, because of the test that GPT4 wrote for us, but that's okay - I'm happy with the result which took almost no effort.

If we wanted to ask ChatGPT to fix it, we would just call `@chatfix!`. Or you could have simply called `@chatreflect!` to have the code automatically evaluated and fixed until it's correct.


If you wanted to see the whole conversation, you can get a formatted preview in VSCode with `edit(get_history())` or you can save it to JSON with `save_chat(get_history())`. It will be timestamped to avoid overwriting.

## Full Example

1) Ensure you have an API key saved in `ENV["OPENAI_API_KEY"]` (loaded when imported) or set it later via OpenAI Providers
`set_provider!(OpenAI.OpenAIProvider(api_key=get(ENV, "OPENAI_API_KEY", "")))` (useful when you use Azure API!)

2) Set the prompt
See available prompts with `prompts()`. Set it with `set_prompt!(:jlaidevtemplate)`. Get current prompt with `get_prompt()`

3) Start a chat
I prefer the explicit style with explicit `ChatHistory()`:
```julia
hist = ChatHistory() 
@chat! hist :MYPROMPT MYCOMMAND MYARGS`
```
which will record all conversation history in `hist`. `:MYPROMPT` is not necessary if you already set a prompt in your history.
`MYARGS` can be any Julia variable, so you can pass in a string, a vector, a DataFrame, etc. The macro will describe its schema/metadata and pass that information to the API.

It uses function `objectschema()` to describe the object. You can override it by defining your own `objectschema` method for your type.
```
using DataFramesMeta
df = DataFrame(a=repeat(1:5, outer=20),
     b=repeat(["a", "b", "c", "d"], inner=25), c=repeat(1:20, inner=5))
objectschema(df)
```

which will return a string with the schema of the DataFrame:
```julia
"""
User-provided data:
- ``: DataFrame with 100 rows and 3 columns like this"
   - `a`: Vector{Int64} with total of 100 elements of type Int64 (5 of which are unique)"
   - `b`: Vector{String} with total of 100 elements of type String (4 of which are unique)"
   - `c`: Vector{Int64} with total of 100 elements of type Int64 (20 of which are unique)"
```
To ensure that generated code is accurate as possible and requires little to no editing.

If you use the implicit style with `@chat`, the conversation will be automatically reset with `reset_chat!()`. The history will be removed EXCEPT for the prompt, which will be kept.

4) Iteration
The GPT4 rarely gets it right the first time. That is why each response is automatically parsed and evaluated (`hascodevalid(msg)` will tell you if message has passed the evaluation or simply look for "VALID" in the ChatHistory preview `edit(hist)`.

If an error happens, it's automatically saved, scrubbed for private information (eg, paths), summarized and prepared to be sent back for fixing. So you can simply call `@chatfix` to automatically request the fix.

Sometimes you just want to shortcut the process and just call `@chatreflect!` which will automatically evaluate the code and fix it until it's valid. This is useful for when you are just trying to get a working example.

```julia
using GPTCodingTools
const CMC = ChatMessageCode #used often for providing our own code

hist = get_history()
s = """
  Write a function `extract_imports` that receives a string and extracts any Julia package to be imported.
Return the package names into a vector of strings.

  Examples:
  "using Test, LinearAlgebra" -> ["Test","LinearAlgebra"]
  "import Test\n"import ABC,DEF\nusing GEM: func" -> ["Test","ABC","DEF","GEM"]
  """
m = @chatreflect! hist :jlaidevtemplate s
```

It took several iterations, but, eventually, it gets it right. It did cost me c. $0.25 but I didn't have to think about it at all and could have worked on something else in parallel.

```julia
# [ Info: User message built...
# [ Info: Response received...
# [ Info: Finished: Duration: 25.8s, Cost: 0.0 with prompt_tokens: 0.3K, completion_tokens: 0.3K, total_tokens: 0.6K
# [ Info: >>> Reflection cycle 1
# [ Info: >>> Errors found. Requesting fix...
# [ Info: User message built...
# [ Info: Response received...
# [ Info: Finished: Duration: 26.5s, Cost: 0.0 with prompt_tokens: 0.8K, completion_tokens: 0.4K, total_tokens: 1.2K
# [ Info: >>> Reflection cycle 2
# [ Info: >>> Errors found. Requesting fix...
# [ Info: User message built...
# [ Info: Response received...
# [ Info: Finished: Duration: 17.1s, Cost: 0.1 with prompt_tokens: 1.5K, completion_tokens: 0.3K, total_tokens: 1.8K
# [ Info: >>> Reflection cycle 3
# [ Info: >>> Errors found. Requesting fix...
# [ Info: User message built...
# [ Info: Response received...
# [ Info: Finished: Duration: 24.6s, Cost: 0.1 with prompt_tokens: 2.3K, completion_tokens: 0.4K, total_tokens: 2.6K
# Chat Message from: assistant (Valid Code: TRUE)
#   ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡
# ...
```
(pasting the full conversation here would be too long - try it yourself!).

See also: 
- `@achat!`, `@achatreflect!`  (a is for async if you want to run multiple conversations in parallel)
- `@chatfix!`
- The underlying functions are: `get_response!`, `get_fix!`, `reflection_cycle!`

A few examples can be found in the [examples](examples) folder.

## How it works

It wraps `OpenAI.create_chat` call and defines a few useful macros and types to make it easier to use.

There are several basic types to manage the conversation artifacts:
- ChatHistory - a history of ChatMessages (mostly a simple vector a few masks to allow for threading conversations, etc.)
- ChatMessage - a message in the conversation, which _might_ include a code
- ChatMessageCode - any code in the message, aggressively extracted, parsed and evaluated to be ready when needed

Workflow:
- a prompt is set with `set_prompt!(:jlaidevtemplate)`, which also initiates the first message (of type `ChatMessage` from role="system") in the global `ChatHistory` tracker (`get_history()`)
- a user writes a message with `@chat "message"` or `get_response("message")`, which compiles the `"message"` and other useful artifacts like user-provided code or schema of any user-provided object (like a DataFrame) into a new `ChatMessage`
- The whole ChatHistory is sent to `OpenAI.create_chat` and the response is subsequently parsed into a new `ChatMessage`
- The new `ChatMessage` is added to the `HISTORY` and the process repeats... (sometimes automatically with `@chatreflect!` or `reflection_cycle!`)

## Tips and Learnings
- `@code_string` from [CodeTracking.jl](https://github.com/timholy/CodeTracking.jl) is a great tool for getting function definitions
- The longer and more detailed the prompt, the better the results
- Defining a "template" in the prompt provides more consistent results (see prompt `:template`)
- More than 3 iterations of the reflection loop aren't necessary (usually, there is some simple error somewhere)
- I've tried the [ReWoo](https://arxiv.org/abs/2305.18323)-like approach (having the faster GPT3.5 do the planning), but it didn't have great results. I'd rather pay a bit more and come back later to a higher-quality result.