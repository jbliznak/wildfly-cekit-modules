#!/bin/sh

# This script executes a list of modules defined by CONFIGURE_SCRIPTS.
#
# Configuration occurs over three basic phases: preConfigure, configure and
# postConfigure.
#
# The configure phase is special in that it iterates over a series of
# environments.  In addition to the execution environment, users may specify
# additional configuration details through environment scripts specified through
# the ENV_FILES variable.  The processing of env files is similar to the process
# for the execution environment, with the addition of a prepareEnv method, which
# is used to clean the environment before processing the env contributed by
# a file.  This is to help ensure that duplicate configurations are not created
# when processing env files.
#
# The following details the API which the modules may implement.  If a
# particular function is not implemented by a module, it is treated as a no-op.
#
# preConfigure:     invoked before any configuration takes place.  Use this to
#                   manipulate the environment prior to configuration.  For
#                   example, the backward-compatiblity.sh module initializes
#                   environment variables from older variable names, if present.
#
# configure:        invoked to configure based on the execution environment.
#
# postConfigure:    invoked after all configuration has been completed.
#
# delayedPostConfigure:    invoked after all configuration has been fully 
#                          completed (CLI script executed).
#
# prepareEnv:       invoked prior to processing env files.  Modules should
#                   use this to prepare the environment before processing
#                   configuration from a file, e.g. by unset'ing variables
#                   defined in the execution environment to prevent duplicate
#                   configuration entries.  This method is invoked once, as
#                   each env file is processed in a subshell, thus preventing
#                   contamination of the environment from file to file.
#
# preConfigureEnv:  similar to preConfigure, except this is invoked after an env
#                   file has been sourced, but before configureEnv.
#
# configureEnv:     similar to configure.
#
# postConfigureEnv: simliar to postConfigure, except that it is invoked for each
#                   env file.
#
# finalVerification: called after everything else. Modules can use this to check
#                    information from both the non-env and env cases.
#
# The reason the configuration API is duplicated for an Env, is that some
# modules may not support env files, or may require configuration of "singleton"
# type entries, which should only be processed once.
#

# clear functions from any previous module
function prepareModule() {
  unset -f preConfigure
  unset -f configure
  unset -f postConfigure
  unset -f delayedPostConfigure

  unset -f prepareEnv
  unset -f preConfigureEnv
  unset -f configureEnv
  unset -f postConfigureEnv

  unset -f finalVerification
}

# Execute a particular function from a module
# $1 - module file
# $2 - function name
function executeModule() {
  source $1;
  if [ -n "$(type -t $2)" ]; then
    eval $2
  fi
}

# Run through the list of scripts, executing the specified function for each.
# $1 - function name
function executeModules() {
  for module in ${CONFIGURE_SCRIPTS[@]}; do
    prepareModule
    executeModule $module $1
  done
}

# Processes the files provided by ENV_FILES.  Invokes the *Env functions for
# each module.  Env processing is done in subshells.  The outer subshell
# provides a sanitized environment, that will be used by each inner subshell.
# This insulates the execution environment from any changes made during env
# file processing, and keeps the base environment the same from file to file
# (i.e. we don't have to run prepareEnv for each file).
function processEnvFiles() {
  if [ -n "$ENV_FILES" ]; then
    (
      executeModules prepareEnv
      for prop_file_arg in $(echo $ENV_FILES | sed "s/,/ /g"); do
        for prop_file in $(find $prop_file_arg -maxdepth 0 2>/dev/null); do
          (
            if [ -f $prop_file ]; then
              source $prop_file
              executeModules preConfigureEnv
              executeModules configureEnv
              executeModules postConfigureEnv
            else
              log_warning "Could not process environment for $prop_file.  File does not exist."
            fi
          )
        done
      done
    )
  fi
}

executeModules preConfigure
executeModules configure
processEnvFiles
executeModules postConfigure
executeModules finalVerification
