//
//  GenericProgram.h
//  KPCC
//
//  Created by Eric Richardson on 9/1/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

#ifndef GenericProgram_h
#define GenericProgram_h

@protocol GenericProgram <NSObject>
@required
@property (nonatomic, retain) NSString* title;
@property (nonatomic, retain) NSString* program_slug;
@property (nonatomic, retain) NSString* public_url;
@end

#endif /* GenericProgram_h */
