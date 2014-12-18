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
@dynamic soft_starts_at;

+ (NSString *)entityName {
    return @"Program";
}


+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context {

    if ( !context ) context = [[ContentManager shared] managedObjectContext];
    
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
            return (Program *)result[0];
        } else {
            NSLog(@"create new Program");
            return (Program *)[NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:context];
        }

    }
    return nil;
}

+ (instancetype)insertProgramWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context {
    
    Program* programObj = nil;
    
    if (dictionary[@"program"] != [NSNull null] && dictionary[@"program"][@"slug"] != [NSNull null]) {
        programObj = [self fetchProgramWithSlug:dictionary[@"program"][@"slug"] fromManagedObjectContext:context];
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
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"program_slug LIKE %@", program[@"slug"]];
            NSArray *matchedArray = [storedRecords filteredArrayUsingPredicate:predicate];

            Program *programObj = nil;

            if ([matchedArray count] == 1) {
                // Update existing Program
                NSLog(@"Update Program - %@", [matchedArray[0] program_slug]);
                programObj = matchedArray[0];
                [self updateProgramObject:programObj withDictionary:program];
            } else if ([matchedArray count] > 1) {
                NSLog(@"UH OH! More than one Program for - %@ - exists in CoreData", [matchedArray[0] program_slug]);
            } else {
                // Creating new Program
                NSLog(@"Create new Program - %@",  program[@"slug"]);
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
                if (![Utils pureNil:apiProgram[@"slug"]] && [apiProgram[@"slug"] isEqualToString:storedProgram.program_slug]) {
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
    if ( ![Utils pureNil:dictionary[@"program"]]) {

        if ( ![Utils pureNil:dictionary[@"title"]]) {
            program.title = dictionary[@"title"];
        }

        if ( ![Utils pureNil:dictionary[@"program"][@"slug"]]) {
            program.program_slug = dictionary[@"program"][@"slug"];
        }

        if ( ![Utils pureNil:dictionary[@"starts_at"]]) {
            program.starts_at = [Utils dateFromRFCString:dictionary[@"starts_at"]];
        }

        if ( ![Utils pureNil:dictionary[@"ends_at"]]) {
            program.ends_at = [Utils dateFromRFCString:dictionary[@"ends_at"]];
        }

        if ( ![Utils pureNil:dictionary[@"public_url"]]) {
            program.public_url = dictionary[@"public_url"];
        }
        if ( ![Utils pureNil:dictionary[@"soft_starts_at"]] ) {
            program.soft_starts_at = [Utils dateFromRFCString:dictionary[@"soft_starts_at"]];
        }

    } else {
        if ( ![Utils pureNil:dictionary[@"title"]]) {
            program.title = dictionary[@"title"];
        }

        if ( ![Utils pureNil:dictionary[@"slug"]]) {
            program.program_slug = dictionary[@"slug"];
        }
        
        if ( ![Utils pureNil:dictionary[@"public_url"]]) {
            program.public_url = dictionary[@"public_url"];
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
            return (Program *)result[0];
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
    NSArray *result = nil;
    
    @try {
        result = [context executeFetchRequest:request error:&error];
    }
    @catch (NSException *exception) {
        NSLog(@"Problem with coreData");
    }
    @finally {
        
    }

    if (result == nil) {
        NSLog(@"fetch result = nil");
    } else if ([result count] > 1) {
        NSLog(@"more than one unique result for '%@' slug found", slug);
    } else if ([result count] == 0) {
        NSLog(@"no results with '%@' slug found", slug);
    } else {
        NSLog(@"one result for '%@' slug found", slug);
        return (Program *)result[0];
    }

    return nil;
}

@end
