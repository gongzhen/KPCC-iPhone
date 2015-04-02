//
//  Utils.h
//  KPCC
//
//  Created by John Meeker on 6/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCPRAppDelegate.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"
#import "NSDate+Helper.h"
#import "UIButton+Additions.h"
#import "NSData+JSONAdditions.h"
@import AVFoundation;

//@class SCPRMasterViewController;



#define kUpdateProgramKey @":UPDATE-PROGRAM:"
#define SEQ(a,b) [a isEqualToString:b]
#define kFadeDuration 0.5

static NSString *kPotentialElements = @"date time uri cs-guid s-ip s-ip-changes sc-count c-duration-downloaded c-start-time c-duration-watched bytes c-observed-bitrate sc-indicated-bitrate c-stalls c-frames-dropped c-startup-time c-overdue c-reason c-observed-min-bitrate c-observed-max-bitrate c-observed-bitrate-sd s-playback-type sc-wwan-count c-switch-bitrate";

@interface Utils : NSObject

+ (SCPRAppDelegate*)del;

+ (NSDate*)dateFromRFCString:(NSString*)dateString;
+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate;
+ (NSString*)prettyStringFromRFCDate:(NSDate*)date;

+ (NSString*)episodeDateStringFromRFCDate:(NSDate *)date;
+ (NSString*)elapsedTimeStringWithPosition:(double)position andDuration:(double)duration;
+ (CGFloat)degreesToRadians:(CGFloat) degrees;
+ (CGFloat)radiansToDegrees:(CGFloat)radians;

+ (BOOL)pureNil:(id)object;
+ (BOOL)isRetina;
+ (BOOL)isThreePointFive;
+ (BOOL)isIOS8;
+ (NSDictionary*)gConfig;
+ (NSString *)base64:(NSData *)input;
+ (id)loadJson:(NSString*)json;
+ (NSString*)rawJson:(id)object;
+ (NSString*)prettyVersion;
+ (NSString*)sha1:(NSString*)input;
+ (BOOL)validateEmail:(NSString *)string;
+ (NSString*)urlSafeVersion;
+ (NSDictionary*)accessLogToDictionary:(AVPlayerItemAccessLog*)accessLog;
+ (NSDictionary*)errorLogToDictionary:(AVPlayerItemErrorLog*)errorLog;
+ (NSArray*)reversedArrayFromArray:(NSArray*)inOrder;

@end
