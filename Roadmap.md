# Prioritized Milestones

## Clarify Use-cases & Update Nomenclature

* Define and employ Profiles (selections of available services)
* Compose command wrapper



Replace STACK with PROFILE.

Consider simplifying command wrapper. Focus on Makefile as primary wrapping use-case, rather than CLI.

Separate primary use-cases into two includes



## Document ENV Config management better



## Place Notice in Generated Config

Indicate that docker-compose.yml is auto-generated.

## Better CLI Help

A help 

## Activate Multiple Profiles?

Maybe this already works? More than one "active" profile doesn't seem necessary, but what might be stumbling blocks of bringing up more than one profile? What tools would help to manage multiple "up" profiles?

## Sub-Command
Require invocation via `make compose` to appear as a sub-command. I don't think we can conditionally include the library, but we can conditionally enable targets.

Un-tested code with a dummy target, help text when no other targets are given, and conditional wrapper to rest of library targets.

``` make
compose:
  @echo "Dummy compose target"

ifeq ($(filter compose,$(MAKECMDGOALS)),compose)
ifeq ($(words $(MAKECMDGOALS)),1)
$(info Usage: make compose [other_targets])
$(info Utils for integrating docker compose.)
else
# define targets ...
endif
endif
```
