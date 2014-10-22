//
//  SCPRTritonXMLParserDelegate.h
//  KPCC
//
//  Created by John Meeker on 10/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCPRTritonXMLParserDelegate : NSObject<NSXMLParserDelegate>

@property(nonatomic, strong) NSMutableDictionary *currentDictionary;   // current section being parsed
@property(nonatomic, strong) NSMutableDictionary *xmlTriton;          // completed parsed xml response
@property(nonatomic, strong) NSString *elementName;
@property(nonatomic, strong) NSMutableString *outstring;

@end
