#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// عرض قائمة الإعدادات اليسار (بالنقاط)
#define SIDEBAR_W 320.0
// إنزال السيرش (بالنقاط)
#define SEARCH_DY 11.0

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic) int cellType;
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end

@interface PSListController : NSObject
- (void)setSpecifiers:(NSArray *)specs;
- (NSIndexPath *)indexPathForSpecifier:(id)spec;
- (NSArray *)specifiers;
@end

@interface S26Pill : UIView
@end
@implementation S26Pill
- (void)layoutSubviews {
  [super layoutSubviews];
  self.layer.cornerRadius = self.bounds.size.height / 2.0;
  self.layer.masksToBounds = YES;
}
@end

static NSMutableArray *gAppsRows;
static PSSpecifier *gAppsSpec;

static UIColor *sideBG(void) {
  return [UIColor colorWithRed:25/255.0 green:29/255.0 blue:32/255.0 alpha:1];
}

static UIImage *appsIcon(void) {
  UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(29, 29)];
  return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef c = ctx.CGContext;
    CGContextSaveGState(c);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29, 29) cornerRadius:6.5] addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = {140/255.0, 126/255.0, 238/255.0, 1,
                        100/255.0,  84/255.0, 234/255.0, 1};
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(14.5, 0), CGPointMake(14.5, 29), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(c);

    CGFloat cols[9][3] = {
      {108, 191, 128}, {236, 201, 108}, {227, 148, 108},
      {206,  79, 108}, {225, 225, 240}, {193,  88, 139},
      {157,  85, 236}, { 95, 129, 255}, {124, 170, 239}
    };
    for (int i = 0; i < 9; i++) {
      CGRect rc = CGRectMake(4.5 + (i % 3) * 7.5, 4.5 + (i / 3) * 7.5, 5.8, 5.8);
      [[UIColor colorWithRed:cols[i][0]/255.0 green:cols[i][1]/255.0 blue:cols[i][2]/255.0 alpha:1] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:rc cornerRadius:1.6] fill];
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
    vc.edgesForExtendedLayout = UIRectEdgeAll;
    vc.extendedLayoutIncludesOpaqueBars = YES;
    if ([tv isKindOfClass:[UITableView class]]) {
      tv.backgroundColor = bg;
      tv.separatorStyle = UITableViewCellSeparatorStyleNone;
      tv.sectionHeaderTopPadding = 0;
      tv.sectionHeaderHeight = 10;
      tv.sectionFooterHeight = 0.01;
      tv.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
      tv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
      if (!CGRectEqualToRect(tv.frame, vc.view.bounds)) tv.frame = vc.view.bounds;
    }
    UISplitViewController *sv = vc.splitViewController;
    if (sv && !objc_getAssociatedObject(sv, "s26sv")) {
      objc_setAssociatedObject(sv, "s26sv", @YES, OBJC_ASSOCIATION_RETAIN);
      sv.minimumPrimaryColumnWidth = SIDEBAR_W;
      sv.maximumPrimaryColumnWidth = SIDEBAR_W;
      sv.preferredPrimaryColumnWidth = SIDEBAR_W;
    }
    UINavigationController *nc = vc.navigationController;
    if (nc) {
      nc.view.backgroundColor = bg;
      nc.navigationBar.prefersLargeTitles = NO;
      nc.navigationBar.translucent = YES;
      if (!objc_getAssociatedObject(nc, "s26nav")) {
        objc_setAssociatedObject(nc, "s26nav", @YES, OBJC_ASSOCIATION_RETAIN);
        UINavigationBarAppearance *edge = [UINavigationBarAppearance new];
        [edge configureWithOpaqueBackground];
        edge.backgroundColor = bg;
        edge.shadowColor = [UIColor clearColor];
        UINavigationBarAppearance *std = [UINavigationBarAppearance new];
        [std configureWithTransparentBackground];
        std.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        std.backgroundColor = [UIColor colorWithRed:25/255.0 green:29/255.0 blue:32/255.0 alpha:0.78];
        std.shadowColor = [UIColor clearColor];
        nc.navigationBar.standardAppearance = std;
        nc.navigationBar.compactAppearance = std;
        nc.navigationBar.scrollEdgeAppearance = edge;
      }
    }
    vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    vc.navigationItem.hidesSearchBarWhenScrolling = NO;
    if (!vc.navigationItem.titleView) vc.navigationItem.titleView = [UIView new];

    UISearchController *sc = vc.navigationItem.searchController;
    if (sc) {
      sc.hidesNavigationBarDuringPresentation = NO;
      sc.automaticallyShowsCancelButton = NO;
    }
    UISearchBar *sb = sc.searchBar;
    if (sb) {
      if (!objc_getAssociatedObject(sb, "s26sb")) {
        objc_setAssociatedObject(sb, "s26sb", @YES, OBJC_ASSOCIATION_RETAIN);
        sb.searchBarStyle = UISearchBarStyleMinimal;
        sb.showsCancelButton = NO;
        [sb setSearchFieldBackgroundImage:[UIImage new] forState:UIControlStateNormal];
      }
      UISearchTextField *tf = sb.searchTextField;
      objc_setAssociatedObject(tf, "s26sf", @YES, OBJC_ASSOCIATION_RETAIN);
      tf.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
      tf.layer.borderWidth = 1;
      tf.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
      tf.layer.cornerRadius = tf.bounds.size.height / 2.0;
      tf.layer.masksToBounds = YES;
      tf.transform = CGAffineTransformMakeTranslation(0, SEARCH_DY);
    }
    if (!objc_getAssociatedObject(vc, "s26kb")) {
      objc_setAssociatedObject(vc, "s26kb", @YES, OBJC_ASSOCIATION_RETAIN);
      __weak UIViewController *wvc = vc;
      [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        UIViewController *v = wvc;
        if (!v) return;
        UISearchController *c = v.navigationItem.searchController;
        if (c && c.isActive && c.searchBar.text.length == 0) c.active = NO;
      }];
    }
  } @catch (NSException *e) {}
}

static void selectCurrent(id selfObj) {
  @try {
    UIViewController *vc = (UIViewController *)selfObj;
    UITableView *tv = [selfObj valueForKey:@"table"];
    if (![tv isKindOfClass:[UITableView class]] || tv.indexPathForSelectedRow) return;
    UISplitViewController *sv = vc.splitViewController;
    if (!sv || sv.viewControllers.count < 2) return;
    UIViewController *det = sv.viewControllers.lastObject;
    if ([det isKindOfClass:[UINavigationController class]])
      det = ((UINavigationController *)det).viewControllers.firstObject;
    NSString *t = det.title.length ? det.title : det.navigationItem.title;
    if (!t.length) return;
    for (PSSpecifier *s in [(PSListController *)selfObj specifiers]) {
      if (s.cellType != 0 && [s.name isEqualToString:t]) {
        NSIndexPath *ip = [(PSListController *)selfObj indexPathForSpecifier:s];
        if (ip) [tv selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
        break;
      }
    }
  } @catch (NSException *e) {}
}

static UITableView *tvOf(UIView *v) {
  UIView *p = v.superview;
  while (p && ![p isKindOfClass:[UITableView class]]) p = p.superview;
  return (UITableView *)p;
}

static BOOL inSidebar(UIView *v) {
  UITableView *tv = tvOf(v);
  Class pc = NSClassFromString(@"PSUIPrefsListController");
  return tv && pc && [tv.delegate isKindOfClass:pc];
}

%hook UISearchBar
- (void)setShowsCancelButton:(BOOL)s {
  if (objc_getAssociatedObject(self, "s26sb")) s = NO;
  %orig(s);
}
- (void)setShowsCancelButton:(BOOL)s animated:(BOOL)a {
  if (objc_getAssociatedObject(self, "s26sb")) s = NO;
  %orig(s, a);
}
%end

%hook UISearchTextField
- (void)layoutSubviews {
  %orig;
  if (objc_getAssociatedObject(self, "s26sf")) {
    self.layer.cornerRadius = self.bounds.size.height / 2.0;
    self.layer.masksToBounds = YES;
  }
}
%end

%hook UISwitch
- (void)layoutSubviews {
  %orig;
  if (inSidebar(self) && CGAffineTransformIsIdentity(self.transform))
    self.transform = CGAffineTransformMakeScale(1.216, 0.887);
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
  %orig;
  if (!inSidebar(self)) return;
  UITableView *tv = tvOf(self);
  self.backgroundColor = [UIColor clearColor];
  if (self.accessoryType != UITableViewCellAccessoryNone) self.accessoryType = UITableViewCellAccessoryNone;

  UIView *sel = self.selectedBackgroundView;
  S26Pill *pill = (S26Pill *)[sel viewWithTag:26026];
  if (![pill isKindOfClass:[S26Pill class]]) {
    sel = [UIView new];
    sel.backgroundColor = [UIColor clearColor];
    pill = [S26Pill new];
    pill.tag = 26026;
    pill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.085];
    [sel addSubview:pill];
    self.selectedBackgroundView = sel;
  }
  sel.frame = self.bounds;
  CGRect full = [self convertRect:tv.bounds fromView:tv];
  CGFloat ph = 51.0;
  pill.frame = CGRectMake(full.origin.x + 22, (self.bounds.size.height - ph) / 2.0, full.size.width - 44, ph);
  [pill setNeedsLayout];

  UIImageView *iv = self.imageView;
  BOOL hasIcon = (iv.image && iv.bounds.size.width > 0 && iv.bounds.size.width <= 34);
  BOOL bigImage = (iv.image && iv.bounds.size.width > 34);
  if (hasIcon) {
    CGRect r = [iv convertRect:iv.bounds toView:tv];
    CGFloat dx = 28.5 - r.origin.x;
    if (dx < 0) { CGRect f = iv.frame; f.origin.x += dx; iv.frame = f; }
  }
  if (!bigImage) {
    UILabel *tl = self.textLabel;
    if (tl.text.length) {
      tl.font = [tl.font fontWithSize:14.4];
      CGFloat target = hasIcon ? 63.5 : 32.5;
      CGRect lr = [tl convertRect:tl.bounds toView:tv];
      CGFloat dx = target - lr.origin.x;
      CGRect f = tl.frame; f.origin.x += dx; f.size.width -= dx; tl.frame = f;
    }
    UILabel *dl = self.detailTextLabel;
    if (dl.text.length) {
      dl.font = [dl.font fontWithSize:14.4];
      CGRect rr = [dl convertRect:dl.bounds toView:tv];
      CGFloat dx2 = 287.7 - CGRectGetMaxX(rr);
      CGRect f2 = dl.frame; f2.origin.x += dx2; dl.frame = f2;
    }
  }
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
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  selectCurrent(self);
  __weak id ws = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    id s = ws;
    if (s) selectCurrent(s);
  });
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
  return 10;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s {
  return 0.01;
}
%end
