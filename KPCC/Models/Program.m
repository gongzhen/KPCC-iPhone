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
@dynamic program_slug;

+ (NSString *)entityName {
    return @"Program";
}

+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context {

    // Find or Create new Program
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
}

+ (instancetype)findOrCreateProgram:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context {

    if ([[dictionary objectForKey:@"program"] objectForKey:@"slug"]) {
        [self fetchProgramWithSlug:[[dictionary objectForKey:@"program"] objectForKey:@"slug"] fromManagedObjectContext:context];
    }
    

    return nil;
}

+ (instancetype)insertProgramWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context {
    
    Program* programObj = nil;
    
    NSArray *storedRecords = [self fetchAllProgramsInContext:context];
    if ([storedRecords count] != 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"program_slug LIKE %@", [[dictionary objectForKey:@"program"] objectForKey:@"slug"]];
        NSArray *matchedArray = [storedRecords filteredArrayUsingPredicate:predicate];

        if ([matchedArray count] > 0) {
            // Update existing Program
            NSLog(@"Update Program");
            programObj = [matchedArray objectAtIndex:0];
        } else {
            // Creating new Program
            NSLog(@"Create new Program");
            programObj = (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
        }
    } else {
        // Import initial Program
        NSLog(@"Importing initial");
        
        programObj = (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
    }

    return [self updateProgramObject:programObj withDictionary:dictionary];
}

+ (instancetype)updateProgramObject:(Program *)program withDictionary:(NSDictionary *)dictionary {

    if ([dictionary objectForKey:@"title"]) {
        program.title = [dictionary objectForKey:@"title"];
    }

    if ([[dictionary objectForKey:@"program"] objectForKey:@"slug"]) {
        program.program_slug = [[dictionary objectForKey:@"program"] objectForKey:@"slug"];
    }

    return program;
}

+ (instancetype)fetchObjectFromContext:(NSManagedObjectContext *)context {

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

+ (NSArray *)fetchAllProgramsInContext:(NSManagedObjectContext *)context {

    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];
    
    if (result == nil) {
        NSLog(@"fetch result = nil");
        // Handle the error here
    } else {
        if ([result count] > 0) {
            NSLog(@"CoreData has %lu Programs", (unsigned long)[result count]);
            return result;
        }
    }
    
    // No Programs exist in CoreData
    return nil;
}

+ (instancetype)fetchProgramWithSlug:(NSString *)slug fromManagedObjectContext:(NSManagedObjectContext *)context {

    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    [request setPredicate:[NSPredicate predicateWithFormat:@"program_slug LIKE %@", slug]];

    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];

    if (result == nil) {
        NSLog(@"fetch result = nil");
    } else if ([result count] > 1) {
        NSLog(@"more than one unique result for '%@' slug found", slug);
    } else if ([result count] == 0) {
        NSLog(@"no results with '%@' slug found", slug);
    } else {
        NSLog(@"one result for '%@' slug found", slug);
        return (Program *)[result objectAtIndex:0];
    }

    // Not found
    return nil;
}

@end
