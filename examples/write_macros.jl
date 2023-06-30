# # Write macro:

hist = get_history()
set_prompt!(hist, :jlaidevtemplate)
user_code = CMC("")
s = """
Write a macro called `@chat` that takes 1-3 arguments: a Symbol `prompt`, a String `message` and `user_code` of type ChatMessageCode

It then calls the following snippet:
```
hist=get_history()
set_prompt!(hist,prompt)
get_response!(hist, message; user_code)
```

First, write a helper function that accepts all args and separates `prompt`,`message`,`user_code`
- If `prompt` isn't provided, skip the `set_prompt!(hist,prompt)` call and apply `reset_chat!(hist)` instead
- If `user_code` isn't provided, set it to `user_code=nothing`
- `message` must always be provided!

Make sure all variables are properly escaped inside of the macro
"""
msg = get_response!(hist, s)

s = """
Your goal is to write a macro called `@chat` that takes 1-3 arguments: a Symbol `prompt`, a String `message` and `user_code` of type ChatMessageCode

It then calls the following snippet:
"""
msg = get_response!(hist, s)


### Use Cases

# Example:
v1 = ones(50)
@chat "how many elements are in v1?" v1
@macroexpand @chat "how many elements are in v1?" v1

hist = get_history()
v1 = ones(50)
@chat! hist "how many elements are in v1?" v1
@macroexpand @chat! hist "how many elements are in v1?" v1

# Asynchronous
hist = get_history()
v1 = ones(10)
t = @achat! hist :jlaidev "how many elements are in v1?" v1
istaskdone(t)
m = fetch(t)

# Reflection
v1 = ones(50)
c = CMC("""
len(vect::AbstractVector)=length(vect)
""")
@chatreflect "how many elements are in v1? Use function `len`" v1

hist = get_history() |> reset_chat!
v1 = ones(50)
c = CMC("""
len(vect::AbstractVector)=length(vect)
""")
t = @achatreflect! hist "how many elements are in v1? Use function `len`" c v1
m = fetch(t)