// LiquidSettings v0.1 — iPadOS 26 look for Settings on iPadOS 16 (rootless)
#import <UIKit/UIKit.h>

static const CGFloat kLGSectionRadius = 26.0;

static UITableView *LGTableViewFor(UIView *v) {
    UIView *s = v.superview;
    while (s && ![s isKindOfClass:[UITableView class]]) s = s.superview;
    return (UITableView *)s;
}

// 1) Bigger, continuous rounded corners on grouped sections
%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    UITableView *tv = LGTableViewFor(self);
    if (!tv || tv.style == UITableViewStylePlain) return;
    NSIndexPath *ip = [tv indexPathForCell:self];
    if (!ip) return;
    NSInteger rows = [tv numberOfRowsInSection:ip.section];
    CACornerMask mask = 0;
    if (ip.row == 0) mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == rows - 1) mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.layer.maskedCorners = mask;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.cornerRadius = mask ? kLGSectionRadius : 0;
    self.layer.masksToBounds = (mask != 0);
}
%end

// 2) Small centered titles, no large titles, glassy bar without hairline
%hook UINavigationBar
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    self.prefersLargeTitles = NO;

    UINavigationBarAppearance *edge = [UINavigationBarAppearance new];
    [edge configureWithTransparentBackground];

    UINavigationBarAppearance *std = [UINavigationBarAppearance new];
    [std configureWithTransparentBackground];
    std.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    std.shadowColor = UIColor.clearColor;

    self.standardAppearance = std;
    self.compactAppearance = std;
    self.scrollEdgeAppearance = edge;
}
%end

%hook UINavigationItem
- (UINavigationItemLargeTitleDisplayMode)largeTitleDisplayMode {
    return UINavigationItemLargeTitleDisplayModeNever;
}
%end
