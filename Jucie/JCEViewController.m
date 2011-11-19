//
//  JCEViewController.m
//  Jucie
//
//  Created by 上田 澄博 on 11/11/17.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "JCEViewController.h"
#import "SAIImageScanner.h"

@interface JCEViewController ()

@property (nonatomic,strong) SAIImageScanner *iManager;
@property (nonatomic,readwrite) SystemSoundID alertSoundIDC;
@property (nonatomic,readwrite) SystemSoundID alertSoundIDF;

@end

@implementation JCEViewController
@synthesize staticImageView;
@synthesize dynamicImageView;
@synthesize capturedImageView;
@synthesize histgramImageView;
@synthesize fpsLabel;
@synthesize distanceLabel;
@synthesize saveSwitch;

@synthesize iManager;
@synthesize alertSoundIDC;
@synthesize alertSoundIDF;

-(void)awakeFromNib {
	NSURL *url;
	url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"C" ofType:@"aif"] isDirectory:NO];
	AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &alertSoundIDC);

	url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"F" ofType:@"aif"] isDirectory:NO];
	AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &alertSoundIDF);

	self.iManager = [[SAIImageScanner alloc] init];
	self.iManager.delegate = self;
	self.iManager.useHistogramImage = YES;
	[self.iManager startCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	self.saveSwitch.on = NO;
}

- (void)viewDidUnload
{
	[self setCapturedImageView:nil];
	[self setHistgramImageView:nil];
	[self setFpsLabel:nil];
	[self setStaticImageView:nil];
	[self setDynamicImageView:nil];
	[self setDistanceLabel:nil];
	[self setSaveSwitch:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}

#pragma mark -
- (void)imageScanner:(SAIImageScanner*)imageScanner pixelBufferReadyForDisplay:(CVImageBufferRef)pixelBufferRef {
	
}

-(void)imageScanner:(SAIImageScanner *)imageScanner didChangeDistance:(double)distance {
	NSLog(@"distance: %f",distance);
	dispatch_async(dispatch_get_main_queue(), ^{
		self.distanceLabel.text = [NSString stringWithFormat:@"%0.4f dis",distance];
	});
}

-(void)imageScanner:(SAIImageScanner *)imageScanner didCaptureImage:(CGImageRef)imageRef {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.capturedImageView.image = [UIImage imageWithCGImage:imageRef];
		self.fpsLabel.text = [NSString stringWithFormat:@"%0.2f fps",self.iManager.videoFrameRate];
	});
}

-(void)imageScanner:(SAIImageScanner *)imageScanner didDrawHistgramImage:(UIImage *)image {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.histgramImageView.image = image;
	});
}

-(void)imageScanner:(SAIImageScanner *)imageScanner didCaptureImageAtDynamic:(CGImageRef)imageRef {
	UIImage *image = [UIImage imageWithCGImage:imageRef];
	dispatch_async(dispatch_get_main_queue(), ^{
		self.dynamicImageView.image = image;
		if(self.saveSwitch.on) {
			AudioServicesPlaySystemSound(alertSoundIDC);
		}
	});
}

-(void)imageScanner:(SAIImageScanner *)imageScanner didCaptureImageAtStatic:(CGImageRef)imageRef {
	UIImage *image = [UIImage imageWithCGImage:imageRef];
	if (self.saveSwitch.on) {
		UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		self.staticImageView.image = image;
		if(self.saveSwitch.on) {
			AudioServicesPlaySystemSound(alertSoundIDF);
		}
	});
}

@end
