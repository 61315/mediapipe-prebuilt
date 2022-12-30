#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBPose;

@protocol MPPBPoseDelegate <NSObject>
- (void)tracker: (MPPBPose *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)tracker: (MPPBPose *)tracker didOutputLandmarks: (NSArray<NSNumber *> *)landmarks withIndex: (NSInteger)index;
- (void)tracker: (MPPBPose *)tracker didOutputWorldLandmarks: (NSArray<NSNumber *> *)landmarks withIndex: (NSInteger)index;
@end

@interface MPPBPose : NSObject
- (instancetype)init;
- (instancetype)initWithString: (NSString *)string;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBPoseDelegate> delegate;
@end
