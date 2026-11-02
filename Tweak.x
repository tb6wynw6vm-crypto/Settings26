#import <Foundation/Foundation.h>

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic) int cellType;
+ (instancetype)emptyGroupSpecifier;
@end

static NSArray *layout(void) {
  return @[
    @[@"Airplane Mode", @"Wi-Fi", @"Bluetooth", @"Battery"],
    @[@"General", @"Accessibility", @"Appearance", @"Apple Pencil", @"Camera",
      @"Control Center", @"Display & Brightness",
      @"Home Screen & App Library|Home Screen & Dock|Home Screen & Multitasking",
      @"Multitasking & Gestures|Multitasking", @"Search",
      @"Siri|Siri & Search", @"Wallpaper"],
    @[@"Notifications", @"Sounds", @"Focus", @"Screen Time"],
    @[@"Face ID & Passcode|Touch ID & Passcode", @"Privacy & Security|Privacy"],
    @[@"Game Center", @"iCloud", @"Wallet & Apple Pay"],
    @[@"Apps"],
    @[@"Developer"]
  ];
}

static BOOL slotMatches(NSString *slot, NSString *name) {
  if (![name isKindOfClass:[NSString class]]) return NO;
  for (NSString *n in [slot componentsSeparatedByString:@"|"])
    if ([n isEqualToString:name]) return YES;
  return NO;
}

static NSArray *reorder(NSArray *orig) {
  @try {
    if (![orig isKindOfClass:[NSArray class]] || orig.count < 5) return orig;
    NSUInteger firstIdx = NSNotFound;
    for (NSUInteger i = 0; i < orig.count && firstIdx == NSNotFound; i++) {
      PSSpecifier *s = orig[i];
      if (s.cellType == 0) continue;
      for (NSArray *g in layout())
        for (NSString *slot in g)
          if (slotMatches(slot, s.name)) firstIdx = i;
    }
    if (firstIdx == NSNotFound) return orig;

    NSMutableArray *out = [[orig subarrayWithRange:NSMakeRange(0, firstIdx)] mutableCopy];
    while (out.count && ((PSSpecifier *)out.lastObject).cellType == 0) [out removeLastObject];

    NSMutableSet *used = [NSMutableSet set];
    for (NSArray *g in layout()) {
      NSMutableArray *grp = [NSMutableArray array];
      for (NSString *slot in g)
        for (NSUInteger i = firstIdx; i < orig.count; i++) {
          PSSpecifier *s = orig[i];
          if (s.cellType != 0 && ![used containsObject:s] && slotMatches(slot, s.name)) {
            [grp addObject:s]; [used addObject:s]; break;
          }
        }
      if (grp.count) {
        [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
        [out addObjectsFromArray:grp];
      }
    }
    NSMutableArray *rest = [NSMutableArray array];
    for (NSUInteger i = firstIdx; i < orig.count; i++) {
      PSSpecifier *s = orig[i];
      if (s.cellType != 0 && ![used containsObject:s]) [rest addObject:s];
    }
    if (rest.count) {
      [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
      [out addObjectsFromArray:rest];
    }
    return out;
  } @catch (NSException *e) {
    return orig;
  }
}

%hook PSUIPrefsListController
- (void)setSpecifiers:(NSArray *)specs {
  %orig(reorder(specs));
}
%end
