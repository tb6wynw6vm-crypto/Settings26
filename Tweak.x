#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic) int cellType;
+ (instancetype)emptyGroupSpecifier;
@end

@interface PSListController : NSObject
- (void)setSpecifiers:(NSArray *)specs;
@end

static NSMutableString *gLog;
static int gCalls = 0;

static void plog(NSString *s) {
  if (!gLog) gLog = [NSMutableString string];
  [gLog appendFormat:@"%@\n", s];
  CFPreferencesSetAppValue(CFSTR("log"), (__bridge CFStringRef)[gLog copy], CFSTR("com.settings26.log"));
  CFPreferencesAppSynchronize(CFSTR("com.settings26.log"));
}

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

static BOOL hasName(NSArray *a, NSString *n) {
  for (PSSpecifier *s in a)
    if ([s respondsToSelector:@selector(name)] && [s.name isEqualToString:n]) return YES;
  return NO;
}

static NSArray *reorder(NSArray *orig) {
  @try {
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
    plog([NSString stringWithFormat:@"EXC %@", e]);
    return orig;
  }
}

static id handle(id self, id o) {
  if (![o isKindOfClass:[NSArray class]]) return o;
  NSArray *a = o;
  if (gCalls < 12) {
    gCalls++;
    plog([NSString stringWithFormat:@"%@ n=%lu wifi=%d bt=%d", NSStringFromClass([self class]), (unsigned long)a.count, hasName(a, @"Wi-Fi"), hasName(a, @"Bluetooth")]);
  }
  if (objc_getAssociatedObject(self, "s26")) return o;
  if (!(hasName(a, @"Wi-Fi") && hasName(a, @"Bluetooth"))) return o;
  objc_setAssociatedObject(self, "s26", @YES, OBJC_ASSOCIATION_RETAIN);
  NSArray *n = reorder(a);
  if (n != a) {
    NSMutableArray *m = [n mutableCopy];
    [self setSpecifiers:m];
    plog(@"REORDERED");
    return m;
  }
  NSMutableString *names = [NSMutableString stringWithString:@"NO MATCH: "];
  for (PSSpecifier *s in a) [names appendFormat:@"%@, ", s.name];
  plog(names);
  return o;
}

%hook PSUIPrefsListController
- (id)specifiers {
  id o = %orig;
  return handle(self, o);
}
%end

%hook PSListController
- (id)specifiers {
  id o = %orig;
  return handle(self, o);
}
%end

%ctor {
  plog(@"loaded");
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    UIViewController *vc = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows)
      if (w.isKeyWindow) vc = w.rootViewController;
    if (!vc) vc = [UIApplication sharedApplication].windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    NSString *t = gLog.length > 700 ? [gLog substringToIndex:700] : (gLog ?: @"empty");
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Settings26 log" message:t preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
  });
}
