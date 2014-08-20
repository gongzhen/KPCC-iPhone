//
//  Utils.m
//  KPCC
//
//  Created by John Meeker on 6/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Utils.h"

@implementation Utils

+ (NSDate*)dateFromRFCString:(NSString*)dateString {
    if ([dateString isEqual:[NSNull null] ]) {
        return nil;
    }
    
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc]init];
    [rfc3339DateFormatter setDateFormat:@"yyyy-MM-dd'T'HHmmssZZZ"];
    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    dateString = [dateString stringByReplacingOccurrencesOfString:@":" withString:@""];
    
    // Convert the RFC 3339 date time string to an NSDate.
    NSDate *date = [rfc3339DateFormatter dateFromString:dateString];
    if (!date) {
        [rfc3339DateFormatter setDateFormat:@"yyyy-MM-dd'T'HHmmss.000ZZZ"];
        return [rfc3339DateFormatter dateFromString:dateString];
    }
    return date;
}

+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate {
    NSDate *date = [self dateFromRFCString:rawDate];
    return [self prettyStringFromRFCDate:date];
}

+ (NSString*)prettyStringFromRFCDate:(NSDate*)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"h:mm a"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:[[NSTimeZone localTimeZone] secondsFromGMT]]];
    return [dateFormatter stringFromDate:date];
}

+ (BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0))?1:0;
}


/**
 * Date helper functions
 * in Swift
 */
/*
 func dateFromRFCString(dateString: NSString) -> NSDate {
 if (dateString == NSNull()) {
 return NSDate.date();
 }
 
 var rfc3339DateFormatter = NSDateFormatter()
 rfc3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmssZZZ"
 rfc3339DateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
 
 var fixedDateString = dateString.stringByReplacingOccurrencesOfString(":", withString: "")
 
 // Convert the RFC 3339 date time string to an NSDate.
 var date = rfc3339DateFormatter.dateFromString(fixedDateString)
 if (!date) {
 rfc3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmss.000ZZZ"
 return rfc3339DateFormatter.dateFromString(fixedDateString)
 }
 return date;
 }
 
 func prettyStringFromRFCDateString(rawDate: NSString) -> NSString {
 let date = dateFromRFCString(rawDate)
 var outputFormatter = NSDateFormatter()
 outputFormatter.dateFormat = "h:mm a"
 outputFormatter.timeZone = NSTimeZone(forSecondsFromGMT: NSTimeZone.localTimeZone().secondsFromGMT)
 var dateString = outputFormatter.stringFromDate(date)
 return dateString
 }
 
 func prettyStringFromRFCDate(date: NSDate) -> NSString {
 var outputFormatter = NSDateFormatter()
 outputFormatter.dateFormat = "h:mm a"
 outputFormatter.timeZone = NSTimeZone(forSecondsFromGMT: NSTimeZone.localTimeZone().secondsFromGMT)
 var dateString = outputFormatter.stringFromDate(date)
 return dateString
 }
 */

@end
