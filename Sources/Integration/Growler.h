//
//  Growler.h
//  Hermes
//

@class Song;

#define GROWLER [HMSAppDelegate growler]

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface Growler : NSObject<NSUserNotificationCenterDelegate>
#pragma clang diagnostic pop

- (void) growl:(Song*)song withImage:(NSData*)image isNew:(BOOL) n;

@end
