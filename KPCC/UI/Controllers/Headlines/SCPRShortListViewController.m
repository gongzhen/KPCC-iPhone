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

@interface SCPRShortListViewController ()

- (void)extractTitleFromString:(NSString*)fullHTML completed:(CompletionBlockWithValue)completed;

@end

@implementation SCPRShortListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    
    NSURLRequest *rq = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://www.scpr.org/short-list/latest"]];
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
    [self.slWebView loadRequest:rq];
    
    NSLog(@"Width: %1.1f, Height: %1.1f",self.view.frame.size.width,self.view.frame.size.height);
    
    // Do any additional setup after loading the view from its nib.
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    self.navigationItem.title = self.cachedParentTitle;
}

- (void)share {
    
}

#pragma mark - UIWebView
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    if ( webView == self.slWebView ) {
        if ( !self.initialLoad ) {
            self.initialLoad = YES;
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
           
            scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
            scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
            
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
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.mainScrollView setContentOffset:CGPointMake(self.view.frame.size.width,
                                                                  self.mainScrollView.contentOffset.y)];
            } completion:^(BOOL finished) {
                

                
                SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
                SCPRNavigationController *navigation = [del masterNavigationController];
                [navigation applyCustomLeftBarItem:CustomLeftBarItemPop
                                     proxyDelegate:self];
                
                NSString *jsonString = [self.detailWebView stringByEvaluatingJavaScriptFromString:
                                        @"document.body.innerHTML"];
                
                [self extractTitleFromString:jsonString completed:^(id returnedObject) {
                    
                    NSLog(@"Title : %@",(NSString*)returnedObject);
                    self.cachedTitle = self.navigationItem.title;
                    self.navigationItem.title = (NSString*)returnedObject;
                    
                }];
                
            }];

        }
    }
    
}

- (void)popPressed {
    self.popping = YES;
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self.mainScrollView setContentOffset:CGPointMake(0.0,
                                                          self.mainScrollView.contentOffset.y)];
    } completion:^(BOOL finished) {
        
        SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
        SCPRNavigationController *navigation = [del masterNavigationController];
        [navigation restoreLeftBarItem:self];

        [self.detailWebView loadHTMLString:@"" baseURL:nil];
        self.navigationItem.title = self.cachedTitle;
        
    }];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ( webView == self.slWebView ) {
        NSString *str = [[request URL] absoluteString];
        NSLog(@"Loading %@ ... ",str);
        
        if ( self.initialLoad ) {
            if ( [str rangeOfString:@"googleads"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"googlesyndication"].location != NSNotFound ) {
                return YES;
            }
            if ( [str rangeOfString:@"http"].location != NSNotFound ) {
                [self.detailWebView loadRequest:request];
                
                
                return NO;
            }
            
            return YES;
        }
        
    }
    if ( webView == self.detailWebView ) {

    }
    return YES;
}

#pragma mark - Utilities
- (void)extractTitleFromString:(NSString *)fullHTML completed:(CompletionBlockWithValue)completed {
    
    
    NSError *error = nil;
    
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"<h1 class=\"title.*?\"><span>.*<"
                                  options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators
                                  error:&error];
    
    __block NSString *title = @"";
    [regex enumerateMatchesInString:fullHTML options:0 range:NSMakeRange(0, [fullHTML length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        
        title = [fullHTML substringWithRange:[match rangeAtIndex:0]];
        title = [title substringToIndex:[title rangeOfString:@"</span>"].location];
        title = [title substringFromIndex:[title rangeOfString:@"<span>"].location + [@"<span>" length]];
        
        if ( completed ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(title);
            });
        }
        
    }];
    
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
