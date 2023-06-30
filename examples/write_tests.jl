using GPTCodingTools
const CMC = ChatMessageCode
const GPT = GPTCodingTools

# # Set the API Key directly
set_provider!(GPT.OpenAI.OpenAIProvider(api_key=get(ENV, "OPENAI_API_KEY", "")));

# # Example 1: Low level tools
user_code = CMC("""
  "Builds a dictionary from ordered labels (eg, a dict from a vector of strings)"
  function build_dict_from_ordered_labels(ordered_labels::AbstractVector{T1},
                                          output_type::Type{T2} = Integer) where {T1,
                                                                                  T2 <:
                                                                                  Integer}
      Dict{T1, T2}((ordered_labels) .=> T2.(1:length(ordered_labels)))
  end
  """)
s = "Write unit tests for the provided functions"

# Inspect the message that will be generated
msg = GPTCodingTools.build_user_message("Write tests for the provided function"; user_code)

# Low level workflow
hist = get_history()
set_prompt!(hist, :jlaidevtemplate)
msg = get_response!(hist, s; user_code);
msg |> hasvalidcode
codeerror(msg)

# Ask for the automatic fix
msg = get_fix!(hist)
msg |> hasvalidcode

# Adjust the ask
msg = get_response!(hist, "Adds tests for the empty case")

# save_chat(hist)
# h = load_chat("history/chat_20230330_193228967.json")


# # Example 2: More Challenging
# Provide an arbitrary set of functions
user_code = CMC("""
  "Builds a dictionary from ordered labels (eg, a dict from a vector of strings)"
  function build_dict_from_ordered_labels(ordered_labels::AbstractVector{T1},
                                          output_type::Type{T2} = Integer) where {T1,
                                                                                  T2 <:
                                                                                  Integer}
      Dict{T1, T2}((ordered_labels) .=> T2.(1:length(ordered_labels)))
  end

  "Changes the output type of a dictionary"
  function retype_dict_output(d::Dict{T1, T2}, output_type::Type{T3} = T2) where {T1, T2, T3}
      convert(Dict{T1, T3}, d)
  end
  function lookup_product_id(urlpaths::AbstractVector{T1}, urlpath_mapping::Dict{T2, T3},
                             ids::AbstractVector{T4}, id_labels::AbstractVector{T5},
                             output_type::Type{T6} = Integer) where {T1, T2, T3, T4,
                                                                     T5, T6 <: Integer}
      id2idx = build_dict_from_ordered_labels(id_labels, output_type)
      urlpath2idx = retype_dict_output(urlpath_mapping, output_type)
      other_value = output_type(length(mfid_labels))
      lookup_function = genfun_lookup_product_id(urlpath2idx, id2idx, other_value)
      map(lookup_function, urlpaths, ids)
  end
  """)
hist = get_history() |> reset_chat!
set_prompt!(hist, :jlaidevtemplate)
s = "Write unit tests for the provided functions"
# Run the reflection loop 5times
msg = reflection_cycle!(hist, s; user_code, n_cycles=5);
# Optional inspection, but easiest is to do `edit(hist)`
hasvalidcode(msg)
code(msg)

# Show the conversation in Markdown in VS Code
edit(hist)

# Ask for a fix
msg = get_fix!(hist)
msg |> hasvalidcode
msg |> codeerror


# Save the chat for later
# save_chat(hist)