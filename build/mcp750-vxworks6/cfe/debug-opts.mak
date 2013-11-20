##
## Debug Options for build
##
DEBUG_OPTS = -g -O0
DEBUG_LEVEL = 3

##
## Table Debug options.
## In order for the elf2cfetbl utility to work
## The -g option must be used. It generates the symbols
## in the object file
##
TABLE_DEBUG_OPTS = -g -O0 -mno-align-int

