
# docker-compose command
DKC_BIN ?= docker compose

# It's recommended to use root directory of the project as the project directory.
# Just take note of this, especially when defining build-context.
# e.g. your context might be `./docker/...`  while you might mount `volume: ./src:/app` 
# ... even if your config file is in said directory and your source is in a parent dir.
# Remembering all paths are relative to the project directory seems a reasonably sane standard.
DKC_PROJ_DIR ?= . # --project-directory

# we set project-directory explicitly because we do not want it determined by include file dirs.
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
ifndef STACK_SERVICES
$(if $(wildcard ${STACK_NAME}.stack),,$(error ERROR: could not find Stack declaration ${STACK_NAME}.stack))
include ${STACK_NAME}.stack
endif # ifndef STACK_SERVICES
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
	@ echo '# ' > $@
	@ echo '# WARNING: Generated Configuration using - $^' >> $@
	@ echo '# ' >> $@
	@cat $^ >>$@

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


# # #
# transform interpolated environment variables in docker-compose.yml
# so that configured values are not leaked into the generated file.
define rm-env-vals.awk :=
	/environment:/ { \
		in_environment = 1; \
		print; \
		next; \
	} \
	in_environment { \
		if (saved_indent == "") { \
			match($$0, /^[ \t]*/); \
			saved_indent = substr($$0, RSTART, RLENGTH); \
		} \
		if (substr($$0, 1, length(saved_indent)) == saved_indent) { \
			gsub(/^ +/, "", $$0); \
			colon_pos = index($$0, ":"); \
			if (colon_pos > 0) { \
				printf "%s- %s\n", saved_indent, substr($$0, 1, colon_pos - 1); \
			} else { \
				printf "%s%s\n", saved_indent, $$0; \
			} \
			next; \
		} else { \
			in_environment = 0; \
		} \
	} \
	{ \
		print; \
	}
endef

# replace the current directory with '.' in the generated file
strip-parent-dirs.awk = {gsub("'"$(shell pwd)"'", ".")}1

# # #
# IMPORTANT: call rm-env-values.awk so that 
# interpolated values are not leaked into the generated file.
#
# strip-parent-dirs.awk is used to keep the generated file portable.
%-compose.yml: ${stack-config-includes}
	@ echo '# ' > $@
	@ echo '# WARNING: Generated Configuration using - $^' >> $@
	@ echo '# ' >> $@
	@$(DKC_BIN) $(foreach f,$^,-f $f) config | \
	awk '$(rm-env-vals.awk)' | \
	awk '$(strip-parent-dirs.awk)' \
	>> $@

.INTERMEDIATE: ${STACK_NAME}-compose.yml # enable auto-clean-up of generated files

docker-compose.yml: ${STACK_NAME}-compose.yml
	@cp $< $@

# # #
# if DEBUG = DCMP_DEBUG, turn on debug output.
ifeq (${DEBUG},DCMP_DEBUG)
DISP_DEBUG := 1
endif

# Display Sources
ifdef DISP_DEBUG
$(info STACK: ${STACK})\
$(info ENV SOURCES: $(filter-out /dev/null,${stack-env-includes}))\
$(info COMPOSER SOURCES: ${stack-config-includes})\
$(info )
endif

# # #
# Commands
# # #

activate: | deactivate .env docker-compose.yml
ifeq (${STACK},NULL)
	$(eval STACK=${INACTIVE})
	$(if ${STACK},,$(error STACK not given to activate.))
endif
	@echo "STACK=${STACK}" > .active
	$(info )
	$(info ENV SOURCES: $(filter-out /dev/null,${stack-env-includes}))\
	$(info COMPOSER SOURCES: ${stack-config-includes})\
	$(info )
	$(info SERVICES ACTIVATED:)
	@$(MAKE) --quiet services && echo ""

deactivate:
	@$(foreach f,.env docker-compose.yml ${STACK_NAME}.stack.env ${STACK_NAME}-compose.yml,$(call rm-file,$f))
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
$(if $(filter down,$*),$(if ${TASK},rm --force --stop,down --orphans))\
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

# Include a TASK.yml and TASK.env if TASK is defined
DKC := ${DKC_BIN} $(if $(wildcard docker-compose.yml), -f docker-compose.yml) \
        $(if $(wildcard docker/${TASK}.yml), --file docker/${TASK}.yml) \
        $(if $(wildcard docker/${TASK}.env), --env-file docker/${TASK}.env)

ifdef DISP_DEBUG
$(info DKC=${DKC})
endif

# # #
# make wrapper
# # #

# Pass --workdir if WORKING_DIR is defined and the action is rund, run, or exec
DKC_RUN_COMMAND = $(if ${WORKING_DIR},$(if $(filter rund run exec,$*),--workdir ${WORKING_DIR})) \
	$(if $(filter-out config,$*),${TASK}) $(set-run-cmd)

#
# declare recipe prerequisites, docker-compose.yml and .env files, only if STACK is defined.
# 
dkc-%: $(if $(filter-out NULL,${STACK}),docker-compose.yml) $(if $(filter-out NULL,${STACK}),.env) 
ifdef DISP_DEBUG
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

orphans:
	docker container prune --force

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
