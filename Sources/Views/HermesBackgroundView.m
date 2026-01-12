//
//  HermesBackgroundView.m
//  Hermes
//
//  Created by Nicholas Riley on 9/9/16.
//
//

#import "HermesBackgroundView.h"

@implementation HermesBackgroundView

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    [self setupModernAppearance];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self setupModernAppearance];
  }
  return self;
}

- (void)setupModernAppearance {
  // Configure translucent appearance with vibrancy using NSVisualEffectView
  self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  self.material = NSVisualEffectMaterialSidebar;
  self.state = NSVisualEffectStateActive;
}

@end
