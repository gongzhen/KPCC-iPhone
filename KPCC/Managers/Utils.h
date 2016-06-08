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
#import "SimpleCompletionBlocks.h"

@import AVFoundation;

//@class SCPRMasterViewController;



#define kUpdateProgramKey @":UPDATE-PROGRAM:"
#define SEQ(a,b) [a isEqualToString:b]
#define kFadeDuration 0.5
#define kMainLiveStreamTitle [[DesignManager shared] mainLiveStreamTitle]

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
+ (NSString *)base64:(NSData *)input;
+ (id)loadJson:(NSString*)json;
+ (NSString*)rawJson:(id)object;
+ (NSString*)prettyVersion;
+ (NSString*)sha1:(NSString*)input;
+ (BOOL)validateEmail:(NSString *)string;
+ (NSString*)urlSafeVersion;
+ (NSArray*)reversedArrayFromArray:(NSArray*)inOrder;
+ (void)crash;
+ (NSString*)formatOfInterestFromDate:(NSDate*)rawDate startDate:(BOOL)startDate;
+ (NSString*)formatOfInterestFromDate:(NSDate*)rawDate startDate:(BOOL)startDate gapped:(BOOL)gapped;
+ (NSDictionary*)globalConfig;
+ (id)xib:(NSString*)name;
+ (NSMutableDictionary*)sanitizeDictionary:(NSDictionary*)dictionary;

@end
