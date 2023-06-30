remove_file_paths(error_message::AbstractString) = replace(error_message, r" ([~/\\]+[^:]+:\d+)" => " <SENSITIVE_PATH>")
# s = "at /Users/myusername/Documents/Julia-stuff/openai-macros/code_parser.jl:67"
# remove_file_paths(s)
# @test "at /Users<SENSITIVE_PATH>" == remove_file_paths(s)
# s = "@ ~/.julia/juliaup/julia-1.9.0+0.aarch64.apple.darwin14/share/julia/stdlib/v1.9/Test/src/Test.jl:478 [inlined]"
# remove_file_paths(s)
# @test "@ <SENSITIVE_PATH> [inlined]" == remove_file_paths(s)
# remove_file_paths(msg) |> println

