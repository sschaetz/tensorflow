#!/usr/bin/env bash

# Prepares a tflite release.
# TODO: Add Linux build.

# Prepare directory
rev=tflite-`(git rev-parse --short HEAD)`
wdir=/tmp/$rev
mkdir -p $wdir/macos_arm64/shared-lib

# Copy ARM64 binaries
cp bazel-bin/tflite/libtensorflowlite*.dylib $wdir/macos_arm64/shared-lib

# Prepare header files
mkdir -p $wdir/include/tensorflow/lite
rsync -a --prune-empty-dirs --include '*/' --include '*.h' --exclude '*' tensorflow/lite/ $wdir/include/tensorflow/lite/
cp -r bazel-bin/external/flatbuffers/_virtual_includes/flatbuffers/flatbuffers $wdir/include

# Package it up
pushd /tmp
zip -vr $rev.zip $rev -x "*.DS_Store"
popd

unzip -l /tmp/$rev.zip

# Compute shasum
shasum -a 256 /tmp/$rev.zip


