//
//  NSData+JSONAdditions.h
//  KPCC
//
//  Created by Ben Hochberg on 11/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (JSONAdditions)

@property (NS_NONATOMIC_IOSONLY, readonly, strong) id jsonify;

@end
