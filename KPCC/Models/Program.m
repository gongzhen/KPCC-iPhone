//
//  Program.m
//  KPCC
//
//  Created by John Meeker on 6/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Program.h"
#import "Utils.h"


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

+ (instancetype)insertProgramWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context {
    
    Program* programObj = nil;
    
    if ([dictionary objectForKey:@"program"] != [NSNull null] && [[dictionary objectForKey:@"program"] objectForKey:@"slug"] != [NSNull null]) {
        programObj = [self fetchProgramWithSlug:[[dictionary objectForKey:@"program"] objectForKey:@"slug"] fromManagedObjectContext:context];
    }

    if (programObj == nil) {
        NSLog(@"Create new Program with Dictionary");
        programObj = (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
    }

    return [self updateProgramObject:programObj withDictionary:dictionary];
}

+ (void)insertProgramsWithArray:(NSArray *)array inManagedObjectContext:(NSManagedObjectContext *)context {

    if (!array || [array count] == 0) {
        return;
    }

    NSArray *storedRecords = [self fetchAllProgramsInContext:context];

    NSLog(@"Inserting/Updating %ld Programs into CoreData", (unsigned long)[array count]);
    NSLog(@"Already %ld Programs exist in CoreData", (unsigned long)[storedRecords count]);

    if ([storedRecords count] != 0) {

        for (NSDictionary *program in array) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"program_slug LIKE %@", [program objectForKey:@"slug"]];
            NSArray *matchedArray = [storedRecords filteredArrayUsingPredicate:predicate];

            Program *programObj = nil;

            if ([matchedArray count] == 1) {
                // Update existing Program
                NSLog(@"Update Program - %@", [[matchedArray objectAtIndex:0] program_slug]);
                programObj = [matchedArray objectAtIndex:0];
                [self updateProgramObject:programObj withDictionary:program];
            } else if ([matchedArray count] > 1) {
                NSLog(@"UH OH! More than one Program for - %@ - exists in CoreData", [[matchedArray objectAtIndex:0] program_slug]);
            } else {
                // Creating new Program
                NSLog(@"Create new Program - %@",  [program objectForKey:@"slug"]);
                programObj = (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
                [self updateProgramObject:programObj withDictionary:program];
            }
        }

        /***
         ** Remove old/off-air programs from Core Data.
         ** Handles issue of Program slug changing on our backend, or going offair.
         **
         ** Dev note: Seems like the best place to handle while we have
         ** existing records in CoreData and latest from our API to compare.
         ***/
        for (Program *storedProgram in storedRecords) {
            BOOL foundInApi = NO;
            for (NSDictionary *apiProgram in array) {
                if (![Utils pureNil:[apiProgram objectForKey:@"slug"]] && [[apiProgram objectForKey:@"slug"] isEqualToString:storedProgram.program_slug]) {
                    foundInApi = YES;
                    break;
                }
            }

            if (foundInApi == NO) {
                // NSLog(@"NOT FOUND! %@", storedProgram.program_slug);
                [context deleteObject:storedProgram];
            }
        }

    } else {
        // Import initial Programs
        for (NSDictionary *program in array) {
            Program *programObj = (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
            [self updateProgramObject:programObj withDictionary:program];
        }
    }
}

+ (instancetype)updateProgramObject:(Program *)program withDictionary:(NSDictionary *)dictionary {

    if ([Utils pureNil:program] || [Utils pureNil:dictionary]) {
        return nil;
    }

    /**
     * We have to handle Program dictionaries in two possible forms at this point.
     * One in the form returned from the /schedule endpoint, and one in the form
     * from the /programs endpoint.
     * See SCPRv4 API docs for details - https://github.com/SCPR/api-docs/tree/master/KPCC/v2
     */
    if ( ![Utils pureNil:[dictionary objectForKey:@"program"]]) {

        if ( ![Utils pureNil:[dictionary objectForKey:@"title"]]) {
            program.title = [dictionary objectForKey:@"title"];
        }

        if ( ![Utils pureNil:[[dictionary objectForKey:@"program"] objectForKey:@"slug"]]) {
            program.program_slug = [[dictionary objectForKey:@"program"] objectForKey:@"slug"];
        }

        if ( ![Utils pureNil:[dictionary objectForKey:@"starts_at"]]) {
            program.starts_at = [Utils dateFromRFCString:[dictionary objectForKey:@"starts_at"]];
        }

        if ( ![Utils pureNil:[dictionary objectForKey:@"ends_at"]]) {
            program.ends_at = [Utils dateFromRFCString:[dictionary objectForKey:@"ends_at"]];
        }

        if ( ![Utils pureNil:[dictionary objectForKey:@"public_url"]]) {
            program.public_url = [dictionary objectForKey:@"public_url"];
        }

    } else {
        if ( ![Utils pureNil:[dictionary objectForKey:@"title"]]) {
            program.title = [dictionary objectForKey:@"title"];
        }

        if ( ![Utils pureNil:[dictionary objectForKey:@"slug"]]) {
            program.program_slug = [dictionary objectForKey:@"slug"];
        }
        
        if ( ![Utils pureNil:[dictionary objectForKey:@"public_url"]]) {
            program.public_url = [dictionary objectForKey:@"public_url"];
        }
    }

    // TODO: Add more data fields as necessary.

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

    return nil;
}

@end
