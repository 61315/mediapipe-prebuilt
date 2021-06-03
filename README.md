# mediapipe-iris-ios

Realtime iris tracking demo for iOS

## Preview

![preview](https://user-images.githubusercontent.com/46559594/120622208-909a3e00-c499-11eb-9f30-61350abeb115.gif)

## What is MediaPipe?

[MediaPipe](https://github.com/google/mediapipe) offers cross-platform, customizable ML solutions for live and streaming media.

- **End-to-End acceleration**: Built-in fast ML inference and processing accelerated even on common hardware
- **Build once, deploy anywhere**: Unified solution works across Android, iOS, desktop/cloud, web and IoT
- **Ready-to-use solutions**: Cutting-edge ML solutions demonstrating full power of the framework
- **Free and open source**: Framework and solutions both under Apache 2.0, fully extensible and customizable


## Demo

### What about it?

This project is a mere copy of a [demo](https://github.com/google/mediapipe/tree/master/mediapipe/examples/ios/iristrackinggpu) provided by MediaPipe team. Only packaged to a dynamic framework ready to deploy on your device at one go, sparing you ~~😇painstaking😇~~ python setup.

- [MediaPipe Iris](https://google.github.io/mediapipe/solutions/iris)
- [Tutorial to create an importable iOS framework](https://medium.com/@powderapp/mediapipe-tutorial-find-memes-that-match-your-facial-expression-9bf598da98c0)

**Important**: Use this project for evaluation purposes only. It is strongly recommended to build your own project/framework. MediaPipe provides streamlined build process using bazel script. This also fits well for the CI environment. You can find tutorials [here](https://google.github.io/mediapipe/getting_started/ios.html). 


### Noise filtering

> MediaPipe provides a rich set of helper classes regarding *implementation* of ML models. It includes math library like **eigen**, image processing library like **opencv** and many more. Most of them are abstracted for specific use cases, packed as [calculators](https://google.github.io/mediapipe/framework_concepts/calculators.html), each calculators working as a node, allowing you to create desired ML pipeline just [connecting](https://viz.mediapipe.dev/demo/iris_tracking) those nodes. Some of those calculators are also fine-tuned both algorithm-wise and parameter-wise, let alone the ML models being fine-tuned meaning noble paging strategy for GPU runtime and such. You don't get this kind of bargain often.

Here is one example of calculators. See the difference between the two eyes? One being stabilized and the other being fluctuating/jittering? That is because I applied a smoothing calculator to the left side of landmarks only. 

![noisefilter](https://user-images.githubusercontent.com/46559594/120622250-9abc3c80-c499-11eb-8268-b6ed9875f421.gif)

It is mostly a random digital noise which makes it safe to assume the noise is somewhat [Gaussian](https://www.sfu.ca/sonic-studio-webdav/handbook/Gaussian_Noise.html), so I chose the one-euro-filter. See how the calculator handles jittering? Try the demo yourself. All included in the [bundle calculators](https://github.com/google/mediapipe/tree/master/mediapipe/calculators), say no more.

One I used for this demo is [LandmarksSmoothingCalculator](https://github.com/google/mediapipe/blob/master/mediapipe/calculators/util/landmarks_smoothing_calculator.proto):
```
# Applies smoothing to the single set of iris landmarks.
node {
  calculator: "LandmarksSmoothingCalculator"
  input_stream: "NORM_LANDMARKS:left_iris_landmarks"
  input_stream: "IMAGE_SIZE:input_image_size"
  output_stream: "NORM_FILTERED_LANDMARKS:smoothed_left_iris_landmarks"
  options: {
    [mediapipe.LandmarksSmoothingCalculatorOptions.ext] {
      one_euro_filter {
        min_cutoff: 0.01
        beta: 10.0
        derivate_cutoff: 1.0
      }
    }
  }
}
```

Those calculators are well documented/commented too, [such as](https://github.com/google/mediapipe/blob/ae05ad04b3ae43d475ccb2868e23f1418fea8746/mediapipe/calculators/util/landmarks_smoothing_calculator.proto#L52-L55):
```
...
// For the details of the filter implementation and the procedure of its
// configuration please check http://cristal.univ-lille.fr/~casiez/1euro/
message OneEuroFilter {
    // Frequency of incomming frames defined in frames per seconds. Used only if
    // can't be calculated from provided events (e.g. on the very first frame).
    optional float frequency = 1 [default = 30.0];
...
```

- [1€ Filter](http://cristal.univ-lille.fr/~casiez/1euro/)
- [1€ Filter Interactive Demo](https://cristal.univ-lille.fr/~casiez/1euro/InteractiveDemo/)
- ![one-euro-filter-demo](https://user-images.githubusercontent.com/46559594/120635384-60599c00-c4a7-11eb-8b5d-bf89d1607751.gif)

### Pose estimation

**TODO**

### Build MediaPipe project as a framework

1. Create a BUILD file:
```
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

ios_framework(
    name = "MPPIrisTracking",
    hdrs = [
        "MPPIrisTracker.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.studio61315.MPPIrisTraking",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPIrisTrackingLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPIrisTrackingLibrary",
    srcs = [
        "MPPIrisTracker.mm",
    ],
    hdrs = [
        "MPPIrisTracker.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/graphs/iris_tracking:iris_tracking_gpu.binarypb",
        "//mediapipe/modules/face_detection:face_detection_front.tflite",
        "//mediapipe/modules/face_landmark:face_landmark.tflite",
        "//mediapipe/modules/iris_landmark:iris_landmark.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/iris_tracking:iris_tracking_gpu_deps",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)

```

2. Run bazel command:
```
bazel build -c opt --config=ios_fat mediapipe/examples/ios/iristrackinggpuframework:MPPIrisTracking --verbose_failures
```

## License

**mediapipe-iris-ios** is available under the MIT license. See the [LICENSE](LICENSE) file for more info.