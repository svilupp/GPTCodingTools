using GPTCodingTools: prepare_chat_from_args

@testset "prepare_chat_from_args" begin
    # only message provided
    hist, msg, kwargs = GPT.prepare_chat_from_args(("s"), "only message")
    @test hist == get_history()
    @test msg == "only message"
    @test kwargs == (; user_schemas=Any[])

    # prompt and message
    hist_expected = ChatHistory()
    set_prompt!(hist_expected, :jldev)
    hist, msg, kwargs = GPT.prepare_chat_from_args(("prompt", "s"), :jldev, "prompt+message")
    @test hist == hist_expected
    @test msg == "prompt+message"
    @test kwargs == (; user_schemas=Any[])

    # prompt and message WITH provided history
    hist_expected = ChatHistory()
    set_prompt!(hist_expected, :jldev)
    hist_input = ChatHistory([ChatMessage("a"), ChatMessage("b")])
    hist, msg, kwargs = GPT.prepare_chat_from_args(("history", "prompt", "s"), hist, :jldev, "history+prompt+message")
    @test hist == hist_expected
    @test msg == "history+prompt+message"
    @test kwargs == (; user_schemas=Any[])

    # message WITH provided history
    hist_expected = ChatHistory([ChatMessage("a")])
    hist, msg, kwargs = GPT.prepare_chat_from_args(("history", "s"), hist_expected, "history+message")
    @test hist == hist_expected
    @test msg == "history+message"
    @test kwargs == (; user_schemas=Any[])

    # everything without history
    hist_expected = ChatHistory()
    set_prompt!(hist_expected, :jldev)
    user_code = CMC("a=1")
    v1, v2 = ones(3), ones(5)
    history, message, kwargs = GPT.prepare_chat_from_args(("prompt", "msg", "code", "v1", "v2"), :jldev, "complex msg", user_code, v1, v2)
    @test history == hist_expected
    @test message == "complex msg"
    @test kwargs == (; user_schemas=Any[([1.0, 1.0, 1.0], "v1"), ([1.0, 1.0, 1.0, 1.0, 1.0], "v2")], user_code)

    # everything with history
    hist_input = ChatHistory([ChatMessage("a"), ChatMessage("b")])
    user_code = CMC("a=1")
    v1, v2 = ones(3), ones(5)
    history, message, kwargs = GPT.prepare_chat_from_args(("hist", "msg", "code", "v1", "v2"), hist_input, "complex msg", user_code, v1, v2)
    @test history == hist_input
    @test message == "complex msg"
    @test kwargs == (; user_schemas=Any[([1.0, 1.0, 1.0], "v1"), ([1.0, 1.0, 1.0, 1.0, 1.0], "v2")], user_code)

    # history required
    @test_throws Exception GPT.prepare_chat_from_args(("s"), "only message"; historyrequired=true)
    hist = get_history()
    _ = GPT.prepare_chat_from_args(("hist", "s"), hist, "only message"; historyrequired=true)
end