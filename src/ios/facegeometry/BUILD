load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",   
)

ios_framework(
    name = "MPPBFaceGeometry",
    hdrs = [
        "MPPBFaceGeometry.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.facegeometry",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPBFaceGeometryFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBFaceGeometryFramework",
    srcs = [
        "MPPBFaceGeometry.mm",
    ],
    hdrs = [
        "MPPBFaceGeometry.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/modules/face_detection:face_detection_short_range.tflite",
        "//mediapipe/modules/face_landmark:face_landmark.tflite",
        "//mediapipe/modules/face_geometry/data:geometry_pipeline_metadata_landmarks.binarypb",
        "//mediapipe/examples/ios/prebuilt/facegeometry/graphs:face_geometry_with_transform.binarypb",
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
            "//mediapipe/examples/ios/prebuilt/facegeometry/graphs:face_geometry_with_transform_calculators",
        ],
    }),
)