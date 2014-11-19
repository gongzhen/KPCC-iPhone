//
//  UXmanager.m
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UXmanager.h"

@implementation UXmanager
+ (instancetype)shared {
    static UXmanager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [UXmanager new];
        [shared load];
    });
    return shared;
}

- (void)load {
    if ( self.settings ) {
        self.settings = nil;
    }
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"settings"];
    if ( data ) {
        self.settings = (Settings*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        
    } else {
        self.settings = [Settings new];

    }
}

- (void)persist {
    if ( self.settings ) {
    
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.settings];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"settings"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    }
}

@end
