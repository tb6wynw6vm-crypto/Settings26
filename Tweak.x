#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic) int cellType;
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end

@interface PSListController : NSObject
- (void)setSpecifiers:(NSArray *)specs;
@end

static NSMutableArray *gAppsRows;
static PSSpecifier *gAppsSpec;

static UIColor *sideBG(void) {
  return [UIColor colorWithRed:0.106 green:0.118 blue:0.133 alpha:1];
}

static UIImage *appsIcon(void) {
  UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(29, 29)];
  return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [[UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29, 29) cornerRadius:6.5] fill];
    NSArray *cols = @[[UIColor systemOrangeColor], [UIColor systemYellowColor], [UIColor systemGreenColor],
                      [UIColor systemPinkColor], [UIColor whiteColor], [UIColor systemTealColor],
                      [UIColor systemRedColor], [UIColor systemMintColor], [UIColor systemCyanColor]];
    for (int i = 0; i < 9; i++) {
      CGRect rc = CGRectMake(4.5 + (i % 3) * 7.5, 4.5 + (i / 3) * 7.5, 5.5, 5.5);
      [cols[i] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:rc cornerRadius:1.5] fill];
    }
  }];
}

static id s26Specifiers(id self, SEL _cmd) {
  Ivar iv = class_getInstanceVariable(object_getClass(self), "_specifiers");
  id cur = iv ? object_getIvar(self, iv) : nil;
  if (!cur) {
    [(PSListController *)self setSpecifiers:[gAppsRows mutableCopy] ?: [NSMutableArray array]];
    cur = iv ? object_getIvar(self, iv) : nil;
  }
  return cur;
}

static Class appsClass(void) {
  static Class c;
  if (c) return c;
  Class base = NSClassFromString(@"PSListController");
  if (!base) return Nil;
  c = objc_allocateClassPair(base, "S26AppsController", 0);
  if (!c) { c = NSClassFromString(@"S26AppsController"); return c; }
  class_addMethod(c, @selector(specifiers), (IMP)s26Specifiers, "@@:");
  objc_registerClassPair(c);
  return c;
}

static NSArray *layout(void) {
  return @[
    @[@"Airplane Mode", @"Wi-Fi", @"Bluetooth", @"Battery", @"VPN"],
    @[@"General", @"Accessibility", @"Appearance", @"Apple Pencil", @"Camera",
      @"Control Center", @"Display & Brightness",
      @"Home Screen & App Library|Home Screen & Dock|Home Screen & Multitasking",
      @"Multitasking & Gestures|Multitasking", @"Search",
      @"Siri|Siri & Search", @"Wallpaper"],
    @[@"Notifications", @"Sounds", @"Focus", @"Screen Time"],
    @[@"Face ID & Passcode|Touch ID & Passcode", @"Privacy & Security|Privacy"],
    @[@"Game Center", @"iCloud", @"Wallet & Apple Pay"],
    @[@"__APPS__"],
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

static NSArray *reorder(id owner, NSArray *orig) {
  @try {
    BOOL incr = (gAppsSpec && [orig containsObject:gAppsSpec]);
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
    NSMutableArray *groups = [NSMutableArray array];
    for (NSArray *g in layout()) {
      NSMutableArray *grp = [NSMutableArray array];
      for (NSString *slot in g) {
        if ([slot isEqualToString:@"__APPS__"]) { [grp addObject:slot]; continue; }
        for (NSUInteger i = firstIdx; i < orig.count; i++) {
          PSSpecifier *s = orig[i];
          if (s.cellType != 0 && ![used containsObject:s] && slotMatches(slot, s.name)) {
            [grp addObject:s]; [used addObject:s]; break;
          }
        }
      }
      [groups addObject:grp];
    }

    NSMutableArray *rest = [NSMutableArray array];
    for (NSUInteger i = firstIdx; i < orig.count; i++) {
      PSSpecifier *s = orig[i];
      if (s == gAppsSpec) continue;
      if (s.cellType != 0 && ![used containsObject:s]) [rest addObject:s];
    }

    NSMutableArray *all = [NSMutableArray array];
    if (incr) {
      for (PSSpecifier *x in gAppsRows)
        if (x.cellType != 0 && ![rest containsObject:x]) [all addObject:x];
    }
    [all addObjectsFromArray:rest];

    PSSpecifier *appsSpec = nil;
    Class ac = appsClass();
    if (all.count && ac) {
      gAppsRows = [NSMutableArray array];
      [gAppsRows addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
      [gAppsRows addObjectsFromArray:all];
      if (!incr || !gAppsSpec) {
        gAppsSpec = [%c(PSSpecifier) preferenceSpecifierNamed:@"Apps" target:owner set:NULL get:NULL detail:ac cell:2 edit:Nil];
        [gAppsSpec setProperty:appsIcon() forKey:@"iconImage"];
        [gAppsSpec setProperty:@"S26_APPS" forKey:@"id"];
      }
      appsSpec = gAppsSpec;
    }

    for (NSMutableArray *grp in groups) {
      NSMutableArray *fin = [NSMutableArray array];
      for (id x in grp) {
        if ([x isKindOfClass:[NSString class]]) { if (appsSpec) [fin addObject:appsSpec]; }
        else [fin addObject:x];
      }
      if (fin.count) {
        [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
        [out addObjectsFromArray:fin];
      }
    }
    if (!appsSpec && all.count) {
      [out addObject:[%c(PSSpecifier) emptyGroupSpecifier]];
      [out addObjectsFromArray:all];
    }
    return out;
  } @catch (NSException *e) {
    return orig;
  }
}

static id handle(id self, id o) {
  if (![o isKindOfClass:[NSArray class]]) return o;
  NSArray *a = o;
  if (!(hasName(a, @"Wi-Fi") && hasName(a, @"Bluetooth"))) return o;
  NSNumber *last = objc_getAssociatedObject(self, "s26cnt");
  if (last && last.unsignedIntegerValue == a.count) return o;
  NSArray *n = reorder(self, a);
  if (n != a) {
    NSMutableArray *m = [n mutableCopy];
    objc_setAssociatedObject(self, "s26cnt", @(m.count), OBJC_ASSOCIATION_RETAIN);
    [self setSpecifiers:m];
    return m;
  }
  return o;
}

static void styleSidebar(id selfObj) {
  @try {
    UIViewController *vc = (UIViewController *)selfObj;
    UITableView *tv = [selfObj valueForKey:@"table"];
    UIColor *bg = sideBG();
    vc.view.backgroundColor = bg;
    if ([tv isKindOfClass:[UITableView class]]) {
      tv.backgroundColor = bg;
      tv.separatorStyle = UITableViewCellSeparatorStyleNone;
      tv.sectionHeaderTopPadding = 0;
      tv.sectionHeaderHeight = 14;
      tv.sectionFooterHeight = 8;
    }
    UINavigationController *nc = vc.navigationController;
    if (nc) {
      nc.view.backgroundColor = bg;
      nc.navigationBar.prefersLargeTitles = NO;
      if (!objc_getAssociatedObject(nc, "s26nav")) {
        objc_setAssociatedObject(nc, "s26nav", @YES, OBJC_ASSOCIATION_RETAIN);
        UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
        [ap configureWithTransparentBackground];
        ap.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        ap.backgroundColor = [UIColor clearColor];
        ap.shadowColor = [UIColor clearColor];
        nc.navigationBar.standardAppearance = ap;
        nc.navigationBar.scrollEdgeAppearance = ap;
        nc.navigationBar.compactAppearance = ap;
      }
    }
    vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    vc.navigationItem.hidesSearchBarWhenScrolling = NO;
    if (!vc.navigationItem.titleView) vc.navigationItem.titleView = [UIView new];
    UISearchBar *sb = vc.navigationItem.searchController.searchBar;
    if (sb) {
      sb.searchBarStyle = UISearchBarStyleMinimal;
      UISearchTextField *tf = sb.searchTextField;
      tf.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
      tf.layer.borderWidth = 1;
      tf.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
      objc_setAssociatedObject(tf, "s26sf", @YES, OBJC_ASSOCIATION_RETAIN);
      tf.layer.cornerRadius = 22;
      tf.layer.masksToBounds = YES;
    }
  } @catch (NSException *e) {}
}

static BOOL isSidebarCell(UITableViewCell *cell) {
  UIView *v = cell.superview;
  while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
  UITableView *tv = (UITableView *)v;
  Class pc = NSClassFromString(@"PSUIPrefsListController");
  return tv && pc && [tv.delegate isKindOfClass:pc];
}

%hook UISearchTextField
- (void)layoutSubviews {
  %orig;
  if (objc_getAssociatedObject(self, "s26sf")) {
    self.layer.cornerRadius = self.bounds.size.height / 2.0;
    self.layer.masksToBounds = YES;
  }
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
  %orig;
  if (!isSidebarCell(self)) return;
  self.backgroundColor = [UIColor clearColor];
  if (self.accessoryType != UITableViewCellAccessoryNone) self.accessoryType = UITableViewCellAccessoryNone;
  UIView *sel = self.selectedBackgroundView;
  UIView *pill = [sel viewWithTag:26026];
  if (!pill) {
    sel = [UIView new];
    sel.backgroundColor = [UIColor clearColor];
    pill = [UIView new];
    pill.tag = 26026;
    pill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    [sel addSubview:pill];
    self.selectedBackgroundView = sel;
  }
  sel.frame = self.bounds;
  pill.frame = CGRectInset(sel.bounds, 8, 2);
  pill.layer.cornerRadius = pill.bounds.size.height / 2.0;
}
%end

%hook PSUIPrefsListController
- (id)specifiers {
  id o = %orig;
  return handle(self, o);
}
- (void)viewWillAppear:(BOOL)animated {
  %orig;
  styleSidebar(self);
}
- (void)viewDidLayoutSubviews {
  %orig;
  styleSidebar(self);
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
  CGFloat h = %orig;
  if (s > 0 && (h < 0 || h > 14)) return 14;
  return h;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s {
  CGFloat h = %orig;
  if (h < 0 || h > 8) return 8;
  return h;
}
%end
