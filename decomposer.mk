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

	Note there is no .env in the project directory.

	Composer environment files (--env-file) as well as configurations you may mount in a container
	should be placed in the conf/ folder. You might also put YAML overrides for 
	your service to add a `config:` stanza to your service.

	Targeting a development workflow, docker configs and secrets are not integrated
	into this project-starter, but it should be compatible if your project uses them.

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

DOCKER COMPOSE REFERENCES 

 - https://docs.docker.com/compose/reference/envvars/
 - https://docs.docker.com/compose/compose-file/compose-file-v3/
 - https://docs.docker.com/compose/reference/

endef

ifdef SERVICE
-include service/${SERVICE}.conf
endif

ifdef TASK
-include shell/${TASK}.conf
endif

compose.yml = ${ENV_FILE} ${PROJECT_DIR} ${NETWORK_YML} ${VOLUMES_YML} ${CONFIGS_YML} $(or ${SERVICE_YML},${TASK_YML})

help:
	$(info $(HELP_TXT))

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