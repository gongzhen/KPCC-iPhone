//
//  ContentManager.h
//  KPCC
//
//  Created by John Meeker on 6/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SCPRAppDelegate.h"

#ifndef PRODUCTION
#define kBookmarkPreservationTolerance 60*60*24*90
#else
#define kBookmarkPreservationTolerance 60*60*24*90
#endif

#define kBookmarkCleaningFrequency 60*60*24

@class Bookmark;
@class AudioChunk;

@interface ContentManager : NSObject

+ (ContentManager*)shared;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, copy) NSDate *lastBookmarkSweep;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *modelBase;
- (void)saveContext;

- (Bookmark*)bookmarkForUrl:(NSString*)url;
- (Bookmark*)bookmarkForAudioChunk:(AudioChunk*)chunk;
- (Bookmark*)findBookmarkBySha:(NSString*)shaUrl;
- (NSArray*)allBookmarks;

- (Bookmark*)createBookmarkFromAudioChunk:(AudioChunk*)chunk;
- (void)destroyBookmark:(Bookmark*)b;

- (void)sweepBookmarks;
- (void)sweepTaskWithCompletion:(CompletionBlockWithValue)completion;

@end
