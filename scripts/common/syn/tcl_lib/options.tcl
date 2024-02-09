# Copyright 2022 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Package to map argc/argv to ::options:optionMap.
##
## Call ParseCMDArguments, passing a list of the option names expected.
## On return, option values are in optionMap.
##

namespace eval options {
  variable optionMap

  # Export proc to be invoked that processes argc/argv
  namespace export ParseCMDArguments
 
  set version 1.0
  set MyDescription "HelloWorld"
 
  # Path of the script
  variable dir [file join [pwd] [file dirname [info script]]]
}


##
## Parse the input arguments to the script. Both required_args
## and optional_args are lists of argument names. An error
## is returned if any of the required_args is not set. An
## error is also returned if an argument name is not in either
## list.
##
## On return, optionMap is indexed by argument names. Optional
## arguments will be defined only if they are found on the
## command line.
##
proc ::options::ParseCMDArguments {required_args {optional_args {}}} {
  global argv
  global argc

  if { [info exists ::options::optionMap] } {
    array unset ::options::optionMap
  }
  array set ::options::optionMap {}

  # Expect these options
  foreach a $required_args {
    set singleOptionMap($a) -1
  }

  set success 1
  set i 0

  while { ($i < $argc) && ($success==1) } {
    set arg [lindex $argv $i]
    incr i

    set optList [split $arg "="]
    set opt [lindex $optList 0]

    # Is opt an optional argument? If so, add the option name to the map.
    if { ![info exists singleOptionMap($opt)] && [lsearch $optional_args $opt] >= 0} {
      set singleOptionMap($opt) -1
    }

    if [info exists singleOptionMap($opt)] {
      if { $singleOptionMap($opt) == -1 } {
        if { [llength $optList] < 2 } {
          set success 0
          puts "Error: No value is specified for option $opt"
        } elseif { [llength $optList] > 2 } {
          set success 0
          puts "Error: Illegal option found \"$arg\"."
        } else {
          set optValue [lindex $optList 1]
          if [string equal $optValue ""] {
            set success 0
            puts "Error: No value is specified for option $opt"
          } else {
            set ::options::optionMap($opt) $optValue
          }
        }
      } else {
        if { [llength $optList] == 1 } {
          set ::options::optionMap($arg) 1
        } else {
          set success 0
          puts "Error: Illegal option found \"$arg\"."
        }
      }
    } else {
      set success 0
      puts "Error: $arg is not a valid option."
    }
  }

  if { $success == 1 } {
    foreach opt [array names singleOptionMap] {
      if { $singleOptionMap($opt) == -1 } {
        if { ![info exists ::options::optionMap($opt)] } {
          puts "Error: Missing $opt option."
          set success 0
        }
      }
    }
  }

  if {$success != 1 } {
    return -1
  } 
  return 0
}

package provide options $options::version
