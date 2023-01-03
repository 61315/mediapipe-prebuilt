# "ios/prebuilt/multipose/modules/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/multipose/

load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_simple_subgraph",
)

package(default_visibility = ["//visibility:public"])

mediapipe_simple_subgraph(
    name = "multi_pose_detection_gpu",
    graph = "multi_pose_detection_gpu.pbtxt",
    register_as = "MultiPoseDetectionGpu",
    deps = [
        "//mediapipe/calculators/tensor:image_to_tensor_calculator",
        "//mediapipe/calculators/tensor:inference_calculator",
        "//mediapipe/calculators/tensor:tensors_to_detections_calculator",
        "//mediapipe/calculators/tflite:ssd_anchors_calculator",
        "//mediapipe/calculators/util:detection_letterbox_removal_calculator",
        "//mediapipe/calculators/util:non_max_suppression_calculator",
    ],
)

mediapipe_simple_subgraph(
    name = "multi_pose_landmark_gpu",
    graph = "multi_pose_landmark_gpu.pbtxt",
    register_as = "MultiPoseLandmarkGpu",
    deps = [
        "//mediapipe/modules/pose_landmark:pose_detection_to_roi",
        "//mediapipe/modules/pose_landmark:pose_landmark_by_roi_gpu",
        "//mediapipe/modules/pose_landmark:pose_landmark_filtering",
        "//mediapipe/modules/pose_landmark:pose_landmarks_to_roi",
        "//mediapipe/modules/pose_landmark:pose_segmentation_filtering",
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:gate_calculator",
        "//mediapipe/calculators/core:merge_calculator",
        "//mediapipe/calculators/core:packet_presence_calculator",
        "//mediapipe/calculators/core:previous_loopback_calculator",
        "//mediapipe/calculators/core:split_vector_calculator",
        "//mediapipe/calculators/image:image_properties_calculator",
        "//mediapipe/calculators/util:from_image_calculator",
        ":multi_pose_detection_gpu",
        "//mediapipe/calculators/util:association_norm_rect_calculator",
        "//mediapipe/calculators/core:begin_loop_calculator",
        "//mediapipe/calculators/core:end_loop_calculator",
        "//mediapipe/calculators/util:filter_collection_calculator",
        "//mediapipe/calculators/util:collection_has_min_size_calculator",
        "//mediapipe/calculators/core:clip_vector_size_calculator",
        # renderer
        "//mediapipe/calculators/core:split_proto_list_calculator",
        "//mediapipe/calculators/util:annotation_overlay_calculator",
        "//mediapipe/calculators/util:detections_to_render_data_calculator",
        "//mediapipe/calculators/util:landmarks_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_scale_calculator",
    ],
)
