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

//@class SCPRMasterViewController;



#define kUpdateProgramKey @":UPDATE-PROGRAM:"
#define SEQ(a,b) [a isEqualToString:b]
#define kFadeDuration 0.5

@interface Utils : NSObject

+ (SCPRAppDelegate*)del;

+ (NSDate*)dateFromRFCString:(NSString*)dateString;
+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate;
+ (NSString*)prettyStringFromRFCDate:(NSDate*)date;

+ (NSString*)episodeDateStringFromRFCDate:(NSDate *)date;
+ (NSString*)elapsedTimeStringWithPosition:(double)position andDuration:(double)duration;

+ (BOOL)pureNil:(id)object;
+ (BOOL)isRetina;
+ (BOOL)isThreePointFive;
+ (BOOL)isIOS8;
+ (NSDictionary*)gConfig;
+ (NSString *)base64:(NSData *)input;
+ (id)loadJson:(NSString*)json;
+ (NSString*)rawJson:(id)object;
+ (NSString*)prettyVersion;

@end
