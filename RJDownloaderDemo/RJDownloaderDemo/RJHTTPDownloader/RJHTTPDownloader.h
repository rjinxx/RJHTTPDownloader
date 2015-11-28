//
//  RJHTTPDownloader.h
//  RJDownloaderDemo
//
//  Created by Ryan Jin on 11/2/15.
//  Copyright (c) 2015 ArcSoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RJHTTPDownloader;

@protocol RJHTTPDownloaderDelegate<NSObject>

@optional

- (void)RJHTTPDownloader:(RJHTTPDownloader *)downloader downloadProgress:(double)progress;
- (void)RJHTTPDownloader:(RJHTTPDownloader *)downloader didFinishWithData:(NSData *)data;
- (void)RJHTTPDownloader:(RJHTTPDownloader *)downloader didFailWithError:(NSError *)error;

@end

@interface RJHTTPDownloader : NSOperation

- (id)initWithRequestURL:(NSURL *)URL delegate:(id<RJHTTPDownloaderDelegate>)delegate;
- (id)initWithRequestURL:(NSURL *)URL
                progress:(void (^)(float percent))progress
              completion:(void (^)(id response, NSError *error))completion;

@end
