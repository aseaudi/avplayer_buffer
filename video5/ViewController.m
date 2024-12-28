//
//  ViewController.m
//  video5
//
//  Created by Abdelmuhaimen Seaudi on 25/12/2024.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Foundation/Foundation.h> // Foundation framework
#import <MobileCoreServices/MobileCoreServices.h> // MobileCoreServices framework

@interface ViewController () <AVAssetResourceLoaderDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (nonatomic, strong) id timeObserver;
//@property (weak, nonatomic) IBOutlet UILabel *bufferLabel;

@property NSMutableArray *pendingRequests;
@property NSMutableData *videoData;
@property NSHTTPURLResponse *responset;
@property NSURLConnection *connection;

@property (weak, nonatomic) IBOutlet UILabel *bufferLabel;
@property NSURLSession *session;
@property NSURLSessionDataTask *dataTask;
@property NSUInteger contentLength;
@property Float64 totalBufferedTime;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSURL *videoURL = [[NSURL alloc] initWithString:@"custom://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"];
//    NSURL *videoURL = [[NSURL alloc] initWithString:@"custom://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"];
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    self.videoData = [[NSMutableData alloc] initWithCapacity:1000000];
    self.pendingRequests = [NSMutableArray array];
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    [self addChildViewController:controller];
    [self.view addSubview:controller.view];
    controller.view.frame = self.view.bounds;
    controller.player = self.player;
    controller.showsPlaybackControls = YES;
    NSLog(@"XXXX will play now");
    [self.player play];
    [self addBufferingObservers];
    [self.view addSubview:self.bufferLabel];
    [self.view bringSubviewToFront:self.bufferLabel];
}

- (void)processPendingRequests {
    NSLog(@"XXXX processPendingRequests");
    NSMutableArray *requestsCompleted = [NSMutableArray array];
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        NSLog(@"XXXX processPendingRequests loadingRequest %@", loadingRequest);
        if (loadingRequest.dataRequest.requestedLength == 2) {
            NSLog(@"XXXX this is requestedLength == 2");
            NSLog(@"XXXX header content-range %@", [self.responset valueForHTTPHeaderField:@"Content-Range"]);
            self.contentLength = [[[self.responset valueForHTTPHeaderField:@"Content-Range"] componentsSeparatedByString:@"/"][1] integerValue];
            NSLog(@"XXX content length %lu", (unsigned long)self.contentLength);
            loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
            loadingRequest.contentInformationRequest.contentLength = self.contentLength;
            loadingRequest.contentInformationRequest.contentType = @"video/mp4";
            NSLog(@"respondWithData info");
            [loadingRequest.dataRequest respondWithData:self.videoData];
            [loadingRequest finishLoading];
            [requestsCompleted addObject:loadingRequest];
            [self.videoData initWithCapacity:self.contentLength];
        } else {
            NSLog(@"respondWithData full");
            [loadingRequest.dataRequest respondWithData:self.videoData];
            [loadingRequest finishLoading];
            [requestsCompleted addObject:loadingRequest];
            [self.videoData initWithCapacity:self.contentLength];
        }
    }
    [self.pendingRequests removeObjectsInArray:requestsCompleted];
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"XXXX shouldWaitForLoading");
    NSLog(@"XXXX loadingRequest %@", loadingRequest);
    NSString *urlString = @"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
//    NSString *urlString = @"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4";
    NSURL *realURL = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:realURL];
    NSInteger loadStart = loadingRequest.dataRequest.requestedOffset;
    NSInteger loadEnd = loadingRequest.dataRequest.requestedLength == 2 ? 1 : loadStart + 1000000;
    [request setValue:[NSString stringWithFormat:@"bytes=%ld-%ld", (long)loadStart, (long)loadEnd] forHTTPHeaderField:@"Range"];
    NSLog(@"request %@", request.allHTTPHeaderFields);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.dataTask = [self.session dataTaskWithRequest:request];
    [self.dataTask resume];
    [self.pendingRequests addObject:loadingRequest];
    return YES;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSLog(@"XXXX didReceiveResponse");
    self.responset = (NSHTTPURLResponse *) response;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    [self.videoData appendData:data];
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"XXXX didCancelLoading");
    [self.pendingRequests removeObject:loadingRequest];
}

- (void)addBufferingObservers {
    [self.player addObserver:self
                  forKeyPath:@"timeControlStatus"
                     options:NSKeyValueObservingOptionNew
                     context:nil];

    [self.playerItem addObserver:self
                      forKeyPath:@"playbackBufferEmpty"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
    
    [self.playerItem addObserver:self
                      forKeyPath:@"playbackBufferFull"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
    
    
    [self.playerItem addObserver:self
                      forKeyPath:@"playbackLikelyToKeepUp"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
    
    [self.playerItem addObserver:self
                      forKeyPath:@"loadedTimeRanges"
                         options:NSKeyValueObservingOptionNew
                         context:NULL];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(flushBuffer)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"timeControlStatus"]) {
        AVPlayerTimeControlStatus status = self.player.timeControlStatus;
        if (status == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate) {
            NSLog(@"Buffering...");
        } else if (status == AVPlayerTimeControlStatusPlaying) {
            NSLog(@"Playing...");
        } else if (status == AVPlayerTimeControlStatusPaused) {
            NSLog(@"Paused...");
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        BOOL bufferEmpty = self.playerItem.playbackBufferEmpty;
        if (bufferEmpty) {
            NSLog(@"Buffering: Buffer is empty");
        }
    } else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        BOOL bufferFull = self.playerItem.playbackBufferFull;
        if (bufferFull) {
            NSLog(@"Buffering: Buffer is full");
        }
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        BOOL likelyToKeepUp = self.playerItem.playbackLikelyToKeepUp;
        if (likelyToKeepUp) {
            NSLog(@"Buffering: Buffering complete, likely to keep up");
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray *loadedTimeRanges = self.playerItem.loadedTimeRanges;
        NSLog(@"loadedTimeRanges %@", loadedTimeRanges);
        NSTimeInterval totalLoadedSeconds = 0.0;
        CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
        totalLoadedSeconds = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
        self.totalBufferedTime = totalLoadedSeconds;
        Float64 currentSeconds = CMTimeGetSeconds(self.player.currentTime);
        Float64 remainingBuffer = totalLoadedSeconds - currentSeconds;
        NSLog(@"Total Loaded Time: %.2f seconds", totalLoadedSeconds);
        NSLog(@"Current time: %.2f seconds", currentSeconds);
        NSLog(@"Remaining buffer: %.2f seconds", remainingBuffer);
        self.bufferLabel.text = [NSString stringWithFormat:@"Remaining buffer: %.2f seconds", remainingBuffer];
    }
}

- (void)dealloc {
    [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
    [self.playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.playerItem removeObserver:self forKeyPath:@"playbackBufferFull"];
    [self.playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
}

- (void)flushBuffer {
    if (self.player.currentItem) {
        Float64 remainingBuffer = self.totalBufferedTime - CMTimeGetSeconds(self.player.currentTime);
        if (self.dataTask.state == NSURLSessionTaskStateCompleted && remainingBuffer < 10)
            [self processPendingRequests];
    }
}

@end
