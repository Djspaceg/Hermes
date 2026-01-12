//
//  MainSplitViewController.h
//  Hermes
//
//  Main split view controller for modern sidebar layout
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, SidebarMode) {
    SidebarModeStations,
    SidebarModeHistory
};

@interface MainSplitViewController : NSSplitViewController

@property (nonatomic, assign) SidebarMode sidebarMode;
@property (nonatomic, strong) NSView *sidebarContentView;
@property (nonatomic, strong) NSView *mainContentView;

- (void)showStationsSidebar;
- (void)showHistorySidebar;
- (void)toggleSidebar;
- (void)setSidebarWidth:(CGFloat)width;
- (BOOL)isSidebarCollapsed;

@end
