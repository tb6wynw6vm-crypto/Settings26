// Settings26 v0.3 — iPadOS 26 look for Settings on iPadOS 16 (rootless)
// Sidebar: PSSplitViewController > UINavigationController > PSUIPrefsListController > UITableView
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PSSplitViewController : UISplitViewController
@end
@interface PSListController : UIViewController
@end
@interface PSUIPrefsListController : PSListController
@end

#pragma mark - Measurements (taken from the iPadOS 26 reference)

static const CGFloat kSectionRadius   = 26.0;  // detail sections + header card
static const CGFloat kPanelRadius     = 34.0;  // floating sidebar
static const CGFloat kPanelSide       = 12.0;
static const CGFloat kPanelTop        = 18.0;
static const CGFloat kPanelBottom     = 12.0;
static const CGFloat kSearchHeight    = 44.0;
static const CGFloat kHeaderIcon      = 58.0;
static const CGFloat kHeaderPad       = 20.0;

static const NSInteger kPanelTag      = 0x2601;
static const NSInteger kCapsuleTag    = 0x2602;
static char kSearchStyledKey;
static char kHeaderKey;
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
        [sb setSearchFieldBackgroundImage:LGCapsuleImage(kSearchHeight, [UIColor colorWithWhite:0.5 alpha:0.16])
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

    CGRect target = CGRectMake(kPanelSide, top, colW - kPanelSide * 2.0, H - top - kPanelBottom);
    if (target.size.width <= 0 || target.size.height <= 0) return;
    if (!CGRectEqualToRect(mv.frame, target)) mv.frame = target;

    if (![mv.backgroundColor isEqual:UIColor.clearColor]) mv.backgroundColor = UIColor.clearColor;
    mv.layer.cornerRadius = kPanelRadius;
    mv.layer.cornerCurve  = kCACornerCurveContinuous;
    mv.layer.borderWidth  = 0.75;
    mv.layer.borderColor  = [LGBorderColor() resolvedColorWithTraitCollection:mv.traitCollection].CGColor;
    if (!mv.clipsToBounds) mv.clipsToBounds = YES;

    UIView *panel = [mv viewWithTag:kPanelTag];
    if (!panel) {
        panel = [UIView new];
        panel.tag = kPanelTag;
        panel.userInteractionEnabled = NO;
        panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [mv insertSubview:panel atIndex:0];
    }
    if (!panel.backgroundColor) panel.backgroundColor = LGPanelColor();
    if (!CGRectEqualToRect(panel.frame, mv.bounds)) panel.frame = mv.bounds;

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
static void LGApplyHeaderImpl(UIViewController *vc) {
    UINavigationController *nav = vc.navigationController;
    UISplitViewController *split = nav.splitViewController;
    if (!split || split.isCollapsed || split.viewControllers.count < 2) return;
    if (nav != split.viewControllers.lastObject || nav.viewControllers.firstObject != vc) return;

    NSString *title = LGNormalize(vc.title ?: vc.navigationItem.title ?: @"");
    NSString *desc = LGHeaderTexts()[title];
    if (!desc) return;

    UITableView *tv = LGFind(vc.view, [UITableView class]);
    if (!tv || tv.bounds.size.width < 100) return;

    // Icon comes from the selected sidebar row
    UIImage *icon = nil;
    UITableView *side = LGFind(split.viewControllers.firstObject.view, [UITableView class]);
    NSIndexPath *selIP = side.indexPathForSelectedRow;
    if (selIP) icon = [side cellForRowAtIndexPath:selIP].imageView.image;

    // Match the section inset of the table
    CGRect rf = tv.readableContentGuide.layoutFrame;
    CGFloat x = rf.origin.x, w = rf.size.width;
    if ([tv numberOfSections] > 0 && [tv numberOfRowsInSection:0] > 0) {
        UITableViewCell *first = [tv cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (first && first.frame.size.width > 100) { x = first.frame.origin.x; w = first.frame.size.width; }
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

    if (iv.image != icon) iv.image = icon;
    NSString *t = vc.title ?: vc.navigationItem.title;
    if (![tl.text isEqualToString:t]) tl.text = t;
    if (![dl.text isEqualToString:desc]) dl.text = desc;

    CGFloat inner = w - kHeaderPad * 2;
    CGFloat y = kHeaderPad;
    if (icon) { iv.hidden = NO; iv.frame = CGRectMake(kHeaderPad, y, kHeaderIcon, kHeaderIcon); y += kHeaderIcon + 14; }
    else iv.hidden = YES;
    CGFloat th = ceil([tl sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    tl.frame = CGRectMake(kHeaderPad, y, inner, th); y += th + 6;
    CGFloat dh = ceil([dl sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    dl.frame = CGRectMake(kHeaderPad, y, inner, dh); y += dh + kHeaderPad;

    card.frame = CGRectMake(x, 16, w, y);
    CGFloat totalH = 16 + y + 14;
    CGRect wf = CGRectMake(0, 0, tv.bounds.size.width, totalH);

    if (tv.tableHeaderView != wrap || fabs(wrap.frame.size.height - totalH) > 1.0 ||
        fabs(wrap.frame.size.width - wf.size.width) > 1.0) {
        wrap.frame = wf;
        tv.tableHeaderView = wrap;
    }
}

#pragma mark - Hooks that need Preferences classes

%group LGPrefs

%hook PSSplitViewController
- (void)viewDidLayoutSubviews {
    %orig;
    LGStyleSidebar(self);
}
%end

%hook PSUIPrefsListController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    self.navigationItem.titleView = [UIView new]; // no "Settings" title above search
}
%end

%hook PSListController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    LGInstallBackButton(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    LGApplyHeader(self);
}
%end

%end

#pragma mark - Generic UIKit hooks (Settings only, via filter plist)

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
        UIView *card = [tv.tableHeaderView viewWithTag:1];
        if (fabs(card.frame.origin.x - self.frame.origin.x) > 0.5 ||
            fabs(card.frame.size.width - self.frame.size.width) > 0.5) {
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

%hook UISearchBar
- (void)layoutSubviews {
    %orig;
    if (self.window && LGIsSidebarSearch(self)) LGStyleSearchBar(self);
}
%end

%hook UINavigationBar
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    self.prefersLargeTitles = NO;

    UIImage *back = LGBackImage();

    UINavigationBarAppearance *edge = [UINavigationBarAppearance new];
    [edge configureWithTransparentBackground];
    [edge setBackIndicatorImage:back transitionMaskImage:back];

    UINavigationBarAppearance *std = [UINavigationBarAppearance new];
    [std configureWithTransparentBackground];
    std.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
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

%ctor {
    %init;
    if (NSClassFromString(@"PSSplitViewController") && NSClassFromString(@"PSListController") &&
        NSClassFromString(@"PSUIPrefsListController")) {
        %init(LGPrefs);
    }
}
