//
//  Utils.h
//  KPCC
//
//  Created by John Meeker on 6/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject

+ (NSDate*)dateFromRFCString:(NSString*)dateString;
+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate;
+ (NSString*)prettyStringFromRFCDate:(NSDate*)date;

@end
