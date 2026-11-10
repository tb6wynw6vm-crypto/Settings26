// Settings26 v1.6 — iPadOS 26 look for Settings on iPadOS 16 (rootless)
// Sidebar: PSSplitViewController > UINavigationController > PSUIPrefsListController > UITableView
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface PSSplitViewController : UISplitViewController
@end
@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) id target;
@property (nonatomic, assign) Class detailControllerClass;
@property (nonatomic, assign) NSInteger cellType;
@property (nonatomic, assign) SEL controllerLoadAction;
@property (nonatomic, retain) NSMutableDictionary *properties;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get
                                  detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (void)setButtonAction:(SEL)action;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end
@interface PSListController : UIViewController
@property (nonatomic, retain) PSSpecifier *specifier;
- (NSMutableArray *)specifiers;
- (void)setSpecifiers:(NSArray *)specifiers;
- (void)reloadSpecifiers;
@end
@interface PSUIPrefsListController : PSListController
@end

#pragma mark - Measurements (taken from the iPadOS 26 reference)

static const CGFloat kSectionRadius   = 26.0;  // detail sections + header card
static const CGFloat kPanelRadius     = 34.0;  // floating sidebar
static const CGFloat kPanelSide       = 12.0;
static const CGFloat kPanelTop        = 10.0;
static const CGFloat kPanelClipTop    = 22.0;  // hides the empty title row above the search field
static const CGFloat kPanelBottom     = 12.0;
static const CGFloat kSearchHeight    = 42.0;
static char kSidebarSCKey;
static const CGFloat kHeaderIcon      = 58.0;
static const CGFloat kHeaderPad       = 20.0;

static const NSInteger kPanelTag      = 0x2601;
static const NSInteger kCapsuleTag    = 0x2602;
static char kSearchStyledKey;
static char kHeaderKey;
static char kHeaderPendingKey;
static char kHeaderMergeKey;
static char kSidebarBarKey;
static const NSInteger kFadeTag = 0x2607;
static const NSInteger kHeaderWrapTag = 0x2603;

#pragma mark - Colors

static UIColor *LGDyn(UIColor *dark, UIColor *light) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
    }];
}
static UIColor *LGPanelColor(void) {
    return LGDyn([UIColor colorWithRed:20/255.0 green:20/255.0 blue:22/255.0 alpha:1],
                 [UIColor colorWithRed:242/255.0 green:242/255.0 blue:247/255.0 alpha:1]);
}
static UIColor *LGCapsuleColor(void) {
    return LGDyn([UIColor colorWithWhite:1 alpha:0.10], [UIColor colorWithWhite:0 alpha:0.07]);
}
static UIColor *LGBorderColor(void) {
    return LGDyn([UIColor colorWithWhite:1 alpha:0.08], [UIColor colorWithWhite:0 alpha:0.06]);
}

#pragma mark - Helpers

static UIViewController *LGOwnerVC(UIView *v) {
    UIResponder *r = v;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = r.nextResponder;
    return (UIViewController *)r;
}
static UITableView *LGTableViewFor(UIView *v) {
    UIView *s = v.superview;
    while (s && ![s isKindOfClass:[UITableView class]]) s = s.superview;
    return (UITableView *)s;
}
static id LGFind(UIView *root, Class cls) {
    if ([root isKindOfClass:cls]) return root;
    for (UIView *sub in root.subviews) {
        id f = LGFind(sub, cls);
        if (f) return f;
    }
    return nil;
}
static BOOL LGIsSidebarTable(UITableView *tv) {
    static Class sidebarClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sidebarClass = NSClassFromString(@"PSUIPrefsListController"); });
    if (!tv || !sidebarClass) return NO;
    return [LGOwnerVC(tv) isKindOfClass:sidebarClass];
}

static UIImage *LGCapsuleImage(CGFloat h, UIColor *fill) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(h + 2, h)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [fill setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, h + 2, h) cornerRadius:h / 2.0] fill];
    }];
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(h / 2.0, h / 2.0, h / 2.0, h / 2.0)];
}

// Circular glass back button
static UIImage *LGBackImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGFloat d = 44.0;
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d)];
        img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0.5, 0.5, d - 1, d - 1)];
            [[UIColor colorWithRed:38/255.0 green:38/255.0 blue:40/255.0 alpha:1] setFill];
            [c fill];
            [[UIColor colorWithWhite:1 alpha:0.12] setStroke];
            c.lineWidth = 0.75;
            [c stroke];
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            UIImage *chev = [[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg]
                imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            CGSize s = chev.size;
            [chev drawInRect:CGRectMake((d - s.width) / 2.0 - 1.0, (d - s.height) / 2.0, s.width, s.height)];
        }];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return img;
}

#pragma mark - Back button

@interface LGPopDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UINavigationController *nav;
@end
@implementation LGPopDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    return self.nav.viewControllers.count > 1 && self.nav.transitionCoordinator == nil;
}
@end

static char kPopDelegateKey;
static const NSInteger kBackItemTag = 0x2605;

static void LGInstallBackButton(UIViewController *vc) {
    UINavigationController *nav = vc.navigationController;
    if (!nav || nav.viewControllers.firstObject == vc) return;
    if (vc.navigationItem.leftBarButtonItem.tag == kBackItemTag) return;
    if (vc.navigationItem.leftBarButtonItem) return; // pane has its own left button, leave it

    __weak UINavigationController *wnav = nav;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom
                             primaryAction:[UIAction actionWithHandler:^(UIAction *a) {
        [wnav popViewControllerAnimated:YES];
    }]];
    [b setImage:LGBackImage() forState:UIControlStateNormal];
    b.frame = CGRectMake(0, 0, 44, 44);
    [b.widthAnchor constraintEqualToConstant:44].active = YES;
    [b.heightAnchor constraintEqualToConstant:44].active = YES;
    b.accessibilityLabel = @"Back";

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:b];
    item.tag = kBackItemTag;
    vc.navigationItem.hidesBackButton = YES;
    vc.navigationItem.leftBarButtonItem = item;

    // Keep swipe-to-go-back working with a custom left button
    LGPopDelegate *d = objc_getAssociatedObject(nav, &kPopDelegateKey);
    if (!d) {
        d = [LGPopDelegate new];
        d.nav = nav;
        objc_setAssociatedObject(nav, &kPopDelegateKey, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    nav.interactivePopGestureRecognizer.delegate = d;
    nav.interactivePopGestureRecognizer.enabled = YES;
}

#pragma mark - Sidebar search field (capsule + mic)

static BOOL LGIsSidebarSearch(UIView *v) {
    Class side = NSClassFromString(@"PSUIPrefsListController");
    if (!side) return NO;
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:side]) return YES;
        if ([r isKindOfClass:[UINavigationController class]])
            return [((UINavigationController *)r).viewControllers.firstObject isKindOfClass:side];
        r = r.nextResponder;
    }
    return NO;
}

static void LGStyleSearchBar(UISearchBar *sb) {
    if (!sb) return;
    UISearchTextField *tf = sb.searchTextField;

    if (!objc_getAssociatedObject(sb, &kSearchStyledKey)) {
        objc_setAssociatedObject(sb, &kSearchStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sb setSearchFieldBackgroundImage:LGCapsuleImage(kSearchHeight, [UIColor colorWithRed:38/255.0 green:38/255.0 blue:41/255.0 alpha:0.97])
                                 forState:UIControlStateNormal];
        tf.backgroundColor = UIColor.clearColor;
        tf.font = [UIFont systemFontOfSize:17];
        [sb setPositionAdjustment:UIOffsetMake(8, 0) forSearchBarIcon:UISearchBarIconSearch];
        sb.searchTextPositionAdjustment = UIOffsetMake(4, 0);

        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        UIImage *mic = [[UIImage systemImageNamed:@"mic" withConfiguration:cfg]
            imageWithTintColor:[UIColor colorWithWhite:0.92 alpha:1] renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIImageView *iv = [[UIImageView alloc] initWithImage:mic];
        iv.contentMode = UIViewContentModeCenter;
        iv.frame = CGRectMake(0, 0, 40, 30);
        tf.rightView = iv;
        tf.rightViewMode = UITextFieldViewModeUnlessEditing;

        __weak UISearchBar *wsb = sb;
        [tf addAction:[UIAction actionWithHandler:^(UIAction *a) {
            UISearchBar *bar = wsb;
            if (!bar || bar.searchTextField.text.length) return;
            UIResponder *r = bar;
            while (r && ![r isKindOfClass:[UINavigationController class]]) r = r.nextResponder;
            UISearchController *sc = ((UINavigationController *)r).viewControllers.firstObject.navigationItem.searchController;
            if (sc.isActive) sc.active = NO;
        }] forControlEvents:UIControlEventEditingDidEnd];
    }

    // Capsule even if the background image is ignored
    CGFloat r = tf.bounds.size.height / 2.0;
    if (r > 0 && fabs(tf.layer.cornerRadius - r) > 0.5) {
        tf.layer.cornerRadius = r;
        tf.layer.cornerCurve = kCACornerCurveCircular;
        tf.clipsToBounds = YES;
    }
}

#pragma mark - Floating sidebar panel

static BOOL gLGSidebarBusy;
static void LGStyleSidebarImpl(UISplitViewController *split);
static NSString *LGNormalizeTitle(NSString *s);
static NSString *gLGSelectedName; // sidebar row shown as selected (kept even when UIKit drops the selection)
// Detail tables are widened to 20pt from each side (see LGWideTable); cards use the same frame
static CGRect LGSectionRect(UITableView *tv) {
    CGFloat W = tv.bounds.size.width;
    if (W >= 600) return CGRectMake(20, 0, W - 40, 0);
    UITableViewCell *c0 = tv.visibleCells.firstObject;
    if (c0.bounds.size.width > 100) return CGRectMake(c0.frame.origin.x, 0, c0.frame.size.width, 0);
    return CGRectMake(20, 0, MAX(0, W - 40), 0);
}
static void LGStyleSidebar(UISplitViewController *split) {
    if (gLGSidebarBusy) return;
    gLGSidebarBusy = YES;
    LGStyleSidebarImpl(split);
    gLGSidebarBusy = NO;
}
static char kLastDetailKey;
static void LGStyleSidebarCell(UITableViewCell *cell);
static void LGRestyleSidebar(UITableView *side);
static UILabel *LGCellTitleLabel(UITableViewCell *cell);
static void LGStyleSidebarImpl(UISplitViewController *split) {
    UIColor *bg = UIColor.systemBackgroundColor; // black in dark mode, like the reference
    if (![split.view.backgroundColor isEqual:bg]) split.view.backgroundColor = bg;
    if (split.isCollapsed || split.viewControllers.count < 1) return;
    if (split.primaryColumnWidth <= 0 || split.primaryColumnWidth > split.view.bounds.size.width * 0.6) return;

    if (split.primaryBackgroundStyle != UISplitViewControllerBackgroundStyleNone)
        split.primaryBackgroundStyle = UISplitViewControllerBackgroundStyleNone;

    UIViewController *master = split.viewControllers.firstObject;
    UIView *mv = master.view;
    if (!mv) return;

    UINavigationController *detailNav = [split.viewControllers.lastObject isKindOfClass:[UINavigationController class]]
                                      ? split.viewControllers.lastObject : nil;
    UIViewController *detailRoot = detailNav.viewControllers.firstObject;
    if (detailRoot && objc_getAssociatedObject(split, &kLastDetailKey) != detailRoot) {
        objc_setAssociatedObject(split, &kLastDetailKey, detailRoot, OBJC_ASSOCIATION_ASSIGN);
        NSString *shown = [detailRoot isKindOfClass:NSClassFromString(@"PSListController")]
                        ? LGNormalizeTitle(((PSListController *)detailRoot).specifier.name ?: detailRoot.title ?: @"")
                        : LGNormalizeTitle(detailRoot.title ?: @"");
        if ([shown isEqualToString:@"Siri & Search"]) shown = @"Siri";
        UITableView *side = LGFind(mv, [UITableView class]);
        BOOL known = NO;
        for (UITableViewCell *c in side.visibleCells)
            if ([LGNormalizeTitle(LGCellTitleLabel(c).text ?: @"") isEqualToString:shown]) { known = YES; break; }
        if (!known && [master isKindOfClass:[UINavigationController class]]) {
            PSListController *root = (PSListController *)((UINavigationController *)master).viewControllers.firstObject;
            if ([root respondsToSelector:@selector(specifiers)])
                for (PSSpecifier *sp in [root specifiers])
                    if ([LGNormalizeTitle(sp.name ?: @"") isEqualToString:shown]) { known = YES; break; }
        }
        if (known && shown.length && ![shown isEqualToString:gLGSelectedName] && ![gLGSelectedName isEqualToString:@"iCloud"]) {
            gLGSelectedName = shown;
            LGRestyleSidebar(side);
        }
    }

    CGFloat colW = split.primaryColumnWidth;
    CGFloat H    = split.view.bounds.size.height;
    CGFloat top  = split.view.safeAreaInsets.top + kPanelTop;

    // Kill the grey column background around the panel
    UIView *container = mv.superview;
    if (![container.backgroundColor isEqual:bg]) container.backgroundColor = bg;
    for (UIView *v in container.subviews) {
        if (v == mv || v.bounds.size.width < 1) continue;
        if (CGRectGetMinX(v.frame) < 1 && CGRectGetMaxX(v.frame) <= colW + 1) {
            if ([v isKindOfClass:[UIVisualEffectView class]]) { if (!v.hidden) v.hidden = YES; }
            else if (![v.backgroundColor isEqual:bg]) v.backgroundColor = bg;
        }
    }

    // The nav view is taller than the visible panel; its top kPanelClipTop points are masked off
    CGFloat panelW = colW - kPanelSide * 2.0;
    CGFloat panelH = H - top - kPanelBottom;
    if (panelW <= 0 || panelH <= 0) return;
    CGRect target = CGRectMake(kPanelSide, top - kPanelClipTop, panelW, panelH + kPanelClipTop);
    if (!CGRectEqualToRect(mv.frame, target)) mv.frame = target;

    if (![mv.backgroundColor isEqual:UIColor.clearColor]) mv.backgroundColor = UIColor.clearColor;
    if (mv.layer.cornerRadius != 0) mv.layer.cornerRadius = 0;
    if (mv.layer.borderWidth != 0) mv.layer.borderWidth = 0;
    if (mv.clipsToBounds) mv.clipsToBounds = NO;

    CGRect visible = CGRectMake(0, kPanelClipTop, panelW, panelH);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:visible cornerRadius:kPanelRadius];

    CAShapeLayer *mask = [mv.layer.mask isKindOfClass:[CAShapeLayer class]] ? (CAShapeLayer *)mv.layer.mask : nil;
    if (!mask) { mask = [CAShapeLayer layer]; mv.layer.mask = mask; }
    if (!CGRectEqualToRect(mask.frame, mv.bounds)) mask.frame = mv.bounds;
    if (!CGPathEqualToPath(mask.path, path.CGPath)) mask.path = path.CGPath;

    UIView *panel = [mv viewWithTag:kPanelTag];
    if (!panel) {
        panel = [UIView new];
        panel.tag = kPanelTag;
        panel.userInteractionEnabled = NO;
        [mv insertSubview:panel atIndex:0];
    } else if (mv.subviews.firstObject != panel) {
        [mv sendSubviewToBack:panel];
    }
    if (!CGRectEqualToRect(panel.frame, mv.bounds)) panel.frame = mv.bounds;
    UITraitCollection *traits = split.view.window ? split.view.window.traitCollection : UIScreen.mainScreen.traitCollection;
    UIColor *panelNow = [LGPanelColor() resolvedColorWithTraitCollection:traits];
    if (![panel.backgroundColor isEqual:panelNow]) panel.backgroundColor = panelNow;

    // Hairline border drawn on the visible rounded rect
    CAShapeLayer *border = nil;
    for (CALayer *l in panel.layer.sublayers) if ([l.name isEqualToString:@"LGBorder"]) border = (CAShapeLayer *)l;
    if (!border) {
        border = [CAShapeLayer layer];
        border.name = @"LGBorder";
        border.fillColor = UIColor.clearColor.CGColor;
        border.lineWidth = 1.0;
        [panel.layer addSublayer:border];
    }
    border.strokeColor = [LGBorderColor() resolvedColorWithTraitCollection:mv.traitCollection].CGColor;
    if (!CGPathEqualToPath(border.path, path.CGPath)) border.path = path.CGPath;

    UITableView *tv0 = nil;
    if ([master isKindOfClass:[UINavigationController class]])
        tv0 = LGFind(((UINavigationController *)master).viewControllers.firstObject.view, [UITableView class]);

    if ([master isKindOfClass:[UINavigationController class]]) {
        UINavigationBar *bar = ((UINavigationController *)master).navigationBar;
        // Opaque panel-colored bar: rows slide under the search field without the grey blur band
        if (!objc_getAssociatedObject(bar, &kSidebarBarKey)) {
            objc_setAssociatedObject(bar, &kSidebarBarKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
            [ap configureWithTransparentBackground];
            ap.shadowColor = UIColor.clearColor;
            bar.standardAppearance = ap;
            bar.compactAppearance = ap;
            bar.scrollEdgeAppearance = ap;
        }
        // Fade: opaque above the search field, see-through behind it, clear just below it
        UIView *fadeView = (bar.superview == mv) ? [mv viewWithTag:kFadeTag] : nil;
        if (bar.superview == mv) {
        if (!fadeView) {
            fadeView = [UIView new];
            fadeView.tag = kFadeTag;
            fadeView.userInteractionEnabled = NO;
            [mv insertSubview:fadeView belowSubview:bar];
        } else if ([mv.subviews indexOfObject:fadeView] + 1 != [mv.subviews indexOfObject:bar]) {
            [mv insertSubview:fadeView belowSubview:bar];
        }
        // The colour is a dynamic UIColor on the view; the gradient only shapes alpha (mask),
        // so a light-mode snapshot taken when leaving Settings can't freeze it white.
        UIColor *fadeNow = [LGPanelColor() resolvedColorWithTraitCollection:
                               mv.window ? mv.window.traitCollection : UIScreen.mainScreen.traitCollection];
        if (![fadeView.backgroundColor isEqual:fadeNow]) fadeView.backgroundColor = fadeNow;
        if (fadeView.hidden) fadeView.hidden = NO;
        CAGradientLayer *mask = (CAGradientLayer *)fadeView.layer.mask;
        if (![mask isKindOfClass:[CAGradientLayer class]]) {
            for (CALayer *l in [fadeView.layer.sublayers copy]) [l removeFromSuperlayer];
            mask = [CAGradientLayer layer];
            fadeView.layer.mask = mask;
        }
        CGFloat barBottom = CGRectGetMaxY(bar.frame);
        CGFloat fadeH = barBottom + 18.0;
        CGRect ff = CGRectMake(0, 0, mv.bounds.size.width, fadeH);
        if (fadeH > 20 && (!CGRectEqualToRect(fadeView.frame, ff) || !mask.colors)) {
            fadeView.frame = ff;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            mask.frame = fadeView.bounds;
            CGFloat searchTop = MAX(0, barBottom - kSearchHeight - 8.0);
            mask.colors = @[(id)UIColor.blackColor.CGColor, (id)UIColor.blackColor.CGColor,
                            (id)[UIColor colorWithWhite:0 alpha:0.78].CGColor,
                            (id)UIColor.clearColor.CGColor];
            mask.locations = @[@0.0, @(searchTop / fadeH), @(barBottom / fadeH), @1.0];
            [CATransaction commit];
        }
        }

        UIViewController *sideRoot = ((UINavigationController *)master).viewControllers.firstObject;
        UISearchController *sc = sideRoot.navigationItem.searchController;
        if (sc && !objc_getAssociatedObject(sc, &kSidebarSCKey))
            objc_setAssociatedObject(sc, &kSidebarSCKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (tv0 && tv0.showsVerticalScrollIndicator) tv0.showsVerticalScrollIndicator = NO;
        if (sideRoot.navigationItem.hidesSearchBarWhenScrolling)
            sideRoot.navigationItem.hidesSearchBarWhenScrolling = NO;
    }

    if ([master isKindOfClass:[UINavigationController class]]) {
        UIViewController *rootVC = ((UINavigationController *)master).topViewController;
        if (![rootVC.view.backgroundColor isEqual:UIColor.clearColor])
            rootVC.view.backgroundColor = UIColor.clearColor;
        UITableView *tv = LGFind(rootVC.view, [UITableView class]);
        if (tv) {
            if (![tv.backgroundColor isEqual:UIColor.clearColor]) tv.backgroundColor = UIColor.clearColor;
            if (tv.backgroundView) tv.backgroundView = nil;
            if (tv.separatorStyle != UITableViewCellSeparatorStyleNone)
                tv.separatorStyle = UITableViewCellSeparatorStyleNone;
        }
    }
}

#pragma mark - Sidebar rows (flat, grey capsule when selected, blue text)

static void LGGlossIcon(UIImageView *iv);
static void LGGlossIconMax(UIImageView *iv, CGFloat maxSide);
static NSMutableDictionary<NSString *, UIImage *> *gLGIconCache;
static NSString *LGNormalizeTitle(NSString *s) {
    if (!s.length) return @"";
    s = [s stringByReplacingOccurrencesOfString:@"\u2011" withString:@"-"];
    s = [s stringByReplacingOccurrencesOfString:@"\u2010" withString:@"-"];
    s = [s stringByReplacingOccurrencesOfString:@"\u00A0" withString:@" "];
    s = [s stringByReplacingOccurrencesOfString:@"\u202F" withString:@" "];
    return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

// title of a sidebar row, also for rows that draw their name in their own label
static UILabel *LGCellTitleLabel(UITableViewCell *cell) {
    if (cell.textLabel.text.length) return cell.textLabel;
    UILabel *best = nil;
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell.contentView];
    while (st.count) {
        UIView *v = st.firstObject; [st removeObjectAtIndex:0];
        [st addObjectsFromArray:v.subviews];
        if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length && !v.hidden) {
            if (!best || ((UILabel *)v).font.pointSize > best.font.pointSize) best = (UILabel *)v;
        }
    }
    return best;
}
#pragma mark - Real iPadOS 26 icons (cropped from the reference screenshots, packed in icons.png)

static NSDictionary<NSString *, NSArray<NSNumber *> *> *LGAtlasMap(void) {
    static NSDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = @{
    @"hdr_ipados": @[@0, @940, @116],
    @"hdr_system_data": @[@116, @940, @116],
    @"ipados": @[@0, @882, @58],
    @"system_data": @[@58, @882, @58],
    @"about": @[@0, @0, @58],
    @"accessibility": @[@58, @0, @58],
    @"accessories": @[@116, @0, @58],
    @"airdrop": @[@174, @0, @58],
    @"airplane_mode": @[@232, @0, @58],
    @"airplay_continuity": @[@290, @0, @58],
    @"analytics_improvements": @[@348, @0, @58],
    @"app_clips": @[@406, @0, @58],
    @"app_privacy_report": @[@464, @0, @58],
    @"apple_advertising": @[@522, @0, @58],
    @"apple_pencil": @[@0, @58, @58],
    @"applecare_warranty": @[@58, @58, @58],
    @"apps": @[@116, @58, @58],
    @"audio_descriptions": @[@174, @58, @58],
    @"autofill_passwords": @[@232, @58, @58],
    @"background_app_refresh": @[@290, @58, @58],
    @"background_security_improvements": @[@348, @58, @58],
    @"battery": @[@406, @58, @58],
    @"blocked_contacts": @[@464, @58, @58],
    @"bluetooth": @[@522, @58, @58],
    @"calendars": @[@0, @116, @58],
    @"camera": @[@58, @116, @58],
    @"contacts": @[@116, @116, @58],
    @"control_center": @[@174, @116, @58],
    @"critical_messages": @[@232, @116, @58],
    @"date_time": @[@290, @116, @58],
    @"default_apps": @[@348, @116, @58],
    @"dictionary": @[@406, @116, @58],
    @"display_brightness": @[@464, @116, @58],
    @"display_text_size": @[@522, @116, @58],
    @"files_folders": @[@0, @174, @58],
    @"focus": @[@58, @174, @58],
    @"fonts": @[@116, @174, @58],
    @"game_center": @[@174, @174, @58],
    @"game_controller": @[@232, @174, @58],
    @"general": @[@290, @174, @58],
    @"hdr_accessibility": @[@0, @464, @116],
    @"hdr_applecare_warranty": @[@116, @464, @116],
    @"hdr_bluetooth": @[@232, @464, @116],
    @"hdr_default_apps": @[@348, @464, @116],
    @"hdr_general": @[@464, @464, @116],
    @"hdr_privacy_security": @[@0, @580, @116],
    @"hdr_siri": @[@116, @580, @116],
    @"hdr_wi_fi": @[@232, @580, @116],
    @"health_data": @[@348, @174, @58],
    @"hidden_apps": @[@406, @174, @58],
    @"home_screen_app_library": @[@464, @174, @58],
    @"hover_text": @[@522, @174, @58],
    @"icloud": @[@0, @232, @58],
    @"ipad_storage": @[@58, @232, @58],
    @"journaling_suggestions": @[@116, @232, @58],
    @"keyboard": @[@174, @232, @58],
    @"language_region": @[@232, @232, @58],
    @"legal_regulatory": @[@290, @232, @58],
    @"local_network": @[@348, @232, @58],
    @"location_services": @[@406, @232, @58],
    @"lockdown_mode": @[@464, @232, @58],
    @"microphone": @[@522, @232, @58],
    @"motion": @[@0, @290, @58],
    @"motion_fitness": @[@58, @290, @58],
    @"multitasking_gestures": @[@116, @290, @58],
    @"notifications": @[@174, @290, @58],
    @"paired_devices": @[@232, @290, @58],
    @"privacy_security": @[@290, @290, @58],
    @"read_speak": @[@348, @290, @58],
    @"screen_capture": @[@406, @290, @58],
    @"screen_time": @[@464, @290, @58],
    @"search": @[@522, @290, @58],
    @"siri": @[@0, @348, @58],
    @"software_update": @[@58, @348, @58],
    @"sounds": @[@116, @348, @58],
    @"speech_recognition": @[@174, @348, @58],
    @"touch_id_passcode": @[@232, @348, @58],
    @"tracking": @[@290, @348, @58],
    @"transfer_or_reset_ipad": @[@348, @348, @58],
    @"tv_provider": @[@406, @348, @58],
    @"voiceover": @[@464, @348, @58],
    @"vpn_device_management": @[@522, @348, @58],
    @"wallet_apple_pay": @[@0, @406, @58],
    @"wallpaper": @[@58, @406, @58],
    @"wi_fi": @[@116, @406, @58],
    @"wired_accessories": @[@174, @406, @58],
    @"zoom": @[@232, @406, @58],
    }; });
    return m;
}

static UIImage *LGAtlas(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *p in @[@"/var/jb/Library/Application Support/Settings26/icons.png",
                              @"/Library/Application Support/Settings26/icons.png"]) {
            img = [UIImage imageWithContentsOfFile:p];
            if (img) break;
        }
        if (img && [img respondsToSelector:@selector(imageByPreparingForDisplay)]) {
            UIImage *ready = [img imageByPreparingForDisplay]; // keeps the Display P3 colors
            if (ready) img = ready;
        }
    });
    return img;
}

static NSString *LGSlug(NSString *t) {
    NSMutableString *o = [NSMutableString new];
    BOOL sep = NO;
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t.lowercaseString characterAtIndex:i];
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
            if (sep && o.length) [o appendString:@"_"];
            [o appendFormat:@"%C", c];
            sep = NO;
        } else sep = YES;
    }
    return o;
}

// iPadOS 16 names -> the iPadOS 26 icon that replaced them
static NSDictionary<NSString *, NSString *> *LGIconAliases(void) {
    return @{ @"Siri & Search": @"Siri",
              @"Home Screen & Multitasking": @"Home Screen & App Library",
              @"Home Screen & Dock": @"Home Screen & App Library",
              @"AirPlay & Handoff": @"AirPlay & Continuity",
              @"Files and Folders": @"Files & Folders",
              @"Health": @"Health Data" };
}

static UIColor *LGHex(uint32_t h);
static void LGDrawTile(CGContextRef cg, CGFloat d, UIColor *fill);
static UIImage *LGDrawnIcon(NSString *title, BOOL large) {
    if (![title isEqualToString:@"Face ID & Passcode"]) return nil;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    NSString *key = [title stringByAppendingString:large ? @"#L" : @"#S"];
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;
    CGFloat d = large ? 58.0 : 29.0;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:d * 0.55 weight:UIImageSymbolWeightMedium];
    UIImage *sym = [[UIImage systemImageNamed:@"faceid" withConfiguration:cfg]
                       imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        LGDrawTile(ctx.CGContext, d, LGHex(0x34C759));
        if (sym) {
            CGSize ss = sym.size;
            CGFloat k = MIN(1.0, d * 0.62 / MAX(ss.width, ss.height));
            CGSize ds = CGSizeMake(ss.width * k, ss.height * k);
            [sym drawInRect:CGRectMake((d - ds.width) / 2.0, (d - ds.height) / 2.0, ds.width, ds.height)];
        }
    }];
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (img) [cache setObject:img forKey:key];
    return img;
}

static UIImage *LGRefIcon(NSString *title, BOOL large) {
    UIImage *drawn = LGDrawnIcon(title, large);
    if (drawn) return drawn;
    if (!title.length || !LGAtlas()) return nil;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    NSString *t = LGIconAliases()[title] ?: title;
    NSString *slug = LGSlug(t);
    NSString *key = large ? [@"hdr_" stringByAppendingString:slug] : slug;
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;
    NSArray<NSNumber *> *r = LGAtlasMap()[key];
    if (!r) return large ? LGRefIcon(title, NO) : nil;
    CGRect px = CGRectMake(r[0].doubleValue, r[1].doubleValue, r[2].doubleValue, r[2].doubleValue);
    CGImageRef cg = CGImageCreateWithImageInRect(LGAtlas().CGImage, px);
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:2.0 orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    if ([img respondsToSelector:@selector(imageByPreparingForDisplay)]) {
        UIImage *ready = [img imageByPreparingForDisplay];
        if (ready) img = ready;
    }
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (img) [cache setObject:img forKey:key];
    return img;
}

static UIImage *LGAtlasPart(NSString *key) {
    static NSDictionary *rects;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; rects = @{
    @"mt_full": @[@0, @696, @249, @186],
    @"mt_windowed": @[@249, @696, @248, @186],
    @"mt_stage": @[@497, @696, @249, @186],
    }; });
    UIImage *hit = [cache objectForKey:key];
    if (hit || !LGAtlas()) return hit;
    NSArray<NSNumber *> *r = rects[key];
    if (!r) return nil;
    CGImageRef cg = CGImageCreateWithImageInRect(LGAtlas().CGImage,
        CGRectMake(r[0].doubleValue, r[1].doubleValue, r[2].doubleValue, r[3].doubleValue));
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:1.32 orientation:UIImageOrientationUp]; // reference was 1.32 px/pt
    CGImageRelease(cg);
    if (img) [cache setObject:img forKey:key];
    return img;
}

static char kSetIconTitleKey;
static char kSetIconCountKey;
static void LGHideGloss(UIImageView *iv) {
    for (CALayer *l in iv.layer.sublayers) if ([l.name isEqualToString:@"LGGloss"] && !l.hidden) l.hidden = YES;
}
// Put an icon on a cell without ever fighting the cell in a loop
static void LGSetCellIcon(UITableViewCell *cell, UIImage *img) {
    if (!img || cell.imageView.image == img) { LGHideGloss(cell.imageView); return; }
    NSString *t = cell.textLabel.text ?: @"";
    if (![objc_getAssociatedObject(cell, &kSetIconTitleKey) isEqualToString:t]) {
        objc_setAssociatedObject(cell, &kSetIconTitleKey, t, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(cell, &kSetIconCountKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *rec = objc_getAssociatedObject(cell, &kSetIconCountKey);
    NSInteger n = [rec isKindOfClass:[NSArray class]] ? [rec[0] integerValue] : 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if ([rec isKindOfClass:[NSArray class]] && now - [rec[1] doubleValue] > 1.0) n = 0;
    if (n >= 6) return;
    objc_setAssociatedObject(cell, &kSetIconCountKey, @[@(n + 1), @(now)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    cell.imageView.image = img;
    LGHideGloss(cell.imageView);
}

static char kCellBGKey;
static char kCellBGCountKey;
static const NSInteger kClearSelTag = 0x2604;

static BOOL LGIsClearConfig(UIBackgroundConfiguration *c) {
    return c && [c.backgroundColor isEqual:UIColor.clearColor] && c.customView == nil;
}
static void LGApplyClearBackground(UITableViewCell *cell) {
    if (LGIsClearConfig(cell.backgroundConfiguration)) return;
    UIBackgroundConfiguration *bg = [UIBackgroundConfiguration clearConfiguration];
    bg.backgroundColor = UIColor.clearColor;
    cell.backgroundConfiguration = bg;
}
// From layoutSubviews: at most 4 attempts per cell, so it can never loop
static void LGApplyClearBackgroundLimited(UITableViewCell *cell) {
    if (LGIsClearConfig(cell.backgroundConfiguration)) return;
    NSInteger n = [objc_getAssociatedObject(cell, &kCellBGCountKey) integerValue];
    if (n >= 4) return;
    objc_setAssociatedObject(cell, &kCellBGCountKey, @(n + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    LGApplyClearBackground(cell);
}

static void LGStyleSidebarCell(UITableViewCell *cell) {
    // Every write is guarded: writing an unchanged value can still re-trigger layout.
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (![cell.backgroundColor isEqual:UIColor.clearColor]) cell.backgroundColor = UIColor.clearColor;
    if (![cell.contentView.backgroundColor isEqual:UIColor.clearColor])
        cell.contentView.backgroundColor = UIColor.clearColor;
    if (cell.layer.cornerRadius != 0) cell.layer.cornerRadius = 0;
    if (cell.selectedBackgroundView.tag != kClearSelTag) {
        UIView *clear = [UIView new];
        clear.tag = kClearSelTag;
        clear.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = clear;
    }
    LGApplyClearBackgroundLimited(cell);

    // Ask UIKit once to run updateConfigurationUsingState, where the clear background is applied
    if (!objc_getAssociatedObject(cell, &kCellBGKey)) {
        objc_setAssociatedObject(cell, &kCellBGKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell setNeedsUpdateConfiguration];
    }

    UILabel *titleLabel = LGCellTitleLabel(cell);
    NSString *rowTitle = LGNormalizeTitle(titleLabel.text ?: @"");
    BOOL on = cell.isHighlighted ||
              (gLGSelectedName ? [rowTitle isEqualToString:gLGSelectedName] : cell.isSelected);

    UIView *cap = [cell viewWithTag:kCapsuleTag];
    if (!cap) {
        cap = [UIView new];
        cap.tag = kCapsuleTag;
        cap.userInteractionEnabled = NO;
        cap.backgroundColor = LGCapsuleColor();
        [cell insertSubview:cap atIndex:0];
    } else if (cell.subviews.firstObject != cap) {
        [cell sendSubviewToBack:cap];
    }
    CGRect f = CGRectInset(cell.bounds, 0, 2);
    if (!CGRectEqualToRect(cap.frame, f)) {
        cap.frame = f;
        cap.layer.cornerRadius = f.size.height / 2.0;
    }
    if (cap.hidden == on) cap.hidden = !on;

    if (cell.bounds.size.height > 60) { // the account row
        NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell.contentView];
        while (st.count) {
            UIView *v = st.lastObject; [st removeLastObject];
            [st addObjectsFromArray:v.subviews];
            if ([v isKindOfClass:[UILabel class]]) {
                UILabel *l = (UILabel *)v;
                if ([l.text hasPrefix:@"Apple ID, iCloud"]) l.text = @"Apple Account, iCloud, and more";
            }
        }
    }
    if (!cell.imageView.image && cell.bounds.size.height <= 60 && cell.textLabel.text.length) {
        // notice rows (e.g. "iPadOS 27.2 Now Available") have no chevron in iPadOS 26
        if (cell.accessoryType != UITableViewCellAccessoryNone) cell.accessoryType = UITableViewCellAccessoryNone;
        NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell];
        while (st.count) {
            UIView *v = st.lastObject; [st removeLastObject];
            if (v == cell.contentView) continue;
            [st addObjectsFromArray:v.subviews];
            if ([v isKindOfClass:[UIImageView class]] && v != cell.imageView &&
                [((UIImageView *)v).image.description rangeOfString:@"chevron"].location != NSNotFound && !v.hidden)
                v.hidden = YES;
        }
    }
    UIImage *ref = cell.imageView.image ? LGRefIcon(LGNormalizeTitle(cell.textLabel.text ?: @""), NO) : nil;
    if (ref) LGSetCellIcon(cell, ref);
    else LGGlossIcon(cell.imageView);
    if (cell.textLabel.text.length && cell.imageView.image) {
        if (!gLGIconCache) gLGIconCache = [NSMutableDictionary new];
        gLGIconCache[LGNormalizeTitle(cell.textLabel.text)] = cell.imageView.image;
    }
    if (titleLabel) {
        UIColor *want = on ? UIColor.systemBlueColor : UIColor.labelColor;
        if (![titleLabel.textColor isEqual:want]) titleLabel.textColor = want;
        for (UIView *v in cell.contentView.subviews)
            if ([v isKindOfClass:[UILabel class]] && v != cell.textLabel && v != cell.detailTextLabel &&
                [((UILabel *)v).text isEqualToString:titleLabel.text] && ![((UILabel *)v).textColor isEqual:want])
                ((UILabel *)v).textColor = want;
    }
}

static void LGRestyleSidebar(UITableView *side) {
    for (UITableViewCell *c in side.visibleCells) LGStyleSidebarCell(c);
}


#pragma mark - Header card (icon + title + description) for top-level panes

static NSDictionary<NSString *, NSString *> *LGHeaderTexts(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"General": @"Manage your overall setup and preferences for iPad, such as software updates, device language, AirDrop, and more.",
            @"Wi-Fi": @"Connect to Wi-Fi, view available networks, and manage settings for joining networks and nearby hotspots.",
            @"Bluetooth": @"Connect to accessories you can use for activities such as streaming music, making phone calls, and gaming.",
            @"Accessibility": @"Personalize iPad in ways that work best for you with accessibility features for vision, mobility, hearing, speech, and cognition.",
            @"Privacy & Security": @"Control which apps can access your data, location, camera, and microphone, and manage safety protections.",
            @"Siri": @"Siri is an intelligent assistant that helps you find information and get things done.",
            @"Face ID & Passcode": @"Use Face ID and a passcode to unlock iPad, sign in to apps, approve purchases, and protect your personal data.",
            @"AppleCare & Warranty": @"View coverage status for all your devices, and purchase coverage for eligible devices.",
            @"Default Apps": @"Manage your default apps for iPad, including choosing the apps you prefer to use for opening links on the web, sending emails, making contactless payments, and more.",
        };
    });
    return d;
}

static NSString *LGNormalize(NSString *s) { return LGNormalizeTitle(s); }

static BOOL gLGHeaderBusy;
static void LGApplyHeaderImpl(UIViewController *vc);
static void LGApplyHeader(UIViewController *vc) {
    if (gLGHeaderBusy) return;
    gLGHeaderBusy = YES;
    LGApplyHeaderImpl(vc);
    gLGHeaderBusy = NO;
}
static char kHeaderRetryKey;

static void LGApplyHeaderImpl(UIViewController *vc) {
    UINavigationController *nav = vc.navigationController;
    UISplitViewController *split = nav.splitViewController;
    if (!split || split.isCollapsed || split.viewControllers.count < 2) return;
    if (nav != split.viewControllers.lastObject) return;

    // Some panes (Wi-Fi) are a child inside a container: use the container for position and title
    UIViewController *top = vc;
    while (top.parentViewController && top.parentViewController != nav) top = top.parentViewController;
    NSString *title = LGNormalize(vc.title ?: top.title ?: top.navigationItem.title ?: @"");
    if ([title isEqualToString:@"Siri & Search"]) title = @"Siri"; // iPadOS 26 name
    // Top-level panes get the card; of the pushed ones only those the reference shows with one
    BOOL pushedOK = [title isEqualToString:@"Default Apps"] || [title isEqualToString:@"AppleCare & Warranty"];
    if (nav.viewControllers.firstObject != top && !pushedOK) {
        UITableView *t0 = LGFind(vc.view, [UITableView class]);
        UIView *h0 = objc_getAssociatedObject(t0, &kHeaderKey);
        if (h0 && t0.tableHeaderView == h0) t0.tableHeaderView = nil;
        return;
    }
    NSString *desc = LGHeaderTexts()[title];
    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 100) return;
    UIView *mineHdr = objc_getAssociatedObject(tv, &kHeaderKey);
    if (!desc) { // Settings reuses controllers: never leave another page's card behind
        if (mineHdr && tv.tableHeaderView == mineHdr) tv.tableHeaderView = nil;
        return;
    }
    if (tv.isEditing) { // edit lists (Known Networks) have no card
        if (mineHdr && tv.tableHeaderView == mineHdr) tv.tableHeaderView = nil;
        return;
    }
    // Leave a pane's own header alone, unless the slot was ours before (Edit -> Cancel resets it)
    BOOL replaceOwn = [title isEqualToString:@"Face ID & Passcode"] || [title isEqualToString:@"Siri"];
    if (!mineHdr && !replaceOwn && tv.tableHeaderView && tv.tableHeaderView.bounds.size.height > 1) return;

    // Icon: selected sidebar row, else the cache filled while styling sidebar rows
    UIImage *icon = nil;
    UITableView *side = LGFind(split.viewControllers.firstObject.view, [UITableView class]);
    NSIndexPath *selIP = side.indexPathForSelectedRow;
    if (selIP) icon = [side cellForRowAtIndexPath:selIP].imageView.image;
    UIImage *refHdr = LGRefIcon(title, YES);
    if (refHdr) icon = refHdr;
    if (!icon) icon = gLGIconCache[title];
    if (!icon) {
        NSInteger n = [objc_getAssociatedObject(vc, &kHeaderRetryKey) integerValue];
        if (n < 8) {
            objc_setAssociatedObject(vc, &kHeaderRetryKey, @(n + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UIViewController *wvc = vc;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ if (wvc) LGApplyHeader(wvc); });
        }
    }

    UIView *wrap = mineHdr;
    UIView *card; UIImageView *iv; UILabel *tl; UILabel *dl;
    if (!wrap) {
        wrap = [UIView new];
        wrap.tag = kHeaderWrapTag;
        card = [UIView new]; card.tag = 1;
        card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card.layer.cornerRadius = kSectionRadius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [wrap addSubview:card];

        iv = [UIImageView new]; iv.tag = 2;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.layer.cornerRadius = kHeaderIcon * 0.225;
        iv.layer.cornerCurve = kCACornerCurveContinuous;
        iv.clipsToBounds = YES;
        [card addSubview:iv];

        tl = [UILabel new]; tl.tag = 3;
        tl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        tl.textColor = UIColor.labelColor;
        [card addSubview:tl];

        dl = [UILabel new]; dl.tag = 4;
        dl.font = [UIFont systemFontOfSize:17];
        dl.textColor = UIColor.secondaryLabelColor;
        dl.numberOfLines = 0;
        [card addSubview:dl];

        objc_setAssociatedObject(tv, &kHeaderKey, wrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    card = [wrap viewWithTag:1];
    iv = [card viewWithTag:2]; tl = [card viewWithTag:3]; dl = [card viewWithTag:4];

    // Horizontal placement: exactly where the first section is drawn, measured in the header's own space
    CGRect sr0 = LGSectionRect(tv);
    CGFloat x = sr0.origin.x, w = sr0.size.width;

    if (iv.image != icon) iv.image = icon;
    NSString *t = title;
    if (![tl.text isEqualToString:t]) tl.text = t;
    static NSSet *learnMore;
    static dispatch_once_t lmOnce;
    dispatch_once(&lmOnce, ^{
        learnMore = [NSSet setWithArray:@[@"Wi-Fi", @"Bluetooth", @"Accessibility", @"Siri", @"Privacy & Security",
                                          @"Face ID & Passcode"]];
    });
    if (![dl.text hasPrefix:desc]) {
        NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:desc attributes:@{
            NSFontAttributeName: dl.font, NSForegroundColorAttributeName: UIColor.secondaryLabelColor }];
        NSString *link = [title isEqualToString:@"AppleCare & Warranty"] ? @" Learn more about coverage\u2026"
                       : ([learnMore containsObject:title] ? @" Learn more\u2026" : nil);
        if (link)
            [as appendAttributedString:[[NSAttributedString alloc] initWithString:link attributes:@{
                NSFontAttributeName: dl.font, NSForegroundColorAttributeName: UIColor.systemBlueColor }]];
        dl.attributedText = as;
    }

    CGFloat inner = w - kHeaderPad * 2;
    CGFloat y = kHeaderPad;
    if (icon) {
        iv.hidden = NO;
        iv.frame = CGRectMake(kHeaderPad, y, kHeaderIcon, kHeaderIcon);
        if (icon == refHdr) LGHideGloss(iv); else LGGlossIconMax(iv, 64.0);
        y += kHeaderIcon + 14;
    }
    else iv.hidden = YES;
    CGFloat th = ceil([tl sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    tl.frame = CGRectMake(kHeaderPad, y, inner, th); y += th + 6;
    CGFloat dh = ceil([dl sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    dl.frame = CGRectMake(kHeaderPad, y, inner, dh); y += dh + kHeaderPad;

    BOOL merge = [title isEqualToString:@"Wi-Fi"] || [title isEqualToString:@"Bluetooth"];
    objc_setAssociatedObject(tv, &kHeaderMergeKey, merge ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    static const CGFloat kCardTop = 24.0, kCardBottomGap = 30.0;
    CGFloat cardH = y;
    CGFloat totalH = kCardTop + y + (merge ? 0 : kCardBottomGap);
    CGRect wf = CGRectMake(0, 0, tv.bounds.size.width, totalH);
    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1.0 ||
        fabs(wrap.frame.size.width - wf.size.width) > 1.0) {
        wrap.frame = wf;
        tv.tableHeaderView = wrap;
    }
    wrap.clipsToBounds = NO;

    // Merged: the card runs down to the first row, square bottom corners, hairline between
    if (merge && [tv numberOfSections] > 0 && [tv numberOfRowsInSection:0] > 0) {
        // geometry from the table itself: no waiting for the cell to appear (Edit -> Cancel gap)
        CGRect r0 = [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        CGFloat firstTop = r0.origin.y - wrap.frame.origin.y;
        if (firstTop - kCardTop > cardH) cardH = firstTop - kCardTop;
    }
    CGRect cf = CGRectMake(x, kCardTop, w, cardH);
    if (!CGRectEqualToRect(card.frame, cf)) card.frame = cf;
    CACornerMask cm = merge ? (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)
                            : (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner);
    if (card.layer.maskedCorners != cm) card.layer.maskedCorners = cm;

    UIView *line = [card viewWithTag:5];
    if (!line) {
        line = [UIView new];
        line.tag = 5;
        line.backgroundColor = UIColor.separatorColor;
        [card addSubview:line];
    }
    line.hidden = !merge;
    CGFloat hair = 1.0 / UIScreen.mainScreen.scale;
    CGRect lf = CGRectMake(kHeaderPad, cardH - hair, w - kHeaderPad, hair);
    if (!CGRectEqualToRect(line.frame, lf)) line.frame = lf;
}

#pragma mark - Row icons for General / Privacy & Security (drawn in code, 26 style)

static UIColor *LGHex(uint32_t h) {
    return [UIColor colorWithRed:((h >> 16) & 0xFF) / 255.0 green:((h >> 8) & 0xFF) / 255.0
                            blue:(h & 0xFF) / 255.0 alpha:1];
}

static NSDictionary<NSString *, NSArray *> *LGRowIconMap(void) {
    static NSDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNumber *gray = @0x8E8E93, *blue = @0x0A84FF, *green = @0x30D158, *orange = @0xFF9F0A,
                 *red = @0xFF453A, *indigo = @0x5E5CE6, *purple = @0xBF5AF2, *black = @0x1C1C1E,
                 *pink = @0xFF375F, *teal = @0x40C8E0;
        m = @{
            // General
            @"About": @[@"ipad", gray],
            @"Software Update": @[@"gearshape.arrow.triangle.2.circlepath", gray],
            @"iPad Storage": @[@"internaldrive.fill", gray],
            @"AirDrop": @[@"dot.radiowaves.left.and.right", @0xFFFFFF, blue],
            @"AirPlay & Handoff": @[@"airplayvideo", blue],
            @"AirPlay & Continuity": @[@"airplayvideo", blue],
            @"Picture in Picture": @[@"pip", blue],
            @"Screen Capture": @[@"camera.viewfinder", gray],
            @"AutoFill & Passwords": @[@"key.fill", gray],
            @"Background App Refresh": @[@"arrow.clockwise", gray],
            @"Date & Time": @[@"calendar.badge.clock", blue],
            @"Dictionary": @[@"character.book.closed.fill", blue],
            @"Fonts": @[@"TEXT:Aa", gray],
            @"Game Controller": @[@"gamecontroller.fill", gray],
            @"Gestures": @[@"hand.draw.fill", gray],
            @"Keyboard": @[@"keyboard", gray],
            @"Language & Region": @[@"globe", blue],
            @"TV Provider": @[@"tv", black],
            @"VPN & Device Management": @[@"gear", gray],
            @"AppleCare & Warranty": @[@"applelogo", @0xFFFFFF, red],
            @"Health Data": @[@"square.stack.3d.up.fill", blue],
            @"Legal & Regulatory": @[@"doc.text.fill", gray],
            @"Transfer or Reset iPad": @[@"arrow.counterclockwise", gray],
            // Privacy & Security
            @"Location Services": @[@"location.fill", blue],
            @"Tracking": @[@"point.topleft.down.curvedto.point.bottomright.up", orange],
            @"Calendars": @[@"calendar", @0xFFFFFF, red],
            @"Contacts": @[@"person.crop.circle.fill", gray],
            @"Files and Folders": @[@"folder.fill", blue],
            @"Files & Folders": @[@"folder.fill", blue],
            @"Focus": @[@"moon.fill", indigo],
            @"Health": @[@"heart.fill", @0xFFFFFF, pink],
            @"HomeKit": @[@"house.fill", orange],
            @"Media & Apple Music": @[@"music.note", red],
            @"Passkeys Access for Web Browsers": @[@"person.badge.key.fill", gray],
            @"Photos": @[@"photo.on.rectangle", orange],
            @"Reminders": @[@"list.bullet", blue],
            @"Accessories": @[@"dot.radiowaves.right", blue],
            @"Bluetooth": @[@"bolt.horizontal.fill", blue],
            @"Camera": @[@"camera.fill", gray],
            @"Critical Messages": @[@"exclamationmark.bubble.fill", green],
            @"Local Network": @[@"network", blue],
            @"Microphone": @[@"mic.fill", orange],
            @"Motion & Fitness": @[@"figure.run", green],
            @"Paired Devices": @[@"ipad.and.iphone", blue],
            @"Research Sensor & Usage Data": @[@"waveform.path.ecg", blue],
            @"Speech Recognition": @[@"waveform", gray],
            @"Journaling Suggestions": @[@"wand.and.stars", purple],
            @"Safety Check": @[@"person.2.fill", blue],
            @"Blocked Contacts": @[@"nosign", red],
            @"Sensitive Content Warning": @[@"eye.fill", blue],
            @"Analytics & Improvements": @[@"chart.bar.fill", blue],
            @"Apple Advertising": @[@"megaphone.fill", blue],
            @"App Privacy Report": @[@"checkmark.shield.fill", green],
            @"Wired Accessories": @[@"cable.connector", gray],
            @"Background Security Improvements": @[@"shield.fill", blue],
            @"Lockdown Mode": @[@"hand.raised.fill", blue],
            @"Developer Mode": @[@"hammer.fill", teal],
        };
    });
    return m;
}

static UIColor *LGShade(UIColor *c, CGFloat amt) { // amt > 0 lighter, < 0 darker
    CGFloat r, g, b, al;
    if (![c getRed:&r green:&g blue:&b alpha:&al]) return c;
    if (amt >= 0) { r += (1 - r) * amt; g += (1 - g) * amt; b += (1 - b) * amt; }
    else { r *= 1 + amt; g *= 1 + amt; b *= 1 + amt; }
    return [UIColor colorWithRed:r green:g blue:b alpha:al];
}

static const CGFloat kTileRadiusK = 0.2237; // iOS app-icon squircle ratio

static void LGDrawTile(CGContextRef cg, CGFloat d, UIColor *fill) {
    UIBezierPath *tile = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, d, d) cornerRadius:d * kTileRadiusK];
    CGContextSaveGState(cg);
    [tile addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    BOOL white = [fill isEqual:LGHex(0xFFFFFF)];
    NSArray *cols = @[(id)(white ? LGHex(0xFFFFFF) : LGShade(fill, 0.14)).CGColor,
                      (id)(white ? LGHex(0xE9E9EE) : LGShade(fill, -0.08)).CGColor];
    CGGradientRef gr = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)cols, NULL);
    CGContextDrawLinearGradient(cg, gr, CGPointMake(0, 0), CGPointMake(0, d), 0);
    CGGradientRelease(gr);
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(cg);

    UIBezierPath *edge = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.25, 0.25, d - 0.5, d - 0.5)
                                                    cornerRadius:d * kTileRadiusK - 0.25];
    edge.lineWidth = 0.5;
    [[UIColor colorWithWhite:1 alpha:white ? 0.0 : 0.22] setStroke];
    [edge stroke];
}

static UIImage *LGRowIcon(NSString *title) {
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    UIImage *img = [cache objectForKey:title];
    if (img) return img;

    NSArray *spec = LGRowIconMap()[title];
    if (!spec) return nil;
    NSString *name = spec[0];
    UIColor *fill = LGHex([spec[1] unsignedIntValue]);
    UIColor *glyph = spec.count > 2 ? LGHex([spec[2] unsignedIntValue]) : UIColor.whiteColor;

    UIImage *sym = nil;
    NSString *text = nil;
    if ([name hasPrefix:@"TEXT:"]) {
        text = [name substringFromIndex:5];
    } else {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
        sym = [UIImage systemImageNamed:name withConfiguration:cfg];
        if (!sym) return nil;
        sym = [sym imageWithTintColor:glyph renderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    CGFloat d = 29.0;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d)];
    img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        LGDrawTile(ctx.CGContext, d, fill);
        if (sym) {
            CGSize ss = sym.size;
            CGFloat k = MIN(1.0, 18.0 / MAX(ss.width, ss.height));
            CGSize ds = CGSizeMake(ss.width * k, ss.height * k);
            [sym drawInRect:CGRectMake((d - ds.width) / 2.0, (d - ds.height) / 2.0, ds.width, ds.height)];
        } else {
            NSDictionary *at = @{ NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],
                                  NSForegroundColorAttributeName: glyph };
            CGSize ts = [text sizeWithAttributes:at];
            [text drawAtPoint:CGPointMake((d - ts.width) / 2.0, (d - ts.height) / 2.0) withAttributes:at];
        }
    }];
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (img) [cache setObject:img forKey:title];
    return img;
}

// 26 gloss on icons the system already draws (sidebar + other panes): top sheen + light edge
static void LGGlossIcon(UIImageView *iv) { LGGlossIconMax(iv, 40.0); }
static void LGGlossIconMax(UIImageView *iv, CGFloat maxSide) {
    CGSize sz = iv.bounds.size;
    CALayer *gloss = nil;
    for (CALayer *l in iv.layer.sublayers) if ([l.name isEqualToString:@"LGGloss"]) gloss = l;
    BOOL eligible = iv.image && sz.width >= 20 && sz.width <= maxSide && fabs(sz.width - sz.height) < 2;
    if (!eligible) { if (gloss && !gloss.hidden) gloss.hidden = YES; return; }

    if (!gloss) {
        CAGradientLayer *g = [CAGradientLayer layer];
        g.name = @"LGGloss";
        g.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.20].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                     (id)[UIColor colorWithWhite:0 alpha:0.06].CGColor];
        g.locations = @[@0.0, @0.55, @1.0];
        g.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
        g.borderWidth = 0.5;
        g.cornerCurve = kCACornerCurveContinuous;
        g.masksToBounds = YES;
        [iv.layer addSublayer:g];
        gloss = g;
    }
    if (gloss.hidden) gloss.hidden = NO;
    CGRect f = iv.bounds;
    if (!CGRectEqualToRect(gloss.frame, f)) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        gloss.frame = f;
        gloss.cornerRadius = f.size.width * kTileRadiusK;
        [CATransaction commit];
    }
}

static char kRowIconKey;

static void LGApplyRowIcon(UITableViewCell *cell, UITableView *tv) {
    NSString *t = cell.textLabel.text;
    if (!t.length) return;
    NSString *key = LGNormalizeTitle(t);
    UIViewController *ownerVC = LGOwnerVC(tv);
    NSString *owner = LGNormalizeTitle(([ownerVC isKindOfClass:NSClassFromString(@"PSListController")]
                                        ? ((PSListController *)ownerVC).specifier.name : nil) ?: ownerVC.title ?: @"");
    BOOL iconPage = [owner isEqualToString:@"General"] || [owner isEqualToString:@"Privacy & Security"];

    UIImage *mine = objc_getAssociatedObject(cell, &kRowIconKey);
    BOOL systemIcon = cell.imageView.image && cell.imageView.image != mine;

    UIImage *ref = LGRefIcon(key, NO);
    if (ref && (systemIcon || iconPage || cell.imageView.image == ref)) {
        objc_setAssociatedObject(cell, &kRowIconKey, ref, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        LGSetCellIcon(cell, ref);
        return;
    }
    if (systemIcon) { LGGlossIcon(cell.imageView); return; }
    if (!iconPage) return;

    UIImage *want = LGRowIcon(key); // drawn fallback for rows the reference doesn't show
    if (!want || cell.imageView.image == want) return;
    objc_setAssociatedObject(cell, &kRowIconKey, want, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    LGSetCellIcon(cell, want);
}

#pragma mark - iPadOS 26 switch (63x28 track, white capsule knob)

static const NSInteger kSwitchOverlayTag = 0x2606;
static const CGFloat kSwW = 63.0, kSwH = 28.0, kKnobW = 39.0, kKnobH = 24.0, kKnobInset = 2.0;
static char kSwitchTargetKey;

static void LGStyleSwitch(UISwitch *sw, BOOL animated);

@interface LGSwitchTarget : NSObject
@end
@implementation LGSwitchTarget
- (void)changed:(UISwitch *)sw { LGStyleSwitch(sw, YES); }
@end

static void LGStyleSwitch(UISwitch *sw, BOOL animated) {
    if (!sw.window) return;

    UIView *ov = [sw viewWithTag:kSwitchOverlayTag];
    if (!ov) {
        ov = [UIView new];
        ov.tag = kSwitchOverlayTag;
        ov.userInteractionEnabled = NO;
        ov.layer.cornerRadius = kSwH / 2.0;
        ov.layer.cornerCurve = kCACornerCurveCircular;

        UIView *knob = [UIView new];
        knob.tag = 1;
        knob.backgroundColor = UIColor.whiteColor;
        knob.layer.cornerRadius = kKnobH / 2.0;
        knob.layer.cornerCurve = kCACornerCurveCircular;
        knob.layer.shadowColor = UIColor.blackColor.CGColor;
        knob.layer.shadowOpacity = 0.18;
        knob.layer.shadowRadius = 3;
        knob.layer.shadowOffset = CGSizeMake(0, 1);
        [ov addSubview:knob];
        [sw addSubview:ov];

        LGSwitchTarget *t = [LGSwitchTarget new];
        objc_setAssociatedObject(sw, &kSwitchTargetKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:t action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    }

    // Hide the native drawing with an empty mask: alpha stays 1, so taps and drags still work
    for (UIView *v in sw.subviews) {
        if (v == ov) continue;
        CALayer *m = v.layer.mask;
        if (!m || ![m.name isEqualToString:@"LGHide"]) {
            CALayer *hide = [CALayer layer];
            hide.name = @"LGHide";
            v.layer.mask = hide;
        }
    }
    if (sw.subviews.lastObject != ov) [sw bringSubviewToFront:ov];

    // Right edge stays where the system switch ends; the extra width grows to the left
    CGSize b = sw.bounds.size;
    CGRect of = CGRectMake(b.width - kSwW, (b.height - kSwH) / 2.0, kSwW, kSwH);
    if (!CGRectEqualToRect(ov.frame, of)) ov.frame = of;

    BOOL on = sw.isOn;
    UIColor *onColor = sw.onTintColor ?: UIColor.systemGreenColor;
    UIColor *offColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:1 alpha:0.16]
                                                                 : [UIColor colorWithWhite:0 alpha:0.09];
    }];
    UIView *knob = [ov viewWithTag:1];
    CGRect kf = CGRectMake(on ? kSwW - kKnobInset - kKnobW : kKnobInset, (kSwH - kKnobH) / 2.0, kKnobW, kKnobH);

    void (^apply)(void) = ^{
        ov.backgroundColor = on ? onColor : offColor;
        knob.frame = kf;
        ov.alpha = sw.isEnabled ? 1.0 : 0.45;
    };
    if (animated && !CGRectEqualToRect(knob.frame, kf)) {
        [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:apply completion:nil];
    } else {
        apply();
    }
}

#pragma mark - Sidebar layout of iPadOS 26 (order, names, extra rows, "Apps" page)
// Kill switch: create /var/mobile/Library/Preferences/com.basel.settings26.nosidebar to turn this part off.

static const NSInteger kPSGroupCell = 0;
static const NSInteger kPSLinkCell = 1;
static BOOL gLGReordering;
static BOOL gLGSidebarFailed;
static NSInteger gLGSidebarFailCount;
static char kReorderMarkKey;
static char kReorderPendingKey;
static NSArray *gLGAppSpecs;      // specifiers shown on the "Apps" page
static char kAppsFilterKey;
static NSArray *gLGTalkSpecs;     // real Siri switches shown on "Talk to Siri"
static char kPaneBuiltForKey;
static NSSet *gLGKeepNames;       // leftover rows that stay in the sidebar
static NSString *const kLGFakePrefix = @"LG26_";

static BOOL LGSidebarEnabled(void) {
    static BOOL off;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        off = [[NSFileManager defaultManager] fileExistsAtPath:
                  @"/var/mobile/Library/Preferences/com.basel.settings26.nosidebar"];
    });
    return !off && !gLGSidebarFailed;
}

static Class LGSpecClass(void) { return NSClassFromString(@"PSSpecifier"); }

static PSSpecifier *LGGroup(NSString *ident) {
    PSSpecifier *g = [(Class)LGSpecClass() groupSpecifierWithName:nil];
    g.identifier = [kLGFakePrefix stringByAppendingString:ident];
    return g;
}

static double LGParseBytes(NSString *t);
static NSString *LGFormatBytes(double b);
static NSString *const kSysReservedText = @"6.4 GB"; // iPadOS 16 keeps no such space: look only
static double LGSpecBytes(PSSpecifier *src) {
    if (![src isKindOfClass:LGSpecClass()]) return -1;
    NSMutableArray *vals = [NSMutableArray new];
    @try {
        if ([src respondsToSelector:@selector(performGetter)]) {
            id v = [src performSelector:@selector(performGetter)];
            if (v) [vals addObject:v];
        }
    } @catch (NSException *e) {}
    for (NSString *k in @[@"value", @"size", @"PSValue"]) { id v = [src propertyForKey:k]; if (v) [vals addObject:v]; }
    for (id v in vals) {
        if ([v isKindOfClass:[NSString class]]) { double b = LGParseBytes(v); if (b >= 0) return b; }
        if ([v isKindOfClass:[NSNumber class]] && [v doubleValue] > 1e6) return [v doubleValue];
    }
    return -1;
}

@interface LGValueSource : NSObject
@end
@implementation LGValueSource
- (id)lgValue:(PSSpecifier *)spec { return [spec propertyForKey:@"lgValue"]; }
- (id)lgSysTotal:(PSSpecifier *)spec {
    double os = LGSpecBytes([spec propertyForKey:@"lgSrc"]);
    if (os >= 0) return LGFormatBytes(os + LGParseBytes(kSysReservedText));
    return [spec propertyForKey:@"lgValue"];
}
- (void)lgNoop:(PSSpecifier *)spec {}
@end
static LGValueSource *LGValues(void) {
    static LGValueSource *v;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ v = [LGValueSource new]; });
    return v;
}

// "Name" link row, "Name=Value" link row with a value on the right, "+Name" blue button row
static PSSpecifier *LGFakeRowSpec(NSString *raw, id target) {
    NSString *name = raw, *value = nil;
    BOOL button = [raw hasPrefix:@"+"];
    if (button) name = [raw substringFromIndex:1];
    NSRange eq = [name rangeOfString:@"="];
    if (eq.location != NSNotFound) { value = [name substringFromIndex:eq.location + 1]; name = [name substringToIndex:eq.location]; }
    PSSpecifier *s;
    if (button) {
        s = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:LGValues() set:NULL get:NULL detail:Nil cell:13 edit:Nil];
        if ([s respondsToSelector:@selector(setButtonAction:)]) [s setButtonAction:@selector(lgNoop:)];
    } else if (value) {
        s = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:LGValues() set:NULL get:@selector(lgValue:)
                                                    detail:NSClassFromString(@"LGPaneController") cell:2 edit:Nil];
        [s setProperty:value forKey:@"lgValue"];
    } else {
        s = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:target set:NULL get:NULL
                                                    detail:NSClassFromString(@"LGPaneController") cell:kPSLinkCell edit:Nil];
    }
    s.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(name)];
    UIImage *icon = button ? nil : LGRefIcon(name, NO);
    if (icon) [s setProperty:icon forKey:@"iconImage"];
    return s;
}

static PSSpecifier *LGFakeRow(NSString *name, id target) {
    Class pane = NSClassFromString(@"LGPaneController");
    PSSpecifier *s = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:target set:NULL get:NULL
                                                             detail:pane cell:kPSLinkCell edit:Nil];
    s.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(name)];
    UIImage *icon = LGRefIcon(name, NO);
    if (icon) [s setProperty:icon forKey:@"iconImage"];
    return s;
}


static __weak PSSpecifier *gLGAccountSpec;
static PSSpecifier *LGICloudRow(PSSpecifier *account, id target) {
    gLGAccountSpec = account;
    PSSpecifier *c = LGFakeRow(@"iCloud", target); // tapping it is redirected to the account row
    return c;
}

static NSMutableArray *LGReorderSidebar(PSListController *lc, NSArray *orig) {
    // 1. split into groups, dropping rows this tweak added earlier
    NSMutableArray<NSMutableArray *> *groups = [NSMutableArray new];
    for (PSSpecifier *sp in orig) {
        BOOL mine = [sp.identifier hasPrefix:kLGFakePrefix];
        if (sp.cellType == kPSGroupCell) {
            [groups addObject:[NSMutableArray arrayWithObject:sp]];
            continue;
        }
        if (mine) continue;
        if (!groups.count) [groups addObject:[NSMutableArray arrayWithObject:LGGroup(@"top")]];
        [groups.lastObject addObject:sp];
    }
    // 2. where the "settings" part starts (first group with Airplane Mode / Wi-Fi)
    NSUInteger start = NSNotFound;
    for (NSUInteger i = 0; i < groups.count && start == NSNotFound; i++)
        for (PSSpecifier *sp in groups[i]) {
            NSString *n = LGNormalizeTitle(sp.name ?: @"");
            if ([n isEqualToString:@"Airplane Mode"] || [n isEqualToString:@"Wi-Fi"]) { start = i; break; }
        }
    if (start == NSNotFound) return nil; // unknown layout: leave Settings untouched

    NSMutableArray *out = [NSMutableArray new];
    PSSpecifier *account = nil;
    for (NSUInteger i = 0; i < start; i++) {
        [out addObjectsFromArray:groups[i]];
        for (PSSpecifier *sp in groups[i]) if (!account && sp.cellType != kPSGroupCell) account = sp;
    }

    // 3. pool of all remaining rows (our own group headers are dropped and rebuilt)
    NSMutableArray<PSSpecifier *> *pool = [NSMutableArray new];
    NSMutableArray<NSNumber *> *poolGroup = [NSMutableArray new];
    NSUInteger privacyGroup = NSNotFound;
    for (NSUInteger i = start; i < groups.count; i++)
        for (NSUInteger j = 1; j < groups[i].count; j++) {
            PSSpecifier *sp = groups[i][j];
            [pool addObject:sp];
            [poolGroup addObject:@(i)];
            if ([LGNormalizeTitle(sp.name ?: @"") isEqualToString:@"Privacy & Security"]) privacyGroup = i;
        }

    NSMutableSet *placed = [NSMutableSet new];
    PSSpecifier *(^take)(NSArray<NSString *> *) = ^PSSpecifier *(NSArray<NSString *> *names) {
        for (NSString *want in names) {
            [placed addObject:want];
            for (NSUInteger k = 0; k < pool.count; k++)
                if ([LGNormalizeTitle(pool[k].name ?: @"") isEqualToString:want]) {
                    PSSpecifier *sp = pool[k];
                    [pool removeObjectAtIndex:k];
                    [poolGroup removeObjectAtIndex:k];
                    return sp;
                }
            // an earlier pass may have parked it on the Apps page
            for (PSSpecifier *sp in gLGAppSpecs)
                if ([LGNormalizeTitle(sp.name ?: @"") isEqualToString:want]) {
                    NSMutableArray *a = [gLGAppSpecs mutableCopy];
                    [a removeObject:sp];
                    gLGAppSpecs = a;
                    return sp;
                }
        }
        return nil;
    };
    void (^addGroup)(NSString *, NSArray *) = ^(NSString *ident, NSArray *rows) {
        if (!rows.count) return;
        [out addObject:LGGroup(ident)];
        [out addObjectsFromArray:rows];
    };

    // 4. iPadOS 26 groups
    NSMutableArray *g1 = [NSMutableArray new];
    for (NSArray *n in @[@[@"Airplane Mode"], @[@"Wi-Fi"], @[@"Bluetooth"], @[@"Cellular", @"Cellular Data", @"Mobile Data"],
                         @[@"Personal Hotspot"], @[@"Battery"], @[@"VPN"]]) {
        PSSpecifier *sp = take(n); if (sp) [g1 addObject:sp];
    }
    addGroup(@"connect", g1);

    NSMutableArray *g2 = [NSMutableArray new];
    for (NSArray *n in @[@[@"General"], @[@"Accessibility"], @[@"Apple Pencil"], @[@"Camera"], @[@"Control Center"],
                         @[@"Display & Brightness"], @[@"Home Screen & Multitasking", @"Home Screen & Dock", @"Home Screen & App Library"],
                         @[@"MULTI"], @[@"SEARCH"], @[@"Siri & Search", @"Siri"], @[@"Wallpaper"]]) {
        NSString *first = n.firstObject;
        if ([first isEqualToString:@"MULTI"]) { [g2 addObject:LGFakeRow(@"Multitasking & Gestures", lc)]; continue; }
        if ([first isEqualToString:@"SEARCH"]) continue; // added right after Siri is found
        PSSpecifier *sp = take(n);
        if (!sp) continue;
        if ([first hasPrefix:@"Home Screen"]) sp.name = @"Home Screen & App Library";
        if ([first hasPrefix:@"Siri"]) {
            [g2 addObject:LGFakeRow(@"Search", lc)];
            sp.name = @"Siri";
        }
        [g2 addObject:sp];
    }
    addGroup(@"system", g2);

    NSMutableArray *g3 = [NSMutableArray new];
    for (NSArray *n in @[@[@"Notifications"], @[@"Sounds", @"Sounds & Haptics"], @[@"Focus"], @[@"Screen Time"]]) {
        PSSpecifier *sp = take(n); if (sp) [g3 addObject:sp];
    }
    addGroup(@"attention", g3);

    NSMutableArray *g4 = [NSMutableArray new];
    for (NSArray *n in @[@[@"Face ID & Passcode", @"Touch ID & Passcode", @"Passcode"], @[@"Privacy & Security"]]) {
        PSSpecifier *sp = take(n); if (sp) [g4 addObject:sp];
    }
    addGroup(@"security", g4);

    NSMutableArray *g5 = [NSMutableArray new];
    PSSpecifier *gc = take(@[@"Game Center"]);
    if (gc) [g5 addObject:gc];
    [g5 addObject:LGICloudRow(account, lc)];
    PSSpecifier *wallet = take(@[@"Wallet & Apple Pay"]);
    if (wallet) [g5 addObject:wallet];
    addGroup(@"services", g5);

    // 5. leftovers: rows from before Privacy stay in the sidebar, the app list moves to "Apps"
    // First pass decides which leftovers stay in the sidebar; later passes reuse that decision,
    // so rows Settings adds afterwards (third-party apps) always end up on the Apps page.
    NSMutableArray *keep = [NSMutableArray new];
    NSMutableArray *apps = [NSMutableArray arrayWithArray:gLGAppSpecs ?: @[]];
    BOOL firstPass = (gLGKeepNames == nil);
    NSMutableSet *keepNames = firstPass ? [NSMutableSet new] : [gLGKeepNames mutableCopy];
    for (NSUInteger k = 0; k < pool.count; k++) {
        NSString *n = LGNormalizeTitle(pool[k].name ?: @"");
        BOOL toApps;
        if (firstPass) toApps = privacyGroup != NSNotFound && poolGroup[k].unsignedIntegerValue > privacyGroup;
        else toApps = ![keepNames containsObject:n];
        if ([n isEqualToString:@"TV Provider"]) toApps = YES;
        if (toApps) {
            BOOL dup = NO;
            for (PSSpecifier *e in apps) if (e == pool[k] || [LGNormalizeTitle(e.name ?: @"") isEqualToString:n]) { dup = YES; break; }
            if (!dup) [apps addObject:pool[k]];
        } else {
            [keep addObject:pool[k]];
            if (firstPass) [keepNames addObject:n];
        }
    }
    gLGKeepNames = keepNames;
    [apps filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PSSpecifier *sp, NSDictionary *b) {
        return ![placed containsObject:LGNormalizeTitle(sp.name ?: @"")];
    }]];
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    [apps filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PSSpecifier *sp, NSDictionary *b) {
        NSString *bid = sp.identifier;
        if (!proxyClass || bid.length < 3 || [bid rangeOfString:@"."].location == NSNotFound || [bid hasPrefix:@"com.apple."]) return YES;
        @try {
            id proxy = [proxyClass performSelector:@selector(applicationProxyForIdentifier:) withObject:bid];
            if (proxy && [proxy respondsToSelector:@selector(isInstalled)])
                return ((BOOL (*)(id, SEL))objc_msgSend)(proxy, @selector(isInstalled));
        } @catch (NSException *e) {}
        return YES;
    }]];
    gLGAppSpecs = [apps sortedArrayUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
        return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
    }];
    addGroup(@"apps", @[LGFakeRow(@"Apps", lc)]);
    addGroup(@"other", keep);
    return out;
}

static NSUInteger LGSpecSignature(NSArray *specs) {
    NSUInteger h = specs.count;
    for (id sp in specs) h = h * 31 + (NSUInteger)(__bridge void *)sp;
    return h;
}
static void LGScheduleReorder(PSListController *lc);
static void LGCheckReorder(PSListController *lc) {
    if (gLGReordering || !LGSidebarEnabled() || !lc) return;
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSMutableArray *cur = iv ? object_getIvar(lc, iv) : nil;
    NSNumber *mark = cur ? objc_getAssociatedObject(cur, &kReorderMarkKey) : nil;
    if (cur.count && (!mark || mark.unsignedIntegerValue != LGSpecSignature(cur))) LGScheduleReorder(lc);
}

static void LGScheduleReorder(PSListController *lc) {
    if (objc_getAssociatedObject(lc, &kReorderPendingKey)) return;
    objc_setAssociatedObject(lc, &kReorderPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak PSListController *weakLC = lc;
    dispatch_async(dispatch_get_main_queue(), ^{
        PSListController *me = weakLC;
        if (!me) return;
        objc_setAssociatedObject(me, &kReorderPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gLGReordering = YES;
        @try {
            NSMutableArray *cur = [me specifiers];
            NSMutableArray *n = LGReorderSidebar(me, cur);
            if (n) {
                [me setSpecifiers:n];
                NSMutableArray *now = [me specifiers];
                objc_setAssociatedObject(now, &kReorderMarkKey, @(LGSpecSignature(now)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else if (cur) {
                objc_setAssociatedObject(cur, &kReorderMarkKey, @(LGSpecSignature(cur)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } @catch (NSException *e) {
            NSLog(@"[Settings26] sidebar layout failed: %@", e);
            if (++gLGSidebarFailCount >= 3) gLGSidebarFailed = YES;
        }
        gLGReordering = NO;
    });
}

#pragma mark - Choice lists (Search Engine, Default Apps rows)

static NSDictionary<NSString *, NSArray<NSString *> *> *LGChoices(void) {
    return @{ @"Search Engine": @[@"Google", @"Yahoo", @"Bing", @"DuckDuckGo", @"Ecosia"],
              @"Email": @[@"Mail"], @"Messaging": @[@"Messages"], @"Calling": @[@"None"],
              @"Call Filtering": @[@"None"], @"Browser App": @[@"Safari"],
              @"Translation": @[@"Translate", @"Google Translate"], @"Passwords & Codes": @[@"Passwords"] };
}
static NSString *LGChoiceValue(NSString *page) {
    NSString *v = [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"]
                      stringForKey:[@"LG26_choice_" stringByAppendingString:LGSlug(page)]];
    return v ?: LGChoices()[page].firstObject;
}

#pragma mark - Pages for rows iPadOS 16 doesn't have ("Apps", "Family", "iCloud", ...)

static NSMutableArray *LGPaneSpecifiers(PSListController *pc) {
    NSString *title = pc.specifier.name ?: pc.title ?: @"";
    pc.title = title;
    NSMutableArray *out = [NSMutableArray new];

    if ([title isEqualToString:@"Apps"]) {
        [out addObject:LGGroup(@"apps_top")];
        PSSpecifier *def = LGFakeRow(@"Default Apps", pc);
        [def setProperty:@"Manage default apps on iPad" forKey:@"lgSubtitle"];
        [def setProperty:@64 forKey:@"height"];
        [out addObject:def];
        NSString *letter = nil;
        NSString *filter = objc_getAssociatedObject(pc, &kAppsFilterKey);
        NSMutableArray *alpha = [NSMutableArray new], *other = [NSMutableArray new];
        for (PSSpecifier *sp in gLGAppSpecs) {
            unichar c = sp.name.length ? [sp.name.uppercaseString characterAtIndex:0] : '#';
            [((c >= 'A' && c <= 'Z') ? alpha : other) addObject:sp];
        }
        for (PSSpecifier *sp in [alpha arrayByAddingObjectsFromArray:other]) {
            NSString *n = sp.name ?: @"";
            if (filter.length && [n rangeOfString:filter options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
            NSString *l = n.length ? [n substringToIndex:1].uppercaseString : @"#";
            unichar c = [l characterAtIndex:0];
            if (!(c >= 'A' && c <= 'Z')) l = @"#";
            if (![l isEqualToString:letter]) {
                letter = l;
                PSSpecifier *g = [(Class)LGSpecClass() groupSpecifierWithName:l];
                g.identifier = [kLGFakePrefix stringByAppendingFormat:@"letter_%@", l];
                [out addObject:g];
            }
            [out addObject:sp];
        }
        [out addObject:LGGroup(@"apps_hidden")];
        [out addObject:LGFakeRow(@"Hidden Apps", pc)];
        return out;
    }

    PSSpecifier *(^toggle)(NSString *) = ^PSSpecifier *(NSString *name) {
        PSSpecifier *sp = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:pc set:@selector(lgSet:specifier:)
                                                                     get:@selector(lgGet:) detail:Nil cell:6 edit:Nil];
        sp.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(name)];
        [sp setProperty:sp.identifier forKey:@"key"];
        return sp;
    };
    PSSpecifier *(^group)(NSString *, NSString *, NSString *) = ^PSSpecifier *(NSString *ident, NSString *header, NSString *footer) {
        PSSpecifier *g = [(Class)LGSpecClass() groupSpecifierWithName:header];
        g.identifier = [kLGFakePrefix stringByAppendingString:ident];
        if (footer) [g setProperty:footer forKey:@"footerText"];
        return g;
    };

    if ([title isEqualToString:@"AppleCare & Warranty"]) {
        [out addObject:group(@"ac_this", @"This Device", nil)];
        PSSpecifier *dev = LGFakeRowSpec(UIDevice.currentDevice.name, pc);
        [dev setProperty:@"Coverage Expired" forKey:@"lgSubtitle"];
        [dev setProperty:@64 forKey:@"height"];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
        UIImage *ipad = [[UIImage systemImageNamed:@"ipad" withConfiguration:cfg]
                            imageWithTintColor:UIColor.secondaryLabelColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (ipad) [dev setProperty:ipad forKey:@"iconImage"];
        [out addObject:dev];
        return out;
    }

    if ([title isEqualToString:@"Health Data"]) {
        [out addObject:group(@"hd_medical", @"Medical Details", nil)];
        [out addObject:LGFakeRowSpec(@"Health Details", pc)];
        [out addObject:group(@"hd_data", @"Data", nil)];
        [out addObject:LGFakeRowSpec(@"Data Access & Devices", pc)];
        return out;
    }

    if ([title isEqualToString:@"Multitasking & Gestures"]) {
        // the three mode cards are the table header (built in -viewDidLayoutSubviews)
        [out addObject:group(@"mg_gestures", @"Gestures",
            @"- Go home by pinching with four or five fingers.\n- Switch apps by swiping left and right with four or five fingers.\n- Open the App Switcher by pinching and pausing with four or five fingers.")];
        [out addObject:toggle(@"Four & Five Finger App Switching")];
        [out addObject:group(@"mg_productivity", nil,
            @"- Double-tap with three fingers to undo.\n- Pinch and spread with three fingers to copy and paste.\n- Swipe left with three fingers to undo and swipe right to redo.")];
        [out addObject:toggle(@"Productivity Gestures")];
        [out addObject:group(@"mg_shake", nil, nil)];
        [out addObject:toggle(@"Shake to Undo")];
        return out;
    }

    if ([title isEqualToString:@"Search"]) {
        [out addObject:group(@"s_lookup", @"Search and Look Up",
            @"Allow content from Apple and other partners to be shown when searching or when looking up text or objects in photos. About Search & Privacy\u2026")];
        [out addObject:toggle(@"Show Recent Searches")];
        [out addObject:toggle(@"Show Related Content")];
        [out addObject:group(@"s_engine", nil, nil)];
        [out addObject:LGFakeRow(@"Search Engine", pc)];
        [out addObject:group(@"s_improve", nil,
            @"Help improve Search by allowing Apple to store the searches you enter into Safari, Siri, and Spotlight in a way that is not linked to you.\n\nSearches include lookups of general knowledge, and requests to do things like play music and get directions. About Search & Privacy\u2026")];
        [out addObject:toggle(@"Help Apple Improve Search")];
        [out addObject:group(@"s_apps", nil, nil)];
        [out addObject:LGFakeRow(@"App Clips", pc)];
        for (PSSpecifier *app in gLGAppSpecs) [out addObject:app];
        return out;
    }

    if ([title isEqualToString:@"Talk to Siri"]) {
        [out addObject:group(@"talk", nil, @"Choose how you want to talk to Siri.")];
        [out addObjectsFromArray:gLGTalkSpecs ?: @[]];
        return out;
    }

    NSArray *choices = LGChoices()[title];
    if (choices) {
        [out addObject:LGGroup(@"choices")];
        for (NSString *c in choices) {
            PSSpecifier *sp = [(Class)LGSpecClass() preferenceSpecifierNamed:c target:pc set:NULL get:NULL
                                                                      detail:Nil cell:4 edit:Nil];
            sp.identifier = [kLGFakePrefix stringByAppendingFormat:@"choice_%@", LGSlug(c)];
            [out addObject:sp];
        }
        return out;
    }

    if ([title isEqualToString:@"Default Apps"]) {
        NSUInteger kb = UITextInputMode.activeInputModes.count;
        NSArray *sections = @[
            @[@[@"Email", @"Mail"], @[@"Messaging", @"Messages"], @[@"Calling", @"None"], @[@"Call Filtering", @"None"]],
            @[@[@"Browser App", @"Safari"], @[@"Translation", @"Translate"], @[@"Passwords & Codes", @"Passwords"],
              @[@"Keyboards", [NSString stringWithFormat:@"%lu", (unsigned long)MAX(kb, (NSUInteger)1)]]]];
        NSUInteger gi = 0;
        for (NSArray *sec in sections) {
            [out addObject:LGGroup([NSString stringWithFormat:@"defaults_%lu", (unsigned long)gi++])];
            for (NSArray *row in sec) {
                PSSpecifier *sp = [(Class)LGSpecClass() preferenceSpecifierNamed:row[0] target:pc set:NULL
                                                                             get:@selector(lgValue:)
                                                                          detail:NSClassFromString(@"LGPaneController")
                                                                            cell:2 edit:Nil];
                sp.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(row[0])];
                [sp setProperty:(LGChoices()[row[0]] ? LGChoiceValue(row[0]) : row[1]) forKey:@"lgValue"];
                [out addObject:sp];
            }
        }
        return out;
    }

    PSSpecifier *g = LGGroup(@"pane");
    if (![title isEqualToString:@"Hidden Apps"])
        [g setProperty:@"This page is part of the iPadOS 26 look and has no settings on iPadOS 16." forKey:@"footerText"];
    [out addObject:g];
    return out;
}

#pragma mark - iPadOS 26 bar buttons (Edit / Done / Cancel / Save as glass capsules)

@interface LGBarItemProxy : NSObject
@property (nonatomic, strong) UIBarButtonItem *item;
@property (nonatomic, weak) UIButton *button;
@property (nonatomic, copy) NSString *fixedTitle;
@end
@implementation LGBarItemProxy
- (void)attach {
    [self.item addObserver:self forKeyPath:@"enabled" options:0 context:NULL];
    [self.item addObserver:self forKeyPath:@"title" options:0 context:NULL];
    [self sync];
}
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)ctx {
    dispatch_async(dispatch_get_main_queue(), ^{ [self sync]; });
}
- (void)sync {
    UIButton *b = self.button;
    if (!b) return;
    NSString *t = self.item.title.length ? self.item.title : self.fixedTitle;
    UIButtonConfiguration *cfg = b.configuration;
    if (![cfg.title isEqualToString:t]) { cfg.title = t; b.configuration = cfg; }
    b.enabled = self.item.isEnabled;
}
- (void)tap {
    UIBarButtonItem *it = self.item;
    if (it.action) [UIApplication.sharedApplication sendAction:it.action to:it.target from:it forEvent:nil];
}
- (void)dealloc {
    @try { [_item removeObserver:self forKeyPath:@"enabled"]; [_item removeObserver:self forKeyPath:@"title"]; }
    @catch (NSException *e) {}
}
@end

static char kBarProxyKey;

static UIBarButtonItem *LGWrapBarItem(UIBarButtonItem *it) {
    if (!it || it.customView) return nil;
    NSString *fixed = nil;
    BOOL bold = it.style == UIBarButtonItemStyleDone;
    NSInteger sys = -1;
    @try { id v = [it valueForKey:@"systemItem"]; if ([v respondsToSelector:@selector(integerValue)]) sys = [v integerValue]; }
    @catch (NSException *e) {}
    BOOL isSystem = NO;
    @try { isSystem = [[it valueForKey:@"isSystemItem"] boolValue]; } @catch (NSException *e) { isSystem = sys >= 0 && !it.title; }
    if (isSystem || !it.title) {
        switch (sys) {
            case UIBarButtonSystemItemDone:   fixed = @"Done"; bold = YES; break;
            case UIBarButtonSystemItemCancel: fixed = @"Cancel"; break;
            case UIBarButtonSystemItemEdit:   fixed = @"Edit"; break;
            case UIBarButtonSystemItemSave:   fixed = @"Save"; bold = YES; break;
            default: break;
        }
    }
    if (!fixed && !it.title.length) return nil; // icon-only buttons stay as they are

    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.baseBackgroundColor = [UIColor colorWithRed:38/255.0 green:38/255.0 blue:40/255.0 alpha:1];
    cfg.baseForegroundColor = UIColor.whiteColor;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(11, 17, 11, 17);
    cfg.title = it.title.length ? it.title : fixed;
    UIFont *font = [UIFont systemFontOfSize:17 weight:bold ? UIFontWeightSemibold : UIFontWeightRegular];
    cfg.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *in) {
        NSMutableDictionary *o = [in mutableCopy];
        o[NSFontAttributeName] = font;
        return o;
    };
    UIButton *b = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    b.layer.cornerRadius = 22;
    b.layer.cornerCurve = kCACornerCurveCircular;

    LGBarItemProxy *px = [LGBarItemProxy new];
    px.item = it;
    px.button = b;
    px.fixedTitle = fixed;
    [b addTarget:px action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *w = [[UIBarButtonItem alloc] initWithCustomView:b];
    objc_setAssociatedObject(w, &kBarProxyKey, px, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [px attach];
    return w;
}

static NSArray *LGWrapItems(NSArray *items, BOOL *changed) {
    if (!items.count) return items;
    NSMutableArray *o = [NSMutableArray arrayWithCapacity:items.count];
    for (UIBarButtonItem *it in items) {
        UIBarButtonItem *w = LGWrapBarItem(it);
        if (w) *changed = YES;
        [o addObject:w ?: it];
    }
    return o;
}

static void LGWrapNavItem(UINavigationItem *ni) {
    BOOL ch = NO;
    NSArray *r = LGWrapItems(ni.rightBarButtonItems, &ch);
    if (ch) ni.rightBarButtonItems = r;
    ch = NO;
    NSArray *l = LGWrapItems(ni.leftBarButtonItems, &ch);
    if (ch) ni.leftBarButtonItems = l;
}

static char kNavWrapPendingKey;
static BOOL LGIsDetailBar(UINavigationBar *bar) {
    UIResponder *r = bar;
    while (r && ![r isKindOfClass:[UINavigationController class]]) r = r.nextResponder;
    UINavigationController *nav = (UINavigationController *)r;
    UISplitViewController *split = nav.splitViewController;
    return split && split.viewControllers.count >= 2 && split.viewControllers.lastObject == nav;
}

#pragma mark - "Multitasking & Gestures": the three mode cards from iPadOS 26

static NSString *const kLGModeKey = @"LG26_multitasking_mode";

@interface LGModeTarget : NSObject
@property (nonatomic, weak) UIView *card;
- (void)pick:(UITapGestureRecognizer *)g;
@end

static void LGRefreshModes(UIView *card) {
    NSInteger sel = [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] integerForKey:kLGModeKey];
    for (NSInteger i = 0; i < 3; i++) {
        UIImageView *radio = (UIImageView *)[card viewWithTag:100 + i];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
        radio.image = [UIImage systemImageNamed:(i == sel ? @"checkmark.circle.fill" : @"circle") withConfiguration:cfg];
        radio.tintColor = i == sel ? UIColor.systemBlueColor : UIColor.tertiaryLabelColor;
    }
}

@implementation LGModeTarget
- (void)pick:(UITapGestureRecognizer *)g {
    [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] setInteger:g.view.tag - 200 forKey:kLGModeKey];
    LGRefreshModes(self.card);
}
@end

static char kModeHeaderKey;
static char kModeTargetKey;

static void LGMultitaskingHeader(UIViewController *vc) {
    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 300 || [tv numberOfSections] == 0) return;
    CGRect sr = LGSectionRect(tv);
    CGFloat x = sr.origin.x, w = sr.size.width;

    UIView *wrap = objc_getAssociatedObject(tv, &kModeHeaderKey);
    if (!wrap) {
        wrap = [UIView new];
        UIView *card = [UIView new];
        card.tag = 1;
        card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card.layer.cornerRadius = kSectionRadius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [wrap addSubview:card];
        LGModeTarget *t = [LGModeTarget new];
        t.card = card;
        objc_setAssociatedObject(tv, &kModeTargetKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSArray *titles = @[@"Full Screen Apps", @"Windowed Apps", @"Stage Manager"];
        NSArray *descs = @[@"Always use apps full screen and swipe Home to switch between them.",
                           @"Resize and arrange multiple windows in a single space to multitask with ease.",
                           @"Arrange windows across multiple groups for a focused multitasking experience."];
        NSArray *imgs = @[@"mt_full", @"mt_windowed", @"mt_stage"];
        for (NSInteger i = 0; i < 3; i++) {
            UIView *col = [UIView new];
            col.tag = 200 + i;
            UIImageView *pic = [[UIImageView alloc] initWithImage:LGAtlasPart(imgs[i])];
            pic.tag = 1; pic.contentMode = UIViewContentModeScaleAspectFit;
            UIImageView *radio = [UIImageView new]; radio.tag = 100 + i;
            UILabel *tl = [UILabel new]; tl.tag = 3; tl.text = titles[i];
            tl.font = [UIFont systemFontOfSize:20]; tl.textColor = UIColor.labelColor;
            UILabel *dl = [UILabel new]; dl.tag = 4; dl.numberOfLines = 0;
            NSMutableAttributedString *d = [[NSMutableAttributedString alloc] initWithString:descs[i] attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:15], NSForegroundColorAttributeName: UIColor.secondaryLabelColor }];
            if (i == 2) [d appendAttributedString:[[NSAttributedString alloc] initWithString:@" Learn more…" attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:15], NSForegroundColorAttributeName: UIColor.systemBlueColor }]];
            dl.attributedText = d;
            for (UIView *v in @[pic, radio, tl, dl]) [col addSubview:v];
            [col addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:t action:@selector(pick:)]];
            [card addSubview:col];
        }
        LGRefreshModes(card);
        objc_setAssociatedObject(tv, &kModeHeaderKey, wrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UIView *card = [wrap viewWithTag:1];
    CGFloat pad = 34, gap = 40, colW = (w - pad * 2 - gap * 2) / 3.0, h = 0;
    for (NSInteger i = 0; i < 3; i++) {
        UIView *col = [card viewWithTag:200 + i];
        UIImageView *pic = (UIImageView *)[col viewWithTag:1];
        UIView *radio = [col viewWithTag:100 + i];
        UILabel *tl = (UILabel *)[col viewWithTag:3], *dl = (UILabel *)[col viewWithTag:4];
        CGSize is = pic.image.size;
        CGFloat ph = is.width > 0 ? colW * is.height / is.width : colW * 0.75;
        pic.frame = CGRectMake(0, 0, colW, ph);
        radio.frame = CGRectMake(0, ph + 14, 26, 26);
        tl.frame = CGRectMake(36, ph + 13, colW - 36, 28);
        CGFloat dh = ceil([dl sizeThatFits:CGSizeMake(colW, CGFLOAT_MAX)].height);
        dl.frame = CGRectMake(0, ph + 50, colW, dh);
        CGFloat ch = ph + 50 + dh;
        col.frame = CGRectMake(pad + i * (colW + gap), pad, colW, ch);
        h = MAX(h, ch);
    }
    card.frame = CGRectMake(x, 24, w, h + pad * 2);
    CGFloat totalH = 24 + h + pad * 2 + 16;
    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1 || fabs(wrap.frame.size.width - tv.bounds.size.width) > 1) {
        wrap.frame = CGRectMake(0, 0, tv.bounds.size.width, totalH);
        tv.tableHeaderView = wrap;
    }
}

#pragma mark - Full-width sections in the detail column

static char kWideFallbackKey;
static char kSqueezedKey; // cell held at zero height (hidden by the storage search)
static const CGFloat kSectionSide = 20.0;

static BOOL LGWideTable(UITableView *tv) {
    if (!tv || tv.style == UITableViewStylePlain || tv.bounds.size.width < 600) return NO;
    if (LGIsSidebarTable(tv)) return NO;
    UIViewController *vc = LGOwnerVC(tv);
    if (!vc) return NO;
    UINavigationController *nav = vc.navigationController;
    UISplitViewController *split = nav.splitViewController;
    return split && split.viewControllers.count >= 2 && split.viewControllers.lastObject == nav;
}
static UIEdgeInsets LGClampInset(UIEdgeInsets i) {
    if (i.left > 30) i.left = kSectionSide;
    if (i.right > 30) i.right = kSectionSide;
    return i;
}
// private UIKit inset that Settings uses for its centred "cards" (hooked only if it exists)
static void (*orig_setSecInset)(UITableView *, SEL, UIEdgeInsets);
static void new_setSecInset(UITableView *self, SEL _cmd, UIEdgeInsets i) {
    orig_setSecInset(self, _cmd, LGWideTable(self) ? LGClampInset(i) : i);
}
static UIEdgeInsets (*orig_secInset)(UITableView *, SEL);
static UIEdgeInsets new_secInset(UITableView *self, SEL _cmd) {
    UIEdgeInsets i = orig_secInset(self, _cmd);
    return LGWideTable(self) ? LGClampInset(i) : i;
}

#pragma mark - Row order inside panes (General, Privacy & Security) like iPadOS 26
// Row syntax: "Name|alias|alias". Prefix "*" = add a look-only row if iPadOS 16 doesn't have it,
// "^" = borrow the row from the sidebar list (e.g. TV Provider), "@rest" = every row not listed.

static NSDictionary<NSString *, NSArray *> *LGPageLayouts(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = @{
        @"General": @[
            @{@"rows": @[@"About", @"Software Update", @"iPad Storage"]},
            @{@"rows": @[@"*AppleCare & Warranty"]},
            @{@"rows": @[@"*Health Data"]},
            @{@"rows": @[@"AirDrop", @"AirPlay & Continuity|AirPlay & Handoff", @"*Screen Capture"]},
            @{@"rows": @[@"*AutoFill & Passwords", @"Background App Refresh", @"Date & Time", @"Dictionary", @"Fonts",
                         @"*Game Controller", @"Keyboard", @"Language & Region", @"@rest"]},
            @{@"drop": @[@"Picture in Picture", @"Gestures"]},
            @{@"rows": @[@"^TV Provider"]},
            @{@"rows": @[@"VPN & Device Management|~Device Management|~VPN|~ManagedConfiguration"]},
            @{@"rows": @[@"Legal & Regulatory"]},
            @{@"rows": @[@"Transfer or Reset iPad"]},
            @{@"rows": @[@"Shut Down"]},
        ],
        @"Privacy & Security": @[
            @{@"rows": @[@"Location Services", @"Tracking"]},
            @{@"rows": @[@"Calendars", @"Contacts", @"Files & Folders|Files and Folders", @"Focus", @"Health Data|Health",
                         @"HomeKit", @"Media & Apple Music", @"Passkeys Access for Web Browsers", @"Photos", @"Reminders"]},
            @{@"rows": @[@"*Accessories=0", @"Bluetooth", @"Camera", @"*Critical Messages=0", @"Local Network", @"Microphone",
                         @"Motion & Fitness", @"Nearby Interactions", @"*Paired Devices=0", @"Research Sensor & Usage Data",
                         @"Speech Recognition", @"@rest"]},
            @{@"rows": @[@"*Journaling Suggestions"]},
            @{@"rows": @[@"*Blocked Contacts"]},
            @{@"rows": @[@"Sensitive Content Warning"]},
            @{@"rows": @[@"Analytics & Improvements", @"Apple Advertising"]},
            @{@"header": @"Transparency Logs", @"rows": @[@"App Privacy Report"]},
            @{@"header": @"Security", @"rows": @[@"*Wired Accessories=Automatically Allow When Unlocked",
                                                 @"*Background Security Improvements", @"Developer Mode", @"Lockdown Mode"]},
        ],
        @"Notifications": @[
            @{@"rows": @[@"Scheduled Summary", @"Show Previews", @"Screen Sharing"]},
            @{@"header": @"Siri", @"rows": @[@"*Announce Notifications=Off", @"Siri Suggestions"]},
            @{@"header": @"Notification Style", @"rows": @[@"@rest"]},
        ],
        @"Siri": @[
            @{@"header": @"Siri Requests",
              @"footer": @"Voice input is processed on iPad, but transcripts of your requests are sent to Apple. About Siri & Privacy\u2026",
              @"rows": @[@"Language", @"&Talk to Siri",
                         @"Allow Siri When Locked", @"Voice|Siri Voice", @"Siri Responses", @"*Call Hang Up=Off",
                         @"Announce Calls", @"Announce Notifications", @"Messaging with Siri|Automatically Send Messages",
                         @"Siri & Dictation History", @"My Information"]},
            @{@"header": @"Suggestions",
              @"footer": @"Apple can make suggestions in Search, on Home Screen and Lock Screen, when sharing, or when you may want to listen to media.",
              @"rows": @[@"Suggest Apps Before Searching|Show Suggestions", @"+Reset Hidden Suggestions", @"Allow Notifications",
                         @"Show in App Library", @"Show When Sharing", @"Show Listening Suggestions|Show When Listening"]},
            @{@"header": @"Siri App Access", @"rows": @[@"App Clips", @"*Apps"]},
            @{@"dropRest": @YES},
        ],
    }; });
    return d;
}

static NSString *LGPaneTitle(PSListController *lc);
static NSString *LGTitleCase(NSString *t);

#pragma mark - Privacy counts (TCCAccessCopyInformation, as used by Settings itself)

#include <dlfcn.h>
static NSInteger LGTCCCount(NSString *service, NSInteger *granted) {
    static CFArrayRef (*copyInfo)(CFStringRef, CFDictionaryRef);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_LAZY);
        if (h) copyInfo = (CFArrayRef (*)(CFStringRef, CFDictionaryRef))dlsym(h, "TCCAccessCopyInformation");
    });
    if (!copyInfo) return -1;
    NSArray *info = (__bridge_transfer NSArray *)copyInfo((__bridge CFStringRef)service, NULL);
    if (![info isKindOfClass:[NSArray class]]) return -1;
    NSInteger g = 0;
    for (NSDictionary *d in info) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        id v = d[@"kTCCInfoGranted"];
        if ([v respondsToSelector:@selector(boolValue)] && [v boolValue]) g++;
    }
    if (granted) *granted = g;
    return (NSInteger)info.count;
}

// subtitle rows ("None", "5 apps", "1 full access") and right-side numbers, like the reference
static void LGPrivacyCounts(NSArray *specs) {
    NSDictionary *sub = @{ @"Calendars": @"kTCCServiceCalendar", @"Contacts": @"kTCCServiceAddressBook",
                           @"Focus": @"kTCCServiceFocusStatus", @"HomeKit": @"kTCCServiceWillow",
                           @"Media & Apple Music": @"kTCCServiceMediaLibrary", @"Photos": @"kTCCServicePhotos",
                           @"Reminders": @"kTCCServiceReminders" };
    NSDictionary *num = @{ @"Bluetooth": @"kTCCServiceBluetoothAlways", @"Camera": @"kTCCServiceCamera",
                           @"Microphone": @"kTCCServiceMicrophone", @"Motion & Fitness": @"kTCCServiceMotion",
                           @"Speech Recognition": @"kTCCServiceSpeechRecognition" };
    for (PSSpecifier *sp in specs) {
        NSString *n = LGNormalizeTitle(sp.name ?: @"");
        NSInteger g = 0, c;
        if (sub[n]) {
            c = LGTCCCount(sub[n], &g);
            if (c < 0) continue;
            NSString *t = c == 0 ? @"None"
                        : [n isEqualToString:@"Contacts"] ? [NSString stringWithFormat:@"%ld full access", (long)g]
                        : [NSString stringWithFormat:@"%ld app%@", (long)c, c == 1 ? @"" : @"s"];
            [sp setProperty:t forKey:@"lgSubtitle"];
            [sp setProperty:@64 forKey:@"height"];
        } else if (num[n]) {
            c = LGTCCCount(num[n], &g);
            if (c >= 0) [sp setProperty:[NSString stringWithFormat:@"%ld", (long)c] forKey:@"lgRightValue"];
        } else if ([n isEqualToString:@"Files & Folders"] || [n isEqualToString:@"Health Data"]) {
            [sp setProperty:@"None" forKey:@"lgSubtitle"];
            [sp setProperty:@64 forKey:@"height"];
        }
    }
}

static NSMutableArray *LGReorderPane(PSListController *lc, NSArray *orig, NSArray *layout) {
    NSMutableArray<PSSpecifier *> *pool = [NSMutableArray new];
    NSMutableDictionary<NSString *, PSSpecifier *> *firstFooter = [NSMutableDictionary new];
    PSSpecifier *lastGroup = nil;
    for (PSSpecifier *sp in orig) {
        if (sp.cellType == kPSGroupCell) { lastGroup = sp; continue; }
        if ([sp.identifier hasPrefix:kLGFakePrefix] && !sp.target) continue;
        if ([sp.identifier hasPrefix:kLGFakePrefix] && [sp.detailControllerClass isEqual:NSClassFromString(@"LGPaneController")]) continue;
        [pool addObject:sp];
        // keep the footer text that described this row's group (e.g. Location Services)
        id footer = [lastGroup propertyForKey:@"footerText"];
        if (footer && !lastGroup.identifier.length) firstFooter[LGNormalizeTitle(sp.name ?: @"")] = lastGroup;
        else if (footer && ![lastGroup.identifier hasPrefix:kLGFakePrefix]) firstFooter[LGNormalizeTitle(sp.name ?: @"")] = lastGroup;
    }
    if (!pool.count) return nil;

    // rows the reference page doesn't have
    BOOL dropRest = NO;
    for (NSDictionary *g in layout) {
        if ([g[@"dropRest"] boolValue]) dropRest = YES;
        for (NSString *n in g[@"drop"]) {
            NSIndexSet *ix = [pool indexesOfObjectsPassingTest:^BOOL(PSSpecifier *sp, NSUInteger i, BOOL *st) {
                return [LGNormalizeTitle(sp.name ?: @"") isEqualToString:n]; }];
            [pool removeObjectsAtIndexes:ix];
        }
    }

    NSMutableArray *out = [NSMutableArray new];
    NSUInteger restAt = NSNotFound, gi = 0;
    for (NSDictionary *g in layout) {
        if (!g[@"rows"]) continue;
        NSMutableArray *rows = [NSMutableArray new];
        BOOL wantsRest = NO;
        PSSpecifier *footerSource = nil;
        for (NSString *raw in g[@"rows"]) {
            if ([raw isEqualToString:@"@rest"]) { wantsRest = YES; continue; }
            if ([raw isEqualToString:@"&Talk to Siri"]) {
                // iPadOS 26 moves "Hey Siri" and the top button into a "Talk to Siri" page
                NSMutableArray *talk = [NSMutableArray new];
                for (PSSpecifier *sp in [pool copy]) {
                    NSString *n = LGNormalizeTitle(sp.name ?: @"");
                    if ([n hasPrefix:@"Listen for"] || [n isEqualToString:@"Press Top Button for Siri"] ||
                        [n isEqualToString:@"Press Home for Siri"]) { [talk addObject:sp]; [pool removeObject:sp]; }
                }
                gLGTalkSpecs = talk;
                [rows addObject:LGFakeRow(@"Talk to Siri", lc)];
                continue;
            }
            BOOL fake = [raw hasPrefix:@"*"] || [raw hasPrefix:@"+"], borrow = [raw hasPrefix:@"^"];
            if (fake) {
                // look-only row, but if iPadOS 16 already has a real one with that name, use the real one
                NSString *body = [raw substringFromIndex:1];
                NSString *nm = [[body componentsSeparatedByString:@"="].firstObject componentsSeparatedByString:@"|"].firstObject;
                PSSpecifier *real = nil;
                for (PSSpecifier *sp in pool) if ([LGNormalizeTitle(sp.name ?: @"") isEqualToString:nm]) { real = sp; break; }
                if (real) { [pool removeObject:real]; [rows addObject:real]; }
                else [rows addObject:LGFakeRowSpec([raw hasPrefix:@"+"] ? raw : body, lc)];
                continue;
            }
            NSArray *names = [((fake || borrow) ? [raw substringFromIndex:1] : raw) componentsSeparatedByString:@"|"];
            PSSpecifier *found = nil;
            for (NSString *n in names) {
                BOOL partial = [n hasPrefix:@"~"];
                NSString *needle = partial ? [n substringFromIndex:1] : n;
                for (PSSpecifier *sp in pool) {
                    NSString *nm = LGNormalizeTitle(sp.name ?: @"");
                    if (partial ? ([nm rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound ||
                                   [sp.identifier ?: @"" rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound)
                                : [nm isEqualToString:n]) { found = sp; break; }
                }
                if (found) break;
            }
            if (found) {
                [pool removeObject:found];
                if (![found.name isEqualToString:names.firstObject]) found.name = names.firstObject;
                if (!footerSource) footerSource = firstFooter[LGNormalizeTitle(names.lastObject)] ?: firstFooter[names.firstObject];
                [rows addObject:found];
            } else if (borrow) {
                for (PSSpecifier *sp in gLGAppSpecs)
                    if ([LGNormalizeTitle(sp.name ?: @"") isEqualToString:names.firstObject]) { [rows addObject:sp]; break; }
            }
        }
        if (wantsRest) restAt = out.count + 1 + rows.count; // filled after every group is placed
        if (!rows.count && !wantsRest) continue;
        PSSpecifier *grp = [(Class)LGSpecClass() groupSpecifierWithName:g[@"header"]];
        grp.identifier = [kLGFakePrefix stringByAppendingFormat:@"pane_%lu", (unsigned long)gi++];
        id footer = g[@"footer"];
        if (!footer && rows.count == 1) footer = [footerSource propertyForKey:@"footerText"];
        if (footer) [grp setProperty:footer forKey:@"footerText"];
        [out addObject:grp];
        [out addObjectsFromArray:rows];
        if (wantsRest) restAt = out.count;
    }
    if ([LGPaneTitle(lc) isEqualToString:@"Privacy & Security"]) LGPrivacyCounts(out);
    if (pool.count && !dropRest) {
        if (restAt != NSNotFound && restAt <= out.count)
            [out insertObjects:pool atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(restAt, pool.count)]];
        else {
            [out addObject:LGGroup(@"pane_rest")];
            [out addObjectsFromArray:pool];
        }
    }
    return out;
}

static char kPaneMarkKey;
static char kPanePendingKey;
static BOOL gLGPaneReordering;

static NSString *LGPaneTitle(PSListController *lc) {
    if ([[lc.specifier propertyForKey:@"lgFull"] boolValue]) return @"Battery Usage";
    NSArray *known = [LGPageLayouts().allKeys arrayByAddingObjectsFromArray:@[@"iPad Storage", @"Battery"]];
    NSString *first = nil;
    for (NSString *raw in @[lc.specifier.name ?: @"", lc.title ?: @"", lc.navigationItem.title ?: @""]) {
        NSString *t = LGNormalizeTitle(raw);
        if ([t isEqualToString:@"Siri & Search"]) t = @"Siri";
        if (!first && t.length) first = t;
        if ([known containsObject:t]) return t;
    }
    return first ?: @"";
}
static NSArray *LGLayoutFor(PSListController *lc) {
    if ([lc isKindOfClass:NSClassFromString(@"LGPaneController")] ||
        [lc isKindOfClass:NSClassFromString(@"PSUIPrefsListController")]) return nil;
    return LGPageLayouts()[LGPaneTitle(lc)];
}

static PSSpecifier *LGStorageHiddenRow(id target) {
    PSSpecifier *s = LGFakeRow(@"Hidden Apps", target);
    [s setProperty:@YES forKey:@"lgStorage"];
    return s;
}

static NSMutableArray *LGSpecialPane(PSListController *lc, NSArray *orig, NSString *title) {
    NSMutableArray *out = [orig mutableCopy];
    if ([title isEqualToString:@"iPad Storage"]) {
        for (PSSpecifier *sp in out) if ([sp.identifier isEqualToString:@"LG26_hidden_apps"]) return nil;
        NSUInteger os = NSNotFound;
        for (NSUInteger i = 0; i < out.count; i++)
        {
            NSString *n = LGNormalizeTitle(((PSSpecifier *)out[i]).name ?: @"");
            if ([n isEqualToString:@"iPadOS"] || [n isEqualToString:@"iOS"] || [n isEqualToString:@"System Data"]) { os = i; break; }
        }
        if (os == NSNotFound) {
            // iPadOS 16 draws iPadOS / System Data in custom cells without names: they are the last group
            if (out.count < 8) return nil;
            NSUInteger lastGroup = NSNotFound;
            for (NSUInteger i = out.count; i-- > 0;)
                if (((PSSpecifier *)out[i]).cellType == kPSGroupCell) { lastGroup = i; break; }
            if (lastGroup == NSNotFound || lastGroup == 0) return nil;
            [out insertObjects:@[LGGroup(@"storage_hidden"), LGStorageHiddenRow(lc)]
                     atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lastGroup, 2)]];
            return out;
        }
        NSUInteger g = os;
        while (g > 0 && ((PSSpecifier *)out[g]).cellType != kPSGroupCell) g--;
        [out insertObjects:@[LGGroup(@"storage_hidden"), LGStorageHiddenRow(lc)]
                 atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(g, 2)]];
        return out;
    }
    if ([title isEqualToString:@"Battery"]) {
        // iPadOS 26: level card + Daily Usage (table header), then the switches. The iPadOS 16
        // charts and per-app list move to "View All Battery Usage" (a second, untouched instance).
        NSSet *keepNames = [NSSet setWithArray:@[@"Battery Percentage", @"Low Power Mode", @"Battery Health & Charging",
                                                 @"Battery Health", @"Optimized Battery Charging"]];
        NSMutableArray *kept = [NSMutableArray new];
        __block NSMutableArray *grp = nil;
        __block PSSpecifier *grpSpec = nil;
        __block BOOL grpKeep = NO;
        void (^flush)(void) = ^{
            if (grpKeep && grpSpec) { [kept addObject:grpSpec]; [kept addObjectsFromArray:grp]; }
        };
        for (PSSpecifier *sp in out) {
            if (sp.cellType == kPSGroupCell) { flush(); grpSpec = sp; grp = [NSMutableArray new]; grpKeep = NO; continue; }
            if (!grpSpec) { grpSpec = LGGroup(@"batt_top"); grp = [NSMutableArray new]; }
            [grp addObject:sp];
            if ([keepNames containsObject:LGNormalizeTitle(sp.name ?: @"")]) grpKeep = YES;
        }
        flush();
        if (!kept.count) return nil;
        return kept;
    }
    return nil;
}

#pragma mark - Synchronous layout: specifiers are rearranged before the table first draws (no visible jump)

// iPad Storage > iPadOS / System Data (reference):
//   iPadOS:      header, Reserved Auto-Update Space, iPadOS (was "System Files"), Total Size, footer
//   System Data: header, Total Size (was "Other System Data"), footer (already the same)
static char kSysPageKey;
// rows may only be added when the list is drawn from its specifiers alone (a controller that draws
// its own rows from another model would index past its data and crash)
static BOOL LGSpecDriven(id lc) {
    Class base = objc_getClass("PSListController");
    if (!base || ![lc isKindOfClass:base]) return NO;
    SEL sels[] = { @selector(tableView:cellForRowAtIndexPath:), @selector(tableView:numberOfRowsInSection:),
                   @selector(numberOfSectionsInTableView:), @selector(tableView:heightForRowAtIndexPath:) };
    for (size_t i = 0; i < sizeof(sels) / sizeof(sels[0]); i++) {
        IMP mine = class_getMethodImplementation(object_getClass(lc), sels[i]);
        IMP theirs = class_getMethodImplementation(base, sels[i]);
        if (mine != theirs) return NO;
    }
    return YES;
}
static BOOL LGStorageDetailCandidate(PSListController *lc) {
    NSString *cls = NSStringFromClass(object_getClass(lc));
    if ([cls rangeOfString:@"Storage"].location != NSNotFound) return YES;
    id n = lc.specifier.name;
    return [n isKindOfClass:[NSString class]] &&
           ([n isEqualToString:@"iPadOS"] || [n isEqualToString:@"iOS"] || [n isEqualToString:@"System Data"]);
}
static NSString *LGStorageDetailKind(NSArray *specs) {
    if (![specs isKindOfClass:[NSArray class]] || specs.count > 40) return nil;
    for (PSSpecifier *sp in specs) {
        if (![sp isKindOfClass:LGSpecClass()] || ![sp.name isKindOfClass:[NSString class]]) continue;
        NSString *n = LGNormalizeTitle(sp.name);
        if ([n isEqualToString:@"System Files"]) return @"iPadOS";
        if ([n isEqualToString:@"Other System Data"]) return @"System Data";
    }
    return nil;
}
static NSMutableArray *LGStorageDetailPane(PSListController *lc, NSArray *orig) {
    if (!LGStorageDetailCandidate(lc)) return nil;
    NSString *page = LGStorageDetailKind(orig);
    if (!page) return nil;
    BOOL canAdd = LGSpecDriven(lc);
    NSMutableArray *out = [orig mutableCopy];
    for (NSUInteger i = 0; i < out.count; i++) {
        PSSpecifier *sp = out[i];
        if (![sp isKindOfClass:LGSpecClass()] || ![sp.name isKindOfClass:[NSString class]]) continue;
        NSString *n = LGNormalizeTitle(sp.name);
        if ([page isEqualToString:@"System Data"] && [n isEqualToString:@"Other System Data"]) {
            sp.name = @"Total Size";
            break;
        }
        if ([page isEqualToString:@"iPadOS"] && [n isEqualToString:@"System Files"]) {
            sp.name = @"iPadOS";
            if (!canAdd) break;
            PSSpecifier *res = [(Class)LGSpecClass() preferenceSpecifierNamed:@"Reserved Auto-Update Space" target:LGValues()
                                                                          set:NULL get:@selector(lgValue:) detail:Nil cell:4 edit:Nil];
            res.identifier = [kLGFakePrefix stringByAppendingString:@"sys_reserved"];
            [res setProperty:kSysReservedText forKey:@"lgValue"];
            PSSpecifier *tot = [(Class)LGSpecClass() preferenceSpecifierNamed:@"Total Size" target:LGValues()
                                                                          set:NULL get:@selector(lgSysTotal:) detail:Nil cell:4 edit:Nil];
            tot.identifier = [kLGFakePrefix stringByAppendingString:@"sys_total"];
            [tot setProperty:@"" forKey:@"lgValue"];
            [tot setProperty:sp forKey:@"lgSrc"];
            [out insertObject:tot atIndex:i + 1];
            [out insertObject:res atIndex:i];
            NSString *foot = @"iOS size may vary depending on usage. Reserved update space depends on the amount of free space you have available.";
            BOOL footSet = NO;
            for (NSInteger g = (NSInteger)i; g >= 0; g--) {
                PSSpecifier *gs = out[g];
                if ([gs isKindOfClass:LGSpecClass()] && gs.cellType == kPSGroupCell) {
                    [gs setProperty:foot forKey:@"footerText"];
                    footSet = YES;
                    break;
                }
            }
            if (!footSet) { // the rows sit in the list's first, unnamed group: give it a real group for the footer
                PSSpecifier *g0 = LGGroup(@"sys_group");
                [g0 setProperty:foot forKey:@"footerText"];
                [out insertObject:g0 atIndex:0];
            }
            break;
        }
    }
    lc.title = page;
    lc.navigationItem.title = page;
    objc_setAssociatedObject(lc, &kSysPageKey, page, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return out;
}

static NSMutableArray *LGTransformPane(PSListController *lc, NSMutableArray *s) {
    NSMutableArray *sysDetail = LGStorageDetailPane(lc, s);
    if (sysDetail) return sysDetail;
    NSArray *layout = LGLayoutFor(lc);
    NSString *ptitle = LGPaneTitle(lc);
    BOOL special = [ptitle isEqualToString:@"iPad Storage"] || [ptitle isEqualToString:@"Battery"];
    if (!layout && !special) return nil;
    if ([ptitle isEqualToString:@"Siri"] && ![lc.title isEqualToString:@"Siri"]) {
        lc.title = @"Siri";
        lc.navigationItem.title = @"Siri";
    }
    return layout ? LGReorderPane(lc, s, layout) : LGSpecialPane(lc, s, ptitle);
}

// Runs on every -specifiers call. Only fresh (never seen) arrays are rearranged here; arrays that
// Settings mutates later (rows inserted in place) are left to the deferred pass, so the table never
// sees its data source change in the middle of an update.
static void LGPrimeIcons(NSArray *specs) {
    for (PSSpecifier *sp in specs) {
        if (![sp isKindOfClass:LGSpecClass()] || sp.cellType == kPSGroupCell || ![sp.name isKindOfClass:[NSString class]]) continue;
        UIImage *ref = LGRefIcon(LGNormalizeTitle(sp.name), NO);
        if (ref && [sp propertyForKey:@"iconImage"] != ref) [sp setProperty:ref forKey:@"iconImage"];
    }
}

static NSMutableArray *LGAfterSpecifiers(PSListController *lc, NSMutableArray *s) {
    if (!LGSidebarEnabled() || ![s isKindOfClass:[NSArray class]] || !s.count) return s;
    BOOL sidebar = [lc isKindOfClass:NSClassFromString(@"PSUIPrefsListController")];
    if (sidebar ? gLGReordering : gLGPaneReordering) return s;
    if ([lc isKindOfClass:NSClassFromString(@"LGPaneController")]) return s;
    char *markKey = sidebar ? &kReorderMarkKey : &kPaneMarkKey;
    if (objc_getAssociatedObject(s, markKey)) return s;
    if (sidebar) LGPrimeIcons(s);
    NSMutableArray *n = nil;
    if (sidebar) gLGReordering = YES; else gLGPaneReordering = YES;
    @try {
        n = sidebar ? LGReorderSidebar(lc, s) : LGTransformPane(lc, s);
    } @catch (NSException *e) {
        NSLog(@"[Settings26] layout failed: %@", e);
        n = nil;
    }
    if (sidebar) gLGReordering = NO; else gLGPaneReordering = NO;
    NSMutableArray *out = n ? ([n isKindOfClass:[NSMutableArray class]] ? n : [n mutableCopy]) : s;
    if (n) {
        Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
        if (iv) object_setIvarWithStrongDefault(lc, iv, out);
    }
    objc_setAssociatedObject(out, markKey, @(LGSpecSignature(out)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return out;
}

// Pane classes that implement their own -specifiers (and so never reach PSListController's)
static void LGHookSpecifiersGetter(Class cls) {
    static NSMutableSet *done;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ done = [NSMutableSet new]; });
    Class base = objc_getClass("PSListController");
    Class sidebar = objc_getClass("PSUIPrefsListController");
    Class pane = objc_getClass("LGPaneController");
    SEL sel = @selector(specifiers);
    for (Class c = cls; c && c != base; c = class_getSuperclass(c)) {
        if (c == sidebar || c == pane || [done containsObject:c]) continue;
        [done addObject:c];
        Method m = class_getInstanceMethod(c, sel);
        Method sm = class_getInstanceMethod(class_getSuperclass(c), sel);
        if (!m || (sm && method_getImplementation(m) == method_getImplementation(sm))) continue; // inherited
        unsigned int count = 0;
        BOOL own = NO;
        Method *list = class_copyMethodList(c, &count);
        for (unsigned int i = 0; i < count; i++) if (method_getName(list[i]) == sel) { m = list[i]; own = YES; break; }
        free(list);
        if (!own) continue;
        IMP orig = method_getImplementation(m);
        IMP repl = imp_implementationWithBlock(^NSMutableArray *(id me) {
            NSMutableArray *r = ((NSMutableArray *(*)(id, SEL))orig)(me, sel);
            return LGAfterSpecifiers((PSListController *)me, r);
        });
        method_setImplementation(m, repl);
    }
}

static void LGCheckPane(PSListController *lc) {
    if (gLGPaneReordering || !LGSidebarEnabled()) return;
    NSArray *layout = LGLayoutFor(lc);
    NSString *ptitle = LGPaneTitle(lc);
    BOOL special = [ptitle isEqualToString:@"iPad Storage"] || [ptitle isEqualToString:@"Battery"];
    if (!layout && !special) {
        Ivar sv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
        NSArray *now = sv ? object_getIvar(lc, sv) : nil;
        if (!LGStorageDetailCandidate(lc) || !LGStorageDetailKind(now)) return;
        NSMutableArray *n = LGStorageDetailPane(lc, now);
        if (n) {
            gLGPaneReordering = YES;
            @try { [lc setSpecifiers:n]; } @catch (NSException *e) {}
            gLGPaneReordering = NO;
        }
        return;
    }
    if ([ptitle isEqualToString:@"Siri"] && ![lc.title isEqualToString:@"Siri"]) {
        lc.title = @"Siri";
        lc.navigationItem.title = @"Siri";
    }
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSMutableArray *cur = iv ? object_getIvar(lc, iv) : nil;
    if (!cur.count) return;
    if (!objc_getAssociatedObject(cur, &kPaneMarkKey)) { // try the synchronous path first
        NSMutableArray *done = LGAfterSpecifiers(lc, cur);
        if (done != cur) {
            gLGPaneReordering = YES;
            [lc setSpecifiers:done]; // rebuilds section indices for the new order
            // Settings may keep a copy of the array: mark what it really holds, so it is not redone
            NSMutableArray *held = object_getIvar(lc, iv);
            if (held && held != done)
                objc_setAssociatedObject(held, &kPaneMarkKey, @(LGSpecSignature(held)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            gLGPaneReordering = NO;
            return;
        }
    }
    NSNumber *mark = objc_getAssociatedObject(cur, &kPaneMarkKey);
    if (mark && mark.unsignedIntegerValue == LGSpecSignature(cur)) return;
    if (objc_getAssociatedObject(lc, &kPanePendingKey)) return;
    objc_setAssociatedObject(lc, &kPanePendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UITableView *hideTV = lc.isViewLoaded ? LGFind(lc.view, [UITableView class]) : nil;
    if (hideTV.window && !mark) hideTV.alpha = 0; // first layout of this list: no visible jump
    __weak PSListController *w = lc;
    __weak UITableView *wHide = hideTV;
    dispatch_async(dispatch_get_main_queue(), ^{
        PSListController *me = w;
        if (!me) return;
        objc_setAssociatedObject(me, &kPanePendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gLGPaneReordering = YES;
        @try {
            NSMutableArray *now = [me specifiers];
            NSMutableArray *n = layout ? LGReorderPane(me, now, layout) : LGSpecialPane(me, now, ptitle);
            if (n) { [me setSpecifiers:n]; now = [me specifiers]; }
            if (now) objc_setAssociatedObject(now, &kPaneMarkKey, @(LGSpecSignature(now)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } @catch (NSException *e) {
            NSLog(@"[Settings26] pane layout failed: %@", e);
        }
        gLGPaneReordering = NO;
        wHide.alpha = 1;
    });
}

#pragma mark - Rows added or removed by Settings on a rearranged page (VPN & Device Management...)
// Settings adds such rows later with animated table updates. The page is already in the iPadOS 26
// order, so its index arithmetic no longer matches the table and UIKit throws ("invalid number of
// rows in section"). On rearranged pages the change is applied to the list here instead, the list is
// put back in order, and the table is reloaded in one step (cross-fade), which cannot mismatch.

static BOOL LGPaneManaged(id lc) {
    if (!LGSidebarEnabled() || gLGPaneReordering) return NO;
    if (![lc isKindOfClass:objc_getClass("PSListController")]) return NO;
    return LGLayoutFor((PSListController *)lc) != nil;
}
static NSMutableArray *LGPaneCurrent(PSListController *lc) {
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSArray *cur = iv ? object_getIvar(lc, iv) : nil;
    if (!cur) cur = [lc specifiers];
    return cur ? [cur mutableCopy] : [NSMutableArray new];
}
static NSUInteger LGGroupEnd(NSArray *arr, NSInteger group) {
    NSInteger g = (arr.count && ((PSSpecifier *)arr[0]).cellType != kPSGroupCell) ? 0 : -1;
    for (NSUInteger i = 0; i < arr.count; i++) {
        if (((PSSpecifier *)arr[i]).cellType == kPSGroupCell) {
            if (g == group) return i; // next group starts: end of the wanted one
            g++;
        }
    }
    return arr.count;
}
static void LGPaneApply(PSListController *lc, NSMutableArray *arr, BOOL animated) {
    NSArray *layout = LGLayoutFor(lc);
    gLGPaneReordering = YES;
    NSMutableArray *n = nil;
    @try { n = LGReorderPane(lc, arr, layout); } @catch (NSException *e) { n = nil; }
    if (!n) n = arr;
    UITableView *tv = lc.isViewLoaded ? LGFind(lc.view, [UITableView class]) : nil;
    @try {
        (void)animated; (void)tv;
        [UIView performWithoutAnimation:^{ [lc setSpecifiers:n]; }];
    } @catch (NSException *e) {
        NSLog(@"[Settings26] pane update failed: %@", e);
    }
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSMutableArray *held = iv ? object_getIvar(lc, iv) : nil;
    if (held) objc_setAssociatedObject(held, &kPaneMarkKey, @(LGSpecSignature(held)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gLGPaneReordering = NO;
}
// kind: 0 at index, 1 after specifier, 2 after specifier ID, 3 at end of group
static void LGPaneInsert(PSListController *lc, NSArray *specs, int kind, NSInteger index, id anchor, BOOL animated) {
    NSMutableArray *arr = LGPaneCurrent(lc);
    NSMutableArray *add = [NSMutableArray new];
    for (id sp in specs) if ([sp isKindOfClass:LGSpecClass()] && [arr indexOfObjectIdenticalTo:sp] == NSNotFound) [add addObject:sp];
    if (!add.count) return;
    NSUInteger at = arr.count;
    if (kind == 0 && index >= 0 && (NSUInteger)index <= arr.count) at = (NSUInteger)index;
    if (kind == 1 && anchor) { NSUInteger i = [arr indexOfObjectIdenticalTo:anchor]; if (i != NSNotFound) at = i + 1; }
    if (kind == 2 && [anchor isKindOfClass:[NSString class]]) {
        for (NSUInteger i = 0; i < arr.count; i++)
            if ([((PSSpecifier *)arr[i]).identifier isEqual:anchor]) { at = i + 1; break; }
    }
    if (kind == 3) at = LGGroupEnd(arr, index);
    [arr insertObjects:add atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(at, add.count)]];
    LGPaneApply(lc, arr, animated);
}
static void LGPaneRemove(PSListController *lc, NSArray *specs, BOOL animated) {
    NSMutableArray *arr = LGPaneCurrent(lc);
    BOOL changed = NO;
    for (id sp in specs) {
        NSUInteger i = [arr indexOfObjectIdenticalTo:sp];
        if (i != NSNotFound) { [arr removeObjectAtIndex:i]; changed = YES; }
    }
    if (changed) LGPaneApply(lc, arr, animated);
}
static PSSpecifier *LGPaneSpecWithID(PSListController *lc, NSString *sid) {
    if (![sid isKindOfClass:[NSString class]]) return nil;
    for (PSSpecifier *sp in LGPaneCurrent(lc)) if ([sp.identifier isEqual:sid]) return sp;
    return nil;
}

static IMP o_insCAt, o_insCAfter, o_insCAfterID, o_insCEnd, o_insAt, o_insAfter, o_insAfterID, o_insEnd;
static IMP o_add, o_addArr, o_rem, o_remID, o_remAt, o_remC, o_remLast, o_rep;
static void LGSwapImp(Class c, SEL sel, id block, IMP *orig) {
    Method m = class_getInstanceMethod(c, sel);
    if (!m) return; // not on this iOS: leave it
    *orig = method_setImplementation(m, imp_implementationWithBlock(block));
}
typedef void (*LGF_idlB)(id, SEL, id, NSInteger, BOOL);
typedef void (*LGF_ididB)(id, SEL, id, id, BOOL);
typedef void (*LGF_idB)(id, SEL, id, BOOL);
typedef void (*LGF_lB)(id, SEL, NSInteger, BOOL);
typedef void (*LGF_B)(id, SEL, BOOL);

static void LGInstallPaneMutationHooks(void) {
    Class c = objc_getClass("PSListController");
    if (!c) return;
    SEL s1 = @selector(insertContiguousSpecifiers:atIndex:animated:);
    LGSwapImp(c, s1, ^(id me, NSArray *specs, NSInteger idx, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_idlB)o_insCAt)(me, s1, specs, idx, a); return; }
        LGPaneInsert(me, specs, 0, idx, nil, a);
    }, &o_insCAt);
    SEL s2 = @selector(insertContiguousSpecifiers:afterSpecifier:animated:);
    LGSwapImp(c, s2, ^(id me, NSArray *specs, id after, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_ididB)o_insCAfter)(me, s2, specs, after, a); return; }
        LGPaneInsert(me, specs, 1, 0, after, a);
    }, &o_insCAfter);
    SEL s3 = @selector(insertContiguousSpecifiers:afterSpecifierID:animated:);
    LGSwapImp(c, s3, ^(id me, NSArray *specs, id after, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_ididB)o_insCAfterID)(me, s3, specs, after, a); return; }
        LGPaneInsert(me, specs, 2, 0, after, a);
    }, &o_insCAfterID);
    SEL s4 = @selector(insertContiguousSpecifiers:atEndOfGroup:animated:);
    LGSwapImp(c, s4, ^(id me, NSArray *specs, NSInteger g, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_idlB)o_insCEnd)(me, s4, specs, g, a); return; }
        LGPaneInsert(me, specs, 3, g, nil, a);
    }, &o_insCEnd);
    SEL s5 = @selector(insertSpecifier:atIndex:animated:);
    LGSwapImp(c, s5, ^(id me, id spec, NSInteger idx, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_idlB)o_insAt)(me, s5, spec, idx, a); return; }
        LGPaneInsert(me, @[spec], 0, idx, nil, a);
    }, &o_insAt);
    SEL s6 = @selector(insertSpecifier:afterSpecifier:animated:);
    LGSwapImp(c, s6, ^(id me, id spec, id after, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_ididB)o_insAfter)(me, s6, spec, after, a); return; }
        LGPaneInsert(me, @[spec], 1, 0, after, a);
    }, &o_insAfter);
    SEL s7 = @selector(insertSpecifier:afterSpecifierID:animated:);
    LGSwapImp(c, s7, ^(id me, id spec, id after, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_ididB)o_insAfterID)(me, s7, spec, after, a); return; }
        LGPaneInsert(me, @[spec], 2, 0, after, a);
    }, &o_insAfterID);
    SEL s8 = @selector(insertSpecifier:atEndOfGroup:animated:);
    LGSwapImp(c, s8, ^(id me, id spec, NSInteger g, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_idlB)o_insEnd)(me, s8, spec, g, a); return; }
        LGPaneInsert(me, @[spec], 3, g, nil, a);
    }, &o_insEnd);
    SEL s9 = @selector(addSpecifier:animated:);
    LGSwapImp(c, s9, ^(id me, id spec, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_idB)o_add)(me, s9, spec, a); return; }
        LGPaneInsert(me, @[spec], 0, -1, nil, a);
    }, &o_add);
    SEL s10 = @selector(addSpecifiersFromArray:animated:);
    LGSwapImp(c, s10, ^(id me, NSArray *specs, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_idB)o_addArr)(me, s10, specs, a); return; }
        LGPaneInsert(me, specs, 0, -1, nil, a);
    }, &o_addArr);
    SEL s11 = @selector(removeSpecifier:animated:);
    LGSwapImp(c, s11, ^(id me, id spec, BOOL a) {
        if (!LGPaneManaged(me) || !spec) { ((LGF_idB)o_rem)(me, s11, spec, a); return; }
        LGPaneRemove(me, @[spec], a);
    }, &o_rem);
    SEL s12 = @selector(removeSpecifierID:animated:);
    LGSwapImp(c, s12, ^(id me, id sid, BOOL a) {
        if (!LGPaneManaged(me)) { ((LGF_idB)o_remID)(me, s12, sid, a); return; }
        PSSpecifier *sp = LGPaneSpecWithID(me, sid);
        if (sp) LGPaneRemove(me, @[sp], a);
    }, &o_remID);
    SEL s13 = @selector(removeSpecifierAtIndex:animated:);
    LGSwapImp(c, s13, ^(id me, NSInteger idx, BOOL a) {
        if (!LGPaneManaged(me)) { ((LGF_lB)o_remAt)(me, s13, idx, a); return; }
        NSMutableArray *arr = LGPaneCurrent(me);
        if (idx >= 0 && (NSUInteger)idx < arr.count) LGPaneRemove(me, @[arr[idx]], a);
    }, &o_remAt);
    SEL s14 = @selector(removeContiguousSpecifiers:animated:);
    LGSwapImp(c, s14, ^(id me, NSArray *specs, BOOL a) {
        if (!LGPaneManaged(me) || ![specs isKindOfClass:[NSArray class]]) { ((LGF_idB)o_remC)(me, s14, specs, a); return; }
        LGPaneRemove(me, specs, a);
    }, &o_remC);
    SEL s15 = @selector(removeLastSpecifierAnimated:);
    LGSwapImp(c, s15, ^(id me, BOOL a) {
        if (!LGPaneManaged(me)) { ((LGF_B)o_remLast)(me, s15, a); return; }
        NSMutableArray *arr = LGPaneCurrent(me);
        if (arr.count) LGPaneRemove(me, @[arr.lastObject], a);
    }, &o_remLast);
    SEL s16 = @selector(replaceContiguousSpecifiers:withSpecifiers:animated:);
    LGSwapImp(c, s16, ^(id me, NSArray *olds, NSArray *news, BOOL a) {
        if (!LGPaneManaged(me) || ![olds isKindOfClass:[NSArray class]] || ![news isKindOfClass:[NSArray class]]) {
            ((LGF_ididB)o_rep)(me, s16, olds, news, a); return;
        }
        NSMutableArray *arr = LGPaneCurrent(me);
        NSUInteger at = NSNotFound;
        for (id sp in olds) {
            NSUInteger i = [arr indexOfObjectIdenticalTo:sp];
            if (i == NSNotFound) continue;
            if (at == NSNotFound || i < at) at = i;
        }
        for (id sp in olds) { NSUInteger i = [arr indexOfObjectIdenticalTo:sp]; if (i != NSNotFound) [arr removeObjectAtIndex:i]; }
        if (at == NSNotFound || at > arr.count) at = arr.count;
        NSMutableArray *add = [NSMutableArray new];
        for (id sp in news) if ([sp isKindOfClass:LGSpecClass()] && [arr indexOfObjectIdenticalTo:sp] == NSNotFound) [add addObject:sp];
        if (add.count) [arr insertObjects:add atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(at, add.count)]];
        LGPaneApply(me, arr, a);
    }, &o_rep);
}

#pragma mark - Battery card (level + bar) and iPad Storage search capsule

static NSArray<NSString *> *LGDayLetters(void);
@interface LGUsageChart : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *allDay, *byNow;
@property (nonatomic) CGFloat average;
@end
@implementation LGUsageChart
- (void)drawRect:(CGRect)rect {
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGFloat labelH = 22, top = 6, plotH = H - labelH - top;
    CGFloat maxV = 60.0;
    NSArray *days = LGDayLetters();
    NSInteger n = days.count;
    CGFloat slot = (W - 70) / n, barW = MIN(30, slot * 0.36);
    // baseline
    [[UIColor colorWithWhite:1 alpha:0.12] setFill];
    UIRectFill(CGRectMake(0, top + plotH, W, 1));
    // average line
    CGFloat ay = top + plotH - plotH * MIN(1, self.average / maxV);
    UIBezierPath *avg = [UIBezierPath bezierPath];
    [avg moveToPoint:CGPointMake(0, ay)]; [avg addLineToPoint:CGPointMake(W, ay)];
    avg.lineWidth = 1; CGFloat dash[] = {2, 2}; [avg setLineDash:dash count:2 phase:0];
    [[UIColor colorWithWhite:1 alpha:0.25] setStroke]; [avg stroke];
    NSDictionary *small = @{ NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold],
                             NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:1] };
    CGSize as = [@"Average" sizeWithAttributes:small];
    [@"Average" drawAtPoint:CGPointMake(W - as.width, ay - as.height - 2) withAttributes:small];
    for (NSInteger i = 0; i < n; i++) {
        CGFloat cx = slot * i + slot / 2.0;
        BOOL today = (i == n - 1);
        CGFloat v = [self.allDay[i] doubleValue], w = [self.byNow[i] doubleValue];
        CGFloat h = plotH * MIN(1, v / maxV), hn = plotH * MIN(1, w / maxV);
        if (!today && h > 0) {
            [[UIColor colorWithWhite:1 alpha:0.18] setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx - barW / 2, top + plotH - h, barW, h) cornerRadius:4] fill];
        }
        if (hn > 0) {
            [(today ? UIColor.systemBlueColor : [UIColor colorWithWhite:1 alpha:0.32]) setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx - barW / 2, top + plotH - hn, barW, MAX(hn, 2)) cornerRadius:4] fill];
        }
        if (today) { [UIColor.systemBlueColor setFill]; UIRectFill(CGRectMake(cx - barW / 2, top + plotH - 1, barW, 2)); }
        NSDictionary *la = @{ NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold],
                              NSForegroundColorAttributeName: today ? UIColor.systemBlueColor : [UIColor colorWithWhite:0.6 alpha:1] };
        CGSize ls = [days[i] sizeWithAttributes:la];
        [days[i] drawAtPoint:CGPointMake(cx - ls.width / 2, top + plotH + 6) withAttributes:la];
    }
}
@end

static NSArray<NSString *> *LGDayLetters(void) {
    NSCalendar *cal = NSCalendar.currentCalendar;
    NSArray *sym = @[@"S", @"M", @"T", @"W", @"T", @"F", @"S"];
    NSMutableArray *out = [NSMutableArray new];
    for (NSInteger back = 7; back >= 0; back--) {
        NSDate *d = [cal dateByAddingUnit:NSCalendarUnitDay value:-back toDate:NSDate.date options:0];
        [out addObject:sym[[cal component:NSCalendarUnitWeekday fromDate:d] - 1]];
    }
    return out;
}

// stable per-day pseudo values (look only, as agreed)
static CGFloat LGDayValue(NSInteger dayIndex, NSInteger salt) {
    uint32_t x = (uint32_t)(dayIndex * 2654435761u) ^ (uint32_t)(salt * 40503u);
    x ^= x >> 13; x *= 0x5bd1e995; x ^= x >> 15;
    return (CGFloat)(x % 1000) / 1000.0;
}

@interface LGBatteryNav : NSObject
@property (nonatomic, weak) UIViewController *vc;
- (void)openUsage;
@end
@implementation LGBatteryNav
- (void)openUsage {
    UIViewController *vc = self.vc;
    if (!vc.navigationController) return;
    Class c = [vc class];
    UIViewController *n = [[c alloc] init];
    PSSpecifier *spec = [(Class)NSClassFromString(@"PSSpecifier") preferenceSpecifierNamed:@"Battery Usage" target:nil
                                                                                       set:NULL get:NULL detail:c cell:1 edit:Nil];
    PSSpecifier *orig = [vc respondsToSelector:@selector(specifier)] ? [(id)vc specifier] : nil;
    for (id k in orig.properties) [spec setProperty:orig.properties[k] forKey:k];
    spec.name = @"Battery Usage";
    [spec setProperty:@YES forKey:@"lgFull"];
    if ([n respondsToSelector:@selector(setSpecifier:)]) [(id)n setSpecifier:spec];
    if ([n respondsToSelector:@selector(setRootController:)] && [vc respondsToSelector:@selector(rootController)])
        [n performSelector:@selector(setRootController:) withObject:[vc performSelector:@selector(rootController)]];
    if ([n respondsToSelector:@selector(setParentController:)]) [n performSelector:@selector(setParentController:) withObject:vc];
    n.title = @"Battery Usage";
    [vc.navigationController pushViewController:n animated:YES];
}
@end
static char kBatteryNavKey;

static char kBatteryHeaderKey;
static void LGBatteryHeader(UIViewController *vc) {
    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 300 || tv.isEditing) return;
    UIDevice *d = UIDevice.currentDevice;
    if (!d.batteryMonitoringEnabled) d.batteryMonitoringEnabled = YES;
    float level = d.batteryLevel < 0 ? 0 : d.batteryLevel;
    NSString *state = d.batteryState == UIDeviceBatteryStateCharging ? @"Charging"
                    : d.batteryState == UIDeviceBatteryStateFull ? @"Fully Charged" : @"Not Charging";
    NSAttributedString *lastCharged = nil;
    {
        NSMutableArray<UIView *> *stk = [NSMutableArray arrayWithObject:tv];
        NSString *head = nil, *when = nil;
        while (stk.count && !head) {
            UIView *v = stk.lastObject; [stk removeLastObject];
            if (v == objc_getAssociatedObject(tv, &kBatteryHeaderKey)) continue;
            [stk addObjectsFromArray:v.subviews];
            if (![v isKindOfClass:[UILabel class]]) continue;
            NSString *t = ((UILabel *)v).text;
            if ([t.uppercaseString hasPrefix:@"LAST CHARGED"]) {
                head = t;
                // the time sits in a sibling label on iPadOS 16
                for (UIView *sib in v.superview.subviews)
                    if (sib != v && [sib isKindOfClass:[UILabel class]] && ((UILabel *)sib).text.length &&
                        ![((UILabel *)sib).text.uppercaseString hasPrefix:@"LAST CHARGED"]) { when = ((UILabel *)sib).text; break; }
            }
        }
        NSUserDefaults *look = [[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"];
        if (head) [look setObject:@[head, when ?: @""] forKey:@"LG26_last_charged"];
        else {
            NSArray *cached = [look arrayForKey:@"LG26_last_charged"];
            if (cached.count == 2) { head = cached[0]; when = [cached[1] length] ? cached[1] : nil; }
        }
        if (head) {
            NSString *h = LGTitleCase(head);
            NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:[h stringByAppendingString:when.length ? @": " : @""]
                attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: UIColor.labelColor }];
            if (when.length)
                [a appendAttributedString:[[NSAttributedString alloc] initWithString:when attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:15], NSForegroundColorAttributeName: UIColor.secondaryLabelColor }]];
            lastCharged = a;
        }
    }

    UIView *wrap = objc_getAssociatedObject(tv, &kBatteryHeaderKey);
    if (tv.tableHeaderView && tv.tableHeaderView != wrap && tv.tableHeaderView.bounds.size.height > 1) return; // page has its own header
    if (!wrap) {
        wrap = [UIView new];
        UIView *card = [UIView new]; card.tag = 1;
        card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card.layer.cornerRadius = kSectionRadius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [wrap addSubview:card];
        UILabel *pct = [UILabel new]; pct.tag = 2; [card addSubview:pct];
        UILabel *st = [UILabel new]; st.tag = 3; [card addSubview:st];
        UIView *track = [UIView new]; track.tag = 4;
        track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
        track.layer.cornerRadius = 4;
        [card addSubview:track];
        UIView *fill = [UIView new]; fill.tag = 5;
        fill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.62];
        fill.layer.cornerRadius = 4;
        [track addSubview:fill];
        UIImageView *info = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"]];
        info.tag = 6; info.tintColor = UIColor.tertiaryLabelColor;
        [card addSubview:info];

        // "Daily Usage"
        UILabel *dt = [UILabel new]; dt.tag = 20; dt.text = @"Daily Usage";
        dt.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; dt.textColor = UIColor.secondaryLabelColor;
        [wrap addSubview:dt];
        UIView *card2 = [UIView new]; card2.tag = 21;
        card2.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card2.layer.cornerRadius = kSectionRadius;
        card2.layer.cornerCurve = kCACornerCurveContinuous;
        card2.clipsToBounds = YES;
        [wrap addSubview:card2];
        UILabel *sum = [UILabel new]; sum.tag = 22; sum.numberOfLines = 0;
        sum.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; sum.textColor = UIColor.labelColor;
        [card2 addSubview:sum];
        for (NSInteger t = 23; t <= 30; t += 7) { UIView *sep = [UIView new]; sep.tag = t; sep.backgroundColor = UIColor.separatorColor; [card2 addSubview:sep]; }
        UILabel *avgT = [UILabel new]; avgT.tag = 24; avgT.text = @"Average";
        UILabel *todT = [UILabel new]; todT.tag = 26; todT.text = @"Today";
        for (UILabel *l in @[avgT, todT]) { l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold]; [card2 addSubview:l]; }
        avgT.textColor = UIColor.secondaryLabelColor; todT.textColor = UIColor.systemBlueColor;
        UILabel *avgV = [UILabel new]; avgV.tag = 25; [card2 addSubview:avgV];
        UILabel *todV = [UILabel new]; todV.tag = 27; [card2 addSubview:todV];
        LGUsageChart *chart = [LGUsageChart new]; chart.tag = 28; chart.backgroundColor = UIColor.clearColor; chart.opaque = NO;
        [card2 addSubview:chart];
        UILabel *legend = [UILabel new]; legend.tag = 29; [card2 addSubview:legend];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem]; row.tag = 31;
        [row setTitle:@"View All Battery Usage" forState:UIControlStateNormal];
        [row setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:17];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];
        chev.tag = 32; chev.tintColor = UIColor.tertiaryLabelColor;
        [row addSubview:chev];
        LGBatteryNav *nav = [LGBatteryNav new];
        nav.vc = vc;
        objc_setAssociatedObject(wrap, &kBatteryNavKey, nav, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [row addTarget:nav action:@selector(openUsage) forControlEvents:UIControlEventTouchUpInside];
        [card2 addSubview:row];
        objc_setAssociatedObject(tv, &kBatteryHeaderKey, wrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIView *card = [wrap viewWithTag:1];
    UILabel *pct = (UILabel *)[card viewWithTag:2], *st = (UILabel *)[card viewWithTag:3];
    UIView *track = [card viewWithTag:4], *fill = [track viewWithTag:5], *info = [card viewWithTag:6];

    NSMutableAttributedString *p = [[NSMutableAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"%d", (int)lroundf(level * 100)]
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:40 weight:UIFontWeightBold],
                          NSForegroundColorAttributeName: UIColor.labelColor }];
    [p appendAttributedString:[[NSAttributedString alloc] initWithString:@"%" attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightBold], NSForegroundColorAttributeName: UIColor.labelColor }]];
    if (![pct.attributedText isEqualToAttributedString:p]) pct.attributedText = p;
    if (lastCharged) {
        if (![st.attributedText isEqualToAttributedString:lastCharged]) st.attributedText = lastCharged;
    } else if (![st.text isEqualToString:state]) {
        st.text = state;
        st.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        st.textColor = UIColor.secondaryLabelColor;
    }

    CGRect sr = LGSectionRect(tv);
    CGFloat x = sr.origin.x, w = sr.size.width;
    CGFloat pad = 20;
    pct.frame = CGRectMake(pad, 14, w - pad * 2 - 30, 52);
    st.frame = CGRectMake(pad, 66, w - pad * 2, 20);
    track.frame = CGRectMake(pad, 96, w - pad * 2, 8);
    fill.frame = CGRectMake(0, 0, MAX(8, track.bounds.size.width * level), 8);
    fill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.45]; // reference: grey fill, even when low
    info.frame = CGRectMake(w - pad - 20, 16, 20, 20);
    CGFloat ch = 124;
    card.frame = CGRectMake(x, 24, w, ch);

    // ---- Daily Usage card ----
    UIView *dt = [wrap viewWithTag:20], *card2 = [wrap viewWithTag:21];
    UILabel *sum = (UILabel *)[card2 viewWithTag:22];
    UILabel *avgT = (UILabel *)[card2 viewWithTag:24], *avgV = (UILabel *)[card2 viewWithTag:25];
    UILabel *todT = (UILabel *)[card2 viewWithTag:26], *todV = (UILabel *)[card2 viewWithTag:27];
    LGUsageChart *chart = (LGUsageChart *)[card2 viewWithTag:28];
    UILabel *legend = (UILabel *)[card2 viewWithTag:29];
    UIButton *row = (UIButton *)[card2 viewWithTag:31];

    NSDateFormatter *hm = [NSDateFormatter new];
    hm.dateFormat = @"HH:mm";
    NSString *now = [hm stringFromDate:NSDate.date];
    NSInteger doy = [NSCalendar.currentCalendar ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:NSDate.date];
    NSMutableArray *all = [NSMutableArray new], *by = [NSMutableArray new];
    CGFloat avgSum = 0;
    for (NSInteger i = 0; i < 8; i++) {
        NSInteger day = doy - (7 - i);
        CGFloat a = 18 + 40 * LGDayValue(day, 1);
        CGFloat b = (LGDayValue(day, 2) < 0.4) ? 4 + 10 * LGDayValue(day, 3) : 0;
        if (i < 7) avgSum += a;
        [all addObject:@(i < 7 ? a : 0)];
        [by addObject:@(i < 7 ? b : 1)];
    }
    NSInteger avgPct = (NSInteger)lround(avgSum / 7.0 / 4.0);
    NSInteger todayPct = MAX(1, (NSInteger)lround(LGDayValue(doy, 4) * 3));
    chart.allDay = all; chart.byNow = by; chart.average = avgSum / 7.0 * 0.62;
    [chart setNeedsDisplay];
    NSString *sumText = [NSString stringWithFormat:@"You\u2019re using less battery today than you usually do by %@.", now];
    if (![sum.text isEqualToString:sumText]) sum.text = sumText;
    NSMutableAttributedString *(^pctString)(NSInteger, UIColor *) = ^NSMutableAttributedString *(NSInteger v, UIColor *c) {
        NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)v]
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:26 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: c }];
        [a appendAttributedString:[[NSAttributedString alloc] initWithString:@"%" attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: c }]];
        return a;
    };
    avgV.attributedText = pctString(avgPct, UIColor.secondaryLabelColor);
    todV.attributedText = pctString(todayPct, UIColor.systemBlueColor);
    NSMutableAttributedString *lg = [NSMutableAttributedString new];
    NSDictionary *la = @{ NSFontAttributeName: [UIFont systemFontOfSize:13], NSForegroundColorAttributeName: UIColor.secondaryLabelColor };
    [lg appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u25CF " attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:11], NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.3] }]];
    [lg appendAttributedString:[[NSAttributedString alloc] initWithString:@"All Day   " attributes:la]];
    [lg appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u25CF " attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:11], NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.5] }]];
    [lg appendAttributedString:[[NSAttributedString alloc] initWithString:[@"Daily by " stringByAppendingString:now] attributes:la]];
    legend.attributedText = lg;

    CGFloat cy = 18;
    CGFloat sh = ceil([sum sizeThatFits:CGSizeMake(w - 40, CGFLOAT_MAX)].height);
    sum.frame = CGRectMake(20, cy, w - 40, sh); cy += sh + 16;
    [card2 viewWithTag:23].frame = CGRectMake(20, cy, w - 40, 1.0 / UIScreen.mainScreen.scale); cy += 16;
    avgT.frame = CGRectMake(20, cy, 100, 18); todT.frame = CGRectMake(140, cy, 100, 18); cy += 20;
    avgV.frame = CGRectMake(20, cy, 110, 32); todV.frame = CGRectMake(140, cy, 110, 32); cy += 40;
    chart.frame = CGRectMake(20, cy, w - 40, 150); cy += 156;
    legend.frame = CGRectMake(20, cy, w - 40, 18); cy += 30;
    [card2 viewWithTag:30].frame = CGRectMake(20, cy, w - 40, 1.0 / UIScreen.mainScreen.scale);
    row.frame = CGRectMake(20, cy, w - 40, 56);
    [row viewWithTag:32].frame = CGRectMake(w - 40 - 12, 20, 10, 16);
    cy += 56;
    CGFloat dtY = 24 + ch + 30;
    dt.frame = CGRectMake(x + 20, dtY, w - 40, 22);
    card2.frame = CGRectMake(x, dtY + 30, w, cy);
    CGFloat totalH = dtY + 30 + cy + 30;
    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1 || fabs(wrap.frame.size.width - tv.bounds.size.width) > 1) {
        wrap.frame = CGRectMake(0, 0, tv.bounds.size.width, totalH);
        tv.tableHeaderView = wrap;
    }
}

static char kStorageFilterKey;
static char kStorageShownKey;
static void LGStorageSnapshot(id lc, UITableView *tv);
static void LGStorageCapsule(UIViewController *vc) {
    if (vc.navigationItem.rightBarButtonItem.customView.tag == 0x2612) return;
    UITableView *tv = LGFind(vc.view, [UITableView class]);
    UIViewController *owner = tv ? LGOwnerVC(tv) : vc;
    CGFloat W = 300;
    UIView *cap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 44)];
    cap.tag = 0x2612;
    cap.backgroundColor = [UIColor colorWithRed:38/255.0 green:38/255.0 blue:40/255.0 alpha:1];
    cap.layer.cornerRadius = 22;
    cap.layer.borderWidth = 0.5;
    cap.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    UIImageView *mag = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]];
    UIImageView *mic = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mic" withConfiguration:cfg]];
    mag.tintColor = UIColor.secondaryLabelColor; mic.tintColor = [UIColor colorWithWhite:0.92 alpha:1];
    mag.frame = CGRectMake(16, 11, 22, 22); mic.frame = CGRectMake(W - 38, 11, 22, 22);
    mag.contentMode = UIViewContentModeCenter; mic.contentMode = UIViewContentModeCenter;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(46, 0, W - 46 - 44, 44)];
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Applications"
        attributes:@{ NSForegroundColorAttributeName: UIColor.secondaryLabelColor }];
    tf.font = [UIFont systemFontOfSize:17];
    tf.textColor = UIColor.labelColor;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.returnKeyType = UIReturnKeySearch;
    __weak UIViewController *wo = owner;
    __weak UITableView *wtv = tv;
    [tf addAction:[UIAction actionWithHandler:^(UIAction *a) {
        UIViewController *o = wo;
        if (!o) return;
        UITableView *t = wtv;
        objc_setAssociatedObject(o, &kStorageFilterKey, ((UITextField *)a.sender).text, OBJC_ASSOCIATION_COPY_NONATOMIC);
        // snapshot first (outside any table callback), then reload
        objc_setAssociatedObject(o, &kStorageShownKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id ds = (id)t.dataSource;
        if (!ds) ds = o;
        if (ds != o) objc_setAssociatedObject(ds, &kStorageFilterKey, ((UITextField *)a.sender).text, OBJC_ASSOCIATION_COPY_NONATOMIC);
        @try { LGStorageSnapshot(ds, t); } @catch (NSException *e) {}
        [t reloadData];
    }] forControlEvents:UIControlEventEditingChanged];
    [cap addSubview:mag]; [cap addSubview:tf]; [cap addSubview:mic];
    [cap.widthAnchor constraintEqualToConstant:W].active = YES;
    [cap.heightAnchor constraintEqualToConstant:44].active = YES;
    vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cap];
}

// The storage search works from a snapshot taken when the text changes (never while the table
// is reloading or laying out: asking the table for cells from inside those callbacks crashes it).
static NSString *LGStorageRowName(id lc, UITableView *tv, NSIndexPath *ip) {
    NSString *name = nil;
    @try {
        if ([lc respondsToSelector:@selector(specifierAtIndexPath:)]) {
            PSSpecifier *sp = ((PSSpecifier *(*)(id, SEL, id))objc_msgSend)(lc, @selector(specifierAtIndexPath:), ip);
            name = sp.name;
        } else if ([lc respondsToSelector:@selector(indexForIndexPath:)]) {
            NSInteger i = ((NSInteger (*)(id, SEL, id))objc_msgSend)(lc, @selector(indexForIndexPath:), ip);
            NSArray *sp = [(PSListController *)lc specifiers];
            if (i >= 0 && i < (NSInteger)sp.count) name = ((PSSpecifier *)sp[i]).name;
        }
    } @catch (NSException *e) { return nil; }
    if (!name.length) {
        PSSpecifier *sp = nil;
        @try {
            if ([lc respondsToSelector:@selector(specifierAtIndexPath:)])
                sp = ((PSSpecifier *(*)(id, SEL, id))objc_msgSend)(lc, @selector(specifierAtIndexPath:), ip);
        } @catch (NSException *e) {}
        NSString *bid = sp.identifier;
        for (NSString *k in @[@"bundleID", @"appBundleID", @"bundleIdentifier", @"BUNDLE_ID"]) {
            id v = [sp respondsToSelector:@selector(propertyForKey:)] ? [sp propertyForKey:k] : nil;
            if ([v isKindOfClass:[NSString class]]) { bid = v; break; }
        }
        Class proxyClass = NSClassFromString(@"LSApplicationProxy");
        if (bid.length && proxyClass) {
            @try {
                id proxy = [proxyClass performSelector:@selector(applicationProxyForIdentifier:) withObject:bid];
                if ([proxy respondsToSelector:@selector(localizedName)]) name = [proxy performSelector:@selector(localizedName)];
            } @catch (NSException *e) {}
        }
        // last resort: the text the cell is already showing, but only for an app row (it shows a size);
        // the offload recommendation and other notices have no size and stay hidden while searching
        if (!name.length) {
            UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
            NSString *firstText = nil;
            BOOL hasSize = NO;
            NSMutableArray<UIView *> *st = cell ? [NSMutableArray arrayWithObject:cell.contentView] : [NSMutableArray new];
            while (st.count) {
                UIView *v = st.firstObject; [st removeObjectAtIndex:0];
                [st addObjectsFromArray:v.subviews];
                if (![v isKindOfClass:[UILabel class]]) continue;
                NSString *tx = ((UILabel *)v).text;
                if (!tx.length) continue;
                if (!firstText) firstText = tx;
                if ([tx rangeOfString:@"^[0-9][0-9.,\\s]*(bytes|KB|MB|GB|TB)$"
                              options:NSRegularExpressionSearch | NSCaseInsensitiveSearch].location != NSNotFound) hasSize = YES;
            }
            if (hasSize && firstText.length <= 60) name = firstText;
        }
    }
    return name;
}

static NSInteger LGDSSections(id lc, UITableView *tv) {
    if (![lc respondsToSelector:@selector(numberOfSectionsInTableView:)]) return 1;
    return ((NSInteger (*)(id, SEL, id))objc_msgSend)(lc, @selector(numberOfSectionsInTableView:), tv);
}
static NSInteger LGDSRows(id lc, UITableView *tv, NSInteger s) {
    if (![lc respondsToSelector:@selector(tableView:numberOfRowsInSection:)]) return 0;
    return ((NSInteger (*)(id, SEL, id, NSInteger))objc_msgSend)(lc, @selector(tableView:numberOfRowsInSection:), tv, s);
}
static NSArray *LGDSShape(id lc, UITableView *tv) {
    NSMutableArray *shape = [NSMutableArray new];
    NSInteger n = LGDSSections(lc, tv);
    for (NSInteger s = 0; s < n; s++) [shape addObject:@(LGDSRows(lc, tv, s))];
    return shape;
}

// { f: filter, shape: rows per section, hidden: set of index paths, s: {section: [first, last]}, first }
static void LGStorageSnapshot(id lc, UITableView *tv) {
    NSString *f = objc_getAssociatedObject(lc, &kStorageFilterKey);
    if (!f.length || !tv) { objc_setAssociatedObject(lc, &kStorageShownKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    NSArray *shape = LGDSShape(lc, tv);
    NSMutableSet *hidden = [NSMutableSet new];
    NSMutableDictionary *spans = [NSMutableDictionary new];
    NSInteger first = -1;
    for (NSInteger s = 0; s < (NSInteger)shape.count; s++) {
        NSInteger a = -1, b = -1, rows = [shape[s] integerValue];
        for (NSInteger r = 0; r < rows; r++) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
            NSString *name = nil;
            @try { name = LGStorageRowName(lc, tv, ip); } @catch (NSException *e) { name = nil; }
            NSString *n = LGNormalizeTitle(name ?: @"");
            BOOL hide = !name.length || [n isEqualToString:@"iPadOS"] || [n isEqualToString:@"System Data"] ||
                        [n isEqualToString:@"Hidden Apps"] ||
                        [name rangeOfString:f options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound;
            if (hide) { [hidden addObject:ip]; continue; }
            if (a < 0) a = r;
            b = r;
        }
        if (a >= 0) { spans[@(s)] = @[@(a), @(b)]; if (first < 0) first = s; }
    }
    NSDictionary *c = @{ @"f": f, @"shape": shape, @"hidden": hidden, @"s": spans, @"first": @(first) };
    objc_setAssociatedObject(lc, &kStorageShownKey, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char kStorageResnapKey;
// cached snapshot; if the storage list changed under it (sizes still loading), refresh it on the next turn
static NSDictionary *LGStorageShown(id lc, UITableView *tv) {
    NSString *f = objc_getAssociatedObject(lc, &kStorageFilterKey);
    if (!f.length) return nil;
    NSDictionary *c = objc_getAssociatedObject(lc, &kStorageShownKey);
    if (!c) return nil;
    BOOL stale = ![c[@"f"] isEqualToString:f];
    if (!stale) {
        if (![LGDSShape(lc, tv) isEqualToArray:c[@"shape"]]) stale = YES;
    }
    if (stale && !objc_getAssociatedObject(lc, &kStorageResnapKey)) {
        objc_setAssociatedObject(lc, &kStorageResnapKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak id wlc = lc; __weak UITableView *wtv = tv;
        dispatch_async(dispatch_get_main_queue(), ^{
            id l = wlc; UITableView *t = wtv;
            if (!l) return;
            objc_setAssociatedObject(l, &kStorageResnapKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (!t) return;
            @try { LGStorageSnapshot(l, t); } @catch (NSException *e) {}
            [t reloadData];
        });
    }
    return c;
}

static BOOL LGStorageRowHidden(id lc, UITableView *tv, NSIndexPath *ip) {
    NSDictionary *c = LGStorageShown(lc, tv);
    if (!c) return NO;
    NSArray *shape = c[@"shape"];
    if (ip.section >= (NSInteger)shape.count || ip.row >= [shape[ip.section] integerValue]) return NO;
    return [c[@"hidden"] containsObject:ip];
}
static NSInteger LGStorageFirstShownSection(id lc, UITableView *tv) {
    NSDictionary *c = LGStorageShown(lc, tv);
    return c ? [c[@"first"] integerValue] : -1;
}

#pragma mark - Notifications "Display As" card (iPadOS 16 on iPad has no such setting: look only)

static char kDisplayAsHeaderKey;
@interface LGDisplayAsTarget : NSObject
@property (nonatomic, weak) UIView *card;
- (void)pick:(UITapGestureRecognizer *)g;
@end
static void LGDrawDisplayAs(UIView *card);
@implementation LGDisplayAsTarget
- (void)pick:(UITapGestureRecognizer *)g {
    [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] setInteger:g.view.tag - 300 forKey:@"LG26_display_as"];
    LGDrawDisplayAs(self.card);
}
@end

static UIImage *LGPhoneGlyph(NSInteger style, BOOL on) {
    CGFloat w = 56, h = 76;
    UIColor *line = on ? UIColor.systemBlueColor : [UIColor colorWithWhite:0.56 alpha:1];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1.5, 1.5, w - 3, h - 3) cornerRadius:7];
        frame.lineWidth = 3; [line setStroke]; [frame stroke];
        NSDictionary *at = @{ NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium], NSForegroundColorAttributeName: line };
        CGSize ts = [@"09:41" sizeWithAttributes:at];
        [@"09:41" drawAtPoint:CGPointMake((w - ts.width) / 2.0, 9) withAttributes:at];
        UIColor *fill = on ? UIColor.systemBlueColor : [UIColor colorWithWhite:0.56 alpha:1];
        [fill setFill];
        if (style == 0) {
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w / 2 - 8, h - 12, 16, 2.5) cornerRadius:1.25] fill];
        } else if (style == 1) {
            [[fill colorWithAlphaComponent:0.45] setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w / 2 - 14, h - 15, 28, 8) cornerRadius:4] fill];
            [fill setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w / 2 - 17, h - 21, 34, 10) cornerRadius:5] fill];
        } else {
            for (int i = 0; i < 3; i++)
                [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w / 2 - 17, h - 40 + i * 10, 34, 7.5) cornerRadius:2.5] fill];
        }
    }];
}

static void LGDrawDisplayAs(UIView *card) {
    NSInteger sel = [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] objectForKey:@"LG26_display_as"]
                  ? [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] integerForKey:@"LG26_display_as"] : 1;
    for (NSInteger i = 0; i < 3; i++) {
        UIView *col = [card viewWithTag:300 + i];
        UIImageView *iv = (UIImageView *)[col viewWithTag:1];
        UILabel *l = (UILabel *)[col viewWithTag:2];
        UIView *cap = [col viewWithTag:3];
        BOOL on = (i == sel);
        iv.image = LGPhoneGlyph(i, on);
        cap.hidden = !on;
        l.textColor = on ? UIColor.blackColor : UIColor.labelColor;
        l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    }
}

static void LGDisplayAsHeader(UIViewController *vc) {
    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 300) return;
    UIView *wrap = objc_getAssociatedObject(tv, &kDisplayAsHeaderKey);
    if (!wrap) {
        if (tv.tableHeaderView && tv.tableHeaderView.bounds.size.height > 1) return;
        wrap = [UIView new];
        UILabel *head = [UILabel new]; head.tag = 10;
        head.text = @"Display As";
        head.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        head.textColor = UIColor.secondaryLabelColor;
        [wrap addSubview:head];
        UIView *card = [UIView new]; card.tag = 11;
        card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card.layer.cornerRadius = kSectionRadius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [wrap addSubview:card];
        UILabel *foot = [UILabel new]; foot.tag = 12;
        foot.text = @"Choose the default for how notifications appear.";
        foot.font = [UIFont systemFontOfSize:13];
        foot.textColor = UIColor.secondaryLabelColor;
        [wrap addSubview:foot];
        LGDisplayAsTarget *t = [LGDisplayAsTarget new];
        t.card = card;
        objc_setAssociatedObject(wrap, &kDisplayAsHeaderKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSArray *names = @[@"Count", @"Stack", @"List"];
        for (NSInteger i = 0; i < 3; i++) {
            UIView *col = [UIView new]; col.tag = 300 + i;
            UIImageView *iv = [UIImageView new]; iv.tag = 1;
            UIView *cap = [UIView new]; cap.tag = 3;
            cap.backgroundColor = UIColor.systemBlueColor;
            cap.layer.cornerRadius = 14;
            UILabel *l = [UILabel new]; l.tag = 2; l.text = names[i]; l.textAlignment = NSTextAlignmentCenter;
            [col addSubview:iv]; [col addSubview:cap]; [col addSubview:l];
            [col addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:t action:@selector(pick:)]];
            [card addSubview:col];
        }
        LGDrawDisplayAs(card);
        objc_setAssociatedObject(tv, &kDisplayAsHeaderKey, wrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIView *head = [wrap viewWithTag:10], *card = [wrap viewWithTag:11], *foot = [wrap viewWithTag:12];
    CGRect sr = LGSectionRect(tv);
    CGFloat x = sr.origin.x, w = sr.size.width;
    head.frame = CGRectMake(x + 20, 24, w - 40, 24);
    CGFloat ch = 160;
    card.frame = CGRectMake(x, 54, w, ch);
    CGFloat colW = w / 3.0;
    for (NSInteger i = 0; i < 3; i++) {
        UIView *col = [card viewWithTag:300 + i];
        col.frame = CGRectMake(i * colW, 0, colW, ch);
        [col viewWithTag:1].frame = CGRectMake(colW / 2 - 28, 24, 56, 76);
        UILabel *l = (UILabel *)[col viewWithTag:2];
        CGFloat lw = [l.text sizeWithAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] }].width + 28;
        [col viewWithTag:3].frame = CGRectMake(colW / 2 - lw / 2, 110, lw, 28);
        l.frame = CGRectMake(0, 110, colW, 28);
    }
    foot.frame = CGRectMake(x + 20, 54 + ch + 8, w - 40, 18);
    CGFloat totalH = 54 + ch + 8 + 18 + 16;
    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1 || fabs(wrap.frame.size.width - tv.bounds.size.width) > 1) {
        wrap.frame = CGRectMake(0, 0, tv.bounds.size.width, totalH);
        tv.tableHeaderView = wrap;
    }
}

// Battery: chart titles in Title Case like the rest of iPadOS 26 ("BATTERY LEVEL" -> "Battery Level")
static void LGTitleCaseAll(UITableView *tv) {
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:tv];
    while (st.count) {
        UIView *v = st.lastObject; [st removeLastObject];
        [st addObjectsFromArray:v.subviews];
        if (![v isKindOfClass:[UILabel class]]) continue;
        UILabel *l = (UILabel *)v;
        NSString *t = l.text;
        if (t.length < 3 || ![t isEqualToString:t.uppercaseString] ||
            [t rangeOfCharacterFromSet:NSCharacterSet.uppercaseLetterCharacterSet].location == NSNotFound ||
            [t rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound) continue;
        NSString *f = LGTitleCase(t);
        if (![l.text isEqualToString:f]) l.text = f;
    }
}

#pragma mark - Hooks that need Preferences classes

%group LGPrefs

%hook PSSplitViewController
// style the sidebar as early as UIKit allows, so the first frame is already the iPadOS 26 one
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self.view layoutIfNeeded];
    LGStyleSidebar(self);
}
- (void)viewWillLayoutSubviews {
    %orig;
    LGStyleSidebar(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    LGStyleSidebar(self);
    UIViewController *m = self.viewControllers.firstObject;
    if ([m isKindOfClass:[UINavigationController class]]) {
        UIViewController *root = ((UINavigationController *)m).viewControllers.firstObject;
        if ([root isKindOfClass:NSClassFromString(@"PSUIPrefsListController")]) LGCheckReorder((PSListController *)root);
    }
}
%end

static NSString *LGHiddenSort(void) {
    return [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] stringForKey:@"hiddenSort"] ?: @"Size";
}
// "Name" / "Size" menu (look only: there are no hidden apps on iPadOS 16)
static UIMenu *LGHiddenSortMenu(UIButton *button) {
    __weak UIButton *wb = button;
    NSString *cur = LGHiddenSort();
    NSMutableArray *acts = [NSMutableArray new];
    for (NSString *o in @[@"Name", @"Size"]) {
        UIAction *act = [UIAction actionWithTitle:o image:nil identifier:nil handler:^(UIAction *a) {
            [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"] setObject:o forKey:@"hiddenSort"];
            UIButton *b = wb;
            if (!b) return;
            UIButtonConfiguration *c = b.configuration;
            c.attributedTitle = [[NSAttributedString alloc] initWithString:o
                attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:17] }];
            b.configuration = c;
            b.menu = LGHiddenSortMenu(b);
        }];
        act.state = [o isEqualToString:cur] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [acts addObject:act];
    }
    return [UIMenu menuWithTitle:@"" children:acts];
}

// iPad Storage > Hidden Apps (reference): blue "Size ⌃⌄" sort menu, then a card with the empty state
static void LGStorageHiddenHeader(UITableView *tv) {
    CGFloat W = tv.bounds.size.width;
    if (W < 100) return;
    UIView *wrap = tv.tableHeaderView;
    if (wrap.tag == 0x2616 && fabs(wrap.frame.size.width - W) < 0.5) return;
    if (wrap.tag != 0x2616) {
        wrap = [UIView new];
        wrap.tag = 0x2616;

        UIButton *size = [UIButton buttonWithType:UIButtonTypeSystem];
        size.tag = 1;
        UIButtonConfiguration *bc = [UIButtonConfiguration plainButtonConfiguration];
        bc.attributedTitle = [[NSAttributedString alloc] initWithString:LGHiddenSort()
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:17] }];
        bc.image = [UIImage systemImageNamed:@"chevron.up.chevron.down"
                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
        bc.imagePlacement = NSDirectionalRectEdgeTrailing;
        bc.imagePadding = 4;
        bc.contentInsets = NSDirectionalEdgeInsetsMake(6, 8, 6, 8);
        bc.baseForegroundColor = UIColor.systemBlueColor;
        size.configuration = bc;
        size.menu = LGHiddenSortMenu(size);
        size.showsMenuAsPrimaryAction = YES;
        [wrap addSubview:size];

        UIView *card = [UIView new];
        card.tag = 2;
        card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        card.layer.cornerRadius = kSectionRadius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [wrap addSubview:card];

        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:52 weight:UIImageSymbolWeightRegular];
        UIImage *sym = [UIImage systemImageNamed:@"square.stack.3d.up.slash" withConfiguration:cfg];
        UIImageView *iv = [[UIImageView alloc] initWithImage:sym];
        iv.tintColor = UIColor.secondaryLabelColor;
        UILabel *t = [UILabel new];
        t.text = @"No Hidden Apps";
        t.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
        t.textColor = UIColor.labelColor;
        UILabel *d = [UILabel new];
        d.text = @"No hidden apps found.";
        d.font = [UIFont systemFontOfSize:15];
        d.textColor = UIColor.secondaryLabelColor;
        UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[iv, t, d]];
        st.axis = UILayoutConstraintAxisVertical;
        st.alignment = UIStackViewAlignmentCenter;
        st.spacing = 6;
        [st setCustomSpacing:16 afterView:iv];
        st.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:st];
        [NSLayoutConstraint activateConstraints:@[[st.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
                                                  [st.centerYAnchor constraintEqualToAnchor:card.centerYAnchor constant:-4]]];
    }
    CGFloat side = kSectionSide, sizeH = 44, cardH = 240;
    wrap.frame = CGRectMake(0, 0, W, sizeH + cardH + 8);
    UIButton *size = (UIButton *)[wrap viewWithTag:1];
    CGSize bs = [size sizeThatFits:CGSizeMake(200, sizeH)];
    size.frame = CGRectMake(W - side - bs.width + 4, 0, bs.width, sizeH);
    [wrap viewWithTag:2].frame = CGRectMake(side, sizeH, W - side * 2, cardH);
    tv.tableHeaderView = wrap;
}

%subclass LGPaneController : PSListController
- (void)setSpecifier:(PSSpecifier *)spec {
    %orig;
    NSString *want = spec.name ?: @"";
    NSString *key = [spec propertyForKey:@"lgStorage"] ? [want stringByAppendingString:@"#storage"] : want;
    if (![objc_getAssociatedObject(self, &kPaneBuiltForKey) isEqualToString:key]) {
        Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
        if (iv) object_setIvarWithStrongDefault(self, iv, nil);
        objc_setAssociatedObject(self, &kAppsFilterKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        UIViewController *me = (UIViewController *)self;
        me.title = want;
        me.navigationItem.title = want;
        if (me.navigationItem.rightBarButtonItem.customView.tag == 0x2611) me.navigationItem.rightBarButtonItem = nil;
        if (me.isViewLoaded) {
            UITableView *tv = LGFind(me.view, [UITableView class]);
            if (tv.backgroundView.tag == 0x2608) tv.backgroundView = nil;
            if (tv.tableHeaderView && tv.tableHeaderView == objc_getAssociatedObject(tv, &kModeHeaderKey)) tv.tableHeaderView = nil;
            if ([(id)self respondsToSelector:@selector(reloadSpecifiers)]) [(id)self reloadSpecifiers];
        }
    }
}
- (NSMutableArray *)specifiers {
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSMutableArray *cur = iv ? object_getIvar(self, iv) : nil;
    if (!cur && iv) {
        cur = LGPaneSpecifiers((PSListController *)self);
        object_setIvarWithStrongDefault(self, iv, cur);
        PSSpecifier *ps = ((PSListController *)self).specifier;
        NSString *bk = ps.name ?: @"";
        if ([ps propertyForKey:@"lgStorage"]) bk = [bk stringByAppendingString:@"#storage"];
        objc_setAssociatedObject(self, &kPaneBuiltForKey, bk, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return cur ?: %orig;
}
%new
- (id)lgValue:(PSSpecifier *)spec {
    if (LGChoices()[spec.name ?: @""]) return LGChoiceValue(spec.name);
    return [spec propertyForKey:@"lgValue"];
}
// choice lists: checkmark on the picked row, tap to pick
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = %orig;
    NSString *page = ((UIViewController *)self).title ?: @"";
    if (LGChoices()[page]) {
        c.accessoryType = [c.textLabel.text isEqualToString:LGChoiceValue(page)] ? UITableViewCellAccessoryCheckmark
                                                                                 : UITableViewCellAccessoryNone;
        c.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSString *page = ((UIViewController *)self).title ?: @"";
    if (LGChoices()[page]) {
        NSString *v = [tv cellForRowAtIndexPath:ip].textLabel.text;
        if (v) [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"]
                   setObject:v forKey:[@"LG26_choice_" stringByAppendingString:LGSlug(page)]];
        [tv deselectRowAtIndexPath:ip animated:YES];
        [tv reloadData];
        return;
    }
    %orig;
}
%new
- (id)lgGet:(PSSpecifier *)spec {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"];
    id v = [d objectForKey:spec.identifier];
    return v ?: @YES;
}
%new
- (void)lgSet:(id)value specifier:(PSSpecifier *)spec {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"];
    [d setObject:value forKey:spec.identifier];
}
// A-Z index on the right of "Apps"
%new
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tv {
    if (![((UIViewController *)self).title isEqualToString:@"Apps"]) return nil;
    NSMutableArray *t = [NSMutableArray new];
    for (char c = 'A'; c <= 'Z'; c++) [t addObject:[NSString stringWithFormat:@"%c", c]];
    [t addObject:@"#"];
    return t;
}
%new
- (NSInteger)tableView:(UITableView *)tv sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    // sections: 0 = Default Apps, then one per letter ("#" last), then Hidden Apps
    NSMutableArray<NSString *> *names = [NSMutableArray new];
    for (PSSpecifier *sp in [(PSListController *)self specifiers])
        if (sp.cellType == 0) [names addObject:sp.name ?: @""];
    NSInteger lastLetter = 0;
    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        NSString *l = names[i];
        if (l.length != 1) continue;
        lastLetter = i;
        BOOL hashL = [l isEqualToString:@"#"], hashT = [title isEqualToString:@"#"];
        if (hashT ? hashL : (hashL || [l compare:title] != NSOrderedAscending)) return i;
    }
    return lastLetter;
}
%new
- (void)lgFilterChanged:(UITextField *)tf {
    objc_setAssociatedObject(self, &kAppsFilterKey, tf.text, OBJC_ASSOCIATION_COPY_NONATOMIC);
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    if (iv) object_setIvarWithStrongDefault(self, iv, nil);
    [(id)self reloadSpecifiers];
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIViewController *me = (UIViewController *)self;
    if (![me.title isEqualToString:@"Apps"]) {
        if (me.navigationItem.rightBarButtonItem.customView.tag == 0x2611) me.navigationItem.rightBarButtonItem = nil;
        return;
    }
    if (me.navigationItem.rightBarButtonItem.customView.tag == 0x2611) return;
    // "Search Apps" capsule in the top-right corner
    UIView *cap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 330, 44)];
    cap.tag = 0x2611;
    cap.backgroundColor = [UIColor colorWithRed:38/255.0 green:38/255.0 blue:40/255.0 alpha:1];
    cap.layer.cornerRadius = 22;
    cap.layer.borderWidth = 0.5;
    cap.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    UIImageView *mag = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]];
    UIImageView *mic = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mic" withConfiguration:cfg]];
    mag.tintColor = UIColor.secondaryLabelColor;
    mic.tintColor = [UIColor colorWithWhite:0.92 alpha:1];
    mag.frame = CGRectMake(16, 11, 22, 22); mag.contentMode = UIViewContentModeCenter;
    mic.frame = CGRectMake(330 - 38, 11, 22, 22); mic.contentMode = UIViewContentModeCenter;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(46, 0, 330 - 46 - 44, 44)];
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search Apps"
        attributes:@{ NSForegroundColorAttributeName: UIColor.secondaryLabelColor }];
    tf.font = [UIFont systemFontOfSize:17];
    tf.textColor = UIColor.labelColor;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.returnKeyType = UIReturnKeySearch;
    [tf addTarget:self action:@selector(lgFilterChanged:) forControlEvents:UIControlEventEditingChanged];
    [cap addSubview:mag]; [cap addSubview:tf]; [cap addSubview:mic];
    [cap.widthAnchor constraintEqualToConstant:330].active = YES;
    [cap.heightAnchor constraintEqualToConstant:44].active = YES;
    me.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cap];
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *me = (UIViewController *)self;
    if ([me.title isEqualToString:@"Apps"]) {
        UITableView *tv = LGFind(me.view, [UITableView class]);
        if (tv && ![tv.sectionIndexColor isEqual:UIColor.systemBlueColor]) {
            tv.sectionIndexColor = UIColor.systemBlueColor;
            tv.sectionIndexBackgroundColor = UIColor.clearColor;
            tv.sectionIndexTrackingBackgroundColor = UIColor.clearColor;
        }
    }
    UITableView *tv = LGFind(me.view, [UITableView class]);
    if (!tv) return;
    if ([me.title isEqualToString:@"Multitasking & Gestures"]) LGMultitaskingHeader(me);
    else if (tv.tableHeaderView && tv.tableHeaderView == objc_getAssociatedObject(tv, &kModeHeaderKey)) tv.tableHeaderView = nil;
    BOOL storageHidden = [me.title isEqualToString:@"Hidden Apps"] &&
                         [((PSListController *)(id)self).specifier propertyForKey:@"lgStorage"] != nil;
    if (!storageHidden && tv.tableHeaderView.tag == 0x2616) tv.tableHeaderView = nil;
    if (![me.title isEqualToString:@"Hidden Apps"]) {
        if (tv.backgroundView.tag == 0x2608) tv.backgroundView = nil;
        return;
    }
    if (storageHidden) {
        if (tv.backgroundView.tag == 0x2608) tv.backgroundView = nil;
        LGStorageHiddenHeader(tv);
        return;
    }
    // "Hidden Apps": big centred empty state like iPadOS 26
    if (tv.backgroundView.tag == 0x2608) return;
    UIView *bg = [UIView new];
    bg.tag = 0x2608;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:56 weight:UIImageSymbolWeightRegular];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.stack.3d.up.slash.fill" withConfiguration:cfg]];
    iv.tintColor = UIColor.secondaryLabelColor;
    UILabel *l = [UILabel new];
    l.text = @"No Hidden Apps";
    l.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    l.textColor = UIColor.labelColor;
    UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[iv, l]];
    st.axis = UILayoutConstraintAxisVertical;
    st.alignment = UIStackViewAlignmentCenter;
    st.spacing = 14;
    st.translatesAutoresizingMaskIntoConstraints = NO;
    [bg addSubview:st];
    [NSLayoutConstraint activateConstraints:@[[st.centerXAnchor constraintEqualToAnchor:bg.centerXAnchor],
                                              [st.centerYAnchor constraintEqualToAnchor:bg.centerYAnchor constant:-40]]];
    tv.backgroundView = bg;
}
%end

%hook PSListController
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    if (LGStorageRowHidden(self, tv, ip)) return 0.0;
    return %orig;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    return f.length ? nil : %orig;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    return f.length ? nil : %orig;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    if (!f.length) return %orig;
    return section == LGStorageFirstShownSection(self, tv) ? 16.0 : CGFLOAT_MIN;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    return f.length ? CGFLOAT_MIN : %orig;
}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    return f.length ? nil : %orig;
}
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)section {
    NSString *f = objc_getAssociatedObject(self, &kStorageFilterKey);
    return f.length ? nil : %orig;
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = %orig;
    BOOL hide = LGStorageRowHidden(self, tv, ip);
    if (c.hidden != hide) c.hidden = hide;
    if (hide) c.clipsToBounds = YES;
    return c;
}
- (NSMutableArray *)specifiers {
    NSMutableArray *s = %orig;
    return LGAfterSpecifiers(self, s);
}
- (void)setSpecifier:(PSSpecifier *)spec {
    LGHookSpecifiersGetter(object_getClass(self));
    %orig;
}
- (void)viewDidLoad {
    LGHookSpecifiersGetter(object_getClass(self));
    %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
    LGCheckPane(self);
}
%end

%hook PSUIPrefsListController
// iPadOS 26 keeps sidebar groups close together
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section {
    if (!LGSidebarEnabled()) return %orig;
    if (tv.sectionHeaderTopPadding != 0) tv.sectionHeaderTopPadding = 0;
    return section == 0 ? %orig : 14.0;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)section {
    if (!LGSidebarEnabled()) return %orig;
    return CGFLOAT_MIN;
}
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)section {
    return LGSidebarEnabled() ? nil : %orig;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv cellForRowAtIndexPath:ip];
    NSString *picked = LGCellTitleLabel(c).text;
    if (picked.length) {
        gLGSelectedName = LGNormalizeTitle(picked);
        LGRestyleSidebar(tv);
    }
    PSSpecifier *acct = gLGAccountSpec;
    if (acct && [c.textLabel.text isEqualToString:@"iCloud"]) {
        NSIndexPath *ap = nil;
        if ([self respondsToSelector:@selector(indexPathForSpecifier:)])
            ap = ((NSIndexPath *(*)(id, SEL, id))objc_msgSend)(self, @selector(indexPathForSpecifier:), acct);
        if (ap && ap.section < tv.numberOfSections && ap.row < [tv numberOfRowsInSection:ap.section]) {
            %orig(tv, ap);
            [tv selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
            return;
        }
    }
    %orig;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    NSInteger n = %orig;
    LGCheckReorder(self);
    return n;
}
- (NSMutableArray *)specifiers {
    NSMutableArray *s = LGAfterSpecifiers(self, %orig);
    if (gLGReordering || !LGSidebarEnabled() || !s.count) return s;
    NSNumber *mark = objc_getAssociatedObject(s, &kReorderMarkKey);
    if (mark && mark.unsignedIntegerValue == LGSpecSignature(s)) return s;
    LGScheduleReorder(self);
    return s;
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    self.navigationItem.titleView = [UIView new]; // no "Settings" title above search
    self.navigationItem.hidesSearchBarWhenScrolling = NO; // search stays pinned like iPadOS 26
    UISearchController *sc = self.navigationItem.searchController;
    if (sc) objc_setAssociatedObject(sc, &kSidebarSCKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

%end

#pragma mark - Generic UIKit hooks (Settings only, via filter plist)

static char kTitleCasedKey;
static char kLinkedKey;
// "SEARCH AND LOOK UP" -> "Search and Look Up", "USE FACE ID FOR:" -> "Use Face ID For:"
static NSString *LGTitleCase(NSString *t) {
    static NSSet *small, *keep;
    static NSDictionary *special, *renames;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        small = [NSSet setWithArray:@[@"and", @"or", @"of", @"to", @"the", @"in", @"on", @"a", @"an", @"by", @"at"]];
        keep = [NSSet setWithArray:@[@"ID", @"VPN", @"USB", @"SIM", @"NFC", @"TV", @"DNS", @"IP", @"SOS", @"FM", @"HDR", @"MMS", @"SMS", @"RTT", @"TTY", @"CPU", @"GB", @"MB", @"KB"]];
        special = @{ @"ipad": @"iPad", @"iphone": @"iPhone", @"icloud": @"iCloud", @"airpods": @"AirPods",
                     @"airplay": @"AirPlay", @"airdrop": @"AirDrop", @"facetime": @"FaceTime", @"imessage": @"iMessage",
                     @"carplay": @"CarPlay", @"homekit": @"HomeKit", @"wi-fi": @"Wi-Fi", @"ipados": @"iPadOS" };
        renames = @{ @"Networks": @"Other Networks" }; // Wi-Fi list name in iPadOS 26
    });
    NSArray *words = [t componentsSeparatedByString:@" "];
    NSMutableArray *out = [NSMutableArray new];
    for (NSUInteger i = 0; i < words.count; i++) {
        NSString *w = words[i];
        NSString *core = [w stringByTrimmingCharactersInSet:NSCharacterSet.punctuationCharacterSet];
        NSString *lower = w.lowercaseString;
        NSString *lowerCore = core.lowercaseString;
        NSString *o;
        if ([keep containsObject:core]) o = w;
        else if (special[lowerCore]) o = [w.lowercaseString stringByReplacingOccurrencesOfString:lowerCore withString:special[lowerCore]];
        else if (i > 0 && [small containsObject:lowerCore]) o = lower;
        else o = lower.length ? [[lower substringToIndex:1].uppercaseString stringByAppendingString:[lower substringFromIndex:1]] : lower;
        [out addObject:o];
    }
    NSString *r = [out componentsJoinedByString:@" "];
    return renames[r] ?: r;
}

static void LGTitleCaseHeaders(UITableView *tv) {
    if (tv.style == UITableViewStylePlain || LGIsSidebarTable(tv)) return;
    for (UIView *sub in tv.subviews) {
        if ([sub isKindOfClass:[UITableViewCell class]] || sub == tv.tableHeaderView) continue;
        NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:sub];
        while (stack.count) {
            UIView *v = stack.lastObject;
            [stack removeLastObject];
            [stack addObjectsFromArray:v.subviews];
            if (![v isKindOfClass:[UILabel class]]) continue;
            UILabel *l = (UILabel *)v;
            NSString *t = l.text;
            // Bluetooth footer wording of iPadOS 26
            if (!t.length) continue;
            static NSArray *links;
            static dispatch_once_t lo;
            dispatch_once(&lo, ^{ links = @[@"About Search & Privacy\u2026", @"About Siri & Privacy\u2026",
                                            @"Open Screen Time\u2026", @"Learn more\u2026"]; });
            BOOL linked = NO;
            for (NSString *lk in links) {
                NSRange r = [t rangeOfString:lk options:NSBackwardsSearch];
                if (r.location == NSNotFound) continue;
                linked = YES;
                if ([objc_getAssociatedObject(l, &kLinkedKey) isEqualToString:t]) break;
                NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithAttributedString:l.attributedText];
                NSRange ar = [a.string rangeOfString:lk options:NSBackwardsSearch];
                if (ar.location != NSNotFound) {
                    [a addAttribute:NSForegroundColorAttributeName value:UIColor.systemBlueColor range:ar];
                    l.attributedText = a;
                }
                objc_setAssociatedObject(l, &kLinkedKey, t, OBJC_ASSOCIATION_COPY_NONATOMIC);
                break;
            }
            if (linked) continue;
            if ([t hasPrefix:@"Now discoverable as"]) {
                NSString *nt = [NSString stringWithFormat:@"This iPad is discoverable as \u201C%@\u201D while Bluetooth Settings is open.",
                                UIDevice.currentDevice.name];
                if (![t isEqualToString:nt]) { l.text = nt; [l.superview setNeedsLayout]; }
                continue;
            }
            if (t.length < 2 || ![t isEqualToString:t.uppercaseString] ||
                [t rangeOfCharacterFromSet:NSCharacterSet.lowercaseLetterCharacterSet].location != NSNotFound ||
                [t rangeOfCharacterFromSet:NSCharacterSet.uppercaseLetterCharacterSet].location == NSNotFound) continue;
            if (l.font.pointSize > 15) continue; // only the small caps-style section titles
            NSString *fixed = LGTitleCase(t);
            if ([objc_getAssociatedObject(l, &kTitleCasedKey) isEqualToString:fixed]) continue;
            objc_setAssociatedObject(l, &kTitleCasedKey, fixed, OBJC_ASSOCIATION_COPY_NONATOMIC);
            l.text = fixed;
            l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            l.textColor = UIColor.secondaryLabelColor;
            [l sizeToFit];
        }
    }
}

static const NSInteger kSubtitleTag = 0x2610;
static const NSInteger kDisplayAsCapsuleTag = 0x2614;
static BOOL LGImageIsCircle(UIImage *img, BOOL *filled) {
    NSString *d = img.description ?: @"";
    if ([d rangeOfString:@"circle"].location == NSNotFound) return NO;
    if (filled) *filled = [d rangeOfString:@"checkmark"].location != NSNotFound || [d rangeOfString:@"fill"].location != NSNotFound;
    return YES;
}
static void LGStyleDisplayAs(UITableViewCell *cell) {
    NSMutableDictionary<NSString *, UILabel *> *labels = [NSMutableDictionary new];
    NSMutableArray<UIView *> *circles = [NSMutableArray new];
    NSMutableArray<NSNumber *> *filledFlags = [NSMutableArray new];
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell.contentView];
    while (st.count) {
        UIView *v = st.lastObject; [st removeLastObject];
        [st addObjectsFromArray:v.subviews];
        if ([v isKindOfClass:[UILabel class]]) {
            NSString *t = ((UILabel *)v).text;
            if ([t isEqualToString:@"Count"] || [t isEqualToString:@"Stack"] || [t isEqualToString:@"List"]) labels[t] = (UILabel *)v;
            continue;
        }
        UIImage *img = [v isKindOfClass:[UIImageView class]] ? ((UIImageView *)v).image
                     : [v isKindOfClass:[UIButton class]] ? ((UIButton *)v).currentImage : nil;
        BOOL filled = NO;
        if (img && img.size.width < 40 && LGImageIsCircle(img, &filled)) { [circles addObject:v]; [filledFlags addObject:@(filled)]; }
    }
    if (labels.count != 3 || circles.count < 3) return;

    UIView *chosen = nil;
    for (NSUInteger i = 0; i < circles.count; i++) if (filledFlags[i].boolValue) { chosen = circles[i]; break; }
    if (!chosen) return;
    CGFloat cx = [chosen convertPoint:CGPointMake(CGRectGetMidX(chosen.bounds), 0) toView:cell].x;
    UILabel *sel = nil; CGFloat best = CGFLOAT_MAX;
    for (UILabel *l in labels.allValues) {
        CGFloat lx = [l convertPoint:CGPointMake(CGRectGetMidX(l.bounds), 0) toView:cell].x;
        if (fabs(lx - cx) < best) { best = fabs(lx - cx); sel = l; }
    }
    // the radio circles stay tappable but invisible
    for (UIView *c in circles) if (c.alpha > 0.03) c.alpha = 0.02;
    for (UILabel *l in labels.allValues) {
        BOOL on = (l == sel);
        UIView *cap = [l.superview viewWithTag:kDisplayAsCapsuleTag + (NSInteger)[@[@"Count", @"Stack", @"List"] indexOfObject:l.text]];
        if (!cap) {
            cap = [UIView new];
            cap.tag = kDisplayAsCapsuleTag + (NSInteger)[@[@"Count", @"Stack", @"List"] indexOfObject:l.text];
            cap.userInteractionEnabled = NO;
            cap.backgroundColor = UIColor.systemBlueColor;
            [l.superview insertSubview:cap belowSubview:l];
        }
        CGSize ts = [l.text sizeWithAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] }];
        CGRect f = CGRectMake(l.center.x - ts.width / 2.0 - 14, l.center.y - 15, ts.width + 28, 30);
        if (!CGRectEqualToRect(cap.frame, f)) { cap.frame = f; cap.layer.cornerRadius = 15; }
        if (cap.hidden == on) cap.hidden = !on;
        UIColor *tc = on ? UIColor.whiteColor : UIColor.labelColor;
        if (![l.textColor isEqual:tc]) l.textColor = tc;
        UIFont *fnt = [UIFont systemFontOfSize:15 weight:on ? UIFontWeightSemibold : UIFontWeightRegular];
        if (![l.font isEqual:fnt]) l.font = fnt;
    }
}

static const NSInteger kRightValueTag = 0x2613;
static void LGApplyRightValue(UITableViewCell *cell, PSSpecifier *sp) {
    NSString *v = [sp respondsToSelector:@selector(propertyForKey:)] ? [sp propertyForKey:@"lgRightValue"] : nil;
    UILabel *l = (UILabel *)[cell.contentView viewWithTag:kRightValueTag];
    if (!v.length) { if (l && !l.hidden) l.hidden = YES; return; }
    if (!l) {
        l = [UILabel new];
        l.tag = kRightValueTag;
        l.font = [UIFont systemFontOfSize:17];
        l.textColor = UIColor.secondaryLabelColor;
        l.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:l];
    }
    l.hidden = NO;
    if (![l.text isEqualToString:v]) l.text = v;
    CGRect b = cell.contentView.bounds;
    CGRect f = CGRectMake(b.size.width - 160, 0, 152, b.size.height);
    if (!CGRectEqualToRect(l.frame, f)) l.frame = f;
}

static const NSInteger kSysIconTag = 0x2615;
static char kSysCellKey;      // cell: "iPadOS" / "System Data" while it shows that row
static char kSysLabelKey;     // label: the title label that said so
static char kSysIconRefKey;   // image view: which iPadOS 26 icon it must keep showing
static char kSysIconBigKey;   // image view: large (detail page header) version
static char kSysIconOrigKey;  // image view: the image Settings really asked for
static char kSysDimmedKey;    // custom icon view hidden under our overlay

static BOOL LGIsSysName(NSString *t) {
    if (t.length < 6 || t.length > 16) return NO;
    NSString *n = LGNormalizeTitle(t);
    return [n isEqualToString:@"iPadOS"] || [n isEqualToString:@"System Data"];
}

// gives the cell back to whatever row it shows next (only on reuse or when its title changes)
static void LGStorageSysRelease(UIView *cell) {
    if (!objc_getAssociatedObject(cell, &kSysCellKey)) return;
    objc_setAssociatedObject(cell, &kSysCellKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell];
    while (st.count) {
        UIView *v = st.lastObject; [st removeLastObject];
        [st addObjectsFromArray:v.subviews];
        if (v.tag == kSysIconTag) { v.hidden = YES; continue; }
        if (objc_getAssociatedObject(v, &kSysLabelKey))
            objc_setAssociatedObject(v, &kSysLabelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (objc_getAssociatedObject(v, &kSysDimmedKey)) {
            objc_setAssociatedObject(v, &kSysDimmedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            v.alpha = 1;
        }
        if ([v isKindOfClass:[UIImageView class]] && objc_getAssociatedObject(v, &kSysIconRefKey)) {
            objc_setAssociatedObject(v, &kSysIconRefKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
            UIImage *orig = objc_getAssociatedObject(v, &kSysIconOrigKey);
            objc_setAssociatedObject(v, &kSysIconOrigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ((UIImageView *)v).image = orig;
        }
    }
}

// one-time description of the cell, so a wrong guess about Settings' views can be checked
static void LGStorageSysDump(UIView *cell, NSString *which, BOOL tall) {
    static NSMutableSet *done;
    if (!done) done = [NSMutableSet new];
    NSString *key = [NSString stringWithFormat:@"%@|%d", which, tall];
    if ([done containsObject:key]) return;
    [done addObject:key];
    NSMutableString *out = [NSMutableString stringWithFormat:@"== %@ (%@) cell %@ %@\n", which, tall ? @"detail" : @"list",
                            NSStringFromClass([cell class]), NSStringFromCGRect(cell.bounds)];
    NSMutableArray *st = [NSMutableArray arrayWithObject:@[cell, @0]];
    while (st.count) {
        NSArray *e = st.lastObject; [st removeLastObject];
        UIView *v = e[0]; NSInteger d = [e[1] integerValue];
        CGRect f = [v convertRect:v.bounds toView:cell];
        [out appendFormat:@"%@%@ %@ a=%.2f h=%d tag=%ld", [@"" stringByPaddingToLength:d * 2 withString:@" " startingAtIndex:0],
            NSStringFromClass([v class]), NSStringFromCGRect(f), v.alpha, v.hidden, (long)v.tag];
        if ([v isKindOfClass:[UILabel class]]) [out appendFormat:@" text=\"%@\"", ((UILabel *)v).text ?: @""];
        if ([v isKindOfClass:[UIImageView class]]) [out appendFormat:@" image=%@", NSStringFromCGSize(((UIImageView *)v).image.size)];
        if (v.layer.contents) [out appendString:@" layer-contents"];
        [out appendString:@"\n"];
        for (UIView *c in v.subviews.reverseObjectEnumerator) [st addObject:@[c, @(d + 1)]];
    }
    NSString *path = @"/var/mobile/Documents/Settings26-storage.txt";
    NSString *old = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (old.length > 200000) old = nil;
    [[(old ?: @"") stringByAppendingString:out] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// iPadOS / System Data rows (list) and the header of their detail pages show the iPadOS 26 icon.
// An image view is pinned (the setImage: hook keeps it); a custom icon view is covered.
static void LGStorageHeaderTexts(UIView *cell);
static void LGStorageSystemIcon(UIView *cell) {
    UITableViewCell *tc = [cell isKindOfClass:[UITableViewCell class]] ? (UITableViewCell *)cell : nil;
    UIView *host = tc ? tc.contentView : cell;
    NSString *which = nil;
    UILabel *titleLabel = nil;
    BOOL tall = cell.bounds.size.height > 80;
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:cell];
    UIView *iconView = nil;
    CGFloat iconSide = 0;
    while (st.count) {
        UIView *v = st.firstObject; [st removeObjectAtIndex:0];
        if ((tc && (v == tc.backgroundView || v == tc.selectedBackgroundView)) || v.tag == kSysIconTag) continue;
        [st addObjectsFromArray:v.subviews];
        if (v == cell || v == host) continue;
        if ([v isKindOfClass:[UILabel class]]) {
            if (!which && LGIsSysName(((UILabel *)v).text)) {
                which = LGNormalizeTitle(((UILabel *)v).text);
                titleLabel = (UILabel *)v;
            }
            continue;
        }
        if (v.hidden && !objc_getAssociatedObject(v, &kSysDimmedKey)) continue;
        CGRect f = [v convertRect:v.bounds toView:cell];
        BOOL square = f.size.width >= 24 && f.size.width <= 96 && fabs(f.size.width - f.size.height) < 4;
        BOOL left = f.origin.x >= 0 && f.origin.x < 110;
        BOOL placed = tall ? (f.origin.y < 70) : (fabs(CGRectGetMidY(f) - CGRectGetMidY(cell.bounds)) < 12);
        if (!(square && left && placed)) continue;
        // biggest square on the left; an image view wins over its same-size container
        if (!iconView || f.size.width > iconSide + 1 ||
            (fabs(f.size.width - iconSide) <= 1 && [v isKindOfClass:[UIImageView class]])) {
            iconView = v; iconSide = f.size.width;
        }
    }
    if (!which) which = objc_getAssociatedObject(cell, &kSysCellKey); // title not set yet: keep the pin
    if (!which) return;
    objc_setAssociatedObject(cell, &kSysCellKey, which, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (titleLabel && !objc_getAssociatedObject(titleLabel, &kSysLabelKey))
        objc_setAssociatedObject(titleLabel, &kSysLabelKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    LGStorageSysDump(cell, which, tall);
    if (tall) {
        LGStorageHeaderTexts(cell);
        UITableView *ptv = LGTableViewFor(cell);
        if (!ptv && [cell.superview isKindOfClass:[UITableView class]]) ptv = (UITableView *)cell.superview;
        if (ptv && !objc_getAssociatedObject(ptv, &kSysPageKey))
            objc_setAssociatedObject(ptv, &kSysPageKey, which, OBJC_ASSOCIATION_COPY_NONATOMIC);
        UIViewController *o = ptv ? LGOwnerVC(ptv) : nil;
        if (o && !o.navigationItem.title.length) { o.title = which; o.navigationItem.title = which; }
    }
    if (!iconView) return;
    BOOL big = iconSide > 40;
    UIImage *ref = LGRefIcon(which, big);
    if (!ref) return;

    UIImageView *overlay = nil;
    for (UIView *v in host.subviews) if (v.tag == kSysIconTag) { overlay = (UIImageView *)v; break; }

    if ([iconView isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)iconView;
        if (!objc_getAssociatedObject(iv, &kSysIconRefKey)) {
            objc_setAssociatedObject(iv, &kSysIconOrigKey, iv.image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv, &kSysIconRefKey, which, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        objc_setAssociatedObject(iv, &kSysIconBigKey, @(big), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (iv.image != ref) iv.image = ref; // the hook swaps it
        if (overlay && !overlay.hidden) overlay.hidden = YES;
        return;
    }
    if (!overlay) {
        overlay = [UIImageView new];
        overlay.tag = kSysIconTag;
        overlay.contentMode = UIViewContentModeScaleAspectFit;
        overlay.userInteractionEnabled = NO;
        [host addSubview:overlay];
    }
    CGRect f = [iconView convertRect:iconView.bounds toView:host];
    if (!CGRectEqualToRect(overlay.frame, f)) overlay.frame = f;
    if (overlay.image != ref) overlay.image = ref;
    if (overlay.hidden) overlay.hidden = NO;
    if (host.subviews.lastObject != overlay) [host bringSubviewToFront:overlay];
    objc_setAssociatedObject(iconView, &kSysDimmedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (iconView.alpha > 0.01) iconView.alpha = 0.0;
}

static double LGParseBytes(NSString *t) {
    t = [[t stringByReplacingOccurrencesOfString:@"," withString:@""]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([t.lowercaseString hasPrefix:@"zero"]) return 0;
    NSScanner *sc = [NSScanner scannerWithString:t];
    double v = 0;
    if (![sc scanDouble:&v]) return -1;
    NSString *unit = [[t substringFromIndex:sc.scanLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].uppercaseString;
    NSDictionary *mul = @{ @"BYTES": @1.0, @"BYTE": @1.0, @"KB": @1e3, @"MB": @1e6, @"GB": @1e9, @"TB": @1e12 };
    NSNumber *m = mul[unit];
    return m ? v * m.doubleValue : -1;
}
static NSString *LGFormatBytes(double b) {
    NSArray *units = @[@"bytes", @"KB", @"MB", @"GB", @"TB"];
    NSUInteger u = 0;
    while (b >= 1000 && u + 1 < units.count) { b /= 1000; u++; }
    NSNumberFormatter *nf = [NSNumberFormatter new];
    nf.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    nf.minimumFractionDigits = 0;
    nf.maximumFractionDigits = u >= 3 ? 2 : 1;
    return [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:@(b)], units[u]];
}
static NSArray<UILabel *> *LGCellLabels(UIView *root) {
    NSMutableArray *out = [NSMutableArray new];
    NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:root];
    while (st.count) {
        UIView *v = st.firstObject; [st removeObjectAtIndex:0];
        [st addObjectsFromArray:v.subviews];
        if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length) [out addObject:v];
    }
    return out;
}
static UILabel *LGSizeLabel(NSArray<UILabel *> *labels) {
    for (UILabel *l in labels) if (LGParseBytes(l.text) >= 0) return l;
    return nil;
}

// header of the iPadOS / System Data page: "Apple Inc." first, then "Version: x" (reference)
static char kHeaderSwapCountKey;
static void LGStorageHeaderTexts(UIView *cell) {
    static BOOL busy = NO;
    if (busy) return;
    NSInteger swaps = [objc_getAssociatedObject(cell, &kHeaderSwapCountKey) integerValue];
    if (swaps > 30) return;
    busy = YES;
    UILabel *ver = nil, *apple = nil;
    for (UILabel *l in LGCellLabels(cell)) {
        if ([l.text hasPrefix:@"Version"]) ver = l;
        else if ([l.text isEqualToString:@"Apple Inc."]) apple = l;
    }
    if (ver && ![ver.text hasPrefix:@"Version:"]) {
        NSString *num = [[ver.text substringFromIndex:7] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        ver.text = [@"Version: " stringByAppendingString:num];
    }
    if (ver && apple && [ver convertRect:ver.bounds toView:cell].origin.y < [apple convertRect:apple.bounds toView:cell].origin.y) {
        NSString *v = ver.text;
        ver.text = @"Apple Inc.";
        apple.text = v;
        objc_setAssociatedObject(cell, &kHeaderSwapCountKey, @(swaps + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    busy = NO;
}

static void LGStorageDetailCellImpl(UITableViewCell *cell, UITableView *tv, NSString *page);
static void LGStorageDetailCell(UITableViewCell *cell, UITableView *tv) {
    static BOOL busy = NO;
    if (busy || !tv) return;
    id ds = (id)tv.dataSource;
    NSString *page = objc_getAssociatedObject(tv, &kSysPageKey);
    if (!page && ds) page = objc_getAssociatedObject(ds, &kSysPageKey);
    if (![page isKindOfClass:[NSString class]]) return;
    busy = YES;
    @try { LGStorageDetailCellImpl(cell, tv, page); } @catch (NSException *e) {}
    busy = NO;
}
static void LGStorageDetailCellImpl(UITableViewCell *cell, UITableView *tv, NSString *page) {
    for (UILabel *l in LGCellLabels(cell.contentView)) {
        if ([page isEqualToString:@"iPadOS"] && [l.text isEqualToString:@"System Files"]) l.text = @"iPadOS";
        if ([page isEqualToString:@"System Data"] && [l.text isEqualToString:@"Other System Data"]) l.text = @"Total Size";
    }
    if (![page isEqualToString:@"iPadOS"]) return;
    // Total Size = Reserved Auto-Update Space + iPadOS
    double os = -1;
    UITableViewCell *totalCell = nil;
    NSArray<UITableViewCell *> *cells = tv.visibleCells;
    if (![cells containsObject:cell]) cells = [cells arrayByAddingObject:cell];
    for (UITableViewCell *c in cells) {
        NSArray<UILabel *> *ls = LGCellLabels(c.contentView);
        BOOL named = NO, total = NO;
        for (UILabel *l in ls) {
            if ([l.text isEqualToString:@"iPadOS"]) named = YES;
            if ([l.text isEqualToString:@"Total Size"]) total = YES;
        }
        if (total) totalCell = c;
        if (named && os < 0) { UILabel *sz = LGSizeLabel(ls); if (sz) os = LGParseBytes(sz.text); }
    }
    if (os < 0 || !totalCell) return;
    NSString *total = LGFormatBytes(os + LGParseBytes(kSysReservedText));
    PSSpecifier *sp = [totalCell respondsToSelector:@selector(specifier)] ? [(id)totalCell specifier] : nil;
    if ([sp isKindOfClass:LGSpecClass()]) [sp setProperty:total forKey:@"lgValue"];
    for (UILabel *l in LGCellLabels(totalCell.contentView)) if ([l.text isEqualToString:total]) return; // already shown
    static char kTotalTriesKey;
    NSInteger tries = [objc_getAssociatedObject(totalCell, &kTotalTriesKey) integerValue];
    if (tries >= 4) return;
    objc_setAssociatedObject(totalCell, &kTotalTriesKey, @(tries + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILabel *val = totalCell.detailTextLabel;
    if ([totalCell respondsToSelector:@selector(setValue:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(totalCell, @selector(setValue:), total);
    } else if (val) {
        val.text = total;
    }
}

static void LGApplySubtitle(UITableViewCell *cell) {
    PSSpecifier *sp = [cell respondsToSelector:@selector(specifier)] ? [(id)cell specifier] : nil;
    LGApplyRightValue(cell, sp);
    NSString *sub = [sp respondsToSelector:@selector(propertyForKey:)] ? [sp propertyForKey:@"lgSubtitle"] : nil;
    UILabel *l = (UILabel *)[cell.contentView viewWithTag:kSubtitleTag];
    if (!sub.length) { if (l && !l.hidden) l.hidden = YES; return; }
    if (!l) {
        l = [UILabel new];
        l.tag = kSubtitleTag;
        l.font = [UIFont systemFontOfSize:14];
        l.textColor = UIColor.secondaryLabelColor;
        [cell.contentView addSubview:l];
    }
    l.hidden = NO;
    if (![l.text isEqualToString:sub]) l.text = sub;
    UILabel *t = cell.textLabel;
    if (!t) return;
    CGRect tf = t.frame;
    CGFloat lineH = ceil(l.font.lineHeight);
    CGFloat total = tf.size.height + 2 + lineH;
    CGFloat top = floor((cell.contentView.bounds.size.height - total) / 2.0);
    if (fabs(tf.origin.y - top) > 0.5) { tf.origin.y = top; t.frame = tf; }
    CGRect sf = CGRectMake(tf.origin.x, top + tf.size.height + 2, cell.contentView.bounds.size.width - tf.origin.x - 16, lineH);
    if (!CGRectEqualToRect(l.frame, sf)) l.frame = sf;
}

static BOOL LGInDetailColumn(UIViewController *vc) {
    UINavigationController *nav = vc.navigationController;
    UISplitViewController *split = nav.splitViewController;
    return split && split.viewControllers.count >= 2 && nav == split.viewControllers.lastObject;
}

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (LGInDetailColumn(self)) LGInstallBackButton(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *top = self;
    while (top.parentViewController && ![top.parentViewController isKindOfClass:[UINavigationController class]])
        top = top.parentViewController;
    if (!LGInDetailColumn(top)) return;
    LGApplyHeader(self);
    NSString *t = LGNormalizeTitle(self.title ?: top.title ?: top.navigationItem.title ?: @"");
    if ([self isKindOfClass:NSClassFromString(@"PSListController")] &&
        [[((PSListController *)self).specifier propertyForKey:@"lgFull"] boolValue]) {
        if (![self.title isEqualToString:@"Battery Usage"]) { self.title = @"Battery Usage"; self.navigationItem.title = @"Battery Usage"; }
        UITableView *utv = LGFind(self.view, [UITableView class]);
        if (utv) {
            LGTitleCaseAll(utv);
            // remember "Last Charged to N%" for the card on the main Battery page
            NSMutableArray<UIView *> *stk = [NSMutableArray arrayWithObject:utv];
            while (stk.count) {
                UIView *v = stk.lastObject; [stk removeLastObject];
                [stk addObjectsFromArray:v.subviews];
                if (![v isKindOfClass:[UILabel class]] || ![((UILabel *)v).text.uppercaseString hasPrefix:@"LAST CHARGED"]) continue;
                NSString *when = nil;
                for (UIView *sib in v.superview.subviews)
                    if (sib != v && [sib isKindOfClass:[UILabel class]] && ((UILabel *)sib).text.length &&
                        ![((UILabel *)sib).text.uppercaseString hasPrefix:@"LAST CHARGED"]) { when = ((UILabel *)sib).text; break; }
                [[[NSUserDefaults alloc] initWithSuiteName:@"com.basel.settings26.look"]
                    setObject:@[((UILabel *)v).text, when ?: @""] forKey:@"LG26_last_charged"];
                break;
            }
        }
        return;
    }
    if ([t isEqualToString:@"Battery"]) {
        LGBatteryHeader(self);
        UITableView *btv = LGFind(self.view, [UITableView class]);
        if (btv) LGTitleCaseAll(btv);
    }
    if ([t isEqualToString:@"Notifications"]) LGDisplayAsHeader(self);
    if ([t isEqualToString:@"iPad Storage"] && self == top) LGStorageCapsule(top);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (LGInDetailColumn(self)) LGApplyHeader(self);
}
%end

static void LGSchedulePaneCheck(UITableView *tv) {
    if (gLGPaneReordering || !LGSidebarEnabled()) return;
    id ds = (id)tv.dataSource;
    if (![ds isKindOfClass:objc_getClass("PSListController")]) return;
    if ([ds isKindOfClass:objc_getClass("PSUIPrefsListController")] || [ds isKindOfClass:objc_getClass("LGPaneController")]) return;
    static char kLastCheckKey;
    NSNumber *last = objc_getAssociatedObject(ds, &kLastCheckKey);
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (last && now - last.doubleValue < 1.0) return;
    objc_setAssociatedObject(ds, &kLastCheckKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak PSListController *w = (PSListController *)ds;
    dispatch_async(dispatch_get_main_queue(), ^{
        PSListController *lc = w;
        if (lc && !gLGPaneReordering && lc.isViewLoaded && lc.view.window) LGCheckPane(lc);
    });
}

%hook UITableView
- (void)insertRowsAtIndexPaths:(NSArray *)paths withRowAnimation:(UITableViewRowAnimation)anim {
    %orig;
    LGSchedulePaneCheck(self);
}
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)anim {
    %orig;
    LGSchedulePaneCheck(self);
}
- (void)layoutSubviews {
    %orig;
    UIView *mine = objc_getAssociatedObject(self, &kHeaderKey);
    if (mine && self.tableHeaderView != mine && !self.isEditing && !objc_getAssociatedObject(self, &kHeaderPendingKey)) {
        objc_setAssociatedObject(self, &kHeaderPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UITableView *wtv = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableView *t = wtv;
            if (!t) return;
            objc_setAssociatedObject(t, &kHeaderPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UIViewController *o = LGOwnerVC(t);
            if (o) LGApplyHeader(o);
        });
    }
    LGTitleCaseHeaders(self);
    // iPadOS / System Data detail page whose icon sits in a table header view instead of a cell
    UIView *th = self.tableHeaderView;
    if (th && th.tag != kHeaderWrapTag && th.tag != 0x2616 && th.bounds.size.height > 80) {
        UIViewController *o = LGOwnerVC(self);
        if (LGIsSysName(o.title ?: o.navigationItem.title)) LGStorageSystemIcon(th);
    }
}
// iPadOS 16 Settings centres a narrow table in wide panes (FLEX: table ~690pt in a ~950pt pane)
- (void)setFrame:(CGRect)f {
    UIView *sv = self.superview;
    if (sv && self.style != UITableViewStylePlain && f.size.width > 100 &&
        f.size.width < sv.bounds.size.width - 2.0 && f.origin.x > 1.0) {
        UIViewController *vc = LGOwnerVC(self);
        if (vc && vc.view == sv && LGInDetailColumn(vc) && !LGIsSidebarTable(self)) {
            f.origin.x = 0;
            f.size.width = sv.bounds.size.width;
        }
    }
    %orig(f);
}
// ...and some panes do it with readable-width margins instead
- (void)setLayoutMargins:(UIEdgeInsets)m {
    if (self.style != UITableViewStylePlain && (m.left > 40 || m.right > 40)) {
        UIViewController *vc = LGOwnerVC(self);
        if (vc && LGInDetailColumn(vc)) { m.left = MIN(m.left, 20); m.right = MIN(m.right, 20); }
    }
    %orig(m);
}
- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)m {
    if (self.style != UITableViewStylePlain && (m.leading > 40 || m.trailing > 40)) {
        UIViewController *vc = LGOwnerVC(self);
        if (vc && LGInDetailColumn(vc)) { m.leading = MIN(m.leading, 20); m.trailing = MIN(m.trailing, 20); }
    }
    %orig(m);
}
- (BOOL)cellLayoutMarginsFollowReadableWidth {
    if (!%orig) return NO;
    if (self.style == UITableViewStylePlain) return YES;
    UIViewController *vc = LGOwnerVC(self);
    return (vc && LGInDetailColumn(vc)) ? NO : YES; // detail panes span the column like iPadOS 26
}
%end

%hook UITableViewCell

- (void)prepareForReuse {
    LGStorageSysRelease(self);
    %orig;
}

- (void)setFrame:(CGRect)f {
    UITableView *tv = (UITableView *)self.superview;
    if (![tv isKindOfClass:[UITableView class]]) tv = LGTableViewFor(self);
    if (tv && f.origin.x > 30 && f.size.width > 300 && LGWideTable(tv)) {
        CGFloat W = tv.bounds.size.width;
        // leave room for an A-Z index (Apps page), like the reference
        UIViewController *src = [(id)tv.dataSource isKindOfClass:[UIViewController class]] ? (UIViewController *)tv.dataSource : nil;
        BOOL hasIndex = [src isKindOfClass:NSClassFromString(@"LGPaneController")] && [src.title isEqualToString:@"Apps"];
        f.origin.x = kSectionSide;
        f.size.width = W - kSectionSide * 2 - (hasIndex ? 16.0 : 0);
        if (!objc_getAssociatedObject(tv, &kWideFallbackKey))
            objc_setAssociatedObject(tv, &kWideFallbackKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    %orig(f);
    BOOL squeezed = f.size.height < 1.0;
    BOOL wasSqueezed = objc_getAssociatedObject(self, &kSqueezedKey) != nil;
    if (squeezed && !wasSqueezed) {
        objc_setAssociatedObject(self, &kSqueezedKey, @(self.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.alpha = 0;
    } else if (!squeezed && wasSqueezed) {
        NSNumber *a = objc_getAssociatedObject(self, &kSqueezedKey);
        objc_setAssociatedObject(self, &kSqueezedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.alpha = a.doubleValue > 0.01 ? a.doubleValue : 1.0;
    }
}

- (void)layoutSubviews {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!tv || tv.style == UITableViewStylePlain) return;

    if (LGIsSidebarTable(tv)) { LGStyleSidebarCell(self); return; }
    LGApplySubtitle(self);
    LGStorageSystemIcon(self);
    LGStorageDetailCell(self, tv);

    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!ip) return;
    // storage search: rows that don't match draw nothing at all (reads the snapshot only)
    {
        static char kSearchHideKey;
        id sds = (id)tv.dataSource;
        BOOL hide = [sds isKindOfClass:[UIViewController class]] && LGStorageRowHidden(sds, tv, ip);
        BOOL was = objc_getAssociatedObject(self, &kSearchHideKey) != nil;
        if (hide && !was) {
            objc_setAssociatedObject(self, &kSearchHideKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self.contentView.hidden = YES;
            self.alpha = 0;
        } else if (!hide && was) {
            objc_setAssociatedObject(self, &kSearchHideKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self.contentView.hidden = NO;
            if (self.bounds.size.height >= 1.0) self.alpha = 1;
        }
    }
    if (ip.section == 0 && ip.row == 0) LGStyleDisplayAs(self);

    // Keep the header card aligned with the sections below it
    if (ip.section == 0 && ip.row == 0 && tv.tableHeaderView.tag == kHeaderWrapTag) {
        UIView *wrapV = tv.tableHeaderView;
        UIView *card = [wrapV viewWithTag:1];
        CGRect cr = [self convertRect:self.bounds toView:wrapV];
        BOOL mergedGap = objc_getAssociatedObject(tv, &kHeaderMergeKey) && fabs(CGRectGetMaxY(card.frame) - cr.origin.y) > 2.0;
        if (mergedGap) {
            UIViewController *owner = LGOwnerVC(tv);
            dispatch_async(dispatch_get_main_queue(), ^{ if (owner) LGApplyHeader(owner); });
        }
    }

    NSInteger rows = [tv numberOfRowsInSection:ip.section];
    NSInteger firstRow = 0, lastRow = rows - 1;
    id src = tv.dataSource;
    if ([src isKindOfClass:[UIViewController class]]) {
        NSArray *span = LGStorageShown(src, tv)[@"s"][@(ip.section)];
        if (span) { firstRow = [span[0] integerValue]; lastRow = [span[1] integerValue]; }
    }
    CACornerMask mask = 0;
    BOOL mergedTop = ip.section == 0 && objc_getAssociatedObject(tv, &kHeaderMergeKey) &&
                     tv.tableHeaderView.tag == kHeaderWrapTag;
    if (ip.row == firstRow && !mergedTop) mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == lastRow) mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.layer.maskedCorners = mask;
    self.layer.cornerCurve   = kCACornerCurveContinuous;
    self.layer.cornerRadius  = mask ? kSectionRadius : 0;
    self.layer.masksToBounds = (mask != 0);

    LGApplyRowIcon(self, tv);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    %orig;
    if (LGIsSidebarTable(LGTableViewFor(self))) LGStyleSidebarCell(self);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    %orig;
    if (LGIsSidebarTable(LGTableViewFor(self))) LGStyleSidebarCell(self);
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    %orig;
    if (LGIsSidebarTable(LGTableViewFor(self))) LGApplyClearBackground(self);
}

%end

%hook UITableViewHeaderFooterView
- (void)layoutSubviews {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!tv || tv.style == UITableViewStylePlain || LGIsSidebarTable(tv)) return;

    if (objc_getAssociatedObject(tv, &kWideFallbackKey)) {
        CGFloat targetX = kSectionSide + 20.0; // text sits 20pt inside the card, like the reference
        NSMutableArray<UIView *> *st = [NSMutableArray arrayWithObject:self];
        while (st.count) {
            UIView *v = st.lastObject; [st removeLastObject];
            [st addObjectsFromArray:v.subviews];
            if (![v isKindOfClass:[UILabel class]] && ![v isKindOfClass:[UITextView class]]) continue;
            CGFloat lx = [v convertPoint:CGPointZero toView:tv].x;
            CGFloat dx = lx - targetX;
            if (dx > 2) {
                CGRect fr = v.frame;
                fr.origin.x -= dx;
                fr.size.width = MIN(fr.size.width + dx * 2, tv.bounds.size.width - targetX * 2);
                v.frame = fr;
            }
        }
    }

    UIFont *font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    if ([self.contentConfiguration isKindOfClass:[UIListContentConfiguration class]]) {
        UIListContentConfiguration *c = (UIListContentConfiguration *)self.contentConfiguration;
        NSString *txt = c.text;
        BOOL isHeader = txt.length && c.textProperties.transform == UIListContentTextTransformUppercase;
        if (isHeader) {
            UIListContentConfiguration *n = [c copy];
            n.textProperties.transform = UIListContentTextTransformNone;
            n.textProperties.font = font;
            n.textProperties.color = UIColor.secondaryLabelColor;
            if ([txt isEqualToString:txt.uppercaseString]) n.text = LGTitleCase(txt);
            self.contentConfiguration = n;
        }
        return;
    }

    UILabel *l = self.textLabel;
    NSString *txt = l.text;
    // Only headers come out ALL CAPS on iPadOS 16; footers keep normal case and are left alone
    if (txt.length > 1 && [txt isEqualToString:txt.uppercaseString] &&
        [txt rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound) {
        l.text = LGTitleCase(txt);
        l.font = font;
        l.textColor = UIColor.secondaryLabelColor;
        [l sizeToFit];
    }
}
%end

// a pinned iPadOS / System Data cell re-checks itself whenever Settings adds or lays out its views
%group LGContentView
%hook UITableViewCellContentView
- (void)didAddSubview:(UIView *)sub {
    %orig;
    if (sub.tag == kSysIconTag) return;
    UITableViewCell *c = (UITableViewCell *)((UIView *)(id)self).superview;
    if (![c isKindOfClass:[UITableViewCell class]] || !objc_getAssociatedObject(c, &kSysCellKey)) return;
    __weak UITableViewCell *wc = c;
    dispatch_async(dispatch_get_main_queue(), ^{ if (wc) LGStorageSystemIcon(wc); });
}
- (void)layoutSubviews {
    %orig;
    UITableViewCell *c = (UITableViewCell *)((UIView *)(id)self).superview;
    if ([c isKindOfClass:[UITableViewCell class]] && objc_getAssociatedObject(c, &kSysCellKey)) LGStorageSystemIcon(c);
}
%end
%end

%hook UILabel
- (void)setText:(NSString *)t {
    %orig;
    BOOL marked = objc_getAssociatedObject(self, &kSysLabelKey) != nil;
    BOOL sys = LGIsSysName(t);
    if (!marked && !sys) return;
    UIView *v = self.superview;
    UIView *cell = nil;
    for (int i = 0; v && i < 8; i++, v = v.superview) {
        if ([v isKindOfClass:[UITableViewCell class]]) { cell = v; break; }
        if ([v.superview isKindOfClass:[UITableView class]] && ((UITableView *)v.superview).tableHeaderView == v) { cell = v; break; }
    }
    if (!cell) return;
    if (marked && !sys && t.length) { LGStorageSysRelease(cell); return; } // the cell shows another row now
    if (sys) {
        LGStorageSystemIcon(cell);
        __weak UIView *wc = cell;
        dispatch_async(dispatch_get_main_queue(), ^{ if (wc) LGStorageSystemIcon(wc); });
    }
}
%end

%hook UIImageView
- (void)setImage:(UIImage *)img {
    NSString *which = objc_getAssociatedObject(self, &kSysIconRefKey);
    if (which) {
        UIImage *ref = LGRefIcon(which, [objc_getAssociatedObject(self, &kSysIconBigKey) boolValue]);
        if (ref && img != ref) {
            objc_setAssociatedObject(self, &kSysIconOrigKey, img, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            %orig(ref);
            return;
        }
    }
    %orig;
}
%end

%hook UISwitch
- (void)didAddSubview:(UIView *)v {
    %orig;
    if (v.tag != kSwitchOverlayTag) LGStyleSwitch(self, NO);
}
- (void)didMoveToWindow {
    %orig;
    LGStyleSwitch(self, NO);
}
- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    %orig;
    LGStyleSwitch(self, NO);
}
- (void)layoutSubviews {
    %orig;
    LGStyleSwitch(self, NO);
}
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;
    LGStyleSwitch(self, animated);
}
- (void)setEnabled:(BOOL)enabled {
    %orig;
    LGStyleSwitch(self, NO);
}
%end

static void LGHideCancel(UISearchBar *sb) {
    UIView *tf = sb.searchTextField;
    NSMutableArray<UIView *> *stack = [sb.subviews mutableCopy];
    while (stack.count) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if (v == tf) continue;
        if ([v isKindOfClass:[UIButton class]] || [NSStringFromClass(v.class) containsString:@"NavigationButton"]) {
            if (!v.hidden) v.hidden = YES;
            if (v.userInteractionEnabled) v.userInteractionEnabled = NO;
            continue;
        }
        [stack addObjectsFromArray:v.subviews];
    }
    tf.frame = tf.frame; // re-run the field geometry rules below
}

%hook UISearchTextField
- (void)setFrame:(CGRect)f {
    if (f.size.width > 1 && LGIsSidebarSearch(self)) {
        if (fabs(f.size.height - kSearchHeight) > 0.5) {
            f.origin.y += (f.size.height - kSearchHeight) / 2.0;
            f.size.height = kSearchHeight;
        }
        // Cancel is hidden, so the field keeps its full width
        CGFloat full = self.superview.bounds.size.width - 2.0 * f.origin.x;
        if (full > f.size.width + 0.5) f.size.width = full;
    }
    %orig(f);
}
%end

%hook UISearchBar
- (void)layoutSubviews {
    %orig;
    if (self.window && LGIsSidebarSearch(self)) { LGStyleSearchBar(self); LGHideCancel(self); }
}
- (void)setShowsCancelButton:(BOOL)show animated:(BOOL)animated {
    if (LGIsSidebarSearch(self)) show = NO;
    %orig(show, animated);
}
- (void)setShowsCancelButton:(BOOL)show {
    if (LGIsSidebarSearch(self)) show = NO;
    %orig(show);
}
- (BOOL)showsCancelButton {
    return LGIsSidebarSearch(self) ? NO : %orig;
}
%end

%hook UISearchController
- (BOOL)automaticallyShowsCancelButton {
    return objc_getAssociatedObject(self, &kSidebarSCKey) ? NO : %orig;
}
- (BOOL)hidesNavigationBarDuringPresentation {
    return objc_getAssociatedObject(self, &kSidebarSCKey) ? NO : %orig; // field stays where it is
}
%end

%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, &kSidebarBarKey) || !LGIsDetailBar(self)) return;
    if (objc_getAssociatedObject(self, &kNavWrapPendingKey)) return;
    objc_setAssociatedObject(self, &kNavWrapPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UINavigationBar *wb = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationBar *b = wb;
        if (!b) return;
        objc_setAssociatedObject(b, &kNavWrapPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        LGWrapNavItem(b.topItem);
    });
}
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    self.prefersLargeTitles = NO;
    if (objc_getAssociatedObject(self, &kSidebarBarKey)) return;

    UIImage *back = LGBackImage();

    UINavigationBarAppearance *edge = [UINavigationBarAppearance new];
    [edge configureWithTransparentBackground];
    [edge setBackIndicatorImage:back transitionMaskImage:back];

    UINavigationBarAppearance *std = [UINavigationBarAppearance new];
    [std configureWithTransparentBackground];
    std.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    std.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0 alpha:0.82]
                                                                 : [UIColor colorWithWhite:1 alpha:0.82];
    }];
    std.shadowColor = UIColor.clearColor;
    [std setBackIndicatorImage:back transitionMaskImage:back];

    self.standardAppearance   = std;
    self.compactAppearance    = std;
    self.scrollEdgeAppearance = edge;
}
%end

%hook UINavigationItem
- (UINavigationItemLargeTitleDisplayMode)largeTitleDisplayMode {
    return UINavigationItemLargeTitleDisplayModeNever;
}
- (UINavigationItemBackButtonDisplayMode)backButtonDisplayMode {
    return UINavigationItemBackButtonDisplayModeMinimal;
}
%end

static NSUncaughtExceptionHandler *gLGPrevHandler;
static void LGExceptionHandler(NSException *e) {
    @try {
        NSString *txt = [NSString stringWithFormat:@"%@\n%@: %@\n%@\n\n", [NSDate date], e.name, e.reason,
                         [e.callStackSymbols componentsJoinedByString:@"\n"]];
        [txt writeToFile:@"/var/mobile/Documents/Settings26-crash.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch (NSException *x) {}
    if (gLGPrevHandler) gLGPrevHandler(e);
}

%ctor {
    gLGPrevHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&LGExceptionHandler);
    %init;
    Class contentViewClass = objc_getClass("UITableViewCellContentView");
    if (contentViewClass) %init(LGContentView, UITableViewCellContentView = contentViewClass);
    Class tvc = [UITableView class];
    SEL setSel = sel_registerName("_setSectionContentInset:"), getSel = sel_registerName("_sectionContentInset");
    if (class_getInstanceMethod(tvc, setSel)) MSHookMessageEx(tvc, setSel, (IMP)new_setSecInset, (IMP *)&orig_setSecInset);
    if (class_getInstanceMethod(tvc, getSel)) MSHookMessageEx(tvc, getSel, (IMP)new_secInset, (IMP *)&orig_secInset);
    if (NSClassFromString(@"PSSplitViewController") && NSClassFromString(@"PSListController") &&
        NSClassFromString(@"PSUIPrefsListController")) {
        %init(LGPrefs);
        LGInstallPaneMutationHooks();
    }
}
