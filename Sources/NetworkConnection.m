/**
 * @file NetworkConnection.m
 * @brief Network connectivity monitoring (simplified for macOS 15+)
 */

#import "NetworkConnection.h"

@implementation NetworkConnection

- (id) init {
  // Network monitoring simplified - modern macOS handles connectivity well
  // If needed in future, use Network framework's NWPathMonitor
  return self;
}

- (void) dealloc {
  // No cleanup needed
}

@end
