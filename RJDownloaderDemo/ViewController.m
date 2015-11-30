//
//  ViewController.m
//  RJDownloaderDemo
//
//  Created by Ryan Jin on 11/16/15.
//  Copyright © 2015 ArcSoft. All rights reserved.
//

#import "ViewController.h"
#import "RJHTTPDownloader.h"

NSString * const URL_STRING = @"http://sanjosetransit.com/extras/SJTransit_Icons.zip";

@interface ViewController ()

@property (nonatomic, strong) RJHTTPDownloader *downloader;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@property (nonatomic, weak) IBOutlet UIButton *button;
@property (nonatomic, weak) IBOutlet UIProgressView *progress;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;
    
}

- (IBAction)buttonAction:(UIButton *)sender
{
    if ([sender.titleLabel.text isEqualToString:@"Download"]) {
        [self.button setTitle:@"Cancel" forState:UIControlStateNormal];
        self.progress.progress = 0.f;

        NSURL *URL = [NSURL URLWithString:URL_STRING];
        self.downloader = [[RJHTTPDownloader alloc] initWithRequestURL:URL progress:^(float percent) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progress.progress = percent;
            });
        } completion:^(id response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.button setTitle:@"Download" forState:UIControlStateNormal];
                if (error) self.progress.progress = 0.f;
            });
        }];
        
        [self.operationQueue addOperation:self.downloader];
        [self.operationQueue addOperationWithBlock:^{
            NSLog(@"next operation");
        }];
    }
    else {
        [self.button setTitle:@"Download" forState:UIControlStateNormal];
        self.progress.progress = 0.f; [self.downloader cancel];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
