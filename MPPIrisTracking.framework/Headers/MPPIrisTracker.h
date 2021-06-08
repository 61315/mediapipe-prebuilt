#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPIrisTracker;

@protocol MPPIrisTrackerDelegate <NSObject>
- (void)irisTracker: (MPPIrisTracker *)irisTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)irisTracker: (MPPIrisTracker *)irisTracker didOutputTransform: (simd_float4x4)transform;
@end

@interface MPPIrisTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPIrisTrackerDelegate> delegate;
@end
