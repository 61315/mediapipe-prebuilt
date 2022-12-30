#import "MPPBPose.h"

#import "mediapipe/objc/MPPGraph.h"

#include "mediapipe/framework/port/parse_text_proto.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"custom_pose_tracking_ios";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "pose_landmarks";
static const char* kWorldLandmarksOutputStream = "pose_world_landmarks";

@interface MPPBPose() <MPPGraphDelegate>
@property(nonatomic) MPPGraph* mediapipeGraph;
@end

@implementation MPPBPose { }

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
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kWorldLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];

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

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];

    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kWorldLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];

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
    if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No pose landmarks", packet.Timestamp().Value());
            return;
        }

        const auto& landmarkList = packet.Get<::mediapipe::NormalizedLandmarkList>();
        NSMutableArray *landmarks = [NSMutableArray arrayWithCapacity:landmarkList.landmark_size() * 5];

        for (int i = 0; i < landmarkList.landmark_size(); ++i) {
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).x()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).y()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).z()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).visibility()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).presence()]];
        }

        [_delegate tracker: self didOutputLandmarks: landmarks withIndex: 0];
    }

    if (streamName == kWorldLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No world pose landmarks", packet.Timestamp().Value());
            return;
        }

        const auto& landmarkList = packet.Get<::mediapipe::LandmarkList>();
        NSMutableArray *landmarks = [NSMutableArray arrayWithCapacity:landmarkList.landmark_size() * 5];

        for (int i = 0; i < landmarkList.landmark_size(); ++i) {
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).x()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).y()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).z()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).visibility()]];
            [landmarks addObject:[NSNumber numberWithFloat:landmarkList.landmark(i).presence()]];
        }

        [_delegate tracker: self didOutputWorldLandmarks: landmarks withIndex: 0];
    }
}

@end
