//
//  HermesVolumeSliderCell.m
//  Hermes
//
//  Created by Nicholas Riley on 9/9/16.
//
//

#import "HermesVolumeSliderCell.h"

@implementation HermesVolumeSliderCell

// based upon http://stackoverflow.com/a/29828476/6372
- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
  rect = NSInsetRect(rect, 0, 1);
  
  CGFloat radius = rect.size.height / 2;
  CGFloat proportion = (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
  
  CGFloat leftWidth = proportion * ([[self controlView] frame].size.width - 8);
  
  NSRect leftRect = rect;
  leftRect.size.width = leftWidth;
  
  // Use system colors for modern appearance that adapts to light/dark mode
  NSBezierPath *bar = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
  [[NSColor tertiaryLabelColor] setFill];
  [bar fill];
  
  NSBezierPath *barLeft = [NSBezierPath bezierPathWithRoundedRect: leftRect xRadius:radius yRadius:radius];
  [[NSColor controlAccentColor] setFill];
  [barLeft fill];
}

@end
