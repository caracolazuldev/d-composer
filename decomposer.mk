
# docker-compose command
DKC_BIN ?= docker-compose
DKC_PROJ_DIR ?= . # --project-directory
DKC_BIN := ${DKC_BIN} --project-directory=${DKC_PROJ_DIR}

MAKEFLAGS += --no-builtin-rules
.SUFFIXES: # cancel suffix rules

# # #
# Validation and Derived Configurations
# # #

ifndef STACK
STACK := $(if $(wildcard .active),\
	$(subst STACK=,,$(shell grep STACK $(wildcard .active))))
INACTIVE := $(if $(wildcard .active),\
	$(subst INACTIVE=,,$(shell grep INACTIVE $(wildcard .active))))
endif

STACK := $(strip ${STACK})

ifndef STACK
STACK := NULL# enable few commands to run, such as help and command completion
endif

ifneq (${STACK},NULL)
STACK_NAME := $(shell echo "${STACK}" | tr A-Z a-z)
STACK_ID := $(shell echo "${STACK}" | tr a-z A-Z)
$(if $(wildcard ${STACK_NAME}.stack),,$(error ERROR: could not find Stack declaration ${STACK_NAME}.stack))
include ${STACK_NAME}.stack
endif

ifdef STACK_SERVICES
STACK_SERVICES := $(shell basename -as .yml ${STACK_SERVICES})
endif

# do not change default goal by this include:
.DEFAULT_GOAL_CACHED := ${.DEFAULT_GOAL}

# # #
# Helpers
# # #

if-file-in = $(if $(wildcard $1/$2), $1/$2)

rm-file = $(if $(shell (test -L $1 || test -e $1) && echo 'TRUE'), \
	$(shell rm -f $1 && echo 'rm -f $1'))

# # #
# Generate derived docker-compose files
# # #

# # #
# /dev/null to avoid error from `cat` if no env files are used.
# include service or task env files in docker/
# include ${STACK_NAME}.env in project directory
# include additional files from stack configuration (ENV_INCLUDES)
# TODO: confirm/document precedence
define stack-env-includes
/dev/null \
$(foreach svc,${STACK_SERVICES} ${TASK},$(call if-file-in,docker,${svc}.env)) \
$(foreach stk,${STACK_NAME} ${TASK},$(call if-file-in,.,${stk}.env)) \
${ENV_INCLUDES}
endef

%.stack.env: ${stack-env-includes}
	@cat $^ >$@

.INTERMEDIATE: ${STACK_NAME}.stack.env # enable auto-clean-up of generated files

.env: ${STACK_NAME}.stack.env
	@cp $< $@

# # #
# include YAML files named for the STACK in supported locations
# include service/task definitions in docker/
define stack-config-includes
$(strip \
	$(foreach type,network volume,$(call if-file-in,${type},${STACK_NAME}.yml))\
	$(foreach svc,${STACK_SERVICES},$(call if-file-in,docker,${svc}.yml))
)
endef

ifdef DEBUG
$(info CONFIG-INCLUDES: ${stack-config-includes})
endif

## TODO: enable debug to output errors from `docker compose`. i.e.no /dev/null

%-compose.yml: ${stack-config-includes}
	$(DKC_BIN) $(foreach f,$^,-f $f) config > $@ $(if ${DEBUG},,2>/dev/null)

.INTERMEDIATE: ${STACK_NAME}-compose.yml # enable auto-clean-up of generated files

docker-compose.yml: ${STACK_NAME}-compose.yml
	@cp $< $@

define REPORT_STACK
$(info STACK: ${STACK})\
$(info ENV SOURCES: $(filter-out /dev/null,${stack-env-includes}))\
$(info SERVICES: ${STACK_SERVICES})\
$(info COMPOSER SOURCES: ${stack-config-includes})\
$(info )
endef

ifdef DEBUG
$(call REPORT_STACK)
endif

# # #
# Commands
# # #

## TODO: enable debug to output errors from `docker compose`. i.e.no --quiet

activate: | deactivate
ifeq (${STACK},NULL)
	$(eval STACK=${INACTIVE})
	$(if ${STACK},,$(error STACK not given to activate.))
endif
	@echo "STACK=${STACK}" > .active
	$(MAKE) .env docker-compose.yml 
	$(REPORT_STACK)

deactivate:
	$(foreach f,.env docker-compose.yml ${STACK_NAME}.stack.env ${STACK_NAME}-compose.yml,\
		$(call rm-file,$f))
ifneq (${STACK},NULL)
	@echo "INACTIVE=${STACK}" > .active
endif

# # #
# set and customize docker-compose commands
# and implement custom actions
# # #

custom-actions := down rund orphans services logs

# # #
# docker compose sub-commands
#
# pass-through the action if it is not a custom action [filter-out]
# and define custom actions
#
define set-action
$(filter-out ${custom-actions},$*)\
$(if $(filter down,$*),$(if ${TASK},rm --force --stop,down))\
$(if $(filter orphans,$*),down --remove-orphans)\
$(if $(filter rund,$*),run -d)\
$(if $(filter run,$*),--rm)\
$(if $(filter up,$*),-d)\
$(if $(filter services,$*),config --services)\
$(if $(filter logs,$*),logs --follow)
endef

# # #
# docker run command-parameter
#
# intelligently quote the RUN_CMD if it contains spaces
#
define set-run-cmd
$(if $(filter rund run exec,$*),\
$(if ${RUN_CMD},\
$(if $(filter 1,$(words ${RUN_CMD})),${RUN_CMD},'${RUN_CMD}')\
)) ${CMD_ARGS}
endef

# # #
# docker-compose wrapper
# # #

DKC := ${DKC_BIN} $(if $(wildcard docker-compose.yml), -f docker-compose.yml) \
        $(if $(wildcard docker/${TASK}.yml), --file docker/${TASK}.yml) \
        $(if $(wildcard docker/${TASK}.env), --env-file docker/${TASK}.env)

ifdef DEBUG
$(info DKC=${DKC})
endif

# # #
# make wrapper
# # #

DKC_RUN_COMMAND = $(if ${WORKING_DIR},$(if $(filter rund run exec,$*),--workdir ${WORKING_DIR})) \
	$(if $(filter-out config,$*),${TASK}) $(set-run-cmd)

#
# declare recipe prerequisites, docker-compose.yml and .env files, only if STACK is defined.
# 
# we set project-directory explicitly because we do not want it determined by include file dirs.
#
# Include a TASK.yml and TASK.env if TASK is defined
#
# Pass --workdir if WORKING_DIR is defined and the action is rund, run, or exec
#
dkc-%: $(if $(filter-out NULL,${STACK}),docker-compose.yml) $(if $(filter-out NULL,${STACK}),.env) 
ifdef DEBUG
	$(info $(DKC) $(set-action) ${DK_CMP_OPTS} \) 
	$(info ${DKC_RUN_COMMAND})
endif
	@$(DKC) $(set-action) ${DK_CMP_OPTS} ${DKC_RUN_COMMAND}

# # #
# Aliases
# # #

ENABLE_ALIASES := $(if $(and $(wildcard docker-compose.yml),$(wildcard .env)),ENABLE)

#
# Aliases that do not require a STACK definition
#

run: dkc-run
rund: dkc-rund

#
# Aliases that do require a STACK definition
#
ifdef ENABLE_ALIASES
build: dkc-build
config: dkc-config
create: dkc-create
down: dkc-down
events: dkc-events
exec: dkc-exec
logs: dkc-logs
orphans: dkc-orphans # alias, `down --remove-orphans`
pause: dkc-pause
restart: dkc-restart
rm: dkc-rm
services: dkc-services
start: dkc-start
stop: dkc-stop
top: dkc-top
unpause: dkc-unpause
up: dkc-up
endif

# restore default goal.
.DEFAULT_GOAL := ${.DEFAULT_GOAL_CACHED}
