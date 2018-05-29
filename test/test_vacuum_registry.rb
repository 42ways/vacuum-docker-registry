#!/usr/bin/env ruby
require "minitest/autorun"

require_relative "../vacuum-registry.rb"

class TestVacuumRegistry < Minitest::Test
    def test_to_token_array
        assert_equal [], to_token_array("")
        assert_equal ["abc" ], to_token_array("abc")
        assert_equal [ 123 ], to_token_array("123")
        assert_equal [ 1, "a" ], to_token_array("1a")
        assert_equal ["abc", 123, "AT&Z", 9 ], to_token_array("abc123AT&Z9")
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
