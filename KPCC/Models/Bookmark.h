//
//  Bookmark.h
//  
//
//  Created by Ben Hochberg on 3/9/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Bookmark : NSManagedObject

@property (nonatomic, retain) NSString * urlSha;
@property (nonatomic, retain) NSString * urlPlain;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSString * programTitle;
@property (nonatomic, retain) NSString * audioTitle;
@property (nonatomic, retain) NSNumber * resumeTimeInSeconds;
@property (nonatomic, retain) NSNumber * duration;

@end
