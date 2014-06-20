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

    // Fetch or Create new Program
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];

    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];

    if (result == nil) {
        NSLog(@"fetch result = nil");
        // Handle the error here
    } else {
        if([result count] > 0) {
            NSLog(@"fetch saved Program");
            return (Program *)[result objectAtIndex:0];
        } else {
            NSLog(@"create new Program");
            return (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
        }

    }
    return nil;
    //return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
    //                                     inManagedObjectContext:context];
}

+ (instancetype)fetchObjectFromContext:(NSManagedObjectContext *)context {
    // Fetch or Create new Program
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];
    
    if (result == nil) {
        NSLog(@"fetch result = nil");
        // Handle the error here
    } else {
        if([result count] > 0) {
            NSLog(@"fetch saved Program");
            return (Program *)[result objectAtIndex:0];
        }
    }
    
    // Not found
    return nil;
}

@end
