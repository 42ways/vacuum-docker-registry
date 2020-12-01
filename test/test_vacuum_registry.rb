#!/usr/bin/env ruby
require "minitest/autorun"

require_relative "../vacuum-registry.rb"

class TestVacuumRegistry < Minitest::Test
    def test_to_token_array
        assert_equal [], to_token_array("")
        assert_equal [ [STRING_TOKEN, "abc"] ], to_token_array("abc")
        assert_equal [ [NUMERIC_TOKEN, 123] ], to_token_array("123")
        assert_equal [ [NUMERIC_TOKEN, 1], [STRING_TOKEN, "a"] ], to_token_array("1a")
        assert_equal [ [STRING_TOKEN, "abc"], [NUMERIC_TOKEN, 123], [STRING_TOKEN, "AT&Z"], [NUMERIC_TOKEN, 9] ], to_token_array("abc123AT&Z9")
        assert_equal -1, to_token_array("1.0") <=> to_token_array("1.1")
        assert_equal 1, to_token_array("1.1") <=> to_token_array("1.0")
        assert_equal 1, to_token_array("1.10") <=> to_token_array("1.9")
        assert_equal 1, to_token_array("1.10-b1") <=> to_token_array("1.9-b2")
        assert_equal 1, to_token_array("b-10") <=> to_token_array("b-9")
        assert_equal -1, to_token_array("b-10") <=> to_token_array("c-9")
        assert_equal 1, to_token_array("aa") <=> to_token_array("a")
        assert_equal 1, to_token_array("a") <=> to_token_array("9")
        assert_equal 1, to_token_array("1.a") <=> to_token_array("1.9")
    end

    def test_cleanup_tags
        registry = Minitest::Mock.new

        tags = 1.upto(10).map { |d| "b-#{d}" }
        registry.expect :list_tags, tags, [ "test-repo" ]

        tags.each do |t|
            registry.expect :get_manifest, Manifest.new(t, { "schemaVersion" => 2, "layers" => [] }), [ "test-repo", t ]
        end

        digests = cleanup_tags(registry, "test-repo", [/b-\d+/], 5, true)
        assert_equal 1.upto(5).map { |d| "b-#{d}" }.to_set, digests
    end

    def test_cleanup_tags_grouped
        registry = Minitest::Mock.new

        tags = 1.upto(10).map { |d| "b-#{d}" }
        tags += 1.upto(6).map { |d| "foo-b-#{d}" }
        registry.expect :list_tags, tags, [ "test-repo" ]

        tags.each do |t|
            registry.expect :get_manifest, Manifest.new(t, { "schemaVersion" => 2, "layers" => [] }), [ "test-repo", t ]
        end

        digests = cleanup_tags(registry, "test-repo", [/((?<group>\w*)-)?b-\d+/], 5, true)
        assert_equal (1.upto(5).map { |d| "b-#{d}" } + [ "foo-b-1" ] ).to_set, digests
    end

end
