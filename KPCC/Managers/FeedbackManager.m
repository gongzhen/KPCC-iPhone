//
//  FeedbackManager.m
//  KPCC
//
//  Created by Ben on 7/30/13.
//  Copyright (c) 2013 scpr. All rights reserved.
//

#import "FeedbackManager.h"
#import "Utils.h"

#define kBaseDeskURL @"https://kpcc.desk.com/api/v2"

static FeedbackManager *singleton = nil;
@implementation FeedbackManager

+ (FeedbackManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[FeedbackManager alloc] init];
        }
    }
    
    return singleton;
}

- (void)authWithDesk {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/cases",kBaseDeskURL]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *authStr = [NSString stringWithFormat:@"%@:%@",
                         [Utils gConfig][@"Desk"][@"AuthUser"],
                         [Utils gConfig][@"Desk"][@"AuthPassword"]];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [Utils base64:authData]];
    
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               
                               if ( e ) {
                                   NSLog(@"Error : %@",[e localizedDescription]);
                                   return;
                               }
                               
                               NSError *jsonError = nil;
                               
                               NSDictionary *auth = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:d
                                                                                                   options:NSJSONReadingMutableLeaves
                                                                                                     error:&jsonError];
                               
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   NSLog(@"As dict : %@",[auth description]);
                               });
                               
                               
                               
                           }];
    
}

- (void)enumerateCustomers {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/groups",kBaseDeskURL]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *authStr = [NSString stringWithFormat:@"%@:%@",
                         [Utils gConfig][@"Desk"][@"AuthUser"],
                         [Utils gConfig][@"Desk"][@"AuthPassword"]];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [Utils base64:authData]];
    
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               
                               if ( e ) {
                                   NSLog(@"Error : %@",[e localizedDescription]);
                                   return;
                               }
                               
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   
                               });
                               
                               
                               
                           }];
    
}

- (void) validateCustomer:(NSDictionary *)meta {
    
    NSError *fileError = nil;
    NSString *deskCustomerTemplate = [[NSString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"desk_customer_template"
                                                                                                                      ofType:@"json"]
                                      encoding:NSUTF8StringEncoding
                                                                        error:&fileError];
    NSString *asString = deskCustomerTemplate;
    
    NSString *customerEmail = [NSString stringWithFormat:@"%@",meta[@"email"]];
    
    NSString *name = [NSString stringWithFormat:@"%@",meta[@"name"]];
    NSArray *unfilteredArray = [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *filteredNameArray = [unfilteredArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    
    NSString *firstName = [NSString stringWithFormat:@""];
    if ([filteredNameArray count] > 0) {
        firstName = filteredNameArray[0];
    }
    
    NSString *lastName = [NSString stringWithFormat:@""];
    if ([filteredNameArray count] > 1) {
        lastName = filteredNameArray[1];
    }
    
    asString = [asString stringByReplacingOccurrencesOfString:kDeskCustomerEmailYield
                                                   withString:customerEmail];
    asString = [asString stringByReplacingOccurrencesOfString:kDeskCustomerFirstNameYield
                                                   withString:firstName];
    asString = [asString stringByReplacingOccurrencesOfString:kDeskCustomerLastNameYield
                                                   withString:lastName];
    
    NSLog(@"Final JSON for Desk : %@",asString);
    
    NSData *requestData = [asString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/customers",kBaseDeskURL]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestData];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
    
    NSString *authStr = [NSString stringWithFormat:@"%@:%@",
                         [Utils gConfig][@"Desk"][@"AuthUser"],
                         [Utils gConfig][@"Desk"][@"AuthPassword"]];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [Utils base64:authData]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               
                               if ( e ) {
                                   NSLog(@"Error : %@",[e localizedDescription]);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [self fail];
                                   });
                                   
                                   return;
                               }
                               
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   NSError *jsonError = nil;
                                   NSDictionary *auth = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:d
                                                                                                       options:0
                                                                                                         error:&jsonError];

                                   
                                   if (auth[(@"id")]) {
                                       NSString *cust_id = auth[@"id"];
                                       [self postFeedback:meta customer_id:cust_id];
                                   } else {
                                       
                                       // Customer with given email already exists on Desk. Dive deeper into the rabbit hole. Aka: Find and retrieve that customer's Desk id.
                                       NSURL *searchUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/customers/search?email=%@",kBaseDeskURL,customerEmail]];
                                       NSMutableURLRequest *searchRequest = [[NSMutableURLRequest alloc] initWithURL:searchUrl];
                                       [searchRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                                       [searchRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
                                       
                                       [NSURLConnection sendAsynchronousRequest:searchRequest queue:[[NSOperationQueue alloc] init]
                                                              completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                                                                  
                                                                  if ( e ) {
                                                                      NSLog(@"Error : %@",[e localizedDescription]);
                                                                      
                                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                                          [self fail];
                                                                      });
                                                                      
                                                                      return;
                                                                  }
                                                                  
                                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                                    
                                                                      NSDictionary *auth = (NSDictionary*)[d jsonify];
                                                                      if (auth [@"total_entries"] && [auth[@"total_entries"] integerValue] >= 1) {
                                                                          if (auth[@"_embedded"][@"entries"][0]) {
                                                                              NSDictionary *entry = auth[@"_embedded"][@"entries"][0];
                                                                              if (entry[@"id"]) {
                                                                                  [self postFeedback:meta customer_id:entry[@"id"]];
                                                                              }
                                                                          }
                                                                      } else {
                                                                          [self fail];
                                                                      }
                                                                  });
                                                              }];
                                   }
                               });
                           }];
}

- (void)postFeedback:(NSDictionary *)meta customer_id:(NSString *)customerID {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/cases",kBaseDeskURL]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    NSDictionary *deskPost = [Utils loadJson:@"desk_template"];
    NSString *asString = [Utils rawJson:deskPost];
    
    NSString *headline = [NSString stringWithFormat:@"%@ for KPCC from %@",meta[@"type"],
                          meta[@"name"]];
    
    NSString *type = meta[@"type"];
    NSString *priority = @"5";
    
    if ( [type isEqualToString:@"Bug"] ) {
        priority = @"8";
    }
    if ( [type isEqualToString:@"General Feedback"] ) {
        priority = @"2";
    }
    if ( [type isEqualToString:@"Suggestion"] ) {
        priority = @"4";
    }
    if ( [type isEqualToString:@"Other"] ) {
        priority = @"5";
    }
    
    NSString *prettyMessage = [NSString stringWithFormat:@"%@ : %@ : (UID: %@, Version : %@)",headline,meta[@"message"],
                               [[[UIDevice currentDevice] identifierForVendor] UUIDString],[Utils prettyVersion]];
    
    NSString *customerMessage = [NSString stringWithFormat:@"%@/customers/%@", kBaseDeskURL, customerID];
    
    asString = [asString stringByReplacingOccurrencesOfString:kDeskCustomerYield
                                                   withString:customerMessage];
    asString = [asString stringByReplacingOccurrencesOfString:kDeskBodyYield
                                                   withString:prettyMessage];
    asString = [asString stringByReplacingOccurrencesOfString:kDeskEmailYield
                                                   withString:meta[@"email"]];
    asString = [asString stringByReplacingOccurrencesOfString:kDeskSubjectYield
                                                   withString:headline];
    asString = [asString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"",kDeskPriorityYield]
                                                   withString:priority];
    
    NSDate *date = meta[@"date"];
    NSString *rfc = [date iso];
    
    asString = [asString stringByReplacingOccurrencesOfString:kDeskTimestampYield
                                                   withString:rfc];
    NSLog(@"FInal JSON for Desk : %@",asString);
    
    NSData *requestData = [asString dataUsingEncoding:NSUTF8StringEncoding];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestData];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld",(long) [requestData length]] forHTTPHeaderField:@"Content-Length"];
    
    NSString *authStr = [NSString stringWithFormat:@"%@:%@",
                         [Utils gConfig][@"Desk"][@"AuthUser"],
                         [Utils gConfig][@"Desk"][@"AuthPassword"]];
    
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [Utils base64:authData]];
    
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               
                               if ( e ) {
                                   NSLog(@"Error : %@",[e localizedDescription]);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [self fail];
                                   });
                                   
                                   return;
                               }
                               
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   
                                   NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                                   if ( [Utils pureNil:s] ) {
                                       [self fail];
                                       return;
                                   }
                                   
                                   NSDictionary *auth = (NSDictionary*)[d jsonify];
                                   
                                   if ( !auth ) {
                                       [self fail];
                                       return;
                                   }
                                   
                                   NSLog(@"POST Desk info : %@",s);
                           
                                   
                                   [[NSNotificationCenter defaultCenter]
                                    postNotificationName:@"feedback_submitted"
                                    object:nil];
                                   
                               });
                               
                               
                               
                           }];
    
    
    
}

- (void)fail {
    
    [[[UIAlertView alloc] initWithTitle:@"Error submitting feedback"
                                message:@"Apologies but there was a problem with the network while submitting your feedback. Please try again in a few moments. If the problem continues please email mobilefeedback@kpcc.org. Thanks for your patience."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"feedback_failure"
     object:nil];
    
}


@end
