//
//  RJHTTPDownloader.m
//  RJDownloaderDemo
//
//  Created by Ryan Jin on 11/2/15.
//  Copyright (c) 2015 ArcSoft. All rights reserved.
//

#import "RJHTTPDownloader.h"

#define DELEGATE_HAS_METHOD(delegate, method) delegate && [delegate respondsToSelector:@selector(method)]

typedef NS_ENUM(NSInteger, RJRequestState) {
    RJRequestStateReady     = 0,
    RJRequestStateExecuting = 1,
    RJRequestStateFinished  = 2,
};

static const NSTimeInterval kRequestTimeout = 20.f;

@interface RJHTTPDownloader ()

@property (nonatomic, strong) NSMutableData *fileData;
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;

@property (nonatomic, assign) float expectedLength;
@property (nonatomic, assign) float receivedLength;
@property (nonatomic, assign) RJRequestState state;
@property (nonatomic, assign) CFRunLoopRef operationRunLoop;

@property (nonatomic, weak) id <RJHTTPDownloaderDelegate> delegate;
@property (nonatomic, copy) void (^completion)(id response, NSError *error);
@property (nonatomic, copy) void (^progress)(float percent);

@end

@implementation RJHTTPDownloader
@synthesize state = _state;

#pragma mark - Initialize Methods
- (id)initWithRequestURL:(NSURL *)URL delegate:(id<RJHTTPDownloaderDelegate>)delegate
{
    return [self initWithRequestURL:URL delegate:delegate progress:nil completion:nil];
}

- (id)initWithRequestURL:(NSURL *)URL
                progress:(void (^)(float percent))progress
              completion:(void (^)(id response, NSError *error))completion
{
    return [self initWithRequestURL:URL delegate:nil progress:progress completion:completion];
}

- (id)initWithRequestURL:(NSURL *)URL
                delegate:(id<RJHTTPDownloaderDelegate>)delegate
                progress:(void (^)(float percent))progress
              completion:(void (^)(id response, NSError *error))completion
{
    if (self = [super init]) {
        self.delegate   = delegate;
        self.progress   = progress;
        self.completion = completion;
        
        self.request = [NSMutableURLRequest requestWithURL:URL
                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                           timeoutInterval:kRequestTimeout];
    }
    return self;
}

- (void)dealloc
{
    [self.connection cancel];
}

#pragma mark - NSOperation Methods
- (void)start
{
    if (self.isCancelled) { [self finish]; return; }
    
    /*
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start)
                               withObject:nil
                            waitUntilDone:NO];
        return;
    }
    
    or
     
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
    }];
    */
    
    [self willChangeValueForKey:@"isExecuting"];
    self.state = RJRequestStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                      delegate:self
                                              startImmediately:NO];
    
    NSOperationQueue *currentQueue = [NSOperationQueue currentQueue];
    BOOL backgroundQueue           = (currentQueue != nil && currentQueue != [NSOperationQueue mainQueue]);
    NSRunLoop *targetRunLoop       = (backgroundQueue)?[NSRunLoop currentRunLoop]:[NSRunLoop mainRunLoop];

    [self.connection scheduleInRunLoop:targetRunLoop forMode:NSRunLoopCommonModes];
    [self.connection start];

    // make NSRunLoop stick around until operation is finished
    if (backgroundQueue) {
        self.operationRunLoop = CFRunLoopGetCurrent(); CFRunLoopRun();
    }
}

- (void)cancel
{
    if (![self isExecuting]) return;
    
    [super cancel]; [self finish];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isFinished
{
    return self.state == RJRequestStateFinished;
}

- (BOOL)isExecuting
{
    return self.state == RJRequestStateExecuting;
}

#pragma mark - Request Status
- (void)finish
{
    [self.connection cancel]; self.connection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = RJRequestStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (RJRequestState)state
{
    @synchronized(self) {
        return _state;
    }
}

- (void)setState:(RJRequestState)newState
{
    @synchronized(self) {
        [self willChangeValueForKey:@"state"];
        _state = newState;
        [self didChangeValueForKey:@"state"];
    }
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.expectedLength = response.expectedContentLength;
    self.receivedLength = 0;
    self.fileData       = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.fileData appendData:data]; self.receivedLength += data.length;

    float percent = self.receivedLength / self.expectedLength;
    
    if (self.progress) self.progress(percent);
    
    if (DELEGATE_HAS_METHOD(self.delegate, RJHTTPDownloader:downloadProgress:)) {
        [self.delegate RJHTTPDownloader:self downloadProgress:percent];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self downloadFinishedWithResponse:self.fileData error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self downloadFinishedWithResponse:nil error:error];
}

#pragma mark - Download Finished
- (void)downloadFinishedWithResponse:(id)response error:(NSError *)error
{
    if (self.operationRunLoop) CFRunLoopStop(self.operationRunLoop);

    if (self.isCancelled) return;
    
    if (self.completion) self.completion(self.fileData, error);

    if (response && DELEGATE_HAS_METHOD(self.delegate, RJHTTPDownloader:didFinishWithData:))
    {
        [self.delegate RJHTTPDownloader:self didFinishWithData:response];
    }
    else if (!response && DELEGATE_HAS_METHOD(self.delegate, RJHTTPDownloader:didFailWithError:))
    {
        [self.delegate RJHTTPDownloader:self didFailWithError:error];
    }

    [self finish];
}

@end
