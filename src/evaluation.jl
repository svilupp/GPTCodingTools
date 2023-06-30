function parse_code_block(code::AbstractString)
    success, result = try
        ex = JuliaSyntax.parseall(Expr, code)
        true, ex
    catch e
        false, e
    end
    return success, result
end
# success, result = parse_code_block(c)

error_snippet(err::JuliaSyntax.Diagnostic, code::AbstractString; context_window=30) = code[thisind(code, max(JuliaSyntax.first_byte(err) - context_window, 1)):thisind(code, min(JuliaSyntax.last_byte(err) + context_window, length(code)))]
summarize_error(err::JuliaSyntax.Diagnostic, code::AbstractString) = "- Error: $(err.message) in the following block: `$(replace(error_snippet(err,code), "\n" => " "))`"
# summarize_error(d, c)
summarize_error(err::JuliaSyntax.ParseError, code::AbstractString) = err.diagnostics[[begin, end]] |> x -> summarize_error.(x, code) |> x -> join(x, "\n")
# summarize_error(e, c) |> println


# to hold the stdout message
struct MyTestSetException <: Exception
    err::Union{TestSetException,FallbackTestSetException}
    stdout_msg::String
end

function eval_code_expr(ex::Expr)
    local success, result
    mod = gensym("CustomModule")
    stdout_msg = @capture_out begin
        success, result = try
            # eval in Main module to have access to std libs etc.
            result = @eval(Main, module $mod
            using Test
            $ex
            end)
            true, result
        catch err
            false, err
        end
    end
    if success
        return true, result
    elseif result isa TestSetException || result isa FallbackTestSetException
        return false, MyTestSetException(result, stdout_msg)
    else
        return false, result
    end
end

function extract_failed_tests_and_errors(error::AbstractString)
    regex_pattern = r"(?m)(^.*(?:Error During Test at|Test Failed at)[\s\S]*?(?:\n\n|Stacktrace:))"
    matches = eachmatch(regex_pattern, error)
    cleaned_matches = String[]
    for m in matches
        cleaned_match = "- Error:\n" * (m.match |> remove_file_paths |> strip |> wrap_code_block)
        push!(cleaned_matches, cleaned_match)
    end

    return join(cleaned_matches, "\n")
end
function summarize_error(err::Exception, input)
    io = IOBuffer()
    showerror(io, err)
    e = String(take!(io)) |> remove_file_paths |> strip |> wrap_code_block
    return "- Error:\n" * e
end
summarize_error(err::MyTestSetException, input) = extract_failed_tests_and_errors(err.stdout_msg)


# Combine into one step
function safe_parse_and_eval(code::AbstractString)
    # result = wrap_code_in_safetest(code, user_code)
    # Parse string into an expression
    success, result = parse_code_block(code)
    if !success && result isa JuliaSyntax.ParseError
        return success, summarize_error(result, code)
    elseif !success
        error("Unknown error at parsing: $result")
    end
    # Evalute the expression
    success, result = eval_code_expr(result)
    if !success && result isa Exception
        return success, summarize_error(result, code)
    elseif !success
        error("Unknown error at eval: $result")
    end
    # Success
    return success, nothing
end

safe_parse_and_eval(c::ChatMessageCode, previous_code::String="") = safe_parse_and_eval(previous_code * "\n" * code(c))
