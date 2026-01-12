//
//  HermesMainWindow.m
//  Hermes
//
//  Created by Nicholas Riley on 9/10/16.
//
//

#import "HermesMainWindow.h"

@implementation HermesMainWindow

- (void)awakeFromNib {
  [super awakeFromNib];
  // Use standard window appearance for now
  // Full-size content view requires proper Auto Layout constraints in XIB
}

- (void)sendEvent:(NSEvent *)theEvent {
  if ([theEvent type] == NSEventTypeKeyDown) {
    // don't ever let space bar get through to the field editor so it can be used for play/pause
    if ([[theEvent characters] isEqualToString:@" "] && ([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == 0) {
      [[NSApp mainMenu] performKeyEquivalent:theEvent];
      return;
    }
  }
  [super sendEvent:theEvent];
}

@end
