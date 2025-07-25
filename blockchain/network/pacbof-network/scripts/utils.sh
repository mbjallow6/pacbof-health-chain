#!/usr/bin/env bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# Print the usage message (Placeholder for now, the real one is in network.sh)
function printHelp() {
  echo "No help available yet for utils.sh directly. See network.sh -h"
}

# println echos string
function println() {
  echo -e "$1"
}

# errorln echos in red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}

# Export functions so they are available in subshells and sourced scripts
export -f println
export -f errorln
export -f successln
export -f infoln
export -f warnln
export -f fatalln
