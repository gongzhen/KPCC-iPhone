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

//@class SCPRMasterViewController;

typedef void (^CompletionBlock)(void);
typedef void (^CompletionBlockWithValue)(id returnedObject);

@interface Utils : NSObject

+ (SCPRAppDelegate*)del;

+ (NSDate*)dateFromRFCString:(NSString*)dateString;
+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate;
+ (NSString*)prettyStringFromRFCDate:(NSDate*)date;

+ (NSString*)episodeDateStringFromRFCDate:(NSDate *)date;
+ (NSString*)elapsedTimeStringWithPosition:(double)position andDuration:(double)duration;

+ (BOOL)pureNil:(id)object;
+ (BOOL)isRetina;

@end
