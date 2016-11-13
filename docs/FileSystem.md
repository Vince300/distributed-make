## Distributed file properties

* Is hosted by a particular agent in its working directory (source directory for the driver agent, temporary directory
for a worker).
* Is named relatively to the root of the source directory.
* Has binary contents
* Has attributes (chmod, mtime)

## File sharing semantics

A file that is needed by a Makefile rule *must* be listed as a dependency of this rule. There is no support for a base
file set copy on worker start. This also means all files are treated on the same level.

A worker agent must:

* Download dependencies before executing a rule.

The driver agent must:

* Download the file produced by a rule, if any.

## Failure modes

A worker may fail before the file transfer of the produced file (after executing a rule) to the master has completed.

This means the rule should be run again by another worker. A rule should then be considered done iff the file transfer
to the master process is completed.

## File tuple specification

An agent who has a particular file should publish a tuple like the following :

```ruby
[:file, name, host, handle]
```

* `:file` indicates this tuple represents a file
* `name` is the name of the file represented by this tuple
* `host` is the hostname of the publishing agent (derived from the druby service url)
* `handle` is a distributed object with a method that can be invoked to initiate the file transfer

## File search algorithm

When an agent wants to process a given rule, to find out where to download a file it should try to read the following
tuples :

* `[:file, name, host, nil]`: wanted file, on the same host, to allow zero-copy between hosts using hardlinking
* `[:file, name, nil, nil]`: wanted file, on any host, should be chosen randomly

## Handle distributed object

The handle distributed object in a file tuple is hosted by the agent sharing the file. Its `get_data` method can be
called by the requesting process along with a block, which will be invoked with data chunks transferred over the
network.

This method can deny the file transfer in order to better schedule transfer between hosts.

## Multihost optimization

When starting a new build process, workers will simultaneously request files from the driver process, as none have the
file for hardlinking. In order to prevent that, the file serving agent should only allocate one slot per (host,
requested file) combination, so the requesting process will retry downloading the file from another host, eventually
requesting the file from the same host and creating the hardlink.
