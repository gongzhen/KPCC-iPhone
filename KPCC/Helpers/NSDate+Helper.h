//
//  NSDate+Helper.h
//  myBETAapp
//
//  Created by The Lathe, Inc. on 2/10/10.
//  Copyright 2010 Bayer HealthCare Pharmaceuticals Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Helper)

- (NSInteger)daysAgo;
- (NSUInteger)daysAgoAgainstMidnight;
- (NSString *)stringDaysAgo;
- (NSString *)stringDaysAgoAgainstMidnight:(BOOL)flag;
- (NSUInteger)weekday;

+ (NSString *)dbFormatString;
+ (NSDate *)dateFromString:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date withFormat:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date;
+ (NSString *)stringForDisplayFromDate:(NSDate *)date;
+ (NSString *)stringForDisplayFromDate:(NSDate *)date prefixed:(BOOL)prefixed;

- (NSDate*)dateChangedBy:(NSInteger)days;
- (NSDate *)beginningOfWeek;
- (NSDate *)beginningOfDay;
- (NSDate *)endOfWeek;
- (NSDate *)lastDayOfMonth;
- (NSDate*)forceMidnight;
- (BOOL)isYesterday;

- (NSString*)prettyCompare:(NSDate*)date;
- (NSUInteger)daysBetween:(NSDate *)otherDate;

- (BOOL)isToday;
- (BOOL)isExpired;
- (BOOL)isOlderThanInSeconds:(NSInteger)secondsAgo;
- (NSInteger)secondsUntil;

@end