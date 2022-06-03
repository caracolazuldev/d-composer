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
	 - <stack>.conf is included in make and effects decomposer
	 - <stack>.yml defines top-level docker-compose entities like volumes, config, etc.
	
	- docker/ -
	Service declarations, intended to be composed into stacks, so excluding
	any other top-level compose-file entities. NB: paths, such as build-context,
	should be relative to the project directory.

DEFINING STACKS

	A Stack requires a list of services, defined in the docker/ folder, and
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
	 - files automatically included in docker/

	 Observe that any declaration can be overridden by adding a file to the end
	 of the ENV_INCLUDES list. If services have env files, you can override them
	 in the stack/ folder.

	If TASK is defined, the so-named env file rises in precedence over it's 
	peers in the folder but NOT over the stack/STACK.env or the ENV_INCLUDES files.