#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@class IrisTracker;

@protocol IrisTrackerDelegate <NSObject>
- (void)irisTracker: (IrisTracker*)irisTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface IrisTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;
@property (weak, nonatomic) id <IrisTrackerDelegate> delegate;
@end
