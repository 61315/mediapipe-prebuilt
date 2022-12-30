load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",   
)

ios_framework(
    name = "MPPBPose",
    hdrs = [
        "MPPBPose.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.pose",
    families = ["iphone", "ipad"],
    minimum_os_version = "13.0",
    deps = [
        ":MPPBPoseFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBPoseFramework",
    srcs = [
        "MPPBPose.mm",
    ],
    hdrs = [
        "MPPBPose.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/modules/pose_detection:pose_detection.tflite",
        "//mediapipe/modules/pose_landmark:pose_landmark_heavy.tflite",
        "//mediapipe/examples/ios/prebuilt/pose/graphs:custom_pose_tracking_ios.binarypb",
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
            "//mediapipe/examples/ios/prebuilt/pose/graphs:custom_pose_tracking_ios_calculators",
        ],
    }),
)