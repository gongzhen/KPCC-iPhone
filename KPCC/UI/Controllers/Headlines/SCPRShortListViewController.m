//
//  SCPRShortListViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 10/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRShortListViewController.h"
#import <pop/POP.h>
#import "DesignManager.h"
#import "SCPRNavigationController.h"
#import "SCPRAppDelegate.h"
#import "SCPRSpinnerViewController.h"
#import "NetworkManager.h"

@interface SCPRShortListViewController ()

- (void)extractTitleFromString:(NSString*)fullHTML completed:(CompletionBlockWithValue)completed;

@end

static NSString *kShortListMenuURL = @"http://www.scpr.org/short-list/latest#no-prelims";

@implementation SCPRShortListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.view.frame = [[DesignManager shared] screenFrame];
    
    self.mainScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                                 self.view.frame.size.height)];
    self.detailWebView = [[UIWebView alloc] initWithFrame:CGRectMake(self.view.frame.size.width,
                                                                     0.0, self.view.frame.size.width,
                                                                     self.view.frame.size.height)];
    self.slWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0,
                                                                 0.0,
                                                                 self.view.frame.size.width,
                                                                 self.view.frame.size.height)];
    [self.view addSubview:self.mainScrollView];
    
    self.mainScrollView.contentSize = CGSizeMake(2*self.mainScrollView.frame.size.width,
                                                 self.mainScrollView.frame.size.height);
    [self.mainScrollView addSubview:self.slWebView];
    [self.mainScrollView addSubview:self.detailWebView];
    self.mainScrollView.scrollEnabled = NO;
    
    NSURLRequest *rq = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:kShortListMenuURL]];
    self.slWebView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    self.slWebView.layer.opacity = 0.0;
    
    //self.detailWebView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    self.slWebView.delegate = self;
    self.detailWebView.delegate = self;
    self.cachedParentTitle = self.navigationItem.title;
    self.navigationItem.title = @"Headlines";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                           target:self
                                                                                           action:@selector(share)];
    self.currentObjectURL = kShortListMenuURL;
    
    [SCPRSpinnerViewController spinInCenterOfViewController:self appeared:^{
#ifdef USE_API
        [[NetworkManager shared] fetchEditions:^(id returnedObject) {
            
            NSAssert([returnedObject isKindOfClass:[NSArray class]],@"Expecting an array here");
            NSArray *editions = (NSArray*)returnedObject;
            if ( [editions count] > 0 ) {
                NSDictionary *lead = editions[0];
                self.abstracts = lead[@"abstracts"];
            }
            
        }];
#endif
        [self.slWebView loadRequest:rq];
    }];
    
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    self.navigationItem.title = self.cachedParentTitle;
    self.slWebView.delegate = nil;
    [self.slWebView loadHTMLString:@"" baseURL:nil];
}

- (void)share {
    
    if ( self.currentObjectURL ) {
        UIActivityViewController *activities = [[UIActivityViewController alloc] initWithActivityItems:@[ self.currentObjectURL ]
                                                                                 applicationActivities:nil];
        [self presentViewController:activities
                           animated:YES
                         completion:nil];
    }
}

#pragma mark - UIWebView
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    if ( webView == self.slWebView ) {
        if ( !self.initialLoad ) {
            self.initialLoad = YES;
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
           
            scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
            scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
            [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
                [SCPRSpinnerViewController finishSpinning];
            }];
            
            POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
            genericFadeInAnim.toValue = @(1);
            
            [self.slWebView.layer pop_addAnimation:scaleAnimation forKey:@"springToLife"];
            [self.slWebView.layer pop_addAnimation:genericFadeInAnim forKey:@"springToOpaque"];
        }
    }
    if ( webView == self.detailWebView ) {
        
        if ( self.popping ) {
            self.popping = NO;
            self.detailInitialLoad = NO;
            return;
        }
        
        if ( !self.detailInitialLoad ) {
            self.detailInitialLoad = YES;
            [SCPRSpinnerViewController finishSpinning];
            

            
            POPSpringAnimation *shiftAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPScrollViewContentOffset];
            shiftAnimation.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.0, self.mainScrollView.contentOffset.y)];
            shiftAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.mainScrollView.frame.size.width, self.mainScrollView.contentOffset.y)];
            [shiftAnimation setSpringBounciness:10.0];
            [shiftAnimation setCompletionBlock:^(POPAnimation *anim, BOOL finished) {
#ifdef USE_API
                SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
                SCPRNavigationController *navigation = [del masterNavigationController];
                
                [navigation applyCustomLeftBarItem:CustomLeftBarItemPop
                                     proxyDelegate:self];
                self.navigationItem.leftBarButtonItem.enabled = YES;
                self.pushing = NO;
#else
                NSString *jsonString = [self.detailWebView stringByEvaluatingJavaScriptFromString:
                                        @"document.getElementsByTagName('head')[0].innerHTML;"];
                
                [self extractTitleFromString:jsonString completed:^(id returnedObject) {
                    
                    [SCPRSpinnerViewController finishSpinning];
                    
                    NSLog(@"Title : %@",(NSString*)returnedObject);
                    self.cachedTitle = self.navigationItem.title;
                    self.navigationItem.title = (NSString*)returnedObject;
                    
                    SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
                    SCPRNavigationController *navigation = [del masterNavigationController];
                    
                    [navigation applyCustomLeftBarItem:CustomLeftBarItemPop
                                         proxyDelegate:self];
                    self.navigationItem.leftBarButtonItem.enabled = YES;
                    self.pushing = NO;
                    
                }];
#endif

            }];
            
            [self.mainScrollView pop_addAnimation:shiftAnimation
                                           forKey:@"fauxPush"];
                
        }
    }

    
    
    
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    NSString *str = [[request URL] absoluteString];
    if ( webView == self.slWebView ) {
        
        NSLog(@"Loading %@ ... ",str);
        
        if ( self.initialLoad ) {
            if ( [str rangeOfString:@"googleads"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"googlesyndication"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"google.com/pagead"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"pageview?url"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"http"].location != NSNotFound ) {
                if ( !self.pushing ) {
                    
                    [SCPRSpinnerViewController spinInCenterOfViewController:self appeared:^{
#ifdef USE_API
                        [self findConcreteObjecrBasedOnUrl:str completion:^(id returnedObject) {
                            
                            
                            self.cachedTitle = self.navigationItem.title;
                            self.navigationItem.title = (NSString*)returnedObject;
                            
                            self.currentObjectURL = str;
                            self.pushing = YES;
                            self.navigationItem.leftBarButtonItem.enabled = NO;
                            [self.detailWebView loadRequest:request];
                        }];
#else
                        self.currentObjectURL = str;
                        self.pushing = YES;
                        self.navigationItem.leftBarButtonItem.enabled = NO;
                        [self.detailWebView loadRequest:request];
#endif
                    }];

                }
                return NO;
            }
            if ( [str rangeOfString:@"about:blank"].location != NSNotFound ) {
                return YES;
            }
            
            return YES;
        }
        
    }
    if ( webView == self.detailWebView ) {
        if ( [str rangeOfString:@"share?obj_key"].location != NSNotFound ||
            [str rangeOfString:@"tweet?url"].location != NSNotFound ||
            [str rangeOfString:@"/sharer.php?"].location != NSNotFound ) {
            [[[UIAlertView alloc] initWithTitle:@"Share from the App!"
                                        message:@"If you'd like to share this item, use the share button in the upper right corner"
                                       delegate:nil
                              cancelButtonTitle:@"Will Do!"
                              otherButtonTitles:nil] show];
            return NO;
        }
    }
    return YES;
}

#pragma mark - MenuButtonDelegate
- (void)popPressed {
    
    if ( self.pushing ) return;
    
    self.popping = YES;
    SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
    SCPRNavigationController *navigation = [del masterNavigationController];
    [navigation restoreLeftBarItem:self];
    self.navigationItem.title = self.cachedTitle;
    
    POPSpringAnimation *shiftAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPScrollViewContentOffset];
    shiftAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(0.0, self.mainScrollView.contentOffset.y)];
    shiftAnimation.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.mainScrollView.frame.size.width, self.mainScrollView.contentOffset.y)];
    [shiftAnimation setSpringBounciness:10.0];
    [shiftAnimation setCompletionBlock:^(POPAnimation *anim, BOOL finished) {
        self.currentObjectURL = kShortListMenuURL;
        [self.detailWebView loadHTMLString:@"" baseURL:nil];
        self.navigationItem.leftBarButtonItem.enabled = YES;
    }];
    [self.mainScrollView pop_addAnimation:shiftAnimation
                                   forKey:@"fauxPop"];
}

- (void)backPressed {
    // Should not be called
}

- (void)menuPressed {
    // Should not be called
}




#pragma mark - Utilities
- (void)extractTitleFromString:(NSString *)fullHTML completed:(CompletionBlockWithValue)completed {
    
    NSError *error = nil;
    
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"<title>.*</title>"
                                  options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators
                                  error:&error];
    
    __block NSString *title = @"";
    __block BOOL matched = NO;
    [regex enumerateMatchesInString:fullHTML options:0 range:NSMakeRange(0, [fullHTML length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        
        title = [fullHTML substringWithRange:[match rangeAtIndex:0]];
        title = [title substringToIndex:[title rangeOfString:@"</title>"].location];
        title = [title substringFromIndex:[title rangeOfString:@"<title>"].location + [@"<title>" length]];
        
        *stop = YES;
        matched = YES;
        
        if ( completed ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(title);
            });
        }
        
    }];
    
    if ( !matched ) {
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"<h1 class=\"story-headline\">.*?</a>"
                                      options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators
                                      error:&error];
        
        [regex enumerateMatchesInString:fullHTML options:0 range:NSMakeRange(0, [fullHTML length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            
            title = [fullHTML substringWithRange:[match rangeAtIndex:0]];
            title = [title substringToIndex:[title rangeOfString:@"</a>"].location];
            title = [title substringFromIndex:[title rangeOfString:@"<a href"].location + [@"<a href" length]];
            title = [title substringFromIndex:[title rangeOfString:@">"].location+1];
            
            *stop = YES;
            matched = YES;
            
            if ( completed ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completed(title);
                });
            }
            
        }];
    }


    
}

- (void)findConcreteObjecrBasedOnUrl:(NSString *)url completion:(CompletionBlockWithValue)completion {
    
    NSString *title = @"";
    for ( NSDictionary *abstract in self.abstracts ) {
        int x =1;
        x++;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
