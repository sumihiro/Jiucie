//
//  SAIImageScanner.m
//  Jucie
//
//  Created by 上田 澄博 on 11/11/19.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <opencv2/imgproc/imgproc_c.h>

#import "SAIImageScanner.h"

#define MAX_DIST 0.1
#define MIN_DIST 0.05

typedef enum WaitingMode {
	WaitingModeDynamic,
	WaitingModeStatic
} WaitingMode;

@interface SAIImageScanner ()

// フレームレート計算用の配列
@property (nonatomic,strong) NSMutableArray *previousSecondTimestamps;

// ビデオキャプチャ
@property (nonatomic,strong) AVCaptureSession *captureSession;
@property (nonatomic,strong) AVCaptureConnection *videoConnection;

// ヒストリによる動静判定用の各変数
@property (nonatomic,readwrite) CvHistogram *prevHist;
@property (nonatomic,readwrite) double prevDistance;
@property (nonatomic,readwrite) double distance;
@property (nonatomic,readwrite) WaitingMode waitingMode;


- (void)processPixelBuffer: (CVImageBufferRef)pixelBuffer;
- (void)calculateFramerateAtTimestamp:(CMTime) timestamp;

- (CGImageRef)createCgImageFromCVImageBuffer:(CVImageBufferRef)pixelBuffer;
- (IplImage *)createIplImageFromCGImage:(CGImageRef)imageRef;
- (UIImage*)drawHistgram:(CvHistogram*)histgram;

- (void)showError:(NSError *)error;

@end

@implementation SAIImageScanner

@synthesize delegate;

@synthesize distanceThresholdMax;
@synthesize distanceThresholdMin;
@synthesize useHistogramImage;

@synthesize previousSecondTimestamps;
@synthesize videoFrameRate;
@synthesize captureSession;
@synthesize videoConnection;

@synthesize prevHist;
@synthesize prevDistance;
@synthesize distance;
@synthesize waitingMode;

- (id)init {
    self = [super init];
    if (self) {
        self.previousSecondTimestamps = [[NSMutableArray alloc] init];
		self.distanceThresholdMax = MAX_DIST;
		self.distanceThresholdMin = MIN_DIST;
		self.useHistogramImage = NO;
    }
    return self;
}

#pragma mark Processing

- (void)processPixelBuffer: (CVImageBufferRef)pixelBuffer 
{
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	
	@autoreleasepool {
		CGImageRef imageRef = [self createCgImageFromCVImageBuffer:pixelBuffer];
		IplImage *image = [self createIplImageFromCGImage:imageRef];
		
		int histSize = 256;
		float range[] = {0,256};
		float *ranges[] = {range};
		CvHistogram *hist = cvCreateHist(1, &histSize, CV_HIST_ARRAY, ranges, 1);
		
		IplImage *dstImage = cvCreateImage(cvSize(image->width, image->height), image->depth, 1);
		
		cvSplit(image, dstImage, NULL, NULL, NULL);
		
		cvCalcHist(&dstImage, hist, 0, NULL);
		cvNormalizeHist(hist, 10000);
		
		if (prevHist) {
			self.distance = cvCompareHist(hist, prevHist, CV_COMP_BHATTACHARYYA);
			
			[self.delegate imageScanner:self didChangeDistance:self.distance];
			
			cvReleaseHist(&prevHist);
		}
		
		cvReleaseImage(&dstImage);
		cvReleaseImage(&image);
		
		[self.delegate imageScanner:self didCaptureImage:imageRef];
		if (useHistogramImage) {
			[self.delegate imageScanner:self didDrawHistgramImage:[self drawHistgram:hist]];
		}
		
		switch (self.waitingMode) {
			case WaitingModeStatic: // 動いている状態から止まる状態を待っている
				if (self.distance < self.distanceThresholdMin && self.prevDistance >= self.distanceThresholdMin) {
					self.waitingMode = WaitingModeDynamic;
					[self.delegate imageScanner:self didCaptureImageAtStatic:imageRef];
				}
				break;
			case WaitingModeDynamic: // 止まっている状態から動いている状態を待っている
				if (self.distance > self.distanceThresholdMax && self.prevDistance <= self.distanceThresholdMax) {
					self.waitingMode = WaitingModeStatic;
					[self.delegate imageScanner:self didCaptureImageAtDynamic:imageRef];
				}
				break;
			default:
				break;
		}
		
		self.prevDistance = distance;
		self.prevHist = hist;
		
		
		CGImageRelease(imageRef);
	}
	
	
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

#pragma mark - Capture
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection 
{   
    if ( connection == self.videoConnection ) {
        
        // Get framerate
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
        [self calculateFramerateAtTimestamp:timestamp];
        
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Synchronously process the pixel buffer to de-green it.
        [self processPixelBuffer:pixelBuffer];
	}
    
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position 
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return nil;
}


- (BOOL) setupCaptureSession 
{
    /*
     * Create capture session
     */
    self.captureSession = [[AVCaptureSession alloc] init];
    
    /*
     * Create video connection
     */
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionBack] error:nil];
    if ([self.captureSession canAddInput:videoIn])
        [self.captureSession addInput:videoIn];
    
    AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
    [videoOut setAlwaysDiscardsLateVideoFrames:YES];
    [videoOut setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
    dispatch_release(videoCaptureQueue);
	
    if ([self.captureSession canAddOutput:videoOut])
        [self.captureSession addOutput:videoOut];
    self.videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
	self.videoConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    
    return YES;
}

- (void) setupAndStartCaptureSession
{
    if ( !self.captureSession )
        [self setupCaptureSession];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionStoppedRunningNotification:) name:AVCaptureSessionDidStopRunningNotification object:self.captureSession];
    
    if ( !self.captureSession.isRunning )
        [self.captureSession startRunning];
}

- (void)captureSessionStoppedRunningNotification:(NSNotification *)notification
{
	// do somethig
}


- (void)startCapture {
	self.prevDistance = 0.0;
	[self setupAndStartCaptureSession];
}
- (void)stopCapture {
	[self.captureSession stopRunning];
	
	if (prevHist) {
		cvReleaseHist(&prevHist);
		prevHist = NULL;
	}
}

#pragma mark Utilities

- (void) calculateFramerateAtTimestamp:(CMTime) timestamp
{
    [self.previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
    
    CMTime oneSecond = CMTimeMake( 1, 1 );
    CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
    
    while( CMTIME_COMPARE_INLINE( [[self.previousSecondTimestamps objectAtIndex:0] CMTimeValue], <, oneSecondAgo ) )
        [self.previousSecondTimestamps removeObjectAtIndex:0];
    
    Float64 newRate = (Float64) [self.previousSecondTimestamps count];
    videoFrameRate = (self.videoFrameRate + newRate) / 2;
}

- (CGImageRef)createCgImageFromCVImageBuffer:(CVImageBufferRef)pixelBuffer {
	uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer); 
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer); 
	size_t width = CVPixelBufferGetWidth(pixelBuffer); 
	size_t height = CVPixelBufferGetHeight(pixelBuffer); 
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	CGContextRef originlContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	CGImageRef originalImageRef;
	originalImageRef = CGBitmapContextCreateImage(originlContext);
	
	CGColorSpaceRelease(colorSpace);
	
	return originalImageRef;
}

- (IplImage *)createIplImageFromCGImage:(CGImageRef)imageRef  {
	
	CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	// 一時的なIplImageを作成
	IplImage *iplimage = cvCreateImage(
									   cvSize(imageSize.width,imageSize.height), IPL_DEPTH_8U, 4
									   );
	// CGContextを一時的なIplImageから作成
	CGContextRef contextRef = CGBitmapContextCreate(
													iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault
													);
	// CGImageをCGContextに描画
	CGContextDrawImage(
					   contextRef,
					   CGRectMake(0, 0, imageSize.width, imageSize.height),
					   imageRef
					   );
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	return iplimage;
}

- (UIImage*)drawHistgram:(CvHistogram*)histgram {
	CGSize imageSize = CGSizeMake(256, 256);
	
	CvHistogram *h;
	
	int histSize = 256;
	float range[] = {0,256};
	float *ranges[] = {range};
	h = cvCreateHist(1, &histSize, CV_HIST_ARRAY, ranges, 1);
	
	//cvCopyHist(histgram, &h);
	
	float max = 0;
	cvGetMinMaxHistValue(h, 0, &max, 0, 0);
	cvScale(h->bins,h->bins,((double)imageSize.height) / max, 0);
	//int histSize = sizeof(h->bins);
	
	UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1.0f);
	
	for (int i = 0; i < histSize; ++ i) {
		UIBezierPath *line = [UIBezierPath bezierPath];
		[[UIColor redColor] set];
		float x = imageSize.width / histSize * i;
		[line moveToPoint:CGPointMake(x, imageSize.height)];
		[line addLineToPoint:CGPointMake(x, imageSize.height - cvRound(cvGetReal1D(h->bins, i)))];
		[line stroke];
	}
	
	UIImage *histImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	cvReleaseHist(&h);
	
	return histImage;
}

#pragma mark Error Handling

- (void)showError:(NSError *)error
{
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

@end
