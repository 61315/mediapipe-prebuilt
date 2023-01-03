# "ios/prebuilt/multipose/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/multipose/

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",   
)

ios_framework(
    name = "MPPBMultiPose",
    hdrs = [
        "MPPBMultiPose.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.multipose",
    families = ["iphone", "ipad"],
    minimum_os_version = "13.0",
    deps = [
        ":MPPBMultiPoseFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBMultiPoseFramework",
    srcs = [
        "MPPBMultiPose.mm",
    ],
    hdrs = [
        "MPPBMultiPose.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/modules/pose_detection:pose_detection.tflite",
        "//mediapipe/modules/pose_landmark:pose_landmark_lite.tflite",
        "//mediapipe/examples/ios/prebuilt/multipose/graphs:multi_pose_tracking_gpu.binarypb",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
        # "AssetsLibrary",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/framework/port:parse_text_proto",
            "//mediapipe/examples/ios/prebuilt/multipose/graphs:multi_pose_tracking_gpu_calculators",
        ],
    }),
)