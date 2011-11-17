//
//  JCEViewController.h
//  Jucie
//
//  Created by 上田 澄博 on 11/11/17.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageManager.h"

@interface JCEViewController : UIViewController <ImageManagerDelegate>

@property (strong, nonatomic) IBOutlet UIImageView *staticImageView;
@property (strong, nonatomic) IBOutlet UIImageView *dynamicImageView;

@property (strong, nonatomic) IBOutlet UIImageView *capturedImageView;
@property (strong, nonatomic) IBOutlet UIImageView *histgramImageView;
@property (strong, nonatomic) IBOutlet UILabel *fpsLabel;
@property (strong, nonatomic) IBOutlet UILabel *distanceLabel;
@property (strong, nonatomic) IBOutlet UISwitch *saveSwitch;

@end
