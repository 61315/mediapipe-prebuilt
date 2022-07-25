#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBIris;
// @class MPPLandmark;

@protocol MPPBIrisDelegate <NSObject>
- (void)irisTracker: (MPPBIris *)irisTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)irisTracker: (MPPBIris *)irisTracker didOutputTransform: (simd_float4x4)transform;
// - (void)irisTracker: (MPPIrisTracker *)irisTracker didOutputLandmarks: (NSArray<MPPLandmark *> *)landmarks;
@end

@interface MPPBIris : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBIrisDelegate> delegate;
@end

// @interface MPPLandmark : NSObject
// - (instancetype)init;
// @property simd_float3 data;
// @end
