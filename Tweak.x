// Settings26 v0.3 — iPadOS 26 look for Settings on iPadOS 16 (rootless)
// Sidebar: PSSplitViewController > UINavigationController > PSUIPrefsListController > UITableView
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end
@interface PSListController : UIViewController
@property (nonatomic, retain) PSSpecifier *specifier;
- (NSMutableArray *)specifiers;
- (void)setSpecifiers:(NSArray *)specifiers;
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
static void LGStyleSidebar(UISplitViewController *split) {
    if (gLGSidebarBusy) return;
    gLGSidebarBusy = YES;
    LGStyleSidebarImpl(split);
    gLGSidebarBusy = NO;
}
static void LGStyleSidebarImpl(UISplitViewController *split) {
    UIColor *bg = UIColor.systemBackgroundColor; // black in dark mode, like the reference
    if (![split.view.backgroundColor isEqual:bg]) split.view.backgroundColor = bg;
    if (split.isCollapsed || split.viewControllers.count < 2) return;

    if (split.primaryBackgroundStyle != UISplitViewControllerBackgroundStyleNone)
        split.primaryBackgroundStyle = UISplitViewControllerBackgroundStyleNone;

    UIViewController *master = split.viewControllers.firstObject;
    UIView *mv = master.view;
    if (!mv) return;

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
        panel.backgroundColor = LGPanelColor();
        [mv insertSubview:panel atIndex:0];
    } else if (mv.subviews.firstObject != panel) {
        [mv sendSubviewToBack:panel];
    }
    if (!CGRectEqualToRect(panel.frame, mv.bounds)) panel.frame = mv.bounds;

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
        CAGradientLayer *fade = nil;
        UIView *fadeView = (bar.superview == mv) ? [mv viewWithTag:kFadeTag] : nil;
        if (bar.superview == mv) {
        if (!fadeView) {
            fadeView = [UIView new];
            fadeView.tag = kFadeTag;
            fadeView.userInteractionEnabled = NO;
            fade = [CAGradientLayer layer];
            [fadeView.layer addSublayer:fade];
            [mv insertSubview:fadeView belowSubview:bar];
        } else if ([mv.subviews indexOfObject:fadeView] + 1 != [mv.subviews indexOfObject:bar]) {
            [mv insertSubview:fadeView belowSubview:bar];
        }
        fade = (CAGradientLayer *)fadeView.layer.sublayers.firstObject;
        CGFloat barBottom = CGRectGetMaxY(bar.frame);
        CGFloat fadeH = barBottom + 18.0;
        CGRect ff = CGRectMake(0, 0, mv.bounds.size.width, fadeH);
        if (!CGRectEqualToRect(fadeView.frame, ff) && fadeH > 20) {
            fadeView.frame = ff;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            fade.frame = fadeView.bounds;
            UIColor *pc = [LGPanelColor() resolvedColorWithTraitCollection:mv.traitCollection];
            CGFloat searchTop = MAX(0, barBottom - kSearchHeight - 8.0);
            fade.colors = @[(id)pc.CGColor, (id)pc.CGColor,
                            (id)[pc colorWithAlphaComponent:0.78].CGColor,
                            (id)[pc colorWithAlphaComponent:0.0].CGColor];
            fade.locations = @[@0.0, @(searchTop / fadeH), @(barBottom / fadeH), @1.0];
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
    s = [s stringByReplacingOccurrencesOfString:@"\u2011" withString:@"-"];
    return [s stringByReplacingOccurrencesOfString:@"\u2010" withString:@"-"];
}
#pragma mark - Real iPadOS 26 icons (cropped from the reference screenshots, packed in icons.png)

static NSDictionary<NSString *, NSArray<NSNumber *> *> *LGAtlasMap(void) {
    static NSDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = @{
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

static UIImage *LGRefIcon(NSString *title, BOOL large) {
    if (!title.length || !LGAtlas()) return nil;
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; });
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
    UIImage *img = [[UIImage imageWithCGImage:cg scale:2.0 orientation:UIImageOrientationUp]
                       imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    CGImageRelease(cg);
    [cache setObject:img forKey:key];
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
        objc_setAssociatedObject(cell, &kSetIconCountKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSInteger n = [objc_getAssociatedObject(cell, &kSetIconCountKey) integerValue];
    if (n >= 6) return;
    objc_setAssociatedObject(cell, &kSetIconCountKey, @(n + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

    BOOL on = cell.isSelected || cell.isHighlighted;

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

    UIImage *ref = cell.imageView.image ? LGRefIcon(LGNormalizeTitle(cell.textLabel.text ?: @""), NO) : nil;
    if (ref) LGSetCellIcon(cell, ref);
    else LGGlossIcon(cell.imageView);
    if (cell.textLabel.text.length && cell.imageView.image) {
        if (!gLGIconCache) gLGIconCache = [NSMutableDictionary new];
        gLGIconCache[LGNormalizeTitle(cell.textLabel.text)] = cell.imageView.image;
    }
    if (cell.textLabel.text.length) {
        UIColor *want = on ? UIColor.systemBlueColor : UIColor.labelColor;
        if (![cell.textLabel.textColor isEqual:want]) cell.textLabel.textColor = want;
    }
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
            @"Default Apps": @"Manage your default apps for iPad, including choosing the apps you prefer to use for opening links on the web, sending emails, making contactless payments, and more.",
        };
    });
    return d;
}

static NSString *LGNormalize(NSString *s) {
    s = [s stringByReplacingOccurrencesOfString:@"‑" withString:@"-"];
    return [s stringByReplacingOccurrencesOfString:@"‐" withString:@"-"];
}

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

    NSString *title = LGNormalize(vc.title ?: vc.navigationItem.title ?: @"");
    // Top-level panes get the card; of the pushed ones only those the reference shows with one
    BOOL pushedOK = [title isEqualToString:@"Default Apps"];
    if (nav.viewControllers.firstObject != vc && !pushedOK) return;
    NSString *desc = LGHeaderTexts()[title];
    if (!desc) return;

    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 100) return;
    if (tv.tableHeaderView && tv.tableHeaderView.tag != kHeaderWrapTag &&
        tv.tableHeaderView.bounds.size.height > 1) return;

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

    UIView *wrap = objc_getAssociatedObject(vc, &kHeaderKey);
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

        objc_setAssociatedObject(vc, &kHeaderKey, wrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    card = [wrap viewWithTag:1];
    iv = [card viewWithTag:2]; tl = [card viewWithTag:3]; dl = [card viewWithTag:4];

    // Horizontal placement: exactly where the first section is drawn, measured in the header's own space
    CGRect rf = tv.readableContentGuide.layoutFrame;
    CGFloat x = rf.origin.x, w = rf.size.width;
    if ([tv numberOfSections] > 0 && [tv numberOfRowsInSection:0] > 0) {
        UITableViewCell *first = [tv cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (first && first.bounds.size.width > 100) {
            CGRect cr = (wrap.window && first.window) ? [first convertRect:first.bounds toView:wrap]
                                                       : [first convertRect:first.bounds toView:tv];
            x = cr.origin.x; w = cr.size.width;
        }
    }

    if (iv.image != icon) iv.image = icon;
    NSString *t = vc.title ?: vc.navigationItem.title;
    if (![tl.text isEqualToString:t]) tl.text = t;
    if (![dl.text isEqualToString:desc]) dl.text = desc;

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

    static const CGFloat kCardTop = 24.0, kCardBottomGap = 30.0;
    CGRect cf = CGRectMake(x, kCardTop, w, y);
    if (!CGRectEqualToRect(card.frame, cf)) card.frame = cf;
    CGFloat totalH = kCardTop + y + kCardBottomGap;
    CGRect wf = CGRectMake(0, 0, tv.bounds.size.width, totalH);

    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1.0 ||
        fabs(wrap.frame.size.width - wf.size.width) > 1.0) {
        wrap.frame = wf;
        tv.tableHeaderView = wrap;
    }
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
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; });
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
    [cache setObject:img forKey:title];
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
    NSString *owner = LGNormalizeTitle(LGOwnerVC(tv).title ?: @"");
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
        if (!v.layer.mask) v.layer.mask = [CALayer layer];
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
static char kReorderMarkKey;
static char kReorderPendingKey;
static NSArray *gLGAppSpecs;      // specifiers shown on the "Apps" page
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

static PSSpecifier *LGFakeRow(NSString *name, id target) {
    Class pane = NSClassFromString(@"LGPaneController");
    PSSpecifier *s = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:target set:NULL get:NULL
                                                             detail:pane cell:kPSLinkCell edit:Nil];
    s.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(name)];
    UIImage *icon = LGRefIcon(name, NO);
    if (icon) [s setProperty:icon forKey:@"iconImage"];
    return s;
}

static PSSpecifier *LGCopyRow(PSSpecifier *src, NSString *name) {
    PSSpecifier *c = [(Class)LGSpecClass() preferenceSpecifierNamed:name target:src.target set:NULL get:NULL
                                                             detail:src.detailControllerClass
                                                               cell:src.cellType edit:Nil];
    for (id k in src.properties) [c setProperty:src.properties[k] forKey:k];
    c.controllerLoadAction = src.controllerLoadAction;
    c.name = name;
    c.identifier = [kLGFakePrefix stringByAppendingString:LGSlug(name)];
    [c setProperty:c.identifier forKey:@"id"];
    UIImage *icon = LGRefIcon(name, NO);
    if (icon) [c setProperty:icon forKey:@"iconImage"];
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
    // drop group specifiers we created whose rows are gone
    NSIndexSet *dead = [groups indexesOfObjectsPassingTest:^BOOL(NSMutableArray *g, NSUInteger i, BOOL *stop) {
        return [((PSSpecifier *)g.firstObject).identifier hasPrefix:kLGFakePrefix];
    }];
    NSMutableArray *rowsFromDead = [NSMutableArray new];
    [dead enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
        NSArray *g = groups[i];
        [rowsFromDead addObjectsFromArray:[g subarrayWithRange:NSMakeRange(1, g.count - 1)]];
    }];
    [groups removeObjectsAtIndexes:dead];

    // 2. where the "settings" part starts (first group with Airplane Mode / Wi-Fi)
    NSUInteger start = NSNotFound;
    for (NSUInteger i = 0; i < groups.count && start == NSNotFound; i++)
        for (PSSpecifier *sp in groups[i]) {
            NSString *n = LGNormalizeTitle(sp.name ?: @"");
            if ([n isEqualToString:@"Airplane Mode"] || [n isEqualToString:@"Wi-Fi"]) { start = i; break; }
        }
    if (start == NSNotFound) return nil; // unknown layout: leave Settings untouched

    NSMutableArray *out = [NSMutableArray new];
    for (NSUInteger i = 0; i < start; i++) [out addObjectsFromArray:groups[i]];

    // "Family" under the account row
    NSUInteger acct = NSNotFound;
    for (NSUInteger i = 0; i < out.count; i++)
        if (((PSSpecifier *)out[i]).cellType != kPSGroupCell) { acct = i; break; }
    if (acct != NSNotFound) [out insertObject:LGFakeRow(@"Family", lc) atIndex:acct + 1];

    // 3. pool of all remaining rows, remembering which original group they came from
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
    for (PSSpecifier *sp in rowsFromDead) { [pool addObject:sp]; [poolGroup addObject:@(groups.count)]; }

    PSSpecifier *(^take)(NSArray<NSString *> *) = ^PSSpecifier *(NSArray<NSString *> *names) {
        for (NSString *want in names)
            for (NSUInteger k = 0; k < pool.count; k++)
                if ([LGNormalizeTitle(pool[k].name ?: @"") isEqualToString:want]) {
                    PSSpecifier *sp = pool[k];
                    [pool removeObjectAtIndex:k];
                    [poolGroup removeObjectAtIndex:k];
                    return sp;
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
    PSSpecifier *home = nil;
    for (NSArray *n in @[@[@"General"], @[@"Accessibility"], @[@"Apple Pencil"], @[@"Camera"], @[@"Control Center"],
                         @[@"Display & Brightness"], @[@"Home Screen & Multitasking", @"Home Screen & Dock", @"Home Screen & App Library"],
                         @[@"MULTI"], @[@"SEARCH"], @[@"Siri & Search", @"Siri"], @[@"Wallpaper"]]) {
        NSString *first = n.firstObject;
        if ([first isEqualToString:@"MULTI"]) { if (home) [g2 addObject:LGCopyRow(home, @"Multitasking & Gestures")]; continue; }
        if ([first isEqualToString:@"SEARCH"]) continue; // added right after Siri is found
        PSSpecifier *sp = take(n);
        if (!sp) continue;
        if ([first hasPrefix:@"Home Screen"]) { home = sp; sp.name = @"Home Screen & App Library"; }
        if ([first hasPrefix:@"Siri"]) {
            [g2 addObject:LGCopyRow(sp, @"Search")];
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
    [g5 addObject:LGFakeRow(@"iCloud", lc)];
    PSSpecifier *wallet = take(@[@"Wallet & Apple Pay"]);
    if (wallet) [g5 addObject:wallet];
    addGroup(@"services", g5);

    // 5. leftovers: rows from before Privacy stay in the sidebar, the app list moves to "Apps"
    NSMutableArray *keep = [NSMutableArray new], *apps = [NSMutableArray new];
    for (NSUInteger k = 0; k < pool.count; k++) {
        BOOL afterPrivacy = privacyGroup != NSNotFound && poolGroup[k].unsignedIntegerValue > privacyGroup;
        [(afterPrivacy ? apps : keep) addObject:pool[k]];
    }
    gLGAppSpecs = [apps sortedArrayUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
        return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
    }];
    addGroup(@"apps", @[LGFakeRow(@"Apps", lc)]);
    addGroup(@"other", keep);
    return out;
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
                objc_setAssociatedObject(now, &kReorderMarkKey, @(now.count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else if (cur) {
                objc_setAssociatedObject(cur, &kReorderMarkKey, @(cur.count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } @catch (NSException *e) {
            NSLog(@"[Settings26] sidebar layout disabled: %@", e);
            gLGSidebarFailed = YES;
        }
        gLGReordering = NO;
    });
}

#pragma mark - Pages for rows iPadOS 16 doesn't have ("Apps", "Family", "iCloud", ...)

static NSMutableArray *LGPaneSpecifiers(PSListController *pc) {
    NSString *title = pc.specifier.name ?: pc.title ?: @"";
    pc.title = title;
    NSMutableArray *out = [NSMutableArray new];

    if ([title isEqualToString:@"Apps"]) {
        [out addObject:LGGroup(@"apps_top")];
        [out addObject:LGFakeRow(@"Default Apps", pc)];
        NSString *letter = nil;
        for (PSSpecifier *sp in gLGAppSpecs) {
            NSString *n = sp.name ?: @"";
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

    PSSpecifier *g = LGGroup(@"pane");
    NSString *note = [title isEqualToString:@"Hidden Apps"] ? @"No Hidden Apps"
                   : @"This page is part of the iPadOS 26 look and has no settings on iPadOS 16.";
    [g setProperty:note forKey:@"footerText"];
    [out addObject:g];
    return out;
}

#pragma mark - Hooks that need Preferences classes

%group LGPrefs

%hook PSSplitViewController
- (void)viewDidLayoutSubviews {
    %orig;
    LGStyleSidebar(self);
}
%end

%subclass LGPaneController : PSListController
- (NSMutableArray *)specifiers {
    Ivar iv = class_getInstanceVariable(objc_getClass("PSListController"), "_specifiers");
    NSMutableArray *cur = iv ? object_getIvar(self, iv) : nil;
    if (!cur && iv) {
        cur = LGPaneSpecifiers((PSListController *)self);
        object_setIvarWithStrongDefault(self, iv, cur);
    }
    return cur ?: %orig;
}
%end

%hook PSUIPrefsListController
- (NSMutableArray *)specifiers {
    NSMutableArray *s = %orig;
    if (gLGReordering || !LGSidebarEnabled() || !s.count) return s;
    NSNumber *mark = objc_getAssociatedObject(s, &kReorderMarkKey);
    if (mark && mark.unsignedIntegerValue == s.count) return s;
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
    if (LGInDetailColumn(self)) LGApplyHeader(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (LGInDetailColumn(self)) LGApplyHeader(self);
}
%end

%hook UITableView
- (BOOL)cellLayoutMarginsFollowReadableWidth {
    if (!%orig) return NO;
    if (self.style == UITableViewStylePlain) return YES;
    UIViewController *vc = LGOwnerVC(self);
    return (vc && LGInDetailColumn(vc)) ? NO : YES; // detail panes span the column like iPadOS 26
}
%end

%hook UITableViewCell

- (void)layoutSubviews {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!tv || tv.style == UITableViewStylePlain) return;

    if (LGIsSidebarTable(tv)) { LGStyleSidebarCell(self); return; }

    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!ip) return;

    // Keep the header card aligned with the sections below it
    if (ip.section == 0 && ip.row == 0 && tv.tableHeaderView.tag == kHeaderWrapTag) {
        UIView *wrapV = tv.tableHeaderView;
        UIView *card = [wrapV viewWithTag:1];
        CGRect cr = [self convertRect:self.bounds toView:wrapV];
        if (fabs(card.frame.origin.x - cr.origin.x) > 0.5 ||
            fabs(card.frame.size.width - cr.size.width) > 0.5) {
            UIViewController *owner = LGOwnerVC(tv);
            dispatch_async(dispatch_get_main_queue(), ^{ if (owner) LGApplyHeader(owner); });
        }
    }

    NSInteger rows = [tv numberOfRowsInSection:ip.section];
    CACornerMask mask = 0;
    if (ip.row == 0)        mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == rows - 1) mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
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
            if ([txt isEqualToString:txt.uppercaseString]) n.text = txt.lowercaseString.capitalizedString;
            self.contentConfiguration = n;
        }
        return;
    }

    UILabel *l = self.textLabel;
    NSString *txt = l.text;
    // Only headers come out ALL CAPS on iPadOS 16; footers keep normal case and are left alone
    if (txt.length > 1 && [txt isEqualToString:txt.uppercaseString] &&
        [txt rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound) {
        l.text = txt.lowercaseString.capitalizedString;
        l.font = font;
        l.textColor = UIColor.secondaryLabelColor;
        [l sizeToFit];
    }
}
%end

%hook UISwitch
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
    std.shadowColor = UIColor.clearColor;
    [std setBackIndicatorImage:back transitionMaskImage:back];

    // "Edit" / "Done": white text on a dark glass capsule
    UIImage *capsule = LGCapsuleImage(40.0, [UIColor colorWithRed:38/255.0 green:38/255.0 blue:40/255.0 alpha:1]);
    for (UINavigationBarAppearance *ap in @[edge, std]) {
        for (UIBarButtonItemAppearance *ba in @[ap.buttonAppearance, ap.doneButtonAppearance]) {
            ba.normal.titleTextAttributes = @{
                NSForegroundColorAttributeName: UIColor.whiteColor,
                NSFontAttributeName: [UIFont systemFontOfSize:17 weight:(ba == ap.doneButtonAppearance
                                                                         ? UIFontWeightSemibold : UIFontWeightRegular)]
            };
            ba.highlighted.titleTextAttributes = @{ NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.6] };
            ba.normal.backgroundImage = capsule;
            ba.highlighted.backgroundImage = capsule;
        }
    }

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

%ctor {
    %init;
    if (NSClassFromString(@"PSSplitViewController") && NSClassFromString(@"PSListController") &&
        NSClassFromString(@"PSUIPrefsListController")) {
        %init(LGPrefs);
    }
}
