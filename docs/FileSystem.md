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
[:file, name, host, port]
```

* `:file` indicates this tuple represents a file
* `name` is the name of the file represented by this tuple
* `host` is the hostname of the publishing agent (derived from the druby service url)
* `port` is the randomly chosen port on the host for the file dispatching agent

## File search algorithm

When an agent wants to process a given rule, to find out where to download a file it should try to read the following
tuples :

* `[:file, name, host, nil]`: wanted file, on the same host, to allow zero-copy between hosts using hardlinking
* `[:file, name, nil, nil]`: wanted file, on any host, should be chosen randomly

## File server

All agents should run a TCP server on a given port, that handle incoming requests for files from other agents. This
server is responsible for allocating file serving workers that will stream the data (on another socket) to the
requesting agents, with minimal overhead.

## Example session between the driver and a worker

* Worker A wants to work on cube_anim.blend
* Worker A reads from the tuple space that the driver process has the file, and is receiving requests on port 12345
* Worker A connects to the port 12345 of the driver process
* Once the connection is established, Worker A sends an array `[:remote, name]` where name is the string corresponding
to the file name being requested
* The driver process responds with an array `[:connect, port]` corresponding to the port number for this file transfer
(if an error occurred preparing the file transfer, `[:error, etc]` is returned).
* Worker A then proceeds to connect to the port indicated in the previous exchange
* The driver agent streams the data to the worker and closes the connection as soon as the file has been transferred
* Worker A closes the connection to the driver process, thus terminating the exchange

## Example session between two workers on the same host

A worker requesting a file from the same host knows can hardlink to the temporary file in order to optimize file
transfers.

* Worker A wants to work on cube_anim.blend
* Worker B, on the same machine, already has the requested file
* Worker A connects to the file server port for Worker B (known using the file tuple)
* Worker A then sends an array `[:local, name]` in order to request the file from Worker B
* Worker B responds with the absolute path to the requested file as a string
* Worker A creates a hardlink to the returned path in order to have access to the file in its working directory
* Worker A closes the connection to the other process, thus terminating the exchange

## Multihost optimization

When starting a new build process, workers will simultaneously request files from the driver process, as none have the
file for hardlinking. In order to prevent that, the file serving agent should only allocate one slot per (host,
requested file) combination, so the requesting process will retry downloading the file from another host, eventually
requesting the file from the same host and creating the hardlink.
