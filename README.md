# vacuum-docker-registry - A simple vacuum script for docker registries

This is a simple vacuum script that cleans old images (:= 'manifests' in
docker-registry lingo) from a docker-registry. It it stateless except for its
configuration and only uses the tags from the registry.

A typical use case is to keep the latest n builds from a CI system like jenkins,
but also any that are currently used in production.

**Note**: The docker registry currently (as of version 2.4) does not provide a
REST API to actually free ("garbage collect") the disk space. This tool just
cleans up the metadata.

In order to free the disk space, you have to run the
*Docker Registry Garbage Collection* as described [here](https://docs.docker.com/registry/garbage-collection/).

A typical wrapper script could look like this:
```bash
   rv=vacuum-registry.rb
   if [[ $rv == 0 ]]; then
      # images were deleted
      # shutdown docker registry service
      service docker-registry stop
      docker run
      service docker-registry start
   fi
```

## Cleanup Strategy:

`vacuum-registry` inspects each repository ("image" ) listed in its configuration.

For each repository, it lists all the tags. If a tag is matched by one regular
expressions in the "cleanup" section of the config, it is elegible for cleanup.

All tags not matching an entry of the "cleanup" section are always kept. Of the
candidates we keep the n highest ones according to mixed alpha-numeric order
(see below).

We then delete all manifests that are _only_ referenced by deleted tags (but
not by any of the kept tags).


## Example configuration

```
registry: http://localhost:5000
keep_count: 5
repositories:
    my-docker-image:
        cleanup:
            - "b-.*"
```

This would inspect the image `my-docker-image` on the docker repository `http://localhost:5000`.

Tags matching the regular expression `/b-.*/` are considered for cleanup. We always keep all images
pointed to by the last five build tags, as well as any images pointed to by *other* tags not
listed in the cleanup section.

Note this enables us to keep any images that are currently in production by tagging those images;
e.g., by `prod-#{servername}`.

## Tags sort order

A configurable number of the "cleanup" tags is also kept. We keep the 'highest' tags
according to a mixed alpha-numeric sort. Mix alpha numeric order
means that tags are split into numeric tokens and non-numeric tokens. Numeric tokens
are sorted numerically, non-numeric tokens are sorted alphabetically.

This means that:
 - a-5 is before b-5
 - a-9 is before a-10
