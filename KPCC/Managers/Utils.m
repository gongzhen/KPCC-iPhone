//
//  Utils.m
//  KPCC
//
//  Created by John Meeker on 6/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>
#import "AudioManager.h"

static char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation Utils
+ (NSDictionary*)globalConfig {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    NSDictionary *globalConfig = [[NSDictionary alloc] initWithContentsOfFile:path];
    return globalConfig;
}

+ (SCPRAppDelegate*)del {
    return (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
}

+ (id)xib:(NSString *)name {
    
    NSArray *objects = [[NSBundle mainBundle] loadNibNamed:name
                                                     owner:nil
                                                   options:nil];
    return objects[0];
    
}

+ (CGFloat)degreesToRadians:(CGFloat) degrees {
    return degrees * M_PI / 180.0f;
}

+ (CGFloat)radiansToDegrees:(CGFloat)radians {
    return radians * 180 / M_PI;
}

+ (NSString*)formatOfInterestFromDate:rawDate startDate:(BOOL)startDate gapped:(BOOL)gapped {
    
    NSDateComponents *startComps = [[NSCalendar currentCalendar] components:NSCalendarUnitMinute
                                                                   fromDate:rawDate];
    NSString *dFmt = @"";
    if ( [startComps minute] == 0 ) {
        dFmt = @"h";
    } else {
        dFmt = @"h:mm";
    }
    
    if ( !startDate ) {
        if ( gapped ) {
            dFmt = [dFmt stringByAppendingString:@" a"];
        } else {
            dFmt = [dFmt stringByAppendingString:@"a"];
        }
    }
    
    return dFmt;
}

+ (NSString*)formatOfInterestFromDate:rawDate startDate:(BOOL)startDate {
    return [Utils formatOfInterestFromDate:rawDate startDate:startDate gapped:YES];
}

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

+ (BOOL)validateEmail:(NSString *)string {
    if ( !string || [string isEqualToString:@""] ) {
        return NO;
    }
    
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:string];
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

+ (NSString*)episodeDateStringFromRFCDate:(NSDate *)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM d, yyyy"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:[[NSTimeZone localTimeZone] secondsFromGMT]]];
    return [dateFormatter stringFromDate:date];
}

+ (NSString*)elapsedTimeStringWithPosition:(double)position andDuration:(double)duration {
    int positionSeconds = position,
        positionMinutes = position/60,
        positionHours   = position/3600;

    int durationSeconds = duration,
        durationMintues = duration/60,
        durationHours   = duration/3600;

    positionSeconds = positionSeconds - positionMinutes*60;
    positionMinutes = positionMinutes - positionHours*60;

    durationSeconds = durationSeconds - durationMintues*60;
    durationMintues = durationMintues - durationHours*60;

    NSString *positionHr, *positionMin, *positionSec, *durationHr, *durationMin , *durationSec;

    positionHr  = positionHours > 9 ? [NSString stringWithFormat:@"%d",positionHours] : [NSString stringWithFormat:@"%d",positionHours];
    positionMin = positionMinutes > 9 ? [NSString stringWithFormat:@"%d",positionMinutes] : [NSString stringWithFormat:@"0%d",positionMinutes];
    positionSec = positionSeconds > 9 ? [NSString stringWithFormat:@"%d",positionSeconds] : [NSString stringWithFormat:@"0%d",positionSeconds];

    durationHr  = durationHours > 9 ? [NSString stringWithFormat:@"%d",durationHours] : [NSString stringWithFormat:@"%d",durationHours];
    durationMin = durationMintues > 9 ? [NSString stringWithFormat:@"%d",durationMintues] : [NSString stringWithFormat:@"0%d",durationMintues];
    durationSec = durationSeconds > 9 ? [NSString stringWithFormat:@"%d",durationSeconds] : [NSString stringWithFormat:@"0%d",durationSeconds];

    NSString *ret;
    if (durationHours > 0) {
        ret = [NSString stringWithFormat:@"%@:%@:%@ / %@:%@:%@", positionHr,positionMin,positionSec,durationHr,durationMin,durationSec];
    } else {
        ret = [NSString stringWithFormat:@"%@:%@ / %@:%@", positionMin,positionSec,durationMin,durationSec];
    }

    return ret;
}

+ (BOOL)pureNil:(id)object {
    if (!object) {
        return YES;
    }
    if (object == nil) {
        return YES;
    }
    if (object == [NSNull null]) {
        return YES;
    }
    return NO;
}

+ (BOOL)isIOS8 {
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        return NO;
    }
    
    return YES;
}

+ (NSDictionary*)gConfig {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    NSDictionary *globalConfig = [[NSDictionary alloc] initWithContentsOfFile:path];
    return globalConfig;
}

+ (BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0))?1:0;
}

+ (BOOL)isThreePointFive {
    return [[UIScreen mainScreen] bounds].size.height < 568.0f;
}

+(NSString *)base64:(NSData *)input {
    unsigned long encodedLength = (((([input length] % 3) + [input length]) / 3) * 4) + 1;
    unsigned char *outputBuffer = malloc(encodedLength);
    unsigned char *inputBuffer = (unsigned char *)[input bytes];
    
    NSInteger i;
    NSInteger j = 0;
    unsigned long remain;
    
    for(i = 0; i < [input length]; i += 3) {
        remain = [input length] - i;
        
        outputBuffer[j++] = alphabet[(inputBuffer[i] & 0xFC) >> 2];
        outputBuffer[j++] = alphabet[((inputBuffer[i] & 0x03) << 4) |
                                     ((remain > 1) ? ((inputBuffer[i + 1] & 0xF0) >> 4): 0)];
        
        if(remain > 1)
            outputBuffer[j++] = alphabet[((inputBuffer[i + 1] & 0x0F) << 2)
                                         | ((remain > 2) ? ((inputBuffer[i + 2] & 0xC0) >> 6) : 0)];
        else
            outputBuffer[j++] = '=';
        
        if(remain > 2)
            outputBuffer[j++] = alphabet[inputBuffer[i + 2] & 0x3F];
        else
            outputBuffer[j++] = '=';
    }
    
    outputBuffer[j] = 0;
    
    NSString *result = @((const char*)outputBuffer);
    free(outputBuffer);
    
    return result;
}

+ (NSString*)sha1:(NSString*)input {
    
    input = [NSString stringWithFormat:@"%@",input];
    
    
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

+ (id)loadJson:(NSString *)json {
    NSError *jsonError = nil;
    NSString *path = @"";
    if ( [json rangeOfString:@".json"].location != NSNotFound ) {
        path = [[NSBundle mainBundle] pathForResource:json
                                               ofType:@""];
    } else {
        path = [[NSBundle mainBundle] pathForResource:json
                                               ofType:@"json"];
    }
    
    NSString *jsonString = [[NSString alloc] initWithContentsOfFile:path
                                                           encoding:NSUTF8StringEncoding
                                                              error:&jsonError];
    if ( jsonError ) {
        return nil;
    }
    
    NSData *d = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    id item = [NSJSONSerialization JSONObjectWithData:d
                                              options:0
                                                error:&jsonError];
    
    if ( jsonError ) {
        return nil;
    }
    
    return item;
}

+ (NSString*)rawJson:(id)object {
    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
    if ( jsonError ) {
        return @"";
    }
    
    return [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
}

+ (NSString*)prettyVersion {

    return [NSString stringWithFormat:@"%@ build %@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];

}

+ (NSString*)urlSafeVersion {
    NSString *u = [NSString stringWithFormat:@"%@ %@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    u = [u stringByReplacingOccurrencesOfString:@" "
                                     withString:@"-"];
    return u;
}

+ (NSDictionary*)accessLogToDictionary:(AVPlayerItemAccessLog*)accessLog {
    NSString *logAsString = [[NSString alloc] initWithData:[accessLog extendedLogData]
                                                  encoding:[accessLog extendedLogDataStringEncoding]];
    
    if ( !logAsString ) {
        return nil;
    }
    
    NSRange r = [logAsString rangeOfString:@"#Fields: "];
    if ( r.location == NSNotFound ) {
        return nil;
    }
    
    logAsString = [logAsString substringFromIndex:r.location+r.length];
    
    NSArray *components = [logAsString componentsSeparatedByString:@" "];
    NSArray *potentialComponents = [Utils reversedArrayFromArray:[kPotentialElements componentsSeparatedByString:@" "]];
    
    NSInteger lastIndex = -1;
    for ( unsigned i = 0; i < [potentialComponents count]; i++ ) {
        NSString *pC = potentialComponents[i];
        for ( unsigned j = 0; j < [components count]; j++ ) {
            if ( SEQ(components[j], pC) ) {
                lastIndex = i;
                break;
            }
        }
    }
    
    NSMutableDictionary *neat = [NSMutableDictionary new];
    if ( lastIndex > 0 ) {
        for ( unsigned k = 0; k < lastIndex+1; k++ ) {
            neat[potentialComponents[k]] = components[k+lastIndex];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:neat];
    //return [NSDictionary new];
}

+ (NSDictionary*)errorLogToDictionary:(AVPlayerItemAccessLog *)errorLog {
    /*NSString *logAsString = [[NSString alloc] initWithData:[errorLog extendedLogData]
                                                  encoding:[errorLog extendedLogDataStringEncoding]];
    NSArray *components = [logAsString componentsSeparatedByString:@" "];
    NSArray *potentialComponents = [Utils reversedArrayFromArray:[kPotentialElements componentsSeparatedByString:@" "]];
    
    NSInteger lastIndex = -1;
    for ( unsigned i = 0; i < [potentialComponents count]; i++ ) {
        NSString *pC = potentialComponents[i];
        for ( unsigned j = 0; j < [components count]; j++ ) {
            if ( SEQ(components[j], pC) ) {
                lastIndex = i;
                break;
            }
        }
    }
    
    NSMutableDictionary *neat = [NSMutableDictionary new];
    if ( lastIndex > 0 ) {
        for ( unsigned k = 0; k < lastIndex+1; k++ ) {
            neat[potentialComponents[k]] = components[k+lastIndex];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:neat];*/
    return [NSDictionary new];
}


+ (NSArray*)reversedArrayFromArray:(NSArray *)inOrder {

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[inOrder count]];
    NSEnumerator *enumerator = [inOrder reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;

}

+ (void)crash {
    [NSException raise:NSGenericException format:@"Everything is ok. This is just a test crash."];
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
