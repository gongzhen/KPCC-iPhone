//
//  Program.h
//  KPCC
//
//  Created by John Meeker on 6/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentManager.h"


@interface Program : NSManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSDate * ends_at;
@property (nonatomic, retain) NSDate * starts_at;
@property (nonatomic, retain) NSString * public_url;
@property (nonatomic, retain) NSNumber * is_recurring;
@property (nonatomic, retain) NSString * program_slug;

+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context;
+ (instancetype)fetchObjectFromContext:(NSManagedObjectContext *)context;
+ (instancetype)insertProgramWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context;
+ (void)insertProgramsWithArray:(NSArray *)array inManagedObjectContext:(NSManagedObjectContext *)context;
+ (instancetype)fetchProgramWithSlug:(NSString *)slug fromManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)fetchAllProgramsInContext:(NSManagedObjectContext *)context;

@end
