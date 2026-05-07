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

The default model is `"BAAI/bge-base-en-v1.5"`.

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [fastembed-ruby](https://github.com/Anush008/fastembed-ruby)
- [RubyGems](https://rubygems.org/gems/robot_lab-document_store)
