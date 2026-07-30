# Getting Started

## Prerequisites

- Ruby 3.2+
- **fastembed** (recommended) — requires a platform that can run ONNX Runtime (x86_64 and ARM64 macOS/Linux). On first use the ~23 MB `BAAI/bge-small-en-v1.5` model file is downloaded and cached in `~/.cache/fastembed`.
- Without fastembed the store still works using the built-in TF-IDF fallback (see [Fallback Mode](#fallback-mode) below).

## Installation

Add to your `Gemfile`:

```ruby
gem "robot_lab-document_store"
```

Then:

```sh
bundle install
```

Or install directly:

```sh
gem install robot_lab-document_store
```

### Installing fastembed

fastembed is an optional dependency. To get semantic search quality, install it:

```ruby
# Gemfile
gem "fastembed"
```

```sh
bundle install
```

The ONNX model is downloaded on the first embed call and cached locally. Subsequent starts reuse the cache — no download needed.

## First Run

```ruby
require "robot_lab/document_store"

store = RobotLab::DocumentStore.new

# Store documents — embedding happens here (model downloads if needed)
store.store(:ruby_intro,    "Ruby is a dynamic, open source programming language.")
store.store(:python_intro,  "Python is widely used in data science and AI.")
store.store(:js_intro,      "JavaScript runs in the browser and powers Node.js.")

# Search — returns Array of { key:, text:, score: } hashes
results = store.search("Which language is used for machine learning?", limit: 2)

results.each do |r|
  puts "#{r[:key]}  (#{r[:score].round(3)})"
end
# => python_intro  (0.871)
# => ruby_intro    (0.634)
```

!!! note "Model download on first run"
    The first call to `store` or `search` triggers a ~23 MB ONNX model download.
    All subsequent runs reuse the cached model. Set `FASTEMBED_CACHE_PATH` to control
    the cache location.

## Fallback Mode

When `fastembed` is not installed, `DocumentStore` automatically switches to a
TF-IDF word-frequency embedder. No configuration needed — the switch is silent.

```text
fastembed installed?
  YES → dense vector embeddings via BAAI/bge-small-en-v1.5
   NO → sparse TF-IDF bag-of-words with Porter-style stemming
```

The fallback is lower quality — it relies on lexical overlap rather than semantic
understanding — but it works offline with no model downloads, making it well-suited
for development, CI, and test environments.

```ruby
# Works identically regardless of whether fastembed is installed
store = RobotLab::DocumentStore.new
store.store(:doc, "Ruby programming language")
store.search("Ruby development", limit: 1)
```

## Running the Example

The gem ships with a self-contained example that demonstrates all core features:

```sh
bundle exec ruby examples/01_basic_usage.rb
```

This loads five engineering runbook documents, runs several semantic queries,
demonstrates deletion, and shows the RobotLab Memory integration.

!!! note
    The example requires `robot_lab` core for the Memory integration section.
    The standalone `DocumentStore` section runs without it.
