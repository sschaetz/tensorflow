# TF Lite C++ Library

To compile the Tensorflow Lite library with C++ API for Apple M1 take the following steps.

Note that this is tested with XCode 13.1 installed, Tensorflow release `v2.6.2`
and the corresponding Bazel `3.7.2` release.

## Prerequisites
- make sure XCode is installed (13.1 tested) - installing through the AppStore works fine
- make sure a Python version with numpy is installed, ideally in a conda or some other
  environment management system

## Prepare to Compile
- make sure the correct version of bazel is installed; Tensorflow indicates which version
  of bazel it works with in the `tensorflow/.bazelversion` file; please note that
  bazelisk does not work well for this since it tries to fetch M1 binaries which are not
  available for older versions of bazel:

  ```bash
  # Assume we want to install bazel 3.7.2:
  curl -LO https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-installer-darwin-x86_64.sh
  chmod u+x bazel-3.7.2-installer-darwin-x86_64.sh

  # Do not install system-wide; better to install in a specific directory
  ./bazel-3.7.2-installer-darwin-x86_64.sh --prefix=~/bazel-3.7.2
  ```

- create a build-file for the Tensorflow Lite library:
  ```bash
  # browse to the Tensorflow root directory and create a temporary target
  cd third_party/tensorflow
  mkdir tmp
  touch tmp/BUILD
  ```

  Add the following content to the tmp/BUILD file:

  ```python
    load(
        "//tensorflow/lite:build_def.bzl",
        "tflite_custom_cc_library",
        "tflite_cc_shared_object",
    )

    tflite_custom_cc_library(
        name = "selectively_built_cc_lib",
        models = [],
    )

    tflite_cc_shared_object(
        name = "tensorflowlite",
        # Until we have more granular symbol export for the C++ API on Windows,
        # export all symbols.
        features = ["windows_export_all_symbols"],
        linkopts = select({
            "//tensorflow:macos": [
                "-Wl,-exported_symbols_list,$(location //tensorflow/lite:tflite_exported_symbols.lds)",
            ],
            "//tensorflow:windows": [],
            "//conditions:default": [
                "-Wl,-z,defs",
                "-Wl,--version-script,$(location //tensorflow/lite:tflite_version_script.lds)",
            ],
        }),
        per_os_targets = True,
        deps = [
            ":selectively_built_cc_lib",
            "//tensorflow/lite:tflite_exported_symbols.lds",
            "//tensorflow/lite:tflite_version_script.lds",
        ],
    )

    load(
        "//tensorflow/lite/delegates/flex:build_def.bzl",
        "tflite_flex_shared_library"
    )

    tflite_flex_shared_library(
        name = "tensorflowlite_flex",
        models = [],
    )
  ```

  This creates two targets that build 2 dynamic link libraries:
  - libtensorflowlite.dylib
  - libtensorflowlite_flex.dylib

  Both need to be linked to allow to run tensorflow lite models.
  Note that the flex library will be failry large at it includes all operators
  that exists. If the library should be customized to only support a specific
  set of operators needed by a specific model, the models (.tflite files)
  can be specified in the `models = []` section of each target. The library
  will then compile faster and will be smaller but will only support operators
  that are included in the listed models.

- Configure tensorflow by running `python configure.py` after activating the python environment that represents the environment that should be used to build tensorflow (requires numpy installed); this creates a `.bazelrc` file with necessary configuration options for the subsequent compilation step to succeed.


## Compile

To compile the two libraries execute:
```bash
~/bazel-3.7.2/bin/bazel build -c opt \
  --cxxopt=--std=c++14 \
  --config=macos_arm64 \
  //tmp:tensorflowlite

~/bazel-3.7.2/bin/bazel build -c opt \
  --cxxopt='--std=c++14' \
  --config=monolithic \
  --config=macos_arm64 \
  --host_crosstool_top=@bazel_tools//tools/cpp:toolchain \
  //tmp:tensorflowlite_flex
```

Note that we specify the bazel version installed above and
also note that we compile for target `macos_arm64`; if we omit this
configuration the resulting binaries would be suitable for `macos_x86-64`.

The resulting libraries can be found in `bazel-bin/tmp/`.

## Sources
- [Build TensorFlow Lite for Android](https://www.tensorflow.org/lite/guide/build_android) - helpful because of the overlap betweeh M1 and and Android (arm64)
- [Build TensorFlow Lite for ARM boards](https://www.tensorflow.org/lite/guide/build_arm) - documents that only a bazel build is suitable to compile all operators
- [Reduce TensorFlow Lite binary size](https://www.tensorflow.org/lite/guide/reduce_binary_size) - documents how to compile the build-in ops library (Flex delegate)

