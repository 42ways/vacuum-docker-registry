#!/usr/bin/env ruby
#
# vacuum-registry - a simple vacuum script for docker registries
#
# Copyright 2016 42ways GmbH
#
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
require "json"
require "net/http"
require "optparse"
require "pp"
require "uri"
require "set"
require "yaml"

require_relative "./docker_registry"

def to_token_array(s)
    # partition the string into numeric and non-numeric token, for better
    # mixed search
    s.partition(/\d+/).map { |w| if w =~ /\d+/ then w.to_i else w end }
end

def cleanup_tags(reg, repo, cleanup_res=[], keep_count=5, dry_run=true)
    tags = reg.list_tags(repo)
    tags_digests = {}
    digest_manifests = {}
    keep_tags = [].to_set
    cleanup_candidates = [].to_set
    
    for tag in tags
        manifest = reg.get_manifest(repo, tag)
        digest_manifests[manifest.digest] = manifest
        tags_digests[tag] = manifest.digest

        if cleanup_res.any? {|re| re.match(tag)}
            cleanup_candidates.add(tag)
        else
            keep_tags.add(tag) 
        end
    end
    sorted = cleanup_candidates.sort_by { |s| to_token_array(s) }
    puts "cleanup candidates: #{sorted}"

    keep_highest = sorted.reverse[0...keep_count]
    keep_tags |= keep_highest
    puts "Keep_tags: #{keep_tags.sort_by {|s| to_token_array(s) }}"

    keep_digests = keep_tags.map { |t| tags_digests[t] }.to_set
    delete_digests = tags_digests.values.to_set - keep_digests

    if delete_digests
        puts "Digests to remove:"
        for digest in delete_digests.sort
            puts " - #{digest} (#{sorted.find_all {|t| tags_digests[t] == digest }.join(", ")})"
        end
        if not dry_run
            for digest in delete_digests
                reg.delete_manifest(repo, digest)
            end
        end
    end
    delete_digests
end

options = {
    :config => "vacuum-registry.yml",
    :dry_run => false,
}

OptionParser.new do |opts|
    opts.banner = "Usage: vacuum-registry.rb [options]"

    opts.on("-n", "--dry-run", "Don't change anything") do |d|
        options[:dry_run] = true
    end

    opts.on("-cCFG", "--config=CFG", "config file to use") do |c|
        options[:config] = c
    end
    opts.on("--ca-file", "Trust CA certificate from file") do |c|
        options[:ca_file] = c
    end
    opts.on("-k", "--insecure", "Do not verify peer SSL certificate") do |c|
        options[:insecure] = true
    end
end.parse!

keep_spec = YAML.load_file(options[:config])

reg_url = keep_spec["registry"] or "https://localhost:5000"

reg = DockerRegistry.new(
    reg_url,
    options.fetch(:ca_file) { keep_spec["ca_file"] },
    options.fetch(:insecure) { keep_spec.fetch("insecure") { false }})
reg.validate()

default_keep_count = keep_spec["keep_count"] || 5

total = 0
for repo, repo_spec in keep_spec["repositories"]
    cleanup_res = repo_spec["cleanup"].map { |r| Regexp.new(r) }
    keep_count = repo_spec["keep_count"] || default_keep_count
    puts "=== Cleaning up repo #{repo}, Tags: #{cleanup_res}, keeping #{keep_count}"
    deleted = cleanup_tags(reg, repo, cleanup_res, keep_count, options[:dry_run])
    total += deleted.size
end

exit total == 0 ? 100 : 0
