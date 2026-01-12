//
//  MainSplitViewController.m
//  Hermes
//

#import "MainSplitViewController.h"

@interface MainSplitViewController ()
@property (nonatomic, strong) NSSplitViewItem *sidebarItem;
@property (nonatomic, strong) NSSplitViewItem *contentItem;
@property (nonatomic, strong) NSViewController *sidebarViewController;
@property (nonatomic, strong) NSViewController *contentViewController;
@property (nonatomic, strong) NSView *stationsContainerView;
@property (nonatomic, strong) NSView *historyContainerView;
@end

@implementation MainSplitViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _sidebarMode = SidebarModeStations;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create sidebar view controller
    self.sidebarViewController = [[NSViewController alloc] init];
    NSView *sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 250, 400)];
    self.sidebarViewController.view = sidebarView;
    
    self.sidebarItem = [NSSplitViewItem sidebarWithViewController:self.sidebarViewController];
    self.sidebarItem.minimumThickness = 200;
    self.sidebarItem.maximumThickness = 400;
    self.sidebarItem.canCollapse = YES;
    
    // Create content view controller
    self.contentViewController = [[NSViewController alloc] init];
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
    self.contentViewController.view = contentView;
    
    self.contentItem = [NSSplitViewItem splitViewItemWithViewController:self.contentViewController];
    
    // Add items to split view
    [self addSplitViewItem:self.sidebarItem];
    [self addSplitViewItem:self.contentItem];
    
    // Configure split view
    self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.splitView.autosaveName = @"MainSplitView";
}

- (void)setSidebarContentView:(NSView *)view {
    _sidebarContentView = view;
    
    // Remove old content
    for (NSView *subview in [self.sidebarViewController.view subviews]) {
        [subview removeFromSuperview];
    }
    
    // Add new content
    if (view) {
        [self.sidebarViewController.view addSubview:view];
        view.frame = self.sidebarViewController.view.bounds;
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
}

- (void)setMainContentView:(NSView *)view {
    _mainContentView = view;
    
    // Remove old content
    for (NSView *subview in [self.contentViewController.view subviews]) {
        [subview removeFromSuperview];
    }
    
    // Add new content
    if (view) {
        [self.contentViewController.view addSubview:view];
        view.frame = self.contentViewController.view.bounds;
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
}

- (void)showStationsSidebar {
    if (self.sidebarMode != SidebarModeStations) {
        self.sidebarMode = SidebarModeStations;
        // Trigger sidebar content update in app delegate
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SidebarModeChanged" object:self];
    }
    [self.sidebarItem setCollapsed:NO];
}

- (void)showHistorySidebar {
    if (self.sidebarMode != SidebarModeHistory) {
        self.sidebarMode = SidebarModeHistory;
        // Trigger sidebar content update in app delegate
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SidebarModeChanged" object:self];
    }
    [self.sidebarItem setCollapsed:NO];
}

- (void)toggleSidebar {
    [self.sidebarItem setCollapsed:!self.sidebarItem.isCollapsed];
}

- (void)setSidebarWidth:(CGFloat)width {
    if (!self.sidebarItem.isCollapsed && width >= self.sidebarItem.minimumThickness && width <= self.sidebarItem.maximumThickness) {
        // Force the sidebar to a specific width
        NSRect frame = self.sidebarViewController.view.frame;
        frame.size.width = width;
        [self.sidebarViewController.view setFrame:frame];
    }
}

- (BOOL)isSidebarCollapsed {
    return self.sidebarItem.isCollapsed;
}

@end
