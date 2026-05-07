# frozen_string_literal: true

require "test_helper"

class RobotLab::DocumentStoreTest < Minitest::Test
  # Skip the whole suite if fastembed model download would be needed
  # in a network-restricted environment (e.g. CI without model cache).
  # Set ROBOT_LAB_SKIP_EMBEDDINGS=true to bypass.
  def setup
    skip "Set ROBOT_LAB_SKIP_EMBEDDINGS=false to run embedding tests" \
      if ENV.fetch("ROBOT_LAB_SKIP_EMBEDDINGS", "false") == "true"

    @store = RobotLab::DocumentStore.new
  end

  def test_version_is_defined
    refute_nil RobotLab::DocumentStore::VERSION
  end

  # ---------------------------------------------------------------------------
  # Store / retrieve
  # ---------------------------------------------------------------------------

  def test_store_increases_size
    assert_equal 0, @store.size
    @store.store(:doc_a, "Ruby on Rails is a full-stack web framework written in Ruby.")
    assert_equal 1, @store.size
  end

  def test_keys_reflects_stored_documents
    @store.store(:doc_a, "Ruby on Rails is a full-stack framework.")
    @store.store(:doc_b, "Postgres is a powerful relational database.")
    assert_includes @store.keys, :doc_a
    assert_includes @store.keys, :doc_b
  end

  def test_store_returns_self_for_chaining
    result = @store.store(:doc_a, "some text about Ruby programming language")
    assert_equal @store, result
  end

  def test_overwrite_existing_key
    @store.store(:doc_a, "First version of the Ruby document text here.")
    @store.store(:doc_a, "Updated version with different Ruby content here.")
    assert_equal 1, @store.size
  end

  # ---------------------------------------------------------------------------
  # Search ranking
  # ---------------------------------------------------------------------------

  def test_relevant_document_ranks_first
    @store.store(:ruby_doc,     "Ruby is a dynamic, object-oriented programming language.")
    @store.store(:postgres_doc, "PostgreSQL is an advanced open-source relational database.")

    results = @store.search("object-oriented programming language", limit: 2)
    assert_equal :ruby_doc, results.first[:key]
  end

  def test_results_are_sorted_by_score_descending
    @store.store(:doc_a, "Ruby on Rails enables rapid web application development.")
    @store.store(:doc_b, "Postgres handles complex SQL queries efficiently at scale.")
    @store.store(:doc_c, "Sidekiq processes background jobs in Ruby applications.")

    results = @store.search("Ruby web development", limit: 3)
    scores  = results.map { |r| r[:score] }
    assert_equal scores.sort.reverse, scores
  end

  def test_result_contains_key_text_and_score
    @store.store(:doc_a, "Ruby on Rails is a web framework for rapid development.")

    results = @store.search("Rails web framework")
    refute_empty results

    r = results.first
    assert_equal :doc_a,   r[:key]
    assert_kind_of String, r[:text]
    assert_kind_of Float,  r[:score]
    assert_operator r[:score], :>=, 0.0
    assert_operator r[:score], :<=, 1.0
  end

  # ---------------------------------------------------------------------------
  # Empty store
  # ---------------------------------------------------------------------------

  def test_search_on_empty_store_returns_empty_array
    assert_equal [], @store.search("anything")
  end

  def test_empty_predicate
    assert @store.empty?
    @store.store(:doc_a, "Ruby programming language is object-oriented and dynamic.")
    refute @store.empty?
  end

  # ---------------------------------------------------------------------------
  # Limit
  # ---------------------------------------------------------------------------

  def test_limit_caps_results
    5.times { |i| @store.store(:"doc_#{i}", "Ruby on Rails development topic #{i} web framework.") }
    results = @store.search("Ruby Rails", limit: 2)
    assert_operator results.size, :<=, 2
  end

  # ---------------------------------------------------------------------------
  # Delete / clear
  # ---------------------------------------------------------------------------

  def test_delete_removes_document
    @store.store(:doc_a, "Ruby programming language.")
    @store.delete(:doc_a)
    assert_equal 0, @store.size
  end

  def test_delete_returns_self
    @store.store(:doc_a, "Ruby programming language.")
    assert_equal @store, @store.delete(:doc_a)
  end

  def test_clear_removes_all_documents
    @store.store(:doc_a, "Ruby programming language.")
    @store.store(:doc_b, "Postgres relational database.")
    @store.clear
    assert_equal 0, @store.size
  end

  def test_clear_returns_self
    assert_equal @store, @store.clear
  end
end
