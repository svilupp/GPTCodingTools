using GPTCodingTools
const CMC = ChatMessageCode
const GPT = GPTCodingTools

# # Task 0: Write a simple Chain.jl data pipeline
@chat :jlaidevchain "I have a dataset with weather data. Write a @chain that filters for states NY, CA, PA and then calculates average precipitation by month"


# # Task 1: Get a draft of a package
hist = get_history()
s = """
  Build a data pipeline framework that operates with QueryRecipe, TableRecipe, PipelineRecipe types
  Example usage:
  ```
  # Download one file
  sql_file = "sql/query.sql"
  dir_sql = "sql"
  dir_data_raw = "data_raw"
  qr = QueryRecipe("query.sql"; dir_data_raw, dir_sql) |> cook! # cook! will download and load into property `df` in the struct
  # access property `df` in the struct via `DataFrame()`
  df = DataFrame(qr)

  # Download two files and combine with function `joiner()`
  t1 = TableRecipe("query1.sql", identity; dir_data_raw, dir_sql) # cook! will download, load and apply function `identity`
  t2 = TableRecipe("query2.sql", identity; dir_data_raw, dir_sql) # cook! will download, load and apply function `identity`
  pr = PipelineRecipe([:df_1 => t1, :df_2 => t2], joiner) |> cook! # cook! will download, load, and apply function `joiner(;df_1,df_2)`
  df = DataFrame(pr)
  ```
  """

msg = @chatreflect! hist :jlaidevtemplate s
hasvalidcode(msg)
edit(hist)
# save_chat(hist)

# # Task 3: Bigger idea with Types
hist = get_history()
s = """
  Build a an upsell recommender system that operates with FocusUser, PeersResult, CompareResult types
  It finds the most similar users based on embedding similarity and then finds the products that the peers have, that the focusUser does not have

  Example usage:
  ```
    # Basket holds what products a user has, eg, 1,2,5
    b = Basket([1, 2, 5])
    # Example datA: What product IDs each user has (10 users)
    products = [Basket(rand(1:10, 3)) for i in 1:10]
    embedding = randn(5, 10) # 5 dimensions, 10 users
    fu = FocusUser(1) # User at position one
    # extract 5 peers
    pr = knn(embedding, fu, 5) # return PeersResult(idxs::Vector{<:Int},dists::Vector{<:Real}, valid::Vector{<:Bool})
    # if dists are more than 1.0, set valid mask to false and ignore them
    filter!(pr, 1.0)
    # get total of baskets of all peers in PeerResult
    pb = baskets(products, pr) # return Basket with counts of each product for the peers with `valid=true` mask
    # which components do the peers have, that the focusUser does not
    cr = compare(DifferenceStrategy(), fa, pb) # results CompareResult that holds the product IDs and their counts across peers
  ```
  """
msg = @chatreflect! hist :jlaidevtemplate s
hasvalidcode(msg)
edit(hist)
codeerror(msg) |> println
# save_chat(hist)

# # Task 4: Write a simple function
s = """
  Write a function `extract_imports` that receives a string and extracts any Julia package to be imported.
Return the package names into a vector of strings.

  Examples:
  "using Test, LinearAlgebra" -> ["Test","LinearAlgebra"]
  "import Test\n"import ABC,DEF\nusing GEM: func" -> ["Test","ABC","DEF","GEM"]
  """

m = @chatreflect :jlaidevtemplate s

# save_chat(get_history())



