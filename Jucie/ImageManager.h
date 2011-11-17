//
//  ImageManager.h
//  Jucie
//
//  Created by 上田 澄博 on 11/11/17.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class ImageManager;

@protocol ImageManagerDelegate <NSObject>

- (void)pixelBufferReadyForDisplay:(CVImageBufferRef)pixelBufferRef;
- (void)distanceDidChange:(double)distance;
- (void)didCaptureImage:(CGImageRef)imageRef;
- (void)didDrawHistgramImage:(UIImage*)image;
- (void)didCaptureImageAtStatic:(CGImageRef)imageRef;
- (void)didCaptureImageAtDynamic:(CGImageRef)imageRef;

@end

@interface ImageManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> 

@property (nonatomic, weak) id<ImageManagerDelegate> delegate;
@property (nonatomic, readonly, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic,readwrite) Float64 videoFrameRate;

- (void)startCapture;
- (void)stopCapture;

@end
