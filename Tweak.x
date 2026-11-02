#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic) NSInteger cellType;
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
  if (!name) return NO;
  for (NSString *n in [slot componentsSeparatedByString:@"|"])
    if ([n isEqualToString:name]) return YES;
  return NO;
}

%hook PSUIPrefsListController
- (NSMutableArray *)specifiers {
  NSMutableArray *orig = %orig;
  if (!orig || objc_getAssociatedObject(orig, "s26done")) return orig;

  NSMutableArray *rows = [NSMutableArray array];
  for (PSSpecifier *s in orig) {
    NSLog(@"[Settings26] id=%@ name=%@ type=%ld", s.identifier, s.name, (long)s.cellType);
    if (s.cellType != 0) [rows addObject:s];
  }

  NSUInteger firstIdx = NSNotFound;
  for (NSUInteger i = 0; i < orig.count && firstIdx == NSNotFound; i++)
    for (NSArray *g in layout())
      for (NSString *slot in g)
        if (slotMatches(slot, ((PSSpecifier *)orig[i]).name)) { firstIdx = i; break; }
  if (firstIdx == NSNotFound) return orig;

  NSMutableArray *out = [[orig subarrayWithRange:NSMakeRange(0, firstIdx)] mutableCopy];
  while (out.count && ((PSSpecifier *)out.lastObject).cellType == 0) [out removeLastObject];

  NSMutableSet *used = [NSMutableSet set];
  for (NSArray *g in layout()) {
    NSMutableArray *grp = [NSMutableArray array];
    for (NSString *slot in g)
      for (PSSpecifier *s in rows)
        if (![used containsObject:s] && slotMatches(slot, s.name)) {
          [grp addObject:s]; [used addObject:s]; break;
        }
    if (grp.count) {
      [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
      [out addObjectsFromArray:grp];
    }
  }

  NSMutableArray *rest = [NSMutableArray array];
  for (NSUInteger i = firstIdx; i < orig.count; i++) {
    PSSpecifier *s = orig[i];
    if (s.cellType != 0 && ![used containsObject:s] && s.name.length) [rest addObject:s];
  }
  if (rest.count) {
    [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
    [out addObjectsFromArray:rest];
  }

  [orig setArray:out];
  objc_setAssociatedObject(orig, "s26done", @YES, OBJC_ASSOCIATION_RETAIN);
  return orig;
}
%end
