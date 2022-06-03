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
