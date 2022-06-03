# Prioritized Milestones

## Create Manifest

Capture Features, including documentation

## Update Docs and Help

README is significantly out-of date.

## BUG: when running deactivate and activate together

Reproduce: `make deactivate activate`

Intermediate files get fumbled, I think.

## Dynamic Stack Activation

Unsure what happens when the STACK from the environment does not match the activated STACK.
Probably need to detect, and dynamically swap stack activation.

## Flesh-out Architectural Considerations

* Capture pain-points of Decomposer
* Articulate use-cases and pain-points of docker-compose
* Lifecycle: development environment set-up; development (integrate sources); testing; staging; production deployment;
* Version-control: integrating infrastructure-as-code, builds, and testing, ...into project VC
* Harness external tools and services, e.g. container image repos, aws-cli, production orchestration.


## Create Build?

For documentation? So far, dcp exists as a single include file. For better VC, might split help-text into separate files and build into distributable.

## Project Scaffold?

* Manage suggested folder-structure
* Initialize configuration files



## Integrate mdo-git.mk

If we have a project scaffold, then it would be nice to include the repo-management utilities of `mdo-git.mk`.



## Research Docker-Compose in a k8s world

Does Kubernetes obviate docker-compose?



## Test/Integrate new Docker Compose Command

`docker-compose` vs `docker compose`.

Preserve backwards-compatibility?

Obstacles to upgrading?



## Re-architect Stack Configurations

I'm not happy with the general approach to Stack management. Perhaps I did not effectively leverage docker-compose's ability to compose yaml files? The dynamic instantiation of docker-compose.yml is a little opaque.

Having to set the STACK env variable feels cumbersome. A raw idea for an alternative is to `build` a stack, and not re-create the docker-compose yaml on every invocation. This might be easier to audit. Could maybe use make's stale-file detection to avoid the need to explicitly call the stack build command; e.g. for updated env file sources.

While the documentation makes clear the use of the file folder structure, it is still too arcane. Need  to think more about real-world use-cases for multiple stacks. Consider more the dev-test-stage lifecycle.



## Wrap Commands to Extend Stacks?

The current iteration enables arbitrary and dynamic stack actions. Perhaps the new model should be built around a single active stack, and building out services. Creating commands to manage and update configurations could make the arcane folder structure less of a problem, or obviate it.