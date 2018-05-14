#!/bin/bash

# Fast fail the script on failures.
set -e

# Verify that the libraries are error free.
pub global activate tuneup
pub global run tuneup check

# Run the tests.
pub run test

# Ensure the tool runs in strong mode.
dart --preview-dart-2 bin/mserve.dart -h
