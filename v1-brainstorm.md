# D-composer brainstorms

I thought of splitting the command wrapper and the "composition" functionality, but maybe the wrappers are small enough to include. OR: keep as a single include but activate targets via a flag.

With a flag, we could create different bash aliases so they would appear as separate commands. Default `make` invocation would then show custom targets and select-few d-composer targets. 

Maybe it is time to seriously consider a real executable instead of using `make`. If global installation is encouraged, what is the benefit of a project include? One expectation for the Makefile is the desire to invoke tasks with helpers. Helpers such as, `$(call exec-or-run,<my-service>)`, or using the make-macro for  `docker compose`, or invoking the wrappers using the `TASK=... RUN_CMD=...` method. Will these features still prove useful?

## Possible aliases 

Composition: `dkc`, `dcp`, `dcmp`, `cmp`, 

Cluster actions:`cls`, `clst`, `dcl`, `cla`

## Install Wishlist

* All installer requirements should support Mac and Linux, and popular alternative shells. [Zsh?...]
* install via shell script instead of make
* Check for make as a dependency and install if not found

* Install aliases: 
  * ask for file to insert if location not found; 
  * output location aliases were appended
  * check for alias collision, for each collision detected, offer alternative suggestions and request user to input the alias to use. 
* Option to install only aliases
* With aliases installed: command to download include into current working directory. [Default to `curl` and fall-back to `wget`]



## Basic vs Extended Command Wrappers

Perhaps we should delineate the wrappers that merely alias `docker compose` commands, and those that alter the default behavior.   

More helpers for inspecting the cluster status. I recently wanted a `--no-trun` version of `ls`. More ways to inspect containers.

**Cheat-sheets:** could be really nice. More **help** available on the command-line.

**Reports:** commands to inspect containers could be sequenced as a "report" and also serve as demos of commands in the cheat-sheets. 

I created this as "training wheels"; perhaps it should teach docker for developers.

## Directory Structure (Include Paths)

Perhaps implies a project initiation helper to create folders.

* docker/ - let's give this back to docker and take out service definitions
* composer/ - new home for service declarations
* conf/, config/, or env/

I think using the new composer/ directory will keep things cleaner. Could also fall-back to searching in the docker folder.

Documentation ToDo: note that paths are relative to project-root, regardless of include-location.



## YAML file includes

Assure that files can be included as params to `docker compose config` to generate the docker-compose.yml by explicit filename as well as by omitting the file-extension. For example, with the file, `./composer/mysql.57.yml`, any of the following would select this file:  `mysql.57`, `mysql.57.yml`, `composer/mysql.57.yml`.

In addition to service declaration stubs, we now also want to include "profile" declaration stubs, and a profile-include-list from an environment variable. Composition operations should automatically include a `.profile` file from the conf/ directory that has a basename matching the profile-name. For example, the "dev" profile should evaluate the file `conf/dev.profile` to bring the `PROFILE_INCLUDES` var into scope.



## Testing

Create a Testing branch that should regularly be rebased to the main branch and contains testing code ina `tests/` folder.

Create a bespoke testing toolkit with setup, tear-down, and assertions. Assertions will likely mean simply executing shell commands and using grep or awk to confirm the expected output.

[ToDo: identify key functionality to start writing tests for.]



## Discovery on workings of Docker Compose

Currently, we generate a `docker-compose.yml` file by identifying file-stubs from a list in an environment variable. To confirm a new approach of using, not individual service declaration stubs, but multiple service stubs in a single yaml file, we should devise some simple tests of how conflicting elements declarations are handled.

For instance, if we have to files that are meant to be merged into a single service definition, and they both contain an `environment:` stanza, will the file passed later simply override the former, or will the elements of the stanza be union-ed?

It is not clear that one way is always preferred. It might be ideal if only leaf-nodes have precedence, and any node with children will be merged. That would leave the inability to un-set or remove members, but that seems like a reasonable compromise.

## Profile Stubs

Formerly, we used the nomenclature, `STACK` to define a set of services to include in the generated `docker-compose.yml`.  Now, we want to re-brand this tool as a replacement and explicit alternate approach to the docker compose "Profiles" feature.  

ToDo: write out the argument or preference for maintaining re-usable service declarations in separate files, rather than distinct stanzas in a single `docker-compose.yml` file.

One simple example, if you want to test against two different versions of a dependency, it is easier to activate different profiles that use different service declarations that both refer to the dependency with the same service name.

Include in the argument: it almost seems strange that `docker compose` documentation and articles almost always utilize a single `docker-compose.yml` and seem to imply that "composition" means locally deploying a cluster of services. However, the ability to merge yaml declarations could be the original paradigm that the tool is named for. 



# DRAFT README

**Usage**

The aim of D-Composer is to make the developer experience using `docker compose` more effortless, support reuse of service declarations, and provide a method for release managers to maintain parallel configurations.

The essence of creating docker compositions is specifying:

* environment configs
* service declarations
* volume mounts
* ports and networks

In the vast majority of documentation examples (at this time), a single `docker-compose.yml` file defines the composition. This implies that the "composition" is the deployment of related or networked containers. However, there is another sense of composition, one that this author asserts is more profoundly useful.

Multiple YAML configs can be passed to `docker compose`, and in addition, the resolution of this YAML tree, can be output and saved by invoking `docker compose config`.  D-Composer   then makes the default config file (`docker-compose.yml`) a managed and auto-generated artifact, moving your configurations to a collection of files, which can be employed in myriad compositions, called "Profiles". This is intentional appropriation of the `docker compose` profile concept, as it serves the same purpose and completely obviates it.

## Declaring a Profile

Both implicit and explicit declaration of a profile may be used.  Using directory locations and file extensions, "activating" a profile will cause a `docker-compose.yml` file to be generated by inclusion of any ingredients that match the profile name. 

The simplest profile can consist of a single YAML stub in the `composer/` dir, let's call it, `hello.profile.yml`

``` yaml
services:
	apache-spark:
	volumes:
		- .:/opt/spark/work-dir
```

This composition requires one additional file, `composer/apache-spark.yml`.

```yaml
services: 
	apache-spark:
	image: apache/spark:latest
	ports:
		- 4040:4040
	environment:
		- SPARK_NO_DAEMON=true
```



## How to Reuse Service Definitions

In the basic example, we achieved not much more than separation of a generic service definition and a custom profile with minimal customization (custom volume mounts). To realize the promise of re-use, we need to specify our composition more explicitly.

Let's say we are migrating our application to a new version of Spark. So, we need to be able to easily compare execution in the legacy target version, and the new target version. 

In addition to the `<profile>.profile.yml` we can create a config file, also in the `composer/` dir. Let's create two profiles, "legacy" and "upgrade".

``` bash
TODO: `tree` representation of files.
```



**composer/legacy.conf**

``` make
PROFILE_TPLS = composer/myapp-dev.profile.yml
SERVICE_TPLS = composer/apache-spark.2.4.yml
ENV_INCLUDES ?= conf/legacy.env
```

**composer/migration.conf**

``` make
PROFILE_TPLS = myapp-dev.profile.yml
SERVICE_TPLS = apache-spark/3.0.yml
ENV_INCLUDES ?= migration.env
```

Note that profile config files are evaluated with `make` and can use any Make functionality. 

Note that if you use the expected file location for the type of include, the explicit path need not be provided.

Here we have re-used a profile template and overridden a service declaration and provided alternate environment configurations.
