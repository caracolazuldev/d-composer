-include composition.conf

.DEFAULT_GOAL := help

define HELP_TXT :=

				DECOMPOSING COMPOSER DEFINITIONS

	To escape the defaults set with the assumption that only one stack is defined
	in a working directory, multiple declarations are composed with subsequent
	COMPOSE_FILE parameters ( -f ) to docker-compose. See below for how to make
	WRAPPED DOCKER-COMPOSE COMMANDS.

	Service declarations should be decomposed into the service/ and shell/ folders.
	You may put your full definition in one of these files, but to avoid repeating 
	yourself, put extensions and overrides in network, volume, and conf.

	Services that terminate or are meant to be used with `docker-compose run --rm` can 
	be defined in the shell/ folder and invoked with the TASK env var, instead of 
	the SERVICE env var.

	A docker-compose call is constructed out of configuration vars, i.e.:
	docker-compose $${ENV_FILE} \ 
		$${PROJECT_DIR} $${NETWORK_YML} $${VOLUMES_YML} $${CONFIGS_YML} \ 
		$$(or $${SERVICE_YML},$${TASK_YML})

	Define these configuration vars using `make` syntax in either:
		- service/$${SERVICE}.conf
		- shell/$${TASK}.conf
	
	You should include the necessary flag in each configuration, e.g.

	TASK := bash
	ENV_FILE ?= --env-file conf/bash.env
	PROJECT_DIR ?= --project-directory .
	NETWORK_YML ?= -f network/web.yml
	VOLUMES_YML ?= 
	TASK_YML ?= -f shell/bash.yml
	EXEC_CMD ?= /bin/bash

	Global (trans-stack) configurations may be placed in the make-include file,
	`composition.conf`.

ERGO: TO DEFINE STACKS IN THE SAME FOLDER

	Tasks or services are defined from decomposed docker-compose services by
	creating *.conf files and stacks can be defined in a Makefile that integrates
	these utils.

	Define stacks in the global composition.conf by listing the services in a 
	var with the suffix, "_STACK".

	The docker-compose wrapper is wrapped again as stack-%, so that the stack
	command is run for each service.

	e.g. STACK=LAMP make stack-up

	... to activate the stack defined as LAMP_STACK := php-apache mysql

ENVIRONMENT CONFIG AND SECRETS

	The common .env for docker-compose is obviated because it is fraught to manage
	and may conflict with other uses of an .env file.

	Composer environment files (--env-file) as well as configurations you may 
	mount in a container should be placed in the conf/ folder. You might also 
	put YAML overrides for your service to add a `config:` stanza to your service.

	Targeting a development workflow, docker configs and secrets are not integrated
	into this project-starter, but it should be compatible if your project uses them.

	The secret/ folder will just help separate sensitive passwords and keys from 
	mundane configurations to help you migrate later to a secret manager.

WRAPPED DOCKER-COMPOSE COMMANDS
	
	Defines a pattern-rule for dkc-% to wrap docker-compose commands.

e.g. 
	SERVICE=apache make dkc-up => docker-compose up -d apache
	TASK=bash make dkc-run => docker-compose run --rm bash

	Run-Remove and Run-Detached are separated into dkc-run and dkc-rund aliases.

COMMAND ARGUMENTS

	Arguments to docker-compose commands can be passed either with CMD_ARGS or EXEC_CMD.

	CMD_ARGS are appended to any service command invoked by the wrapper (dkc-%).

	EXEC_CMD is appended only when invoking dkc-exec.

MORE ON GETTING STARTED WITH DOCKER COMPOSE

	If you are a developer still new to all of this infrastructure as code world,
	run `make dkc-rtfm` for some sign-posts.
endef

ifdef SERVICE
-include service/${SERVICE}.conf
endif

ifdef TASK
-include shell/${TASK}.conf
endif

compose.yml = ${ENV_FILE} ${PROJECT_DIR} ${NETWORK_YML} ${VOLUMES_YML} ${CONFIGS_YML} $(or ${SERVICE_YML},${TASK_YML})

dkc-%:
	$(eval TASK := $(or ${SERVICE},${TASK}))
	$(eval ACTION := $(if $(filter rund,$*),run -d,$*))
	$(eval ACTION := ${ACTION} $(if $(filter run,${ACTION}),--rm))
	$(eval ACTION := ${ACTION} $(if $(filter up,${ACTION}),-d))
	-docker-compose ${compose.yml} ${ACTION} $(if $(filter-out down config,$*), ${TASK}) \
		$(if $(filter run exec,${ACTION}),${EXEC_CMD}) ${CMD_ARGS}

stack-%:
	$(eval export STACK)
	$(eval STACK := $(shell echo "$${STACK}" | tr a-z A-Z))
	$(foreach svc,${${STACK}_STACK}, SERVICE=${svc} $(MAKE) dkc-$*;)

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
