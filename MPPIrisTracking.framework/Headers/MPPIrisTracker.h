#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@class MPPIrisTracker;

@protocol MPPIrisTrackerDelegate <NSObject>
- (void)irisTracker: (MPPIrisTracker*)irisTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface MPPIrisTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPIrisTrackerDelegate> delegate;
@end
