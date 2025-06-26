#!/bin/bash

# How to run a single test:
# Add a tag to the test you want to run.
#
# it("should do the thing #only", function() ... end)
#
# Set the tag as an environment variable before running this function.
#
# TAGS=only ./scripts/test.sh

COMMAND="nvim -l tests/minit.lua --busted tests"
if [ -n "$TAGS" ]; then
    COMMAND="$COMMAND --tags=$TAGS"
fi
$COMMAND
