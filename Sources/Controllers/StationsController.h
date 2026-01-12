#define LAST_STATION_KEY @"hermes.last-station"

NS_ASSUME_NONNULL_BEGIN

@class FileReader;
@class Station;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@class NSDrawer;
#pragma clang diagnostic pop

@interface StationsController : NSObject <NSTableViewDataSource, NSOutlineViewDataSource> {

  IBOutlet NSView * _Nullable chooseStationView;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  IBOutlet NSDrawer * _Nullable stations;
#pragma clang diagnostic pop
  IBOutlet NSTableView * _Nullable stationsTable;
  IBOutlet NSProgressIndicator * _Nullable stationsRefreshing;

  IBOutlet NSButton * _Nullable playStationButton;
  IBOutlet NSButton * _Nullable deleteStationButton;
  IBOutlet NSButton * _Nullable editStationButton;

  /* New station by searching */
  IBOutlet NSTextField * _Nullable search;
  IBOutlet NSOutlineView * _Nullable results;
  IBOutlet NSProgressIndicator * _Nullable searchSpinner;
  IBOutlet NSImageView * _Nullable errorIndicator;

  /* New station by genres */
  IBOutlet NSOutlineView * _Nullable genres;
  IBOutlet NSProgressIndicator * _Nullable genreSpinner;

  /* Last known results */
  NSDictionary<NSString *, id> *lastResults;
  NSArray<id> *genreResults;

  /* Sorting the station list */
  IBOutlet NSSegmentedControl * _Nullable sort;

  FileReader * _Nullable reader;
}

- (void)showStationsPanel;
- (void)hideStationsPanel;
- (void) showDrawer __attribute__((deprecated("Drawers are deprecated on macOS 10.13+. Use -showStationsPanel instead.")));
- (void) hideDrawer __attribute__((deprecated("Drawers are deprecated on macOS 10.13+. Use -hideStationsPanel instead.")));
- (void) show;
- (void) reset;
- (void) focus;

// Buttons at bottom of drawer
- (IBAction)deleteSelected: (id)sender;
- (IBAction)playSelected: (id)sender;
- (IBAction)editSelected: (id)sender;
- (IBAction)refreshList: (id)sender;
- (IBAction)addStation: (id)sender;

// Actions from new station sheet
- (IBAction)search: (id)sender;
- (IBAction)cancelCreateStation: (id)sender;
- (IBAction)createStation: (id)sender;
- (IBAction)createStationGenre: (id)sender;

- (int) stationIndex: (Station*) station;

@end

NS_ASSUME_NONNULL_END
