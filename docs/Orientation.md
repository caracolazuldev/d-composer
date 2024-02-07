# Orientation to Decomposer

## Concepts

- **Stack**: 
  An abstraction of a compose-file (docker-compose.yml), or a collection of services that share a network namespace. As a concept, a stack is a set of services that are deployed together. In decomposer, a stack is declared with the `STACK` environment variable, and the services are defined by the `STACK_SERVICES` environment variable.

- **Network**: 
  A docker network namespace. Unless you override `COMPOSER_PROJECT_NAME`, the network name will be set by composer to the current-directory name with a suffix of `_default`. There is no protection against bringing up multiple stacks with the same network name.

- **Volume**:
  A docker volume. Define volumes to be managed by docker if you want to persist data between container runs.

- **Environment File**:
  A file containing environment variables to be used by docker-compose. The `.env` file in the project-root is used by `docker-compose` to set environment variables used by your containers.

- **Container**:
  A running instance of a container image. The containment of a container is of files, system processes, and networking. Containers are created from images, and can be run, started, stopped, and deleted.

- **Image**:
  A read-only template with instructions for creating a Docker container. Images are used to create containers. Images are created with the `docker build` command, and they can be pushed to a registry for others to use.

- **Service**:
  A service is a container running in a managed swarm or cluster. With automatic scaling, or other orchestration features, a service can be a single container or a group of containers. In an active docker compose stack, you can list the services with `docker compose config --services`, or with decomposer, `make services`.

- **Service Declaration**:
  A fragment of a docker-compose file that defines a service. These fragments are compiled by decomposer into a full docker-compose file by `docker compose config`.

- **Task**:
  A task is another name for a container running as a service. You can run ad hoc commands in a service by setting the `TASK` environment variable to the name of the service. In decomposer, a task does not have to exist in your active stack, but it must be defined in a service declaration (i.e. a `.yml` file in the `docker/` directory).

- **Run Command**:
  A command to be run in a service, specified by the `RUN_CMD` environment variable. This is used in conjunction with the `TASK` environment variable to run ad hoc commands in a service. Use `CMD_ARGS` to pass additional options to the command. You will typically define such commands you want to run time and again, in your top-level Makefile.

- **Target**:
  The build-tool, `make`, calls build outputs, "targets", typically application executables. Typical `make` usage is for the cli arguments to be build-targets. In decomposer, the targets are interpreted as `docker compose` commands. Therefor, anything else must be passed as an environment variable, such as `TASK`, `RUN_CMD`, or `CMD_ARGS`.

## Command Wrappers

Decomposer provides a set of command wrappers for `docker-compose` commands. 

## File Structure

Very little is mandatory in terms of file naming and directory structure. Stacks must be defined in the project root, and services must be defined in the `docker/` folder. 

> **NOTE:** Networks and volumes can dynamically be included for a stack by putting a `${STACK}.yml` file in a `network/` or `volume/` folder. **This feature might be removed in future versions.**

You can define a stack just using environment variables, but you will probably want to save those configs in files for reuse. **When you set the `STACK` environment variable, `${STACK}.stack` will be included by `make`, while, `${STACK}.env` will be included by `docker-compose`.**

Service declarations are intended to be composed into stacks, so excluding any other top-level compose-file entities

> **NOTE:** Paths in service declarations, such as build-context, should be relative to the project directory.

A active stack-name is cached in a `.active` file in the project root. This file is used to determine the active stack when the `STACK` environment variable is not set.

## Environment File Precedence

As multiple environment files are aggregated, later settings will supersede earlier settings. This can be a double-edged sword, so attention should be given to the precedence of automatic aggregation.

In order of precedence (reverse order of inclusion):

- Variables from your executing shell environment
- Exported variables included by your top-level Makefile
- Files listed in `ENV_INCLUDES` (increasing order of precedence)
- The `${TASK}.env` file in the project-root, if `TASK` is defined.
- The `${STACK}.env` file in the project-root.
- Files automatically included in `docker/`, e.g. `docker/${SERVICE}.env`

> **TIP:** define useful defaults in `docker/${SERVICE}.env` files, and override them either in the `${STACK}.env` file or in a file in a custom location added to `ENV_INCLUDES`. For example, you can define a common set of database credentials in `conf/db.env`, and include it in `ENV_INCLUDES` for multiple stacks.

## Examples

Here is an example usage in a project's top-level Makefile, for an application targeting two versions of PHP. It includes development workflow tools, and a target to build all of the images used by both stacks.

```Makefile
-include conf/project.env
include decomposer.mk

DKC = docker compose

MANAGED_DIRS ?= volume/htdocs volume/home volume/logs

${MANAGED_DIRS}:
	mkdir $@

facls:
	TASK=shell WORKING_DIR=/var/src/nadcp-stage make run RUN_CMD='make -f src/facls.mk dev'

shell:
	$(DKC) exec --workdir /var/www/html shell /bin/bash

sql-cli:
	make run TASK=mysql8-cli STACK=sql-cli

#
# DEV Utils
#

flush:
	WORKING_DIR=/var/www/html make run TASK=shell RUN_CMD='wp cache flush'

watch:
	# TODO: see watch.md

tail-wp:
	WORKING_DIR=/var/www/html make run TASK=shell RUN_CMD='tail -f /var/www/html/wp-content/debug.log'

#
# Container Image Development
#

build-containers:
	$(MAKE) activate STACK=build-image dkc-build

release:
	${MAKE} deactivate
	${MAKE} activate STACK=build-image
	cp docker-compose.yml build-compose.yml
	${MAKE} deactivate
	${MAKE} activate STACK=dev-php7
	cp docker-compose.yml php7-compose.yml
	${MAKE} deactivate
	${MAKE} activate STACK=dev-php8
	cp docker-compose.yml php8-compose.yml
	sed -i 's#$(shell pwd)#.#g' *-compose.yml
	$(MAKE) deactivate
	$(info NB: replace environment vars in compose files.)	

```

> **NOTE:** the release target saves unique compose files for each stack. This enables committing the stack-specific compose files to version control, in case you want to ease the workflow for other developers that can then either copy or link the stack-specific compose file to `docker-compose.yml` in the project root. Also note how a "build-image" stack was defined to build the images for all of the stacks, without having to activate each stack in turn.