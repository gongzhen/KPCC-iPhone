//
//  SCPRTritonXMLParserDelegate.m
//  KPCC
//
//  Created by John Meeker on 10/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRTritonXMLParserDelegate.h"

@implementation SCPRTritonXMLParserDelegate

- (void) parserDidStartDocument:(NSXMLParser *)parser
{
    NSLog(@"parserDidStartDocument");
    self.xmlTriton = [NSMutableDictionary dictionary];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    NSLog(@"didStartElement --> %@", elementName);
    self.elementName = qName;

    if ([qName isEqualToString:@"Ad"]) {
        self.currentDictionary = [NSMutableDictionary dictionary];
    }

    self.outstring = [NSMutableString string];
}

-(void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    NSLog(@"foundCharacters --> %@", string);
    if (!self.elementName) {
        return;
    }

    [self.outstring appendFormat:@"%@", string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    NSLog(@"didEndElement   --> %@", elementName);

    if ([qName isEqualToString:@"Ad"]) {
        self.xmlTriton[qName] = @[self.currentDictionary];
        self.currentDictionary = nil;
    }

    self.elementName = nil;
}

- (void) parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"parserDidEndDocument");
}

@end
