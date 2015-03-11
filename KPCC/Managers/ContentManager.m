//
//  ContentManager.m
//  KPCC
//
//  Created by John Meeker on 6/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "ContentManager.h"
#import "Bookmark.h"
#import "AudioChunk.h"
#import "UXmanager.h"

static ContentManager *singleton = nil;

@implementation ContentManager

+ (ContentManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[ContentManager alloc] init];
            
            [singleton managedObjectModel];
            [singleton managedObjectContext];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                //[singleton threadedSaveContext:singleton.persistentStoreCoordinator];
            });
        }
    }
    
    return singleton;
}

/**
 * Save changes to the managedObjectContext.
 */
- (void)saveContext {
    if (self.managedObjectContext != nil && [self.managedObjectContext hasChanges]) {
        NSError *error = nil;

        if (![self.managedObjectContext save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Bookmark
- (void)destroyBookmark:(Bookmark *)bookmark {
    [self.managedObjectContext deleteObject:bookmark];
}

- (Bookmark*)bookmarkForAudioChunk:(AudioChunk *)chunk {
    NSString *url = chunk.audioUrl;
    return [self bookmarkForUrl:url];
}

- (Bookmark*)bookmarkForUrl:(NSString *)url {
    NSString *sha = [Utils sha1:url];
    Bookmark *b = [self findBookmarkBySha:sha];
    b.urlPlain = url;
    return b;
}

- (Bookmark*)findBookmarkBySha:(NSString *)shaUrl {
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Bookmark" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    // Set example predicate and sort orderings...
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"urlSha = %@", shaUrl];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    if ( !array || [array count] == 0)
    {
        
        return nil;
        
    } else {
        Bookmark *b = array[0];
        NSLog(@"Bookmark : %@ with resume time of %1.1f",b.audioTitle,[b.resumeTimeInSeconds floatValue]);
    }
    
    return array[0];
}

- (Bookmark*)createBookmarkFromAudioChunk:(AudioChunk *)chunk {
    
    Bookmark *b = [NSEntityDescription insertNewObjectForEntityForName:@"Bookmark"
                                                inManagedObjectContext:self.managedObjectContext];

    b.programTitle = chunk.programTitle;
    b.duration = chunk.audioDuration;
    b.audioTitle = chunk.audioTitle;
    b.createdAt = [NSDate date];
    b.urlPlain = chunk.audioUrl;
    b.urlSha = [Utils sha1:b.urlPlain];
    
    [self saveContext];
    
    return b;
}

- (NSArray*)allBookmarks {
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Bookmark" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error = nil;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    if ( !array || [array count] == 0)
    {
        
        return @[];
        
    }
    
    NSLog(@" >>>>> Found %ld bookmarks ",(long)array.count);
    
    return array;
}

- (void)sweepBookmarks {
    
    NSDate *lastSweep = [[UXmanager shared].settings lastBookmarkSweep];
    if ( !lastSweep || [lastSweep isOlderThanInSeconds:kBookmarkCleaningFrequency] ) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            [self sweepTaskWithCompletion:^(id returnedObject) {
                
                NSArray *expired = (NSArray*)returnedObject;
                NSLog(@"Found %ld expired bookmarks",(long)[expired count]);
                
                for ( Bookmark *b in expired ) {
                    [self destroyBookmark:b];
                }
                [[UXmanager shared].settings setLastBookmarkSweep:[NSDate date]];
                [[UXmanager shared] persist];
                [[ContentManager shared] saveContext];
                
            }];
            
        });
    }
}

- (void)sweepTaskWithCompletion:(CompletionBlockWithValue)completion {
    NSArray *bookmarks = [self allBookmarks];
    NSMutableArray *expired = [[bookmarks filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        Bookmark *b = (Bookmark*)evaluatedObject;
        if ( [[b createdAt] isOlderThanInSeconds:kBookmarkPreservationTolerance] ) {
            return YES;
        }
        
        return NO;
    }]] mutableCopy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(expired);
    });
}

/**
 * Returns the base name of our managed object model.
 */
- (NSString*)modelBase {
    return @"DataModel";
}

/**
 * Returns the managed object context for the application.
 * If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

/**
 * Returns the managed object model for the application.
 * If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:[self modelBase]
                                              withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

/**
 * Returns the persistent store coordinator for the application.
 * If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSString *pathComponent = [NSString stringWithFormat:@"%@.sqlite",[self modelBase]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:pathComponent];
    
    NSError *error = nil;
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark - Application's Documents directory

/**
 * Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}


@end
