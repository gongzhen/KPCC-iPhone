//
//  NSError+PrettyAnalytics.m
//  KPCC
//
//  Created by Ben Hochberg on 2/6/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "NSError+PrettyAnalytics.h"

@implementation NSError (PrettyAnalytics)

- (NSString*)prettyAnalytics {
    
    NSString *rv = [self localizedDescription];
    NSDictionary * userInfo = [self userInfo];
    NSString *fullErrorDescription = @"";
    for ( NSString *key in userInfo.allKeys ) {
        fullErrorDescription = [fullErrorDescription stringByAppendingFormat:@"%@ : %@",key,userInfo[key]];
    }
    
    return rv;
}


@end
