using GPTCodingTools: extract_julia_imports

@testset "extract_imports tests" begin
    @test extract_julia_imports("using Test, LinearAlgebra") == Symbol.(["Test", "LinearAlgebra"])
    @test extract_julia_imports("import Test\nimport ABC,DEF\nusing GEM: func") == Symbol.(["Test", "ABC", "DEF", "GEM"])
    @test extract_julia_imports("import PackageA.PackageB: funcA\nimport PackageC") == Symbol.(["PackageA.PackageB", "PackageC"])
end

# c = CMC("""
# ```
# using LinearAlgebrax
# ```

# """; break_early=false)
# m = c |> code |> extract_julia_imports |> first
# Symbol(m) in Base.loaded_modules |> values .|> Symbol

# success, code_str = extract_code_block(c |> code)
# code_str |> extract_julia_imports

# GPT.detect_missing_package(imports(c))

# m = ChatMessage("""
# ```
#   using Pkg
#   Pkg.change_stuff()
# ```
#   """)
# hasunsafecode(m)
# ChatMessage("")
# code(m)

# GPT.detect_pkg_operation(m |> code |> code)
# GPT.detect_broken_codeblock(m |> code |> code)

# m = ChatMessage("""
# ```julia

# using LinearAlgebra

# asdas
# ```julia

# ```
#   """)
# hasunsafecode(m)
# codeerror(m)
# GPT.detect_broken_codeblock(m |> code |> code)