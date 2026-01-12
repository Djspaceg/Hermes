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
  [self setupModernAppearance];
}

- (void)setupModernAppearance {
  // Enable modern Liquid Glass appearance inspired by macOS Tahoe
  // Using NSVisualEffectView APIs available since macOS 11.0+
  self.titlebarAppearsTransparent = YES;
  self.styleMask |= NSWindowStyleMaskFullSizeContentView;
  
  // Add translucent background with vibrancy
  NSVisualEffectView *visualEffectView = [[NSVisualEffectView alloc] initWithFrame:self.contentView.bounds];
  visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  visualEffectView.material = NSVisualEffectMaterialUnderWindowBackground;
  visualEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
  
  // Insert the visual effect view as the base layer
  if (self.contentView.subviews.count > 0) {
    [self.contentView addSubview:visualEffectView positioned:NSWindowBelow relativeTo:self.contentView.subviews[0]];
  } else {
    [self.contentView addSubview:visualEffectView];
  }
}

- (void)sendEvent:(NSEvent *)theEvent {
  if ([theEvent type] == NSKeyDown) {

    // don't ever let space bar get through to the field editor so it can be used for play/pause
    if ([[theEvent characters] isEqualToString:@" "] && ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == 0) {
      [[NSApp mainMenu] performKeyEquivalent:theEvent];
      return;
    }
  }
  [super sendEvent:theEvent];
}

@end
