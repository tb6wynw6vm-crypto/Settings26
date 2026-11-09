// Settings26 v0.2 — iPadOS 26 look for Settings on iPadOS 16 (rootless)
// Sidebar: PSSplitViewController > UINavigationController > PSUIPrefsListController > UITableView
#import <UIKit/UIKit.h>

@interface PSSplitViewController : UISplitViewController
@end

@interface PSUIPrefsListController : UIViewController
@end

static const CGFloat kLGSectionRadius  = 26.0;  // detail pane sections
static const CGFloat kLGSidebarRadius  = 34.0;  // floating sidebar panel
static const CGFloat kLGSidebarSide    = 12.0;  // gap left/right of sidebar
static const CGFloat kLGSidebarTop     = 18.0;  // gap under status bar
static const CGFloat kLGSidebarBottom  = 12.0;
static const NSInteger kLGBlurTag      = 0x2626;

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

static UITableView *LGFindTable(UIView *root) {
    if ([root isKindOfClass:[UITableView class]]) return (UITableView *)root;
    for (UIView *sub in root.subviews) {
        UITableView *t = LGFindTable(sub);
        if (t) return t;
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

// Circular glass back button (drawn once, reused)
static UIImage *LGBackImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGFloat d = 44.0;
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d)];
        img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0.5, 0.5, d - 1, d - 1)];
            [[UIColor colorWithWhite:0.55 alpha:0.30] setFill];
            [circle fill];
            [[UIColor colorWithWhite:1.0 alpha:0.14] setStroke];
            circle.lineWidth = 0.75;
            [circle stroke];

            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
            UIImage *chev = [[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg]
                imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            CGSize s = chev.size;
            [chev drawInRect:CGRectMake((d - s.width) / 2.0 - 1.0, (d - s.height) / 2.0, s.width, s.height)];
        }];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return img;
}

#pragma mark - Floating glass sidebar

static void LGStyleSidebar(UISplitViewController *split) {
    if (split.isCollapsed || split.viewControllers.count < 2) return;
    UIViewController *master = split.viewControllers.firstObject;
    UIView *mv = master.view;
    if (!mv) return;

    CGFloat colW  = split.primaryColumnWidth;
    CGFloat H     = split.view.bounds.size.height;
    CGFloat top   = split.view.safeAreaInsets.top + kLGSidebarTop;
    CGRect target = CGRectMake(kLGSidebarSide, top,
                               colW - kLGSidebarSide * 2.0,
                               H - top - kLGSidebarBottom);
    if (target.size.width <= 0 || target.size.height <= 0) return;
    if (!CGRectEqualToRect(mv.frame, target)) mv.frame = target;

    mv.backgroundColor     = UIColor.clearColor;
    mv.layer.cornerRadius  = kLGSidebarRadius;
    mv.layer.cornerCurve   = kCACornerCurveContinuous;
    mv.layer.borderWidth   = 0.75;
    mv.layer.borderColor   = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    mv.clipsToBounds       = YES;

    UIVisualEffectView *blur = (UIVisualEffectView *)[mv viewWithTag:kLGBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:
                   [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        blur.tag = kLGBlurTag;
        blur.userInteractionEnabled = NO;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [mv insertSubview:blur atIndex:0];
    }
    blur.frame = mv.bounds;

    // Make everything above the blur transparent
    if ([master isKindOfClass:[UINavigationController class]]) {
        UIViewController *rootVC = ((UINavigationController *)master).topViewController;
        rootVC.view.backgroundColor = UIColor.clearColor;
        UITableView *tv = LGFindTable(rootVC.view);
        if (tv) {
            tv.backgroundColor = UIColor.clearColor;
            tv.backgroundView  = nil;
            tv.separatorStyle  = UITableViewCellSeparatorStyleNone;
        }
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
    // 26 sidebar has no "Settings" title above the search field
    self.navigationItem.titleView = [UIView new];
}
%end

%end

#pragma mark - Generic UIKit hooks (Preferences only, via filter plist)

%hook UITableViewCell

- (void)layoutSubviews {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!tv || tv.style == UITableViewStylePlain) return;

    if (LGIsSidebarTable(tv)) {
        // Sidebar rows are flat on the glass panel, no section cards
        self.layer.cornerRadius  = 0;
        self.layer.masksToBounds = NO;
        return;
    }

    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!ip) return;
    NSInteger rows = [tv numberOfRowsInSection:ip.section];
    CACornerMask mask = 0;
    if (ip.row == 0)        mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == rows - 1) mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.layer.maskedCorners = mask;
    self.layer.cornerCurve   = kCACornerCurveContinuous;
    self.layer.cornerRadius  = mask ? kLGSectionRadius : 0;
    self.layer.masksToBounds = (mask != 0);
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!LGIsSidebarTable(tv)) return;

    BOOL on = state.isSelected || state.isHighlighted;

    // Selected row = grey capsule, everything else = clear
    UIBackgroundConfiguration *bg = [UIBackgroundConfiguration clearConfiguration];
    if (on) {
        bg.backgroundColor  = [UIColor colorWithWhite:1.0 alpha:0.12];
        bg.cornerRadius     = self.bounds.size.height / 2.0;
        bg.backgroundInsets = NSDirectionalEdgeInsetsMake(2, 0, 2, 0);
    }
    self.backgroundConfiguration = bg;

    // Selected text turns blue instead of white
    self.textLabel.highlightedTextColor       = UIColor.systemBlueColor;
    self.detailTextLabel.highlightedTextColor = UIColor.secondaryLabelColor;
    self.textLabel.textColor = on ? UIColor.systemBlueColor : UIColor.labelColor;
}

%end

// Small centered titles, glass bar without hairline, circular back button
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
    std.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
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
    return UINavigationItemBackButtonDisplayModeMinimal; // chevron only, no "Back" text
}
%end

%ctor {
    %init;
    if (NSClassFromString(@"PSSplitViewController") && NSClassFromString(@"PSUIPrefsListController")) {
        %init(LGPrefs);
    }
}
