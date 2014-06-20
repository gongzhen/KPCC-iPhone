//
//  Program.m
//  KPCC
//
//  Created by John Meeker on 6/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Program.h"


@implementation Program

@dynamic title;
@dynamic ends_at;
@dynamic starts_at;
@dynamic public_url;
@dynamic is_recurring;
@dynamic program;

+ (NSString *)entityName {
    return @"Program";
}

+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context {
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                         inManagedObjectContext:context];
}

@end
