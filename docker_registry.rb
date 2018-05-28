#!/usr/bin/env ruby

require "json"
require "net/http"
require "optparse"
require "pp"
require "openssl"
require "uri"
require "set"
require "yaml"

def q(s)
    URI.escape(s)
end
class Layer
    attr_reader :digest, :size

    def initialize(dict)
        @dict = dict
        @size = dict["size"]
        @digest = dict["digest"]
    end
end


class Manifest
    attr_reader :dict, :version, :digest, :layers
    def initialize(digest, dict)
        @digest = digest
        @dict = dict
        @version = dict["schemaVersion"]
        raise "unknown manifest version: #{@version}" unless @version == 2
        @layers = dict["layers"].map { |d| Layer.new(d) }
    end
end

class HttpError < Exception
    attr_reader :code, :code_message, :body
    def initialize(code, code_message, body)
        super("HTTP Error #{code}: #{code_message}")
        @body = body
        @code_message = code_message
        @code = code
    end
end

class DockerRegistry
    def initialize(base_url, ca_file=nil, insecure=false)
        @base_url = base_url + "/v2/"
        @ca_file = ca_file
        @insecure = insecure
    end

    def request(url, clazz=Net::HTTP::Get)
        uri = URI(@base_url + url)
        res = Net::HTTP.start(uri.host, uri.port,
                              :use_ssl => uri.scheme == 'https',
                              :ca_file => @ca_file,
                              :verify_mode => @insecure ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER) do |http|
            request = clazz.new uri.request_uri
            request["Accept"] = "application/vnd.docker.distribution.manifest.v2+json"
            #pp uri.request_uri
            http.request request
        end
        res
    end

    def json_request(url, clazz=Net::HTTP::Get)
        res = request(url, clazz)
        if res.is_a? Net::HTTPSuccess
            body = if res.body.empty? then nil else JSON.parse(res.body) end
            [body, res.to_hash]
        elsif res.is_a? Net::HTTPClientError
            raise HttpError.new(res.code, res.message, res.body)
        else
            raise "Unknown response: #{res}"
        end
    end

    def validate()
        begin
            res, _ = json_request("")
            if res != {}
                raise "Error expected empty object as V2 validation result; got #{res}"
            end
        rescue Net::HTTPServerError => e
            raise "Error validing Registry Server API v2 - got #{e}"
        end
    end

    def list_repositories()
        res, _ = json_request("_catalog")
        res["repositories"]
    end

    def list_tags(repo)
        res, _ = json_request("#{repo}/tags/list")
        res["tags"] or []
    end

    def get_manifest(repo, reference)
        manifest, headers = json_request("#{q(repo)}/manifests/#{q(reference)}")
        Manifest.new(headers["docker-content-digest"].first, manifest)
    end

    def delete_manifest(repo, digest)
        res = json_request("#{q(repo)}/manifests/#{q(digest)}", clazz=Net::HTTP::Delete)
    end

    def delete_blob(repo, digest)
        res = request("#{q(repo)}/blobs/#{q(digest)}", clazz=Net::HTTP::Delete)
    end
end

if __FILE__ == $PROGRAM_NAME
    options = {
        :insecure => false
    }

    OptionParser.new do |opts|
        opts.banner = "Usage: docker_registry.rb [options] <command>"

        opts.on("-cFILE", "--ca-file", "Trust CA certificate from file") do |c|
            options[:ca_file] = c
        end
        opts.on("-k", "--insecure", "Do not verify peer SSL certificate") do |c|
            options[:insecure] = true
        end
    end.parse!

    if ARGV.size < 2
        puts "Syntax: #{$0} <registry> command"
        exit 1
    end

    r = DockerRegistry.new(ARGV[0], options[:ca_file], options[:insecure])
    r.validate
    result = r.send(ARGV[1], *ARGV[2..-1])
    if result.is_a? Enumerable
        for r in result
            puts "- #{r}"
        end
    else
        puts result
    end
end
