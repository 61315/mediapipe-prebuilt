#import "MPPBPlayground.h"
#import "mediapipe/objc/MPPGraph.h"
// #import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/framework/port/parse_text_proto.h"
//#include <mediapipe/framework/port/parse_text_proto.h>


static NSString* const kGraphName = @"our_first";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";

static const char* kGraph = R"pb(
input_stream: "input_video"
output_stream: "output_video"

node: {
    calculator: "PassThroughCalculator"
    input_stream: "input_video"
    output_stream: "output_video"
})pb";

@interface MPPBPlayground() <MPPGraphDelegate>
@property(nonatomic) MPPGraph* mediapipeGraph;
@end

@implementation MPPBPlayground { }

#pragma mark - Cleanup methods

- (void)dealloc {
    self.mediapipeGraph.delegate = nil;
    [self.mediapipeGraph cancel];
    
    // Ignore errors since we're cleaning up.
    [self.mediapipeGraph closeAllInputStreamsWithError:nil];
    [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods
// https://google.github.io/mediapipe/getting_started/hello_world_ios.html#using-a-mediapipe-graph-in-ios

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    if (!resource || resource.length == 0) {
        return nil;
    }
    NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
    NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
    if (!data) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];

    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    
    return newGraph;
}


+ (MPPGraph*)loadGraphFromString:(NSString*)string {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    
    if (!string || string.length == 0) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config string into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config = mediapipe::ParseTextProtoOrDie<mediapipe::CalculatorGraphConfig>(string.UTF8String);

//    config.ParseFromString(R"(
//    input_stream: "input_video"
//
//    # Max number of hands to detect/process. (int)
//    input_side_packet: "num_hands"
//
//    # Model complexity (0 or 1). (int)
//    input_side_packet: "model_complexity"
//
//    # GPU image. (GpuBuffer)
//    output_stream: "output_video"
//    output_stream: "hand_landmarks"
//
//    node {
//        calculator: "FlowLimiterCalculator"
//        input_stream: "input_video"
//        input_stream: "FINISHED:output_video"
//        input_stream_info: {
//            tag_index: "FINISHED"
//            back_edge: true
//        }
//        output_stream: "throttled_input_video"
//    }
//
//    # Detects/tracks hand landmarks.
//    node {
//        calculator: "HandLandmarkTrackingGpu"
//        input_stream: "IMAGE:throttled_input_video"
//        input_side_packet: "MODEL_COMPLEXITY:model_complexity"
//        input_side_packet: "NUM_HANDS:num_hands"
//        output_stream: "LANDMARKS:hand_landmarks"
//        output_stream: "HANDEDNESS:handedness"
//        output_stream: "PALM_DETECTIONS:palm_detections"
//        output_stream: "HAND_ROIS_FROM_LANDMARKS:hand_rects_from_landmarks"
//        output_stream: "HAND_ROIS_FROM_PALM_DETECTIONS:hand_rects_from_palm_detections"
//    }
//
//    node {
//        calculator: "HandRendererSubgraph"
//        input_stream: "IMAGE:throttled_input_video"
//        input_stream: "DETECTIONS:palm_detections"
//        input_stream: "LANDMARKS:hand_landmarks"
//        input_stream: "HANDEDNESS:handedness"
//        input_stream: "NORM_RECTS:0:hand_rects_from_palm_detections"
//        input_stream: "NORM_RECTS:1:hand_rects_from_landmarks"
//        output_stream: "IMAGE:output_video"
//    })");

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];

    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    
    return newGraph;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        self.mediapipeGraph = [[self class] loadGraphFromString:string];
        self.mediapipeGraph.delegate = self;
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (void)startGraph {
    // Start running self.mediapipeGraph.
    NSError* error;
    if (![self.mediapipeGraph startWithError:&error]) {
        NSLog(@"Failed to start graph: %@", error);
    }
}

#pragma mark - MPPInputSourceDelegate methods

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                timestamp:(CMTime)timestamp {
    
    mediapipe::Timestamp graphTimestamp(static_cast<mediapipe::TimestampBaseType>(
        mediapipe::Timestamp::kTimestampUnitsPerSecond * CMTimeGetSeconds(timestamp)));
    
    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer
                               timestamp:graphTimestamp];
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string&)streamName {
    if (streamName == kOutputStream) {
        [_delegate tracker: self didOutputPixelBuffer: pixelBuffer];
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    
}

@end
