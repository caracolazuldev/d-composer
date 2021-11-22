-include composition.conf
-include shell/${TASK}.conf
-include stack/${STACK}.conf

.DEFAULT_GOAL := help

define HELP_TXT :=

				DECOMPOSING COMPOSER DEFINITIONS

	Container composition files define service stacks constructed of 
	orchestrated tasks. Docker compose assumes one stack in a working directory 
	and one stack per composition file.  Utilizing multiple stacks in different 
	configurations of similar services causes duplication of service and global 
	object declarations.

	Decomposer then migrates global objects to automated includes in folders:
	 - network/
	 - volume/
	 - config/
	
	Stacks can be defined by a list of service names that are automatically 
	included as COMPOSE_FILE ( -f ) arguments.


EXAMPLES

	STACK=lamp make stack-up

	TASK=shell make task-run

	STACK=lamp make stack-config CMD_ARGS=--services
	
	STACK=lamp make stack-build SERVICE=php8-apache DK_CMP_OPTS='--no-cache'

	STACK=lamp make stack-exec SERVICE=php8-apache RUN_CMD='php -i'

	[alias for run -d]
	STACK=lamp make stack-rund SERVICE=mysql RUN_CMD='php -i'

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
	 - <stack>.conf is included in make and can define the STACK_SERVICES list
	 - <stack>.yml defines top-level docker-compose entities like volumes, config, etc.
	
	- service/ -
	Service declarations, intended to be composed into stacks, so excluding
	any other top-level compose-file entities. NB: paths, such as build-context,
	 should be relative to the project directory.

	- shell/ -
	Conventional placement of docker-compose service declarations not part of a 
	stack. NB: paths, such as build-context, should be relative to the project 
	directory.

	- network/, volume/, config/ -
	Optional location for top-level compose-file configurations. File-name 
	should be <stack-name>.yml

DEFINING STACKS

	Define stacks in the global composition.conf by listing the services in a 
	var with the suffix, "_STACK". 
	
	Or: define the STACK_SERVICES list in the stack/<stack>.yml file.

	The docker-compose wrapper is wrapped again as stack-%, so that the stack
	command is run for each service.

	e.g. STACK=LAMP make stack-up

	... to activate the stack defined as LAMP_STACK := php-apache mysql

MORE ON GETTING STARTED WITH DOCKER COMPOSE

	If you are a developer still new to all of this infrastructure as code world,
	run `make dkc-rtfm` for some sign-posts.
endef

ifndef STACK
$(warning STACK is not defined.)
endif

include-if = $(if $(wildcard $1/$2),-f $1/$2)
STACK_NAME := $(shell echo "$${STACK}" | tr A-Z a-z)
STACK_ID := $(shell echo "$${STACK}" | tr a-z A-Z)
stack-env-file = $(if $(wildcard stack/${STACK_NAME}.env),--env-file=stack/${STACK_NAME}.env.env)

ifdef SERVICE
task-yml := $(if $(wildcard service/${SERVICE}.yml), service/${SERVICE}.yml)
endif

ifdef TASK
task-yml := $(if $(wildcard shell/${TASK}.yml), shell/${TASK}.yml)
endif

define set-action
$(filter-out rund,$*)\
$(if $(filter rund,$*),run -d)\
$(if $(filter run,$*),--rm)\
$(if $(filter up,$*),-d)
endef

ifdef ${STACK_ID}_STACK
STACK_SERVICES := ${${STACK_ID}_STACK}
endif

define stack-config-includes
$(foreach type,stack network volume config,$(call include-if,${type},${STACK_NAME}.yml))\
$(foreach svc,${STACK_SERVICES},$(call include-if,service,${svc}.yml))
endef

%.yml:
	docker-compose --project-directory . ${stack-config-includes} config > $@

# # #
# stack-aware dkc svc command invocation
#
dkc-% stack-% svc-% task-%: ${STACK_NAME}.yml ${task-yml}
	docker-compose $(stack-env-file) $(foreach f,$^,-f $f) $(set-action) ${DK_CMP_OPTS} $(if $(filter-out down config,$*),$(or ${SERVICE},${TASK})) $(if $(filter rund run exec,$*),${RUN_CMD}) ${CMD_ARGS}

# # #
# HALP
# # #

define DKC_RTFM

				MORE ON GETTING STARTED WITH DOCKER COMPOSE

	If you are new-ish to docker-compose: here are the key concepts you need to
	use decomposer.mk successfully. Because decomposer makes defaults explicit,
	it can help you get a firmer grip on docker-compose by shedding light on
	some of the magic.

	- Project Name and Networks - 

	The current directory becomes the working path for
	building containers, and is the default value of COMPOSER_PROJECT_NAME. By 
	default, containers are joined to the network created automatically by adding
	the suffix "_default" to the COMPOSER_PROJECT_NAME. 

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
	alternate modes as separate stacks and keeping key-strokes to a minimum.

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

dkc-rtfm:
	$(info $(DKC_RTFM))
