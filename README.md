# robot_lab-document_store

Embedding-based semantic document search for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework.

> [!CAUTION]
> This gem is under active development. APIs may change without notice.

## What it provides

`RobotLab::DocumentStore` is a thread-safe, in-memory vector store backed by [fastembed](https://github.com/Anush008/fastembed-ruby) embeddings and cosine similarity search. It supports:

- **`store(key, text)`** — embed and store a document under a symbol key
- **`search(query, limit:)`** — return the top-N most similar documents by cosine similarity
- **`delete(key)`** / **`clear`** — remove individual entries or wipe the store
- **Asymmetric embedding** — passage embeddings for storage, query embeddings for retrieval

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab-document_store"
```

## Quick Example

```ruby
require "robot_lab/document_store"

store = RobotLab::DocumentStore.new

store.store(:alpha, "Ruby is a dynamic, open source programming language.")
store.store(:beta,  "Python is widely used in data science and machine learning.")
store.store(:gamma, "JavaScript runs in the browser and on Node.js servers.")

results = store.search("What language is popular for AI?", limit: 2)
results.each do |r|
  puts "#{r[:key]} (score: #{"%.3f" % r[:score]})"
end
# => beta (score: 0.872)
# => alpha (score: 0.641)
```

## Custom Model

```ruby
store = RobotLab::DocumentStore.new(
  model_name: "BAAI/bge-small-en-v1.5"
)
```

The default model is `"BAAI/bge-small-en-v1.5"`.

## Using with RobotLab Robots

`DocumentStore` works well as in-memory retrieval for RAG (retrieval-augmented generation) workflows. Load documents at startup and pass relevant excerpts into robot context:

```ruby
require "robot_lab"
require "robot_lab/document_store"

store = RobotLab::DocumentStore.new
store.store(:faq_1, "Our return policy allows returns within 30 days.")
store.store(:faq_2, "Shipping typically takes 3-5 business days.")

robot = RobotLab.build(
  name: "support",
  system_prompt: "You are a support agent. Use provided context to answer questions."
)

query  = "How long do I have to return an item?"
chunks = store.search(query, limit: 2).map { |r| r[:text] }.join("\n")

result = robot.run("Context:\n#{chunks}\n\nQuestion: #{query}")
puts result.last_text_content
```

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [fastembed-ruby](https://github.com/Anush008/fastembed-ruby)
- [RubyGems](https://rubygems.org/gems/robot_lab-document_store)

## License

MIT License - Copyright (c) 2025 Dewayne VanHoozer

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/robot_lab-document_store.
