-include service/${TASK}.conf

ifdef STACK
STACK := $(strip ${STACK})
STACK_NAME := $(shell echo "${STACK}" | tr A-Z a-z)
STACK_ID := $(shell echo "${STACK}" | tr a-z A-Z)
include stack/${STACK}.conf
endif

ifdef ${STACK_ID}_STACK
STACK_SERVICES += ${${STACK_ID}_STACK}
endif

if-file = $(if $(wildcard $1/$2), $1/$2)

# # #
# /dev/null to avoid error from `cat` if no env files are used.
# precedence of .env files by location or declaration:
# ENV_INCLUDES > stack/${STACK_ID}.env > stack/ > service/
define stack-env-includes
/dev/null \
$(foreach svc,${STACK_SERVICES} ${TASK},$(call if-file,service,${svc}.env)) \
$(foreach stk,${STACK_SERVICES} ${STACK_ID} ${TASK},$(call if-file,stack,${stk}.env)) \
${ENV_INCLUDES}
endef

.%.env:
	@ cat ${stack-env-includes} >$@

stack-env-file = .${STACK_NAME}.env
--env-file = $(if $(wildcard ${stack-env-file}),--env-file=${stack-env-file})

include-if = $(if $(wildcard $1/$2),-f $1/$2)

define stack-config-includes
$(foreach type,stack network volume config,$(call include-if,${type},${STACK_NAME}.yml))\
$(foreach svc,${STACK_SERVICES},$(call include-if,service,${svc}.yml))
endef

%.yml:
	@ docker-compose --project-directory . ${stack-config-includes} config > $@ 2>/dev/null

# # #
# set and customize docker-compose commands
# and implement custom actions
# # #
custom-actions := down rund orphans services

define set-action
$(filter-out ${custom-actions},$*)\
$(if $(filter down,$*),$(if ${TASK},rm --force --stop,down))\
$(if $(filter orphans,$*),down --remove-orphans)\
$(if $(filter rund,$*),run -d)\
$(if $(filter run,$*),--rm)\
$(if $(filter up,$*),-d)\
$(if $(filter services,$*),config --services)
endef

# # #
# docker-compose wrapper
# # #

dkc-%: .${STACK_NAME}-compose.yml $(if $(wildcard service/${TASK}.yml), service/${TASK}.yml) | ${stack-env-file}
	@ docker-compose ${--env-file} $(foreach f,$^,-f $f) $(set-action) ${DK_CMP_OPTS} $(if $(filter-out config,$*),${TASK}) $(if $(filter rund run exec,$*),${RUN_CMD}) ${CMD_ARGS}

# # #
# Aliases
# # #

build: dkc-build
config: dkc-config
create: dkc-create
down: dkc-down
events: dkc-events
exec: dkc-exec
logs: dkc-logs
pause: dkc-pause
restart: dkc-restart
rm: dkc-rm
run: dkc-run
services: dkc-services
start: dkc-start
stop: dkc-stop
top: dkc-top
unpause: dkc-unpause
up: dkc-up

# custom decomposer cmds:
orphans: dkc-orphans
rund: dkc-rund

# # #
# HALP
# # #

define HELP_TXT :=

				DECOMPOSING COMPOSE DEFINITIONS

	Container composition files define service stacks constructed of 
	orchestrated tasks. Docker compose assumes one stack in a working directory 
	and one stack per composition file.  Utilizing multiple stacks in different 
	configurations of similar services causes duplication of service and global 
	object declarations.

	A decomposed docker-compose YAML file is therefore split into files in the stack/
	and services/ folders, in .yml, .env, and .conf files. The purposes of these
	files are:
		- .env are aggregated into one file passed with `--env-file`
		- stack/...yml defines top-level stack entities other than services
		- service/...yml for each service, automatically aggregated
		- stack/...conf to configure the execution of decomposer

	TIP: `make dkc-config` to review the generated docker-compose.yml

ENV VARS

	- COMPOSER_PROJECT_NAME 	[ derives the network name ]
	- STACK_SERVICES 	[ $${STACK_ID}_STACK is appended if defined ]
	- ENV_INCLUDES
	- STACK 	[ derives STACK_ID (upper-case) and STACK_NAME (lower-case) ]
	- TASK
	- DK_CMP_OPTS	[ options to docker-compose command ]
	- RUN_CMD		[ container commands ]
	- CMD_ARGS		[ options to RUN_CMD ]

EXAMPLES

	STACK must (almost) always be defined. Set and export it in your session 
	for convenience. Setting TASK in your session has the potential to be risky.

	STACK=lamp make up

	STACK=lamp TASK=shell make run

	make TASK=mysqld top

	make config CMD_ARGS=--services
	
	make build TASK=php8-apache DK_CMP_OPTS='--no-cache'

	make exec TASK=php8-apache RUN_CMD='php -i'

	[alias for run -d]
	make rund TASK=shell RUN_CMD='php' CMD_ARGS="-r 'phpinfo();'"

ALIASES

	Any docker-compose commands are available invoked with the prefix, "dkc-".
	Invoke using the prefix if files or directories conflict with command names,
	or if an alias does not exist. Most docker-compose commands are aliased
	so they can be invoked simply e.g., `make build`, `make up`, etc.

MORE ON GETTING ORIENTED TO DECOMPOSER

	For more on folder structure, environment variables and configuration files,
	run `make dcp-orientation`.

MORE ON GETTING STARTED WITH DOCKER COMPOSE

	If you are a developer still new to all of this infrastructure as code world,
	run `make dkc-rtfm` for some sign-posts.

endef


define DCP_ORIENTATION

			ORIENTATION TO DECOMPOSER

CONCEPTS

	- Stack: -
	abstraction of a compose-file (docker-compose.yml), or a collection of 
	services that share a network namespace.

	- Service: -
	a docker-compose service

	- Task: -
	a docker-compose service conventionally not part of a stack, declared
	to be used with docker-compose run.

FOLDERS

	- stack/ -
	define stacks in .conf, .env, and .yml files, named by stack-name.
	 - <stack>.env will be passed in --env-file to docker-compose.
	 - <stack>.conf is included in make and effects decomposer
	 - <stack>.yml defines top-level docker-compose entities like volumes, config, etc.
	
	- service/ -
	Service declarations, intended to be composed into stacks, so excluding
	any other top-level compose-file entities. NB: paths, such as build-context,
	should be relative to the project directory.

DEFINING STACKS

	A Stack requires a list of services, defined in the service/ folder, and
	.env files, and a top-level .yml file for the entities
	other than the services, e.g. networks and volumes. 
	
	Stack definitions are placed into the stack/ folder using the stack-name and
	either a .conf, .yml, or .env extension. Environment files for services may
	be placed in either the stack/ or services/ folders. 

	Environment files for services will be automatically aggregated, but
	additional environment files can be added from the ENV_INCLUDES variable.

	A stack named "web", would then have a web.conf file that defines the services
	in a WEB_STACK variable, and any additional ENV_INCLUDES.

	If defined, ${STACK_ID}_STACK is appended to the STACK_SERVICES list. The 
	suggested convention is to define ".._STACK" in your stack-conf file and
	use STACK_SERVICES for ad hoc command line invocations.

ENVIRONMENT FILE PRECEDENCE

	As multiple environment files are aggregated, later settings will 
	supersede earlier settings. This can be a double-edged sword, so attention
	should be given to the precedence of automatic aggregation. 

	In order of precedence (reverse order of inclusion):

	 - variables from your executing shell environment
	 - exported variables in the stack/$${STACK}.conf
	 - files listed in ENV_INCLUDES (increasing order of precedence)
	 - stack/$${STACK}.env
	 - files automatically included (not from ENV_INCLUDES) in stack/
	 - files automatically included in service/

	 Observe that any declaration can be overridden by adding a file to the end
	 of the ENV_INCLUDES list. If services have env files, you can override them
	 in the stack/ folder.

	If TASK is defined, the so-named env file rises in precedence over it's 
	peers in the folder but NOT over the stack/STACK.env or the ENV_INCLUDES files.

endef

define DKC_RTFM

				MORE ON GETTING STARTED WITH DOCKER COMPOSE

	If you are new-ish to docker-compose: here are the key concepts you need to
	use decomposer.mk successfully. Because decomposer makes defaults explicit,
	it can help you get a firmer grip on docker-compose by shedding light on
	some of the magic.

	- Project Name and Networks - 

	The current directory becomes the working path for building containers, and 
	is the default value of COMPOSER_PROJECT_NAME. By default, containers are 
	joined to the network created automatically by adding the suffix "_default" 
	to the COMPOSER_PROJECT_NAME. 

	https://stackunderflow.dev/p/network-namespaces-and-docker/

	Services in your stack are automatically added to the routing services of the 
	network, so your services in a stack can all find each other just using the
	name of the service. Neat.

	Links are just aliases for hosts on the network.

	- Volumes - 

	The two basic kinds of volumes to learn about are bind mounts and 
	named volumes. Bind mounts should be used sparingly, but are essential for 
	sharing code with your host machine and your containers. Your code will go in
	a bind mount so you can write code and immediately run it in a container. Bind
	mounts are not actually volumes, which are managed by docker, but they are 
	declared under volumes of a service declaration.
	
	Named volumes are faster than bind mounts if you are not using Linux. Volumes 
	are not removed by default by docker-compose down; pass the -v flag to do so.

	- Tasks, Services, and Stacks  - 

	In cloud architecture, a Task is a unit of Container provisioning. A Service
	definition in docker is based on a container image and each instance of the 
	container is referred to as a task. A set of services deployed together is
	known as a Stack.

	- Up, Start, Run, or Exec - 

	Up and Down are the docker-compose commands to create and run, and stop and 
	destroy sets of Services known as a Stack. Networks are removed by down, 
	unless they are still in-use. Volumes are not removed by default.

	Start works either with a stack or a specified service, but does not try to
	create containers and will fail if a container does not exist.
	
	Run creates a new container, building the image if necessary, and can run a 
	command specified. Two important options to the run command are -d (--detach)
	and --rm ("Remove"). Without --rm, your container will be preserved after
	the command stops executing and will be left in an exited status. Detach 
	backgrounds the task so you can keep using your terminal. The stack command, 
	"down" will be the easiest way to clean-up stopped containers.

	Exec runs a command in a running container. By default, it will create an
	interactive terminal.

	Cheat Sheet:
		Build => images
		Create => containers, build if needed
		Start => Services (run), create if needed
		Restart => Services
		Run => Services, start with more options
		Exec => running services, will not start
		Pause => running services, and command execution
		Unpause => resumes running command
		Kill => SIGKILL by default but used to send process -s SIGNAL
		Stop => services, does not remove
		Remove => services, removes containers
		Down => services, stop and remove
	
	- Composing Composer Files -

	Composer yaml files are meant to be composed. By supplying multiple Compose
	files, the default docker-compose.yml is intended to be a base configuration
	for your project. You can then implement different scenarios by adding overrides
	and extensions to your base service definitions. This probably works great for
	automation, but gets klunky quickly for a developer workflow and leads to a 
	lot of typing. Decomposer exploits this feature and makes it trivial to define
	alternate modes as separate stacks and keeping declarations concise.

	To create overrides, you need to provide the context of your YAML snipit so it can
	be readily merged with Compose files passed to the command previously. So,
	you will always provide a top-level declaration, such as "services:", "networks:",
	"volumes:", "configs:", etc.

	The second important concept is the environment file. By default, .env will 
	be used but an alternate canbe specified with --env-file option.
	https://docs.docker.com/compose/env-file/

	Tips and Gotchas:
	 - Variables from the environment override the env-file.
	 - Variables are not automatically provided to containers
	 - Variables are only resolved in YAML values.
	 - More on Variable Substitution, including defaults: 
		https://docs.docker.com/compose/compose-file/compose-file-v3/#variable-substitution
	 - Additional env-files can be declared in a YAML array.


DOCKER COMPOSE REFERENCES 

 - https://docs.docker.com/compose/reference/envvars/
 - https://docs.docker.com/compose/compose-file/compose-file-v3/
 - https://docs.docker.com/compose/reference/

endef

help:
	$(info $(HELP_TXT))

dcp-orientation:
	$(info $(DCP_ORIENTATION))

dkc-rtfm:
	$(info $(DKC_RTFM))
