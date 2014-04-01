//
//  NSDate+Helper.m
//  
//
//  Created by collaborative
//  GPL v2
//

#import "NSDate+Helper.h"

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

+ (NSString *)dbFormatString {
	return @"yyyy-MM-dd HH:mm:ss";
}

+ (NSDate *)dateFromString:(NSString *)string {
	NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
	[inputFormatter setDateFormat:[NSDate dbFormatString]];
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