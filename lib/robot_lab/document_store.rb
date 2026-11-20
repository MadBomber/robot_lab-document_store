# frozen_string_literal: true

require_relative 'document_store/version'

module RobotLab
  # Embedding-based document store for semantic search over arbitrary text.
  #
  # Documents are embedded using fastembed (BAAI/bge-small-en-v1.5 by default)
  # and stored in memory. Queries are embedded the same way, then compared by
  # cosine similarity to find the closest documents.
  #
  # The embedding model is initialised lazily on first use — the ONNX model
  # file is downloaded on that first call (cached locally afterwards).
  #
  # When fastembed is not installed, DocumentStore falls back to a lightweight
  # TF-IDF word-frequency embedder. The fallback is lower quality (no semantic
  # understanding, only lexical overlap) but works offline with no downloads,
  # making it suitable for development and testing.
  #
  # @example Standalone
  #   store = RobotLab::DocumentStore.new
  #   store.store(:q4_report, "Q4 revenue came in at $4.2M, up 18% YoY…")
  #   store.store(:q3_report, "Q3 showed 15% growth, driven by APAC…")
  #
  #   results = store.search("revenue growth", limit: 2)
  #   results.each { |r| puts "#{r[:key]} (#{r[:score].round(3)}): #{r[:text][0..60]}" }
  #
  # @example With robot_lab Memory
  #   memory.store_document(:readme, File.read("README.md"))
  #   memory.search_documents("how to configure redis", limit: 3)
  #
  # :reek:RepeatedConditional -- @using_fastembed selects the dense vs sparse embedding path, fixed at construction.
  class DocumentStore
    # @api private
    FASTEMBED_AVAILABLE = begin
      require 'fastembed'
      true
      # :nocov:
    rescue LoadError
      false
      # :nocov:
    end

    # Default embedding model used when none is specified.
    DEFAULT_MODEL = 'BAAI/bge-small-en-v1.5'

    # @param model_name [String] fastembed model name (ignored when fastembed unavailable)
    def initialize(model_name: DEFAULT_MODEL)
      @model_name      = model_name
      @documents       = {} # key (Symbol) => { text: String, vector: Array<Float> }
      @mutex           = Mutex.new
      @fastembed_model = nil # lazy: initialised on first embed call
      @using_fastembed = FASTEMBED_AVAILABLE
    end

    # Embed +text+ and store it under +key+.
    #
    # If a document already exists under +key+ it is replaced.
    #
    # @param key [Symbol, String] identifier for this document
    # @param text [String] the document text to embed and store
    # @return [self]
    def store(key, text)
      key    = key.to_sym
      vector = passage_vector(text)
      @mutex.synchronize { @documents[key] = { text: text, vector: vector } }
      self
    end

    # Search for documents semantically similar to +query+.
    #
    # @param query [String] natural-language search query
    # @param limit [Integer] maximum number of results (default 5)
    # @return [Array<Hash>] results sorted by score descending.
    #   Each hash contains +:key+, +:text+, and +:score+ (Float 0.0..1.0).
    # :reek:TooManyStatements -- linear embed/score/sort pipeline; the mutex block inflates the count.
    def search(query, limit: 5)
      return [] if empty?

      query_vec = query_vector(query)
      results   = []

      @mutex.synchronize do
        @documents.each do |key, doc|
          score = cosine_similarity(query_vec, doc[:vector])
          results << { key: key, text: doc[:text], score: score }
        end
      end

      results.sort_by { |r| -r[:score] }.first(limit)
    end

    # Number of stored documents.
    # @return [Integer]
    def size
      @mutex.synchronize { @documents.size }
    end

    # Keys of all stored documents.
    # @return [Array<Symbol>]
    def keys
      @mutex.synchronize { @documents.keys }
    end

    # Whether the store contains no documents.
    # @return [Boolean]
    def empty?
      @mutex.synchronize { @documents.empty? }
    end

    # Remove the document stored under +key+.
    # @param key [Symbol, String]
    # @return [self]
    def delete(key)
      @mutex.synchronize { @documents.delete(key.to_sym) }
      self
    end

    # Remove all stored documents.
    # @return [self]
    def clear
      @mutex.synchronize { @documents.clear }
      self
    end

    STOP_WORDS = %w[
      a an the is are was were be been being am do does did
      to of in and or but for with on at by from as into
      it its this that these those i you he she we they
      not no nor so yet
    ].to_set.freeze

    private

    # ── Fastembed path ──────────────────────────────────────────────────────

    def fastembed_model
      @fastembed_model ||= Fastembed::TextEmbedding.new(model_name: @model_name, show_progress: false)
    end

    def passage_vector(text)
      if @using_fastembed
        fastembed_model.passage_embed([text]).to_a.first
      else
        fallback_vector(text)
      end
    end

    def query_vector(text)
      if @using_fastembed
        fastembed_model.query_embed([text]).to_a.first
      else
        fallback_vector(text)
      end
    end

    def cosine_similarity(vec_a, vec_b)
      return 0.0 unless vec_a && vec_b

      @using_fastembed ? dense_cosine(vec_a, vec_b) : sparse_cosine(vec_a, vec_b)
    end

    # :reek:FeatureEnvy -- pure vector math over its two arguments; there is no better home than the store that owns both paths.
    # :reek:TooManyStatements -- one guarded dot-product/norm accumulation; splitting the loop would obscure the formula.
    def dense_cosine(vec_a, vec_b)
      return 0.0 if vec_a.empty? || vec_b.empty?
      return 0.0 if vec_a.length != vec_b.length

      dot    = 0.0
      norm_a = 0.0
      norm_b = 0.0

      vec_a.each_with_index do |a, i|
        b       = vec_b[i]
        dot    += a * b
        norm_a += a * a
        norm_b += b * b
      end

      return 0.0 if norm_a.zero? || norm_b.zero?

      dot / (Math.sqrt(norm_a) * Math.sqrt(norm_b))
    end

    # ── Fallback TF-IDF word-frequency path ─────────────────────────────────

    # Returns a sparse Hash{String => Float} L2-normalised term-frequency vector.
    # :reek:FeatureEnvy -- builds and normalises the local counts hash it returns; there is no other object involved.
    # :reek:TooManyStatements -- one count-then-normalise sequence over the local hash.
    # :reek:UncommunicativeVariableName -- single-char block param (w = word) is accepted project convention.
    def fallback_vector(text)
      counts = Hash.new(0)
      text.downcase.scan(/[a-z]+/).each do |w|
        next if STOP_WORDS.include?(w)

        counts[stem(w)] += 1
      end

      return {} if counts.empty?

      norm = Math.sqrt(counts.values.sum { |c| c * c }.to_f)
      counts.transform_values { |c| c / norm }
    end

    # :reek:TooManyStatements -- one guarded dot-product/norm accumulation; splitting the loop would obscure the formula.
    def sparse_cosine(vec_a, vec_b)
      return 0.0 if vec_a.empty? || vec_b.empty?

      dot    = 0.0
      norm_a = 0.0
      norm_b = 0.0

      vec_a.each do |k, v|
        dot += v * vec_b[k].to_f
        norm_a += v * v
      end
      vec_b.each_value { |v| norm_b += v * v }

      # :nocov:
      return 0.0 if norm_a.zero? || norm_b.zero?
      # :nocov:

      dot / (Math.sqrt(norm_a) * Math.sqrt(norm_b))
    end

    # Very basic Porter-style stemmer for English: strip common suffixes.
    def stem(word)
      word = word.dup
      word.sub!(/ies$/, 'y')    ||
        word.sub!(/ness$/, '')  ||
        word.sub!(/ment$/, '')  ||
        word.sub!(/tion$/, '')  ||
        word.sub!(/ing$/, '')   ||
        word.sub!(/ed$/, '')    ||
        word.sub!(/er$/, '')    ||
        word.sub!(/ly$/, '')    ||
        word.sub!(/s$/, '')
      word
    end
  end
end

if defined?(RobotLab) && RobotLab.respond_to?(:register_extension)
  RobotLab.register_extension(:document_store, RobotLab::DocumentStore)
end
