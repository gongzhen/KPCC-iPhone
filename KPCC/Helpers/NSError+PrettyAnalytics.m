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
    rv = [NSString stringWithFormat:@"%@ - Domain : %@, Code : %ld",rv,self.domain,self.code];
    return rv;
}


@end
