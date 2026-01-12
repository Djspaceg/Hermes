/**
 * @file Growler.h
 * @brief Notification integration for Hermes
 *
 * Provides unified access to displaying notifications for different kinds
 * of events using macOS native notifications.
 */

#import "Growler.h"
#import "PreferencesController.h"
#import "PlaybackController.h"

@implementation Growler

- (id) init {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
#pragma clang diagnostic pop
  return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void) growl:(Song*)song withImage:(NSData*)image isNew:(BOOL)n {
  // Unconditionally remove all notifications from notification center to behave like iTunes
  // notifications and does not fill the notification center with old song details.
  [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];

  if (!PREF_KEY_BOOL(PLEASE_GROWL) ||
      (n && !PREF_KEY_BOOL(PLEASE_GROWL_NEW)) ||
      (!n && !PREF_KEY_BOOL(PLEASE_GROWL_PLAY))) {
    return;
  }

  NSString *title = [song title];
  if ([[song nrating] intValue] == 1) {
	  title = [NSString stringWithFormat:@"👍 %@", title];
  }
  NSString *description = [NSString stringWithFormat:@"%@\n%@", [song artist],
                                                     [song album]];

  // Use macOS native notifications
  NSUserNotification *not = [[NSUserNotification alloc] init];
  [not setTitle:title];
  [not setInformativeText:description];
  [not setHasActionButton:YES];
  [not setActionButtonTitle: @"Skip"];
  
  // Make skip button visible for banner notifications (like in iTunes)
  // - Undocumented API.  Will only work if Apple keeps in NSUserNotification
  //   class.  Otherwise, skip button will only appear if 'Alert' style
  //   notifications are used.
  // - see: https://github.com/indragiek/NSUserNotificationPrivate
  @try {
    [not setValue:@YES forKey:@"_showsButtons"];
  } @catch (NSException *e) {
    if ([e name] != NSUndefinedKeyException) @throw e;
  }
  
  // Skip action
  NSUserNotificationAction *skipAction =
    [NSUserNotificationAction actionWithIdentifier:@"next" title:@"Skip"];
  
  // Like/Dislike actions
  NSString *likeActionTitle =
    ([[song nrating] intValue] == 1) ? @"Remove Like" : @"Like";
  
  NSUserNotificationAction *likeAction =
    [NSUserNotificationAction actionWithIdentifier:@"like" title:likeActionTitle];
  NSUserNotificationAction *dislikeAction =
    [NSUserNotificationAction actionWithIdentifier:@"dislike" title:@"Dislike"];
  
  [not setAdditionalActions: @[skipAction,likeAction,dislikeAction]];
  
  if ([not respondsToSelector:@selector(setContentImage:)]) {
    // Set album art where app icon is (like in iTunes)
    // - Undocumented API.  Will only work if Apple keeps in NSUserNotification
    //   class.  Otherwise, skip button will only appear if 'Alert' style
    //   notifications are used.
    // - see: https://github.com/indragiek/NSUserNotificationPrivate
    @try {
      [not setValue:[[NSImage alloc] initWithData:image] forKey:@"_identityImage"];
    } @catch (NSException *e) {
      if ([e name] != NSUndefinedKeyException) @throw e;
      [not setContentImage:[[NSImage alloc] initWithData:image]];
    }
  }
  
  NSUserNotificationCenter *center =
      [NSUserNotificationCenter defaultUserNotificationCenter];
  [not setDeliveryDate:[NSDate date]];
  [center scheduleNotification:not];
}
#pragma clang diagnostic pop

/******************************************************************************
 * Implementation of NSUserNotificationCenterDelegate
 ******************************************************************************/

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
  /* always show notifications, even if the application is active */
  return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {
  
  PlaybackController *playback = [HMSAppDelegate playback];
  NSString *actionID = [[notification additionalActivationAction] identifier];
  
  switch([notification activationType]) {
    case NSUserNotificationActivationTypeActionButtonClicked:
      
      // Skip button pressed
      [playback next:self];
      break;
      
    case NSUserNotificationActivationTypeAdditionalActionClicked:
      
      // One of the drop down buttons was pressed
      if ([actionID isEqualToString:@"like"]) {
        [playback like:self];
      } else if ([actionID isEqualToString:@"dislike"]) {
        [playback dislike:self];
      } else if ([actionID isEqualToString:@"next"]) {
        [playback next:self];
      }
      break;
      
    case NSUserNotificationActivationTypeContentsClicked:
      // Banner was clicked, so bring up and focus main UI
      [[HMSAppDelegate window] orderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
      break;
      
    default:
      // Any other action
      break;
      
  }
  // Only way to get this notification to be removed from center
  [center removeAllDeliveredNotifications];
}
#pragma clang diagnostic pop



@end
