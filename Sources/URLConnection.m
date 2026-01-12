#import "PreferencesController.h"
#import "URLConnection.h"

NSString * const URLConnectionProxyValidityChangedNotification = @"URLConnectionProxyValidityChangedNotification";

@interface URLConnection ()
@property (nonatomic, copy) void (^cb)(NSData*, NSError*);
@property (nonatomic, strong) NSTimer *timeout;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSURLRequest *request;
@end

@implementation URLConnection
@synthesize cb = cb;
@synthesize timeout = timeout;

- (void)dealloc {
  [self.timeout invalidate];
  self.timeout = nil;
  [self.task cancel];
}

+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(void(^)(NSData*, NSError*)) completion {
  URLConnection *c = [[URLConnection alloc] init];
  c.cb = [completion copy];
  c.request = request;

  // Build a session configuration, including proxy settings if needed
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];

  // Apply proxy according to Hermes preferences
  [self applyHermesProxyToConfiguration:config];

  c.session = [NSURLSession sessionWithConfiguration:config];
  return c;
}

- (void) start {
  if (self.task) { return; }

  __weak typeof(self) weakSelf = self;
  self.task = [self.session dataTaskWithRequest:self.request
                              completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) { return; }

    // In the old implementation, bytes were accumulated incrementally. Here we just forward data.
    if (error) {
      if (strongSelf.cb) strongSelf.cb(nil, error);
    } else {
      if (strongSelf.cb) strongSelf.cb(data ?: [NSData data], nil);
    }

    strongSelf.cb = nil;
    [strongSelf.timeout invalidate];
    strongSelf.timeout = nil;
  }];

  [self.task resume];

  // Maintain similar timeout check behavior (10s repeating timer resetting events)
  self.timeout = [NSTimer scheduledTimerWithTimeInterval:10
                                             target:self
                                           selector:@selector(checkTimeout)
                                           userInfo:nil
                                            repeats:YES];
}

- (void) checkTimeout {
  // With NSURLSession we cannot directly inspect low-level stream events.
  // Emulate the previous behavior: if a task exists and hasn't completed within the window, cancel it and report timeout once.
  if (!self.task || !self.cb) { return; }

  // If the task is still running after the interval, treat as timeout.
  NSURLSessionTaskState state = self.task.state;
  if (state == NSURLSessionTaskStateRunning) {
    [self.task cancel];
    NSError *error = [NSError errorWithDomain:@"Connection timeout."
                                         code:0
                                     userInfo:nil];
    if (self.cb) self.cb(nil, error);
    self.cb = nil;
  }
}

#pragma mark - Proxy Handling

- (void) setHermesProxy {
  // Deprecated path retained for compatibility; NSURLSession path uses configuration at creation time.
}

+ (void) setHermesProxy:(CFReadStreamRef) stream {
  // No-op with NSURLSession; kept for API compatibility if other callers exist.
  (void)stream;
}

+ (void) applyHermesProxyToConfiguration:(NSURLSessionConfiguration *)config {
  switch (PREF_KEY_INT(ENABLED_PROXY)) {
    case PROXY_HTTP: {
      NSString *host = PREF_KEY_VALUE(PROXY_HTTP_HOST);
      NSInteger port = PREF_KEY_INT(PROXY_HTTP_PORT);
      if ([self validProxyHost:&host port:port]) {
        config.connectionProxyDictionary = @{
          (NSString *)kCFNetworkProxiesHTTPEnable: @YES,
          (NSString *)kCFNetworkProxiesHTTPProxy: host,
          (NSString *)kCFNetworkProxiesHTTPPort: @(port),
          (NSString *)kCFNetworkProxiesHTTPSEnable: @YES,
          (NSString *)kCFNetworkProxiesHTTPSProxy: host,
          (NSString *)kCFNetworkProxiesHTTPSPort: @(port)
        };
      }
      break;
    }
    case PROXY_SOCKS: {
      NSString *host = PREF_KEY_VALUE(PROXY_SOCKS_HOST);
      NSInteger port = PREF_KEY_INT(PROXY_SOCKS_PORT);
      if ([self validProxyHost:&host port:port]) {
        config.connectionProxyDictionary = @{
          (NSString *)kCFNetworkProxiesSOCKSEnable: @YES,
          (NSString *)kCFNetworkProxiesSOCKSProxy: host,
          (NSString *)kCFNetworkProxiesSOCKSPort: @(port)
        };
      }
      break;
    }
    case PROXY_SYSTEM:
    default: {
      // Use system proxy settings (defaultSessionConfiguration already does this), nothing to set.
      break;
    }
  }
}

+ (BOOL)validProxyHost:(NSString **)host port:(NSInteger)port {
  static BOOL wasValid = YES;
  *host = [*host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  BOOL isValid = ((port > 0 && port <= 65535) && [NSHost hostWithName:*host].address != nil);
  if (isValid != wasValid) {
    [[NSNotificationCenter defaultCenter] postNotificationName:URLConnectionProxyValidityChangedNotification
                                                        object:nil
                                                      userInfo:@{ @"isValid": @(isValid)}];
    wasValid = isValid;
  }
  return isValid;
}

+ (BOOL) setHTTPProxy:(CFReadStreamRef)stream
                 host:(NSString*)host
                 port:(NSInteger)port {
  // Maintained for compatibility with callers; translate to config on creation time instead.
  (void)stream; (void)host; (void)port;
  if (![self validProxyHost:&host port:port]) return NO;
  
  // Suppress deprecation warnings for legacy proxy configuration APIs
  // These constants are deprecated in favor of NSURLSession configuration
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
          [NSDictionary dictionaryWithObjectsAndKeys:
                  host, kCFStreamPropertyHTTPProxyHost,
                  @(port), kCFStreamPropertyHTTPProxyPort,
                  host, kCFStreamPropertyHTTPSProxyHost,
                  @(port), kCFStreamPropertyHTTPSProxyPort,
                  nil];
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
#pragma clang diagnostic pop
  return YES;
}

+ (BOOL) setSOCKSProxy:(CFReadStreamRef)stream
                  host:(NSString*)host
                  port:(NSInteger)port {
  (void)stream; (void)host; (void)port;
  return YES;
}

+ (void) setSystemProxy:(CFReadStreamRef)stream {
  (void)stream;
  // Suppress deprecation warnings for legacy proxy configuration APIs
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
#pragma clang diagnostic pop
  CFRelease(proxySettings);
}

@end

