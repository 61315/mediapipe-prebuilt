// "ios/prebuilt/multipose/MPPBMultiPose.h"
// https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/multipose/

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBMultiPose;

@protocol MPPBMultiPoseDelegate <NSObject>
- (void)tracker: (MPPBMultiPose *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface MPPBMultiPose : NSObject
- (instancetype)init;
- (instancetype)initWithString: (NSString *)string;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBMultiPoseDelegate> delegate;
@end
