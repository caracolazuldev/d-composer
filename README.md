**TODO:** *this documentation is out of date!*

# DECOMPOSING COMPOSE DEFINITIONS

Container composition files define service stacks constructed of orchestrated tasks. Docker compose assumes one stack in a working directory and one stack per composition file.  Utilizing multiple stacks in different configurations of similar services causes duplication of service and global object declarations.

A decomposed docker-compose YAML file is therefore split into files in the stack/ and docker/ folders, in .yml, .env, and .conf files. The purposes of these files are:
- stack/...yml defines top-level stack entities other than services
- docker/...yml for each service, automatically aggregated
- stack/...conf to configure the execution of decomposer

## ENV VARS

- `COMPOSER_PROJECT_NAME` 	[ derives the network name ]
- `STACK_SERVICES` 	[ `$${STACK_ID}_STACK` is appended if defined ]
- `ENV_INCLUDES`
- `STACK` 	[ derives `STACK_ID` (upper-case) and `STACK_NAME` (lower-case) ]
- `TASK`
- `DK_CMP_OPTS`	[ options to docker-compose command ]
- `RUN_CMD`		[ container commands ]
- `CMD_ARGS`		[ options to `RUN_CMD` ]

### EXAMPLES

`STACK` must (almost) always be defined. Set and export it in your session for convenience. Setting TASK in your session has the potential to be risky.
	
``` bash
STACK=lamp make up

STACK=lamp TASK=shell make run

make TASK=mysqld top

make config CMD_ARGS=--services

make build TASK=php8-apache DK_CMP_OPTS='--no-cache'

make exec TASK=php8-apache RUN_CMD='php -i'

# alias for run -d
make rund TASK=shell RUN_CMD='php' CMD_ARGS="-r 'phpinfo();'"
```

### ALIASES

Any docker-compose commands are available invoked with the prefix, "dkc-".

Invoke using the prefix if files or directories conflict with command names, or if an alias does not exist. Most docker-compose commands are aliased so they can be invoked simply e.g.  `make build`, `make up`, etc.

### MORE ON GETTING ORIENTED TO DECOMPOSER

For more on folder structure, environment variables and configuration files, see [docs/Orientation](docs/Orientation.md).

### MORE ON GETTING STARTED WITH DOCKER COMPOSE

If you are a developer still new to all of this infrastructure as code world, see our [docs/Compose Quick-start](docs/Compose Quick-start.md) for some sign-posts.

