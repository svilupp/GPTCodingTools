module GPTCodingTools

using OpenAI
using JuliaSyntax
using Markdown
using JSON3
using StructTypes
using Suppressor
using Test
using Dates
using Test: FallbackTestSetException, TestSetException
using InteractiveUtils

## Create an extension later
using DataFramesMeta


export ChatHistory, ChatMessage, ChatMessageCode, AIModel
export messages, message
export hasvalidcode, codeerror, code
# export cost, role, duration, to_dict, to_toml
# export isvalidcode, isunsafecode, hasunsafecode, hasvalidcode, isuser, issystem, codeerror
include("types.jl")

const PROVIDER = [OpenAI.OpenAIProvider(api_key=get(ENV, "OPENAI_API_KEY", ""))]
#use:  "gpt-4" or "gpt-3.5-turbo"
const MODEL = [AIModel("gpt-4"; cost_prompt=0.03, cost_completion=0.06)]
const HISTORY = ChatHistory()
const HISTORY_PREVIOUS = ChatHistory()

export prompts, set_prompt!, get_prompt
include("prompting.jl")

export FunctionString, objectschema
include("schemata.jl")

export set_model!, set_provider!
export get_history, get_response, get_response!
export get_fix!, reflection_cycle!, reset_chat!
export save_chat, load_chat
include("conversation.jl")

include("code_manipulation.jl")

include("evaluation.jl")

include("utils.jl")

export @chat, @chat!, @achat!
export @chatfix, @chatfix!
export @chatreflect, @chatreflect!, @achatreflect!
include("macros.jl")

end # module GPTCodingTools
