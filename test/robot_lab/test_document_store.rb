# frozen_string_literal: true

require 'test_helper'

module RobotLab
  class DocumentStoreTest < Minitest::Test
    # Skip the whole suite if fastembed model download would be needed
    # in a network-restricted environment (e.g. CI without model cache).
    # Set ROBOT_LAB_SKIP_EMBEDDINGS=true to bypass.
    def setup
      skip 'Set ROBOT_LAB_SKIP_EMBEDDINGS=false to run embedding tests' \
        if ENV.fetch('ROBOT_LAB_SKIP_EMBEDDINGS', 'false') == 'true'

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
      @store.store(:doc_a, 'Ruby on Rails is a full-stack web framework written in Ruby.')
      assert_equal 1, @store.size
    end

    def test_keys_reflects_stored_documents
      @store.store(:doc_a, 'Ruby on Rails is a full-stack framework.')
      @store.store(:doc_b, 'Postgres is a powerful relational database.')
      assert_includes @store.keys, :doc_a
      assert_includes @store.keys, :doc_b
    end

    def test_store_returns_self_for_chaining
      result = @store.store(:doc_a, 'some text about Ruby programming language')
      assert_equal @store, result
    end

    def test_overwrite_existing_key
      @store.store(:doc_a, 'First version of the Ruby document text here.')
      @store.store(:doc_a, 'Updated version with different Ruby content here.')
      assert_equal 1, @store.size
    end

    # ---------------------------------------------------------------------------
    # Search ranking
    # ---------------------------------------------------------------------------

    def test_relevant_document_ranks_first
      @store.store(:ruby_doc,     'Ruby is a dynamic, object-oriented programming language.')
      @store.store(:postgres_doc, 'PostgreSQL is an advanced open-source relational database.')

      results = @store.search('object-oriented programming language', limit: 2)
      assert_equal :ruby_doc, results.first[:key]
    end

    def test_results_are_sorted_by_score_descending
      @store.store(:doc_a, 'Ruby on Rails enables rapid web application development.')
      @store.store(:doc_b, 'Postgres handles complex SQL queries efficiently at scale.')
      @store.store(:doc_c, 'Sidekiq processes background jobs in Ruby applications.')

      results = @store.search('Ruby web development', limit: 3)
      scores  = results.map { |r| r[:score] }
      assert_equal scores.sort.reverse, scores
    end

    def test_result_contains_key_text_and_score
      @store.store(:doc_a, 'Ruby on Rails is a web framework for rapid development.')

      results = @store.search('Rails web framework')
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
      assert_equal [], @store.search('anything')
    end

    def test_empty_predicate
      assert @store.empty?
      @store.store(:doc_a, 'Ruby programming language is object-oriented and dynamic.')
      refute @store.empty?
    end

    # ---------------------------------------------------------------------------
    # Limit
    # ---------------------------------------------------------------------------

    def test_limit_caps_results
      5.times { |i| @store.store(:"doc_#{i}", "Ruby on Rails development topic #{i} web framework.") }
      results = @store.search('Ruby Rails', limit: 2)
      assert_operator results.size, :<=, 2
    end

    # ---------------------------------------------------------------------------
    # Delete / clear
    # ---------------------------------------------------------------------------

    def test_delete_removes_document
      @store.store(:doc_a, 'Ruby programming language.')
      @store.delete(:doc_a)
      assert_equal 0, @store.size
    end

    def test_delete_returns_self
      @store.store(:doc_a, 'Ruby programming language.')
      assert_equal @store, @store.delete(:doc_a)
    end

    def test_clear_removes_all_documents
      @store.store(:doc_a, 'Ruby programming language.')
      @store.store(:doc_b, 'Postgres relational database.')
      @store.clear
      assert_equal 0, @store.size
    end

    def test_clear_returns_self
      assert_equal @store, @store.clear
    end

    # ---------------------------------------------------------------------------
    # Semantic scoring quality — validates that search returns meaningful scores.
    # These tests belong here, not in robot_lab core, because they verify
    # DocumentStore's embedding behaviour rather than Robot logic.
    # ---------------------------------------------------------------------------

    def test_related_query_scores_above_low_threshold
      @store.store(:skill_a, 'Verifies and validates AgentSkills integration and catalog lookup')
      results = @store.search('I need to verify the AgentSkills integration works', limit: 5)
      assert results.any? { |r| r[:score] >= 0.3 },
             'Expected at least one result with score >= 0.3 for a related query'
    end

    def test_unrelated_query_scores_below_perfect_threshold
      @store.store(:skill_a, 'Verifies and validates AgentSkills integration and catalog lookup')
      results = @store.search('I need to verify the AgentSkills integration works', limit: 5)
      refute results.all? { |r| r[:score] >= 0.999 },
             'Expected no result to score >= 0.999 for a non-identical query'
    end
  end
end

# ---------------------------------------------------------------------------
# Subclass that disables fastembed to exercise the TF-IDF fallback path
# without requiring the fastembed gem to be absent.
# ---------------------------------------------------------------------------

module RobotLab
  class DocumentStoreFallback < RobotLab::DocumentStore
    def initialize(...)
      super
      @using_fastembed = false
    end
  end
end

module RobotLab
  class DocumentStoreFallbackTest < Minitest::Test
    def setup
      @store = RobotLab::DocumentStoreFallback.new
    end

    def test_fallback_mode_is_active
      refute @store.instance_variable_get(:@using_fastembed)
    end

    def test_basic_store_and_search_ranks_correctly
      @store.store(:ruby_doc, 'Ruby programming language dynamic object oriented')
      @store.store(:pg_doc,   'PostgreSQL database relational queries')
      results = @store.search('Ruby programming', limit: 2)
      assert_equal :ruby_doc, results.first[:key]
    end

    def test_search_on_empty_store
      assert_equal [], @store.search('anything')
    end

    def test_result_structure_is_correct
      @store.store(:doc, 'Ruby on Rails web framework')
      r = @store.search('Rails framework').first
      assert_equal :doc,      r[:key]
      assert_kind_of String,  r[:text]
      assert_kind_of Float,   r[:score]
    end

    def test_stopwords_only_text_scores_zero
      # All stop words → empty TF-IDF vector → sparse_cosine({}, {}) → 0.0
      @store.store(:stopwords, 'the a an is are')
      results = @store.search('the a an', limit: 1)
      assert_equal 0.0, results.first[:score]
    end

    def test_all_stem_suffix_patterns
      # Covers ies→y, ness→'', ment→'', tion→'', ing→'', ed→'', er→'', ly→'', s→'', no-match
      @store.store(:doc, 'activities darkness development configuration ' \
                         'running deployed server robots quickly ruby')
      results = @store.search('configuration development activities', limit: 1)
      assert results.first[:score] > 0.0
    end
  end
end

# ---------------------------------------------------------------------------
# Edge-case tests for cosine_similarity private method (fastembed path).
# These cover defensive guards that public-API tests cannot easily reach.
# ---------------------------------------------------------------------------

module RobotLab
  class DocumentStoreEdgeCaseTest < Minitest::Test
    def setup
      @store = RobotLab::DocumentStore.new
    end

    def test_cosine_similarity_returns_zero_for_nil_vectors
      assert_equal 0.0, @store.send(:cosine_similarity, nil, nil)
      assert_equal 0.0, @store.send(:cosine_similarity, nil, [1.0])
      assert_equal 0.0, @store.send(:cosine_similarity, [1.0], nil)
    end

    def test_cosine_similarity_returns_zero_for_empty_vectors
      assert_equal 0.0, @store.send(:cosine_similarity, [], [])
      assert_equal 0.0, @store.send(:cosine_similarity, [], [1.0, 0.5])
      assert_equal 0.0, @store.send(:cosine_similarity, [1.0, 0.5], [])
    end

    def test_cosine_similarity_returns_zero_for_mismatched_lengths
      assert_equal 0.0, @store.send(:cosine_similarity, [1.0, 2.0], [1.0, 2.0, 3.0])
    end

    def test_cosine_similarity_returns_zero_for_zero_vector
      assert_equal 0.0, @store.send(:cosine_similarity, [0.0, 0.0], [1.0, 2.0])
    end
  end
end
