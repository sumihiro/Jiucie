//
//  SAIImageScanner.h
//  Jucie
//
//  Created by 上田 澄博 on 11/11/19.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class SAIImageScanner;

@protocol SAIImageScannerDelegate <NSObject>

- (void)imageScanner:(SAIImageScanner*)imageScanner pixelBufferReadyForDisplay:(CVImageBufferRef)pixelBufferRef;
- (void)imageScanner:(SAIImageScanner*)imageScanner didChangeDistance:(double)distance;
- (void)imageScanner:(SAIImageScanner*)imageScanner didCaptureImage:(CGImageRef)imageRef;
- (void)imageScanner:(SAIImageScanner*)imageScanner didDrawHistgramImage:(UIImage*)image;
- (void)imageScanner:(SAIImageScanner*)imageScanner didCaptureImageAtStatic:(CGImageRef)imageRef;
- (void)imageScanner:(SAIImageScanner*)imageScanner didCaptureImageAtDynamic:(CGImageRef)imageRef;

@end

@interface SAIImageScanner : NSObject  <AVCaptureVideoDataOutputSampleBufferDelegate> 

@property (nonatomic, weak) id<SAIImageScannerDelegate> delegate;

// 処理している映像のフレームレート
@property (nonatomic,readonly) Float64 videoFrameRate;

// 静→動への判定を行なう閾値
@property (nonatomic,readwrite) double distanceThresholdMax;
// 動→静への判定を行なう閾値
@property (nonatomic,readwrite) double distanceThresholdMin;
// ヒストグラム画像の作成を行なうかどうかのフラグ
// NOにする方がフレームレートが上がる
@property (nonatomic,readwrite) BOOL useHistogramImage;

- (void)startCapture;
- (void)stopCapture;

@end
