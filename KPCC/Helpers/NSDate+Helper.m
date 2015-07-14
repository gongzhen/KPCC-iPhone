//
//  NSDate+Helper.m
//  
//
//  Created by collaborative
//  GPL v2
//

#import "NSDate+Helper.h"
#import "DesignManager.h"

@implementation NSDate (Helper)

- (BOOL)isExpired {
  return [[self forceMidnight] compare:[[NSDate date] forceMidnight]] == NSOrderedAscending;
}

- (NSInteger)daysAgo {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:(NSDayCalendarUnit) fromDate:self toDate:[NSDate date]options:0];
  NSInteger diff = [components day];
	return diff;
}

- (NSUInteger)daysBetween:(NSDate *)otherDate {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateFormatter *mdf = [[NSDateFormatter alloc] init];
	[mdf setDateFormat:@"yyyy-MM-dd"];
	NSDate *midnight = [mdf dateFromString:[mdf stringFromDate:self]];
	NSDateComponents *components = [calendar components:(NSDayCalendarUnit) fromDate:midnight toDate:otherDate options:0];
	return [components day];
}

- (NSUInteger)daysBetweenSimple:(NSDate *)otherDate {
	NSDateComponents *components = [[NSCalendar currentCalendar]
                                  components:(NSDayCalendarUnit) 
                                  fromDate:self toDate:otherDate options:0];
	return [components day];
}

- (NSUInteger)daysAgoAgainstMidnight {
	// get a midnight version of ourself:
	NSDateFormatter *mdf = [[NSDateFormatter alloc] init];
	[mdf setDateFormat:@"yyyy-MM-dd"];
	NSDate *midnight = [mdf dateFromString:[mdf stringFromDate:self]];
	
	return (int)[midnight timeIntervalSinceNow] / (60*60*24) *-1;
}

- (NSDate*)minuteRoundedUpByThreshold:(NSInteger)minute {
    NSDateComponents *time = [[NSCalendar currentCalendar]
                              components:( NSCalendarUnitYear | NSCalendarUnitWeekOfYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute )
                              fromDate:self];
    
    NSInteger minutes = [time minute];
    float minuteUnit = ceil((float) minutes / (CGFloat)minute*1.0);
    minutes = minuteUnit * (minute*1.0);
    [time setMinute: minutes];
    [time setSecond:0];
    return [[NSCalendar currentCalendar] dateFromComponents:time];
}

- (NSString *)stringDaysAgo {
	return [self stringDaysAgoAgainstMidnight:YES];
}
   
   
- (NSDate*)forceMidnight {
    NSDateComponents *offsetComponents = [[NSCalendar currentCalendar] components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) 
                                                                          fromDate:self];
    [offsetComponents setHour:0];
    [offsetComponents setMinute:0];
    [offsetComponents setSecond:0];
     
    return [[NSCalendar currentCalendar] dateFromComponents:offsetComponents];
}

- (NSString *)stringDaysAgoAgainstMidnight:(BOOL)flag {
	NSUInteger daysAgo = (flag) ? [self daysAgoAgainstMidnight] : [self daysAgo];
	NSString *text = nil;
	switch (daysAgo) {
		case 0:
			text = NSLocalizedString(@"Localized.today",@"Localized.today");
			break;
		case 1:
			text = @"Yesterday";
			break;
		default:
			text = [NSString stringWithFormat:@"%lu days ago", (unsigned long)daysAgo];
	}
	return text;
}

- (NSDate*)lastDayOfMonth {
  NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit
                                                            fromDate:self];
  [comps setMonth:[comps month]+1];
  [comps setDay:1];
  NSDate *nextMonth = [[NSCalendar currentCalendar] dateFromComponents:comps];
  
  NSDateComponents *lastDay = [[NSCalendar currentCalendar] components:NSYearCalendarUnit|NSDayCalendarUnit|NSMonthCalendarUnit
                                                              fromDate:nextMonth];
  [lastDay setDay:[lastDay day]-1];
  return [[NSCalendar currentCalendar] dateFromComponents:lastDay];
}

- (NSUInteger)weekday {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *weekdayComponents = [calendar components:(NSWeekdayCalendarUnit) fromDate:self];
	return [weekdayComponents weekday];
}

- (NSInteger)secondsUntil {
  
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSTimeInterval this = [self timeIntervalSince1970];
  return (NSInteger)this - now;
}

- (NSString*)prettyCompare:(NSDate*)date {
  NSTimeInterval diff = [date timeIntervalSinceDate:self];
  NSInteger minutes = ceil(diff/60.0);
  NSString *noun = @"days";
  if ( minutes > 59 ) {
    NSInteger hours = ceil(minutes/60.0);
    if ( hours > 23 ) {
      NSInteger days = ceil(hours/24.0);
      if ( days == 1 ) {
        noun = @"day";
      }
      return [NSString stringWithFormat:@"%ld %@ ago",(long)days,noun];
    } else {
      
      NSString *adjective = @"";
      if ( hours == 1 ) {
        adjective = @"An";
        noun = @"hour";
      } else {
        adjective = [NSString stringWithFormat:@"%ld",(long)hours];
        noun = @"hours";
      }
      
      
      return [NSString stringWithFormat:@"%@ %@ ago",adjective,noun];
    }
  } else {
    
    NSString *adjective = @"";
    if ( minutes == 1 ) {
      adjective = @"A";
      noun = @"minute";
    } else {
      adjective = [NSString stringWithFormat:@"%ld",(long)minutes];
      noun = @"minutes";
    }
    return  [NSString stringWithFormat:@"%@ %@ ago",adjective,noun];
  }
  
  return @"A minute ago";
  
}

+ (NSString*)prettyTextFromSeconds:(NSInteger)seconds {
    
    if ( seconds < 60 ) return @"LESS THAN A MINUTE";
    
    NSInteger minutes = ceil(seconds/60);
    NSInteger hours = 0;
    if ( minutes > 59 ) {
        hours = ceil(minutes/60);
        minutes = minutes % 60;
    }
    
    NSString *minuteNoun = nil;
    NSString *hourStatement = @"";
    NSString *minStatement = @"";
    if ( hours > 0 ) {
        if ( hours == 1 ) {
            hourStatement = [NSString stringWithFormat:@"%ld HR ",(long)hours];
        } else {
            hourStatement = [NSString stringWithFormat:@"%ld HRS ",(long)hours];
        }
        minuteNoun = @"MIN";
    } else {
        minuteNoun = @"MINUTE";
    }
    
    if ( minutes > 0 ) {
        if ( minutes > 1 ) {
            minuteNoun = [minuteNoun stringByAppendingString:@"S"];
        }
        minStatement = [NSString stringWithFormat:@"%ld %@",(long)minutes,minuteNoun];
    }
    
    return [NSString stringWithFormat:@"%@%@",hourStatement,minStatement];
    
}

+ (NSMutableAttributedString*)prettyAttributedFromSeconds:(NSInteger)seconds includeSeconds:(BOOL)includeSeconds {

    NSInteger minutes = ceil(seconds/60);
    NSInteger hours = 0;
    if ( minutes > 59 ) {
        hours = ceil(minutes/60);
        minutes = minutes % 60;
    }
    
    NSString *minuteNoun = nil;
    NSString *hourStatement = @"";
    NSString *minStatement = @"";
    if ( hours > 0 ) {
        if ( hours == 1 ) {
            hourStatement = [NSString stringWithFormat:@"%ld hr ",(long)hours];
        } else {
            hourStatement = [NSString stringWithFormat:@"%ld hr ",(long)hours];
        }
        minuteNoun = @"min";
    } else {
        minuteNoun = @"min";
    }
    
    if ( minutes > 0 ) {
        if ( minutes > 1 ) {
            //minuteNoun = [minuteNoun stringByAppendingString:@"S"];
        }
        minStatement = [NSString stringWithFormat:@"%ld %@",(long)minutes,minuteNoun];
    }
    

    NSString *complet = [NSString stringWithFormat:@"%@%@",hourStatement,minStatement];
    if ( includeSeconds ) {
        NSInteger leftovers = seconds % 60;
        NSString *addSec = [NSString stringWithFormat:@"%ld sec",(long)leftovers];
        complet = [complet stringByAppendingFormat:@" %@",addSec];
    }
    NSMutableAttributedString *completeAtt = [[NSMutableAttributedString alloc] initWithString:complet
                                                                                    attributes:@{ NSFontAttributeName : [[DesignManager shared] proLight:48.0f],
                                                                                                  NSForegroundColorAttributeName : [UIColor whiteColor] }];
    NSRange hourRange = [complet rangeOfString:@"hr"];
    if ( hourRange.location != NSNotFound ) {
        [completeAtt addAttributes:@{ NSFontAttributeName : [[DesignManager shared] proLight:26.0f] }
                             range:hourRange];
    }
    
    NSRange minRange = [complet rangeOfString:@"min"];
    if ( minRange.location != NSNotFound ) {
        [completeAtt addAttributes:@{ NSFontAttributeName : [[DesignManager shared] proLight:26.0f] }
                             range:minRange];
    }
    
    NSRange secRange = [complet rangeOfString:@"sec"];
    if ( secRange.location != NSNotFound ) {
        [completeAtt addAttributes:@{ NSFontAttributeName : [[DesignManager shared] proLight:26.0f] }
                             range:secRange];
    }
    return completeAtt;
}

- (NSDictionary*)bookends {
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitDay|NSCalendarUnitSecond|NSCalendarUnitMonth|NSCalendarUnitYear|NSCalendarUnitWeekOfYear
                                                              fromDate:self];
    
    NSInteger originalMinute = [comps minute];
    [comps setSecond:0];
    [comps setMinute:0];
    
    NSDate *top = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    if ( originalMinute < 30 ) {
        [comps setMinute:30];
    } else {
        [comps setMinute:59];
    }
    
    NSDate *bottom = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    return @{ @"top" : top,
              @"bottom" : bottom };
    
}

+ (NSString*)prettyUSTimeFromSeconds:(NSInteger)seconds {
    NSInteger minutes = ceil(seconds/60);
    NSInteger hours = 0;
    if ( minutes > 59 ) {
        hours = ceil(minutes/60);
        minutes = minutes % 60;
    }
    
    NSString *hoursFormatted = @"";
    if ( hours < 10 ) {
        hoursFormatted = [NSString stringWithFormat:@"0%ld",(long)hours];
    } else {
        hoursFormatted = [NSString stringWithFormat:@"%ld",(long)hours];
    }
    
    NSString *minutesFormatted = @"";
    if ( minutes < 10 ) {
        minutesFormatted = [NSString stringWithFormat:@"0%ld",(long)minutes];
    } else {
        minutesFormatted = [NSString stringWithFormat:@"%ld",(long)minutes];
    }
    
    NSString *europe = [NSString stringWithFormat:@"%@:%@",hoursFormatted,minutesFormatted];
    NSLog(@"Raw time : %@",europe);
    
    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    [inputFormatter setDateFormat:@"HH:mm"];
    NSDate *europeanDate = [inputFormatter dateFromString:europe];
    
    NSString *usDateString = [NSDate stringFromDate:europeanDate
                                         withFormat:@"hh:mm a"];
    
    NSLog(@"US : %@",usDateString);
    
    return usDateString;
}

+ (NSDate*)midnightThisMorning {
    NSDate *now = [NSDate date];
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitYear
                                                              fromDate:now];
    NSDate *midnight = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    NSLog(@"Midnight : %@",[NSDate stringFromDate:midnight
                                       withFormat:@"MM/dd/yyyy hh:mm a"]);
    
    return midnight;
}

+ (NSString*)scientificStringFromSeconds:(NSInteger)seconds {
    NSInteger minutes = ceil(seconds/60);
    NSInteger hours = 0;
    if ( minutes > 59 ) {
        hours = ceil(minutes/60);
        minutes = minutes % 60;
    }
    
    NSString *hourStatement = @"";
    NSString *minStatement = @"";
    if ( hours > 0 ) {
        hourStatement = [NSString stringWithFormat:@"%ld:",(long)hours];
    }
 
    minStatement = [NSString stringWithFormat:@"%ld",(long)minutes];
    
    if ( hours > 0 && minutes < 10 ) {
        minStatement = [NSString stringWithFormat:@"0%ld",(long)minutes];
    }
    
    
    NSString *complet = [NSString stringWithFormat:@"%@%@",hourStatement,minStatement];
    NSInteger leftovers = seconds % 60;
    
    
    NSString *addSec = [NSString stringWithFormat:@":%ld",(long)leftovers];
    if ( leftovers < 10 ) {
        addSec = [NSString stringWithFormat:@":0%ld",(long)leftovers];
    }
    complet = [complet stringByAppendingFormat:@"%@",addSec];
    
    return complet;
}



- (BOOL)isWithinReasonableframeOfDate:(NSDate *)date {
    return [self isWithinTimeFrame:60*30 ofDate:date];
}

- (BOOL)isWithinTimeFrame:(NSInteger)seconds ofDate:(NSDate *)date {
    if ( fabs([date timeIntervalSince1970] - [self timeIntervalSince1970]) <= seconds ) {
        return YES;
    }
    
    return NO;
}

- (NSString*)prettyTimeString {
    return [NSDate stringFromDate:self
                       withFormat:[NSDate dbFormatString]];
}

- (BOOL)isYesterday {
  
  if ( [self daysAgoAgainstMidnight] > 1 ) {
    return NO;
  }
  
  NSDate *now = [NSDate date];
  if ( [self earlierDate:now] == now ) {
    return NO;
  }
  
  NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit
                                  fromDate:self];
  NSDateComponents *today = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit
                                                            fromDate:now];
  
  NSInteger myDay = [components day];
  NSInteger todayDay = [today day];
  
  return myDay != todayDay;
  
}

- (NSString*)iso {
    return [NSDate stringFromDate:self
                       withFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
}

+ (NSString *)dbFormatString {
	return @"yyyy-MM-dd HH:mm:ss";
}

+ (NSDate *)dateFromString:(NSString *)string {
    return [NSDate dateFromString:string withFormat:[NSDate dbFormatString]];
}

+ (NSDate*)dateFromString:(NSString *)string withFormat:(NSString*)format {
    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    [inputFormatter setDateFormat:format];
    NSDate *date = [inputFormatter dateFromString:string];
    return date;
}

+ (NSString *)stringFromDate:(NSDate *)date withFormat:(NSString *)format {
	NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
	[outputFormatter setDateFormat:format];
 
	NSString *timestamp_str = [outputFormatter stringFromDate:date];
  
  
	return timestamp_str;
}

+ (NSString *)stringFromDate:(NSDate *)date {
	return [NSDate stringFromDate:date withFormat:[NSDate dbFormatString]];
}

+ (NSString *)stringForDisplayFromDate:(NSDate *)date prefixed:(BOOL)prefixed {
	/* 
	 * if the date is in today, display 12-hour time with meridian,
	 * if it is within the last 7 days, display weekday name (Friday)
	 * if within the calendar year, display as Jan 23
	 * else display as Nov 11, 2008
	 */
	
	NSDate *today = [NSDate date];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *offsetComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) 
													 fromDate:today];
	
	NSDate *midnight = [calendar dateFromComponents:offsetComponents];
	
	NSDateFormatter *displayFormatter = [[NSDateFormatter alloc] init];
	NSString *displayString = nil;
	
	// comparing against midnight
	if ([date compare:midnight] == NSOrderedDescending) {
		if (prefixed) {
			[displayFormatter setDateFormat:@"'at' h:mm a"]; // at 11:30 am
		} else {
			[displayFormatter setDateFormat:NSLocalizedString(@"Localized.timeformat",@"")]; // 11:30 am
		}
	} else {
		// check if date is within last 7 days
		NSDateComponents *componentsToSubtract = [[NSDateComponents alloc] init];
		[componentsToSubtract setDay:-7];
		NSDate *lastweek = [calendar dateByAddingComponents:componentsToSubtract toDate:today options:0];
		if ([date compare:lastweek] == NSOrderedDescending) {
			[displayFormatter setDateFormat:@"EEEE"]; // Tuesday
		} else {
			// check if same calendar year
			NSInteger thisYear = [offsetComponents year];
			
			NSDateComponents *dateComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) 
														   fromDate:date];
			NSInteger thatYear = [dateComponents year];			
			if (thatYear >= thisYear) {
				[displayFormatter setDateFormat:@"MMM dd"];
			} else {
				[displayFormatter setDateFormat:NSLocalizedString(@"Localized.dateformat",@"")];
			}
		}
		if (prefixed) {
			NSString *dateFormat = [displayFormatter dateFormat];
			NSString *prefix = @"'on' ";
			[displayFormatter setDateFormat:[prefix stringByAppendingString:dateFormat]];
		}
	}
	
	// use display formatter to return formatted date string
	displayString = [displayFormatter stringFromDate:date];
	return displayString;
}

- (BOOL)isOlderThanInSeconds:(NSInteger)secondsAgo {
  NSTimeInterval me = [self timeIntervalSince1970];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  return now - me > secondsAgo;
}

+ (NSString *)stringForDisplayFromDate:(NSDate *)date {
	return [self stringForDisplayFromDate:date prefixed:NO];
}

- (NSDate*) dateChangedBy:(NSInteger)days {
  NSDateComponents *comps = [[NSCalendar currentCalendar]
                             components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit
                             fromDate:self];
  [comps setDay:[comps day]+days];
  return [[NSCalendar currentCalendar] dateFromComponents:comps] ;
}

- (NSDate *)beginningOfWeek {
	// largely borrowed from "Date and Time Programming Guide for Cocoa"
	// we'll use the default calendar and hope for the best
	
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *beginningOfWeek = nil;
	BOOL ok = [calendar rangeOfUnit:NSWeekCalendarUnit startDate:&beginningOfWeek
						   interval:NULL forDate:self];
	if (ok) {
		return beginningOfWeek;
	} 
	
	// couldn't calc via range, so try to grab Sunday, assuming gregorian style
	// Get the weekday component of the current date
	NSDateComponents *weekdayComponents = [calendar components:NSWeekdayCalendarUnit fromDate:self];
	
	/*
	 Create a date components to represent the number of days to subtract from the current date.
	 The weekday value for Sunday in the Gregorian calendar is 1, so subtract 1 from the number of days to subtract from the date in question.  (If today's Sunday, subtract 0 days.)
	 */
	NSDateComponents *componentsToSubtract = [[NSDateComponents alloc] init];
	[componentsToSubtract setDay: 0 - ([weekdayComponents weekday] - 1)];
	beginningOfWeek = nil;
	beginningOfWeek = [calendar dateByAddingComponents:componentsToSubtract toDate:self options:0];
	
	//normalize to midnight, extract the year, month, and day components and create a new date from those components.
	NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
											   fromDate:beginningOfWeek];
	return [calendar dateFromComponents:components];
}

- (NSDate *)beginningOfDay {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	// Get the weekday component of the current date
	NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) 
											   fromDate:self];
	return [calendar dateFromComponents:components];
}

- (NSDate *)endOfWeek {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	// Get the weekday component of the current date
	NSDateComponents *weekdayComponents = [calendar components:NSWeekdayCalendarUnit fromDate:self];
	NSDateComponents *componentsToAdd = [[NSDateComponents alloc] init];
	// to get the end of week for a particular date, add (7 - weekday) days
	[componentsToAdd setDay:(7 - [weekdayComponents weekday])];
	NSDate *endOfWeek = [calendar dateByAddingComponents:componentsToAdd toDate:self options:0];
	
	return endOfWeek;
}

- (BOOL)isToday {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
    NSDate *today = [cal dateFromComponents:components];
    
    components = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:self];
    
    NSDate *thisDate = [cal dateFromComponents:components];
    
    return [thisDate isEqualToDate:today];
}

@end