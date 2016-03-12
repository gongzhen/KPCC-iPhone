//
//  NSDate+Helper.h
//  myBETAapp
//
//  Created by The Lathe, Inc. on 2/10/10.
//  Copyright 2010 Bayer HealthCare Pharmaceuticals Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Helper)

@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger daysAgo;
@property (NS_NONATOMIC_IOSONLY, readonly) NSUInteger daysAgoAgainstMidnight;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *stringDaysAgo;
- (NSString *)stringDaysAgoAgainstMidnight:(BOOL)flag;
@property (NS_NONATOMIC_IOSONLY, readonly) NSUInteger weekday;

+ (NSString *)dbFormatString;
+ (NSDate *)dateFromString:(NSString *)string;
+ (NSDate*)dateFromString:(NSString *)string withFormat:(NSString*)format;
+ (NSString *)stringFromDate:(NSDate *)date withFormat:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date;
+ (NSString *)stringForDisplayFromDate:(NSDate *)date;
+ (NSString *)stringForDisplayFromDate:(NSDate *)date prefixed:(BOOL)prefixed;

- (NSDate*)dateChangedBy:(NSInteger)days;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *beginningOfWeek;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *beginningOfDay;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *endOfWeek;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *lastDayOfMonth;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *forceMidnight;
@property (NS_NONATOMIC_IOSONLY, getter=isYesterday, readonly) BOOL yesterday;

- (NSString*)prettyCompare:(NSDate*)date;
- (NSUInteger)daysBetween:(NSDate *)otherDate;

@property (NS_NONATOMIC_IOSONLY, getter=isToday, readonly) BOOL today;
@property (NS_NONATOMIC_IOSONLY, getter=isExpired, readonly) BOOL expired;
- (BOOL)isOlderThanInSeconds:(NSInteger)secondsAgo;
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger secondsUntil;
+ (NSString*)prettyTextFromSeconds:(NSInteger)seconds;
+ (NSMutableAttributedString*)prettyAttributedFromSeconds:(NSInteger)seconds includeSeconds:(BOOL)includeSeconds;
+ (NSString*)scientificStringFromSeconds:(NSInteger)seconds;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *prettyTimeString;
- (NSString*)iso;

- (NSDate*)minuteRoundedUpByThreshold:(NSInteger)minute;

+ (NSDate*)midnightThisMorning;

- (BOOL)isWithinReasonableframeOfDate:(NSDate*)date;
- (BOOL)isWithinTimeFrame:(NSInteger)seconds ofDate:(NSDate*)date;

+ (NSString*)prettyUSTimeFromSeconds:(NSInteger)seconds;

- (NSDictionary*)bookends;

+ (NSString*)simpleDateFormat;

@end