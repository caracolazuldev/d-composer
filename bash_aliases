#!/bin/bash
#
# Suggested Bash Aliases
# to save precious keystrokes
#

alias dk=docker
alias dkc='docker compose'
alias dki='docker image'

# always remove run containers
alias dkr='docker run --rm'

#
# Listing Containers
#

# custom format; see Go Templates for reference
alias dkl='docker ps -a --format '\''table {{if .ID}}{{slice .ID 0 4}}{{end}}\t{{.Names}}\t{{if .Status}}{{slice .Status 0 2}}{{end}}\t{{.Image}}\t{{.Command}}'\'
# CONT      NAMES                   ST        IMAGE                            COMMAND
# e7b7      website-imagick-1       Ex        dpokidov/imagemagick             "convert" 

# no truncate RUN CMD
alias dkll='dkl --no-trunc'

# display port mappings
alias dklp="docker ps --format 'table {{if .ID}}{{slice .ID 0 4}}{{end}}\t{{.Names}}\t{{.Ports}}'"
# CONT      NAMES                   PORTS
# 7a65      website-httpd-1         0.0.0.0:80->80/tcp, :::80->80/tcp
# b6a0      website-tailwindcss-1   0.0.0.0:3000->3000/tcp, :::3000->3000/tcp