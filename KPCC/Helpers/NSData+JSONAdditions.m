//
//  NSData+JSONAdditions.m
//  KPCC
//
//  Created by Ben Hochberg on 11/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NSData+JSONAdditions.h"

@implementation NSData (JSONAdditions)

- (id)jsonify {
    NSError *jsonError = nil;
    return [NSJSONSerialization JSONObjectWithData:self
                                    options:0
                                      error:&jsonError];
}

@end
