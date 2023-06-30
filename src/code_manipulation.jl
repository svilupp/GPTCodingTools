"Extracts the largest possible single code block (ignores nesting)"
function extract_code_blocks(md::AbstractString)
    # regex pattern to identify code blocks
    pattern = r"```(.*)\n([\s\S]*)```"
    matches = eachmatch(pattern, md)
    blocks = Tuple{SubString{String},SubString{String}}[(m.captures[1], m.captures[2]) for m in matches]
    success = length(blocks) > 0
    return success, blocks
end

function extract_code_block(md::AbstractString)
    success, code_blocks = extract_code_blocks(md)
    if success
        # take the first code block and the content is in the second position
        return success, code_blocks[1][2]
    else
        return success, SubString("")
    end
end
# success, code_blocks = extract_code_blocks("")
# success, code_blocks = extract_code_block("")

function extract_julia_imports(input::AbstractString)
    package_names = Symbol[]
    for line in split(input, "\n")
        if occursin(r"(^using |^import )"m, line)# || occursin(r"^import "m, line)
            subparts = replace(replace(line, "using" => ""), "import" => "")
            ## TODO: add split on .
            subparts = map(x -> contains(x, ':') ? split(x, ':')[1] : x, split(subparts, ","))
            subparts = replace(join(subparts, ' '), ',' => ' ')
            packages = filter(!isempty, split(subparts, " ")) .|> Symbol
            append!(package_names, packages)
        end
    end
    return package_names
end

function detect_missing_package(imports_required::AbstractVector{<:Symbol})
    available_packages = Base.loaded_modules |> values .|> Symbol
    missing_packages = filter(pkg -> !in(pkg, available_packages), imports_required)
    if length(missing_packages) > 0
        return true, "Error: Several imports attempted. Missing packages: $(join(missing_packages,", "))"
    else
        return false, ""
    end
end

function detect_pkg_operation(input::AbstractString)
    m = match(r"\bPkg.[a-z]", input)
    if !isnothing(m)
        return true, "Error: Use of package manager (`Pkg`) detected! Please verify the safety of the code (`code(m)`)"
    else
        return false, ""
    end
end

function detect_broken_codeblock(input::AbstractString)
    m = match(r"^```julia"m, input)
    if !isnothing(m)
        return true, "Error: Beginning of a new Julia code block detected inside of the code block! Please verify the code (`code(m)`)"
    else
        return false, ""
    end
end

function is_code_unsafe(input::AbstractString, imports_required::AbstractVector{<:Symbol})
    failure, error = detect_pkg_operation(input)
    failure && return failure, error

    failure, error = detect_missing_package(imports_required)
    failure && return failure, error

    failure, error = detect_broken_codeblock(input)
    failure && return failure, error

    return false, ""
end

unclosed_code_block(md::AbstractString) = findall("```", md) |> length |> isodd
# @test unclosed_code_block("```julia\nprintln(\"Hello, world!\")\n```") == true
# @test unclosed_code_block("```julia\nprintln(\"Hello, world!\")\n") == false
function heal_code_block(md::AbstractString)
    if unclosed_code_block(md)
        @warn "Unclosed code block detected, attempting to heal. Message might be incomplete"
        return md * "\n```"
    else
        return md
    end
end
# @test heal_code_block("```julia\nprintln(\"Hello, world!\")") == "```julia\nprintln(\"Hello, world!\")\n```"
function wrap_code_block(code_block::AbstractString)
    if startswith(code_block, "```") && endswith(code_block, "```")
        return code_block
    else
        return "```\n" * code_block * "\n```"
    end
end
# @test wrap_code_block("println(\"Hello, world!\")") == "```\nprintln(\"Hello, world!\")\n```"

