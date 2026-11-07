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

static UIImage *appsIconFallback(void) {
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

// أيقونة Apps الأصلية من iOS 26 (مقصوصة من سكرينشوت المرجع، 87px @3x)
static UIImage *appsIcon(void) {
  static UIImage *img;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSString *b64 = [@[
    @"iVBORw0KGgoAAAANSUhEUgAAAFcAAABXCAYAAABxyNlsAAABWGlDQ1BJQ0MgUHJvZmlsZQAAeJx9kLFLw1AQxr9WpaB1EB0c",
    @"HDKJQ5SSCro4tBVEcQhVweqUvqapkMZHkiIFN/+Bgv+BCs5uFoc6OjgIopPo5uSk4KLleS+JpCJ6j+N+fO+74zggOW5wbvcD",
    @"qDu+W1zKK5ulLSX1jAS9IAzm8Zyur0r+rj/j/T703k7LWb///43Biukxqp+UGcZdH0ioxPqezyXvE4+5tBRxS7IV8onkcsjn",
    @"gWe9WCC+JlZYzagQvxCr5R7d6uG63WDRDnL7tOlsrMk5lBNYxA48cNgw0IQCHdk//LOBv4BdcjfhUp+FGnzqyZEiJ5jEy3DA",
    @"MAOVWEOGUpN3ju53F91PjbWDJ2ChI4S4iLWVDnA2Rydrx9rUPDAyBFy1ueEagdRHmaxWgddTYLgEjN5Qz7ZXzWrh9uk8MPAo",
    @"xNskkDoEui0hPo6E6B5T8wNw6XwBA6diE8HYWhMAADJESURBVHicdb3Ni21rct75i4h3rb13no97r+uWuiR1uykJSUgIqQyS",
    @"DR4Y0eAW9B9gjPHA4IEGbjeNPfLA9MAD/wfdaGDwwBjjqcGg9kR4YDDSQAhTQjJYH1apS1X36t5zT37std43InoQ79qZpyxn",
    @"1b55Tp6dO/eKFW/EE088ESnwQ7y+fMJf/J9/nG996xf51s/9Zf7HH/kmd3cf467c3195fNi0d9UYOiIUUiEbEfpxBD89PD8Z",
    @"7n81k5bwzWb2Y4stqbYIKTacn/NISxJIAFQCRRAFFUFEEBJJkEyo/5PI/Hz8DzKFIAkABBFFVRFVBAjAI8gMBDAVTBU1qX/P",
    @"8PDx2+7h6ZEgYmr/xZr+vqoNFf0PmfFF9/47ve9feuxEBqbK6bS05aRhFtHHA/cPf8b9/ee8e/c9vvOd3+MP/+jbfPb5f+Xh",
    @"4R1ttde8fv2Wt28/5u2bj7lcXgPGvg32jlyvXbfNfYwMgjeZ+ksq8kug3wL9Gchv1AWCCCCCqoEYlLngMALAzcBl5OPTiz/8",
    @"Nx9l0A++C5D54MVnbjfiz3+92/MtU/4SKYAhCIL9AqkQQsr87uS7wLdBfgv01+sh70EBMZEWzdY8ne64u3vDq9cfcXf3htP9",
    @"K3rvtK9//Rt8+ukP8SM//Bf5xjf+J96++QtkNu7vd71ePR6ful+fxs9GtL+jyN8040dNDdHDeCBCmlogAqqoqIgomUokgKjA",
    @"tH4C9VQiIJOUaQwRkJemqj9FJhlJZpLTyxGZt0ueb1uWQYMkM6aF5k0QQdB6XkCGRYZACiqCpiUupAgpqQmSwTdI+YZg/4uQ",
    @"/0DQ75D2rzL1n4P8J9MTp/W1mlmsy8K+P/LVV5+zbVdEFtpP/MTP8umnP8Q3v/mT/OiP/BivXn2N+692e/flvT8+jY/2zj8Z",
    @"nV/JYDUTlmbB0kLEhBStqxNRVROpo4kIGYdRpgHUyigk4DfXyGQe30QkUQVE53OFnG4bUc9FpI6/CKDTbodxo0JHBhl5u1/l",
    @"yMLNJUPJQAlBsXqkEpkEiYgTCqSmiIWmpkiqqP5opv7DcP37IfKrIqd/vDR9d768NpGPPYGn7QlEubz6mPbz3/oF3r75mK9/",
    @"/Ud5/fpTxmjt4eFpPDz4L+6df4GsP2m2INaGSDORRSOaZs4LozxCREGVFCEy8QjCE0FRNVRaXWnOSJlHBPUZOo7o+uy3h98p",
    @"EMLNAxFBZtg5vvRBdHnxyOnRGcfPqydLCqSiYhit/u5B5iAkwUBUpeli6O3+ZCY+eq4R+fdF5JfNlr+9LO03lpX29u0+fuiH",
    @"7hFV3n70NdpP/sTPYLbS2h1PT27Xp/fj/f32ix76a8ty+mRZXo1mJ8u0lgHD6zS7Q0rWkZJ645JORhnWPcgElYZIq/AmLy4c",
    @"BdH6Pnk2qkxjTGcs40olpZxHPJX5Pc/3Ql4YVmY4yGnyjCQykJieH6CZiFSgqKgUSM6L0wpXglSiFDncQNy9uXsy0pH8SVN+",
    @"LZNfHs5vZDR7dfnY+dR5+/Yt7dNPf5jRg+tT6Pv3T35/33+h7/prKusny3Lx0+muNTuTqfTueA4ivLyBCRy0Il3k8XBSsrxL",
    @"6qglUe4XEy3kTHHy8gTEzf0yD2uVcWUa9/B1jufe7trxGvW/G7ZIYHqtixcy4UhjVIiKI14HqkFq1r2XI2InMcNXPVIyoyXp",
    @"mXyS1/i1PvJ/Fc3fXJc7bSuR+Za2tAveu/R+5empv7le418LyydtWV1ktQhlZEGbPpLuUbFUQEzroUlKQA4IR6xgyxHvIhyP",
    @"inXlEQfIkuk9BafK+7KS3M0NC6qpyrRTEJGVC5nxmSP0zz9Pe2fEfDCzWCVEDFQqlKUPwnv9KBXMBHS+VSq0JYEnMyYz35OB",
    @"YCJ4pH/i3f+1Nf3503r3sJzOopbZHu872zb0+jR83+KfZtg3zU5D9dQijG0LMjc8YARkOCiFGQ2wJMXJHCSdFEc0UasEFq64",
    @"J+4OqUhOj5HyCHuOhNN7ZkJKvxk3VbAXiCC9DJzM2Ctavqht3jCd3stMhvP56TMGSL0/guEDd0dSaGqYNUQFJxjhRDgjojyX",
    @"ciYzu2FrJM0HY7h/M0L+KbL872ZqzcTbV189at/Dr9fxM2PIr4gsYbYashAh9O4MTyKPRFKehEDgkJUEMvt8jHrTKYgspK94",
    @"LEQ2CL0dW27+NosGqZiX6RCdyAHTGKoQccAyGCPwSECRGdOFhtg8UZJl4OMUZCA5yBgznNRNqZM1IPqM5wtC1PvLIMMJ9zop",
    @"6AwTOk/SREYJjhspkS6/Es7/7UO+LanaHh92G57Ru/5daE31NESWlmmMAd0D9xn7TAuxHkcmO+HTqHSQAfQ6aplkKsIZlQtq",
    @"axUWWbEzUEi5GSBwNJ3MDowXN8rraE9kcKAqUYE0BINcgIVwBwaoIhhHvaYyQAYiHcFpdVtmshyYOKmCMiA7GVpQbiblDww6",
    @"T0WFu5zRRgTEM6WNEX9X9viHQ8PavvuIkNeZ+rdEllRZDFr9gJzHUBK9lZiVaDwcZydyR8TBBqpRXpZJ+CB9ZuSmmABphXuj",
    @"YFA6eAYR5bUqjuCIDES8jCEd0iumT0x7HEtyvs8jtubAw8hQkFaGEFCNek0bCB0lUC1E0pZEtWKxzvAWoXgZDcEwVVBDtYHU",
    @"NfiMw1WrBOU5kmPE33L3/wvJhyZpKehfk7RviLQA04jjwCqmR2lbPEDiRA4iOjFjrFrQVqEthrXyMHcYXsWBSkdvxlXShRhC",
    @"EORwEkcJkKRZsrSkWWCaoPEcckhUFWsLqksVKq6MDr47owuRSoQg2khtmBmqWTdOOsKGSq/jL7CI1klKJVMYIeBH+W4TSs54",
    @"rkak4pGMETMWz8LUEBGJiPxGpP+1xP9tE1lQ9K+nGJIaEao3WKM231zV656DzIJjyEANtCnrWVlOsKxgLRCrBOOzUvIRQK84",
    @"5kp0YewV79w7KaNOhwnr2bg7Ny7nxroKahMh+CCo+LssdUTdldGF61OwPTrbY7BHki5kNkQWzBZOq9EsaM3rlNGRHAXftLw8",
    @"0xgu7F3YBzAEn6f3JQ9Sp7Kcxz0JAlVBVBCRyBTN4K9H8m/b8FTgW5mKSBNQIuqVTOsikqRHZ0TFQmzQmrBeGutZOd0JbQ2s",
    @"OUhHmqCt+IeIoO+jiorIMu4mk1vohO8wOkLSFuV8PvH2rfLR25XXb4RldZCFMRruHRGhtRWVhT6U7QoP74P3OsA7PgYeiUhD",
    @"dWVdgst55XwSTmuxYyAzVvrMqEFSN2vrynUTnjbYt6QPJ6LjA0KCpJFSXnxg5dvJFkQwVOxbCNq2zd+oyk+V9U3BJp+SiBUW",
    @"jQh6H/SxkbqzNFjOxt3bhcubxnqXiHU8N0ZcSevYSVlWJTJgH9ATXMEbblVHxuh475A7TYLTarx+pXzy8crXPlU++aRxuTRU",
    @"kjGcMcqHVBRQeleeHpJ3BuKBb4O+bRADRWntxPkUvLokr+8al1OyWMX38EHEILKT0kBWgpXelcdFWCS5d8e707uy+0LIitgZ",
    @"XYxmDVqhiBdloZo0UvkpzXjTRuRPK/l1KxQqLyF+JkQE7l5vJDqROwbosrK8aawfg62DkY/s4yu6P4B1clU4NSKDncEwoeWK",
    @"xgkTI0YiV0e0g+0sFry6GG9fG598tPPJW+XjN8bduQNPjPHEGPvM3oUORmusKdCT8TTYHzv70xV8h4RmO2tzLqfg9XnhsjgL",
    @"V/AnQq6ETFTDAnYCvTDszKonNAzfk6fHUV7rC2Gg2grSHRwxNpFTzIpZUsS+LqI/3VSWrwvaIiQjj/KzjnSmTNLZUUlUAs+d",
    @"7s7QIE8Ql063R572L7jKF4z2gNqgm7CJMTLYGGALl/aaM28RVrgmITuRV4wrSyvv+viN8NHr4PXpgZUO+wMe94Q/gY+CRZwQ",
    @"uYCvnGTl1bKwX4TrZedpeWJsj6Q7JiuL7ZyXzrk1Tmzo9p7Y7hHf0CMs2ILIhcxXLPIaa2+I05ltSd7JDlmIwpYLqOOxkfsg",
    @"24JaA2ahkl54XbMBX29my1/JVDwkItIgZ1dAb1WNSNAUsgljOJ4bXYLRYLTkSb7kfX6Pp/yCtEdUO5aJuNA96A6tXdAFFl1R",
    @"F8ISzx33K5pl3Mt54fUluFuvrLKT+3v28Wf0/o7IbQL8RnJB9RXkK8zvWO01l2XlvOys7QnlnqAjNEw7iw4WFBsP5NMX8Pge",
    @"9Q2RABOkNYgLYa/R9gkInA3WJjTZUBKxBVsgJRjbTh9CRNKWircRUY4oEaJpCH+lwUF6a1VheVQ4MTOlF5RRMKUwoTqYQBvE",
    @"Eox84qr3XPUrQh4gN8QdHEZCSONs0JeNLhsqRs9kxE7EDuwoFQ/XNlgsMR7BvyDG5+DvaDIwlcK2fkUnvlaFsJW1VRgQrmQ+",
    @"kLkDbVaUWayt35PjHeYPLLOSjHC8C5mPpO0IgtmJxoKhKPtMWoHZ0VqKyT8+E/KzFuIluGiZ+hN5I/Zm4RBHeKgXhckSZd0l",
    @"VTADVRAtylBaAEHQibzi3gu9iKEmsCSpMVm1nRGJ38rcgWQAXiGJRNhR2RHrNAmWBZoqMZLRHWFgVuxb4d/Cwx4b7lcyCvrV",
    @"6zRUFJO6IdaCk9QV7xns4YXJtUFcQa6Eb2QYMCqpT1iZQvHTJqhWoVLkkQFBJa0A8idaJj81jUt58VHe5TTutPIEzFUJFfkc",
    @"k0ARFWySHkEjw4onmHX6y5Ixw0l30ieRkvPmcdz6Z1ZsFt2IWFWIYrMlVB+qSsokiKLIIXfHo4qX8he5XcRz12d2MxQ0tTyx",
    @"SA6CwMMnoVO49qA0648635NOfsLI2T4q3uJ4f/FTLUP3rKhC9ZN00nEyL5JZ3x/GdHx3+hX2bSAbxKJoLixyRrQTCsFC5KQa",
    @"3cghhFYtLsXfPSMYoTwAI2kF1KORuZCjEW5EOCYQQxguNC2GClGGC2MkY8Dw4trqLFYhkSx4wggDF3wAmpiBixK2kGqELThK",
    @"T2FEocdIIVOfH1EP0p6/JgdVMHvSZd+95SRScvaYRA4DS93JnPT04a0jcUnGlvQtaXtRzy3PhHRMktBGyo7HYGTgbmhvqFSv",
    @"StyQSCSUCCVEq+KJRsRCtZCkfi6DCNj7XhR4COSC6h2eFyJWejf2Dn0IYxgZC6iBnEHOJGc8E3Inc0ViJ9JpKmALYUpaI/SO",
    @"kSdGNHo2RhgeSaQRaUhMQx4Glnr/3IyrBEdVB620BkfzbmJbgtkLnG2YOk8yj6bSkFQYCl1RWzEuLFpdCq/oQ4bRIrFcWLmj",
    @"5Rn1tWp3r2rNhzIQ+p7smzD6QsaK6pnFVtJWhp2JuM4EIqiutPYKkddEv7BHYxvBtitjGO5L8WFxJvJ4FAOW+gqsOAuaIE2Q",
    @"VsRMcibijOeKh+FhswNRnEjErAGivLkanTL7hgUKChgkIK1lys8Vk6BKCulBzynOsERVZhlc5IXpCSywNNQXdBiMxKRXOasD",
    @"MggPyOqtqp45ccfiF+grsTeiJz4cH50enes1eHwUHh+VbTvz+m6hra+QdofaHT6eiBgghtmK6gUfK5sbT7vytA2ue2PvK8Mr",
    @"IfdxZvQzvZ9xAY1AdCBLKwavyQGWCHQa9czwlTEWwo30w7hGzKZ1ptQJEimDi8zvF7JaBUD+XMvEjjh/BO1DI6Dy4h+ojCjS",
    @"0FwRV2RvsDVEKRbLADGclVV3RjqRguSCjRMZJ3xf8W3BexId3APx5HrtPD4Y9/fG/euFu8uFpSltuYCcCB4ZMWYH4UTEytaF",
    @"+2vw/gHun4Sn7UT3gXtV/b2f2bYz23ZiS0ESNAORldTEJyk+PBlIhQM/0/uJ3hd8FBVAGCmNdK0DfvTtUo7UQRyn9TBYqrWD",
    @"4a+nz0a5GpIT21bone0VJce8i1fBHxRflJYrtgptbahdkNYRczyDbR9sV6d36L3B3vCHhXEV0q2Kgljo/cr9Q/DFu8b5VG2Y",
    @"4QunUyNd5pHvqBnLciay8fDovPtq8GdfJl9+JTxdK+ZGOhHQ94WnxzMPuqKr4CIsAS1XQqMSvwSDZKSwubHHiad+Zrue6Pv0",
    @"1jQylzKyVhLjMGRWaRP50rhyxNxnaHNgrxvqnW2d4tqkjOtKuuHXpN+DScKAdlY4L6grti7YkkUoXzeu9zvjaeAb5J7kVYin",
    @"BXyl6RmxE5mPXLcrX3wJIs7ed97fJ5dzwcBtS/oIrCnLkkQ694+Dd+8H798L9w+Np23B8wxSJ290uD427sPIBbo21lxoJIZX",
    @"e16UEHCE7o09Vq6+sO0L+96IIdWtlBWyze6H3uBXHqc9D0D5wrgRUzcw29s3SDGTh9x6RzJbJ62KjN3xh2CLxDdH14GtA1s7",
    @"YgNs4Jl0d/pOJaxr4htIXzBfsThjpggncGPfk3dfbezjyv3D4NWdcl5AsrP1Im5sabS1E6k8PA0eH5LrtjL6gvsJqDAlUXF/",
    @"ewq0J25B12DNxA6NAtN7K93Qox57wjaEsVudrskNQwPs1mU+yK2XVdnNo0laGVKxQ1WSSe9V3TQTkkYzm4SJ0WSpqs2TeOqM",
    @"4cTTTuoGegW94vHEHhuRibXGstwVft2gXwuKqZzR1lh0RazhGXi/sveNp63z/v3GaU1OLZDs9HGtmLsYbd3wVK5bsG9GRDU7",
    @"TReanKY2wckxGOxct4HLwOmsdDQ6GXtVcLMASjUGxkhnkPQAD4VYEBoqC5lWnitlj8hnQzKr15snH2FBXlQ9R98sIgrzRhK3",
    @"pCoY1f4gHOnFo6LV/Et2kitjPNHHI5GJnE7IpVottoNcK8GJFdNWJHNVO4ExhsxY3bluzmrVW4sYeDrSE3bBA3qvgkAkWUo5",
    @"gorNE5hECO6JhCPpdKo3p+Gz+egIMGZbL6QM65JUY19BDNUFqPfHc8/6gBmHwz577zPOPbQC8/MNz+bBs1evano1CZaCpqAu",
    @"WErBMm2ILggn3JIhMlsgDXMhPLAeqBuZgWU1IkvrUHIjULCGxFogW500Bw2aNJQkZHbcpI6ztAVhJcUqscSEkZ6oB+kJXiz1",
    @"IQtoOXnYhPDEJzqK52QzxSOVWBND0g7B2s2uVYA9n3ie/4ZUEDnq5ry1K0xtdkOrS1tt8mp1KjkjD7SENYVFjLWttAYmsycl",
    @"K0GpcyKhO2wqnJsyorwzxl4XpknqQExZ2xm1RmvB0qrvZRqoBEEwMuiejGCWxQvhZ4gFAsIdcdBwJIMGrCqcRDmLcZJgoaFB",
    @"lcIR7AiehmF4WhUHWtfOrTCQ6gdmcGtgcxQOPMtgb+nsZtzjr+W1xYDJCy5lHi2qdd5klnYxWHNwtuAidRHtkH6KTuPWGxkm",
    @"dDE2XbgO42nANQbdk9BElqCtyuly4XQ2TidhaYHZAIo5G+n0cNrIWQFWuTz2hb4ZvsuUBZUyoimsYpxJLgIXTU4kFg5RpX0T",
    @"ZWkNz8ZgoR9VxbwORIlJZEU6AwgxQnJiW+Ypy5u2jJtxj2wnswQ+jDNjR1avB50oTjOKXklnyc6aO+dwzp6c2DG9knElYqci",
    @"lyDWSFtwbWwYD2kQiY/BGFGVYBOWxbi7W7l7feJyMZYWCBvDN3zs4CXYKG2JIayEN3Zt4Ak9SRzNoJEsqlxEuJPkQnIWZw0g",
    @"nOgd9VFFUWukGHsI2wutxo3OpPRmnoEjuCQprSwiTMpRSuYlh9YwaZW49BZLcipJ4qjS8ohXB3c2kNxZdHCnzoXBSTaWsWF+",
    @"LZI7r0SUmEMwpK3ociENFgzE6Th7JD0EFzBpnJpyOS1cLguXi6HSq40dReAk1RWxydwLRfrkqM5GEEQMNAYthZMaF4OLCpdM",
    @"Fh+0vpH7EzqulZR1YBGkBegCJIERDHIijPrQyVbqjYYVnsNl/S0QCWR+bhHP8QwtXdXwQ1+bNEmagZlg6eAbxBPL4rw5wStN",
    @"bL+S25eIv8fkEZUNiVGUZSrICV3ukGVgLfGAq8NTKnsqhtE0OTVhaWAaszN7pfcH9v2RMfaKdwmIzeQslawyJobp1dkYAxVY",
    @"tXEW5SLBGjuyP5JPX8H+wCKjPHIE4ULqgi0XlvYKF2FIY6TN8BgICyrtpr4pOVbh1zikTRmoljZCchqXaW0IMqXEzVO7ELOn",
    @"pipoBrFvuD+iS3JZ4bUFOZ7Y+xfQv0TlidU6NnWv4cqIBdl39JTIKqwoqwtrNFYMF2hqNA2EQbizZ8f9kb6/p/dJ2sxYjjRm",
    @"3QNRp8tEMHE8OxJ94l6npbFkYL6R+yPx9B4bTyxLqXs8NjYfU670mtaSRRuNBU2bSCmmPs1KyqqV6GpAZYaRmwdP75WgFbqq",
    @"4F5qw1LaaE6CQnxCt+ocuHd8XElPNJXGRuQTGg9IPLDIlZM6TQoAeigyBkSxY6mdRTotFloKNn+OpkM6GQP3JKPjvuOxT3Fe",
    @"HMKLqV07mgxF/4kVkzkkEXzyxYF45QuNEo0QHYtOC1ispFYhO6EK2gg5MWRDcweWohpTCDVcFkKnPpmjkTCVn1RIVcqOMlEV",
    @"B8INSnBnrQhzj+ptlZzIwQfug/CBd6/3mlckNhodE+ekwUmCNgsTL/HllHHWazUSi5xwScqo83XDC5iLlXZMS7M/g9wzZ6qm",
    @"NGmYlAKGnqgppvNKJu15iJgloxqVKpS+OSqfaCIK0SAs6OKldpwI5RD3jRwMBo4RVlD1SGSzc3TjZQ46pj0Dh7wltRqDmp6c",
    @"1Qlwqn8Wh3Q9vN68dGzqGprAImCZaFSJnKk07Ln0pmDSUTjqcWtjtpCiZsFESuyPHBVkNQczskZUIsEqZJWOaL5f6nhGeOHR",
    @"kBogIUvt3rS6IfN6xGreQrRwlNyuL6YW4fnh4rg4Ic4kMGbT9oavXkCxpKXMTDdFwjGJ8syayjkwmd8w8oH/CgdX7JutIYoz",
    @"JZI4mpBRmFlalY0jJuB+wcYdlWNEVUu3KUoSz1m9SZR008FTCSlxdKojrvio0xXudePDcZGaz5hHV0xqzMCPa6uwAdVdiACf",
    @"UKqKnxJ9F1afcx2zCVkx1m95qhz3+Pd6TntZsuX0oJx8aEbUT5KDjJjNS23VVhep5CLL7UGOurgpDAetsljXagIieMqcMRDy",
    @"Rn4cAyV19GVKO29+Pu+HF+xGpPgFMmFESTpH3AR/nlk/h8mzipBaegBXBa8bKEc/K5QRiotVeZ3zcXzvCzrhZq+Mm49U7PUb",
    @"FKP64NN4R9rKgkHuQPgBeCb7Pg3LMo+R1gyErIieUd2RqP5bzESpuiLtDO1M6opjjJgd2wDPapXIrZScMw4K0BCWEs7NGyFq",
    @"mKyYnuqG1QwyI6ok9qjnlWGFkVJdhsnqMVvh1eicnDWGsODHIxtOm3h3NiVn+VWF6xHXn4mbOh0xBTU5PXcaYcaCIjDSa+Yg",
    @"ilDOadxMA5leKIozZtVywvSOVK83ngvYWrhZV6K9AnvFrhf2WKuh6EZ3pUsJjiV0doNLYFzagJoJq/A2SFWMhuoZ1TOSCzkU",
    @"zzLsyOIGkgWX2fhMY0+lFF0GspIsJIVAVAzThtpK6BmXMy4nRq7T2Hoz8HPHYYaI44bfclbcIkC5xi38Po8n5UFK3j4O1r1o",
    @"m2BlpNJd2UgkL6XNUghWRDrIobhphF4YembnxJWVa6xs0djD2KU8WV3Bj8+NFskcL642OQNNRXXF9IzKiQybegSnO4xoDFZA",
    @"cHE6wo5xjRKQhKyoncllzIteC10sC9pOhJ0Y3DG4VIudBacVQphGPriSir/HjNHzR7z4841yrNh6xN859xV6y4LVaFQ8Gj0X",
    @"rg6PXbAAj8ESJcVU7SziqDklUFJGNPZcuMbCYy485sqWC1sqO8WSMZSxC7GBL8W0WZM5MdNKQYhBrpAnIhdiKH0EW+/sI+hj",
    @"YWQNFw6SHbimYpEkgy5Jm1Oy0hZkIgq3FdEVtxN7ntnyzM6ZnalfwErDgBBKaSBmIjrGtWXSlM/diaDVlOGHXGSxY1OKnkc0",
    @"riydYWgYWwYPCaLByJXVA0dJdVbNEodQbZPN6yK3bFxZecyFjYUuxhChA+nC2KV6c5oskbRFUFOgzabg7EDPSaBwGDvsV2Hf",
    @"le4LgaDScIq6f5oK8pGwWrBKYC2Lf46Yk5wNcsVjZefEU5y4xsIWRs9GR/GjdT61Hc8fxdDpTGvPwaGYwxfPm7HkaEyKFMiH",
    @"F1IeY7ixh/MYBeN6Gms0Oskwm8atnLl78jSCa0p5gjY2VnaKJUtRQqKmZzr0p8By0LpgS928UlwGNfN25Iaq+mKA74lvQngr",
    @"42vNH+9Tl9YzuCqsIaymLGqTWCw0lD5vlgldhC2VJ1euk/sYaMmePuhCHGXvCwBxM3d58G3iOVNumVDwKkknHDr+/SCPPY0e",
    @"xpPX80YqezS6JNvwCgsiN5L8KYwNoWsjrDF0octK6nID40EwxhTvxUB30EMZc1RckVOn1ck0dPa0ahxA0GhYSnU2CDqdMZJr",
    @"VlW2RrIELFaaRAKyBzG4YebQYJdkj2RH6AihOjmN4/HswTlnmW96PeVmsw/J8qj/xIuRcZ3d35jPk3k0B8aeBlP02zLpE7wY",
    @"VelEUHoAmc0/WcicwjhdiXLNiQtHFRE9SA9Eo0Zf55Smz4qp8kAgstTPEUWTWXUdo6pC4PNmFOslCLvX3Jl5INRITo4En+Gv",
    @"FRTtEswv4wdfq1qa2YO0mSntEOPHQYUz/7n65B+g46oe53eUfKw88BBJIkpqu8EfUS1EkGVaTUVCyPAC/BiuJ1wrDIQ00BOp",
    @"5bkpUo3CiVCOo1ZRoM5RZA2beFRSNW2YLqQsiFQ8LrWh1YOjyM75mJJlTbqUYSPG7XSaNVQXRBdCGkMUz4qzx2YSnQLFo2Cf",
    @"S05mETRb55rTfjKJmw+M+2zg49OB2eJ4hhR7VPi45JrojI10JFfwnfReR0UXrF1A1lshEKLl33mwDEXG1JgRNTFngrb6oZ41",
    @"huWe1AKKBZOlBIEUkK9pTLntWoB5040aPbWGnhaWdSW5llRp1IyF6FodXmlktmofuREx39etf1PxPjhKZLn9rIIgUeQ9xSTe",
    @"EtpNKSKT55FpyAmcJeoZNsdUNQ/pU2NdjctirOoovdox3kuLZSvZzoxsPPXB0z5KgOdVXruWhzmQWltF2mq000I7KboUF+GR",
    @"jF4DduFS3dgUcPBeYuURwcis9yiCtQoTZo1lhbu3cLmDlCvX/Z6+byjCag2VqvRkCLkp3g26TinT5CK8+ogpOguI8uRSmltN",
    @"e1JFWGTScvbNct7xPBQ2whGdp2dkETBaGLgBTYVTE+7WhVfryrlBE69qKrzuojVCV3YXVHbSn2bXd+ARDIUQwVXADG0L7Xzh",
    @"9OrEetewM9UzS0pvtjn77sSYhh6Bs7EPpqIcTIKmxtKEZW20i3J5vfDmk4VXbwx042m7Y9+fIOu5ijIGyBXiEcZTwpNMCjif",
    @"d+Yg1Bhyxd2DEGrNQKuUjzkU3ESrL89tk9LhsXmAWyQFjUoceNXOi5VR7xbjlRrnVNaAdcI3wSbdZ3gqFlV+pra5n8FngkqG",
    @"KjGPbolILnB3Ii8QJ6p2AEoLt+DW8T752h26C33AoOZwTQW3IFelvTJOn5y4+/jM+aOGXYIUZxnrc4tI5x6InuST4A/CeJ/s",
    @"4uzvq+sMShMruYFHUZ5ZQsWaJZntoBxIlgilia1zOGWSGUx4IUU/iYNlY5GGBORWdFc7N96cV960xhKB7NWQRHjeFRPUqdCa",
    @"/D7NYI820MAdtvAJAY1sJzid8VNja7AJMwzMkjOmuM+KAs1ZLQ2Hnkm04nVDivT2JVlfG+3TxvnTBc7BYz7S/ZFoO6jP5J9I",
    @"KjlALko7L1iDGBtP950tOisrtqzIbCJk+MwUtbWk5qGrdJGsNlcTsZnTDknkzGeZxXXOqailRtZrSHoMWjNeifFaGvSN/nAl",
    @"R5/61SDdca88HaqwNNqycGlVOHQxngh0Cv5SrEJIa3QrRc3wrLI2nIFzqGYEmfqqIFrgyzS2MRkpZ8SVbsF5bfAmkLew68b9",
    @"9R1b3iPmtEUw4zYJSTPSTjWb5krcC7s6W45CE4uhYnj36i3O1hNZIQ4GIgOVYhPbkfUyb1UyNwnvdGCVuXAni4PQSCygpdAC",
    @"GIVPZffqbWUSw5ExKUsTJPK2V6YhUxJ14JMK8iFVCSXF9+4RXMPZotfRlKSZspiVsqfu/fScIrTJmufd2TCcq6zsutFbY+jO",
    @"Va9c9YqZ46ZzXYAUOyZrxaBI8iTkIrP9k1U/tdK0YdXaryZo6R0zCrIok3YkaWP4TFw1clRbMeKgGCYmz0lS5K0PpTITXRSS",
    @"qIVGE9BHVmmaUU1EXoQbn2KLY8/XC/CdWV3njBLO+Dz2njHjXr1WU8q7olo26UIOLR1ZOB47e+xYBHvsbL6x+ULqKGiW4Dox",
    @"ShTGVm0sIqisiEZ1S6ZYRezgDKpTgxTnYdT2FJ1EDSG3pqkgtPDhiJmK1SYQ9LnsuBXMz3TE3FQFeogwCqkms+jIDymgybFP",
    @"Qj6fJU4HOXcgwPmvGc/bl4JbNfH8nuYP0SNEqMBMiCF1um6rCamKy92py3zeCEUyR786mYlpDfm1jOr/zfk4neR3uOM+g9Pc",
    @"9HTMpN06EsmsOBNV8Rbhv60qfwnJEJ0LPZx5QTMuyKx1tO4mlHguDjGJJK5zXQuFS0PK817WKCE5e1EvsHdMLkkow0xDSsy+",
    @"1/yRVQlVSBKf8tajSpcSzgUCYoQojVr90qQEdrVSMGhZpXgcRnFuZFCdznnJE9sTQfrAh9K1V5EySuwXoiXYCiFHNU21EVUr",
    @"89stM0YeU4yzEKk7Xt56VGkpJYxIzZuWKqS0rAi4SlVCh+eakKYVAkzAinWqAcBJdAQfeO5R8xU7VzlrkdqkZDKNm4nORpqo",
    @"3HJDrRI6ytMqgxcRGmVcS0MzWVjwXGY3YcZLgpKBrCxzDGxMmezRcM0IYjiBIJ5lUGXu7JmfDzKnPo+pFYsf8NQjHuZky56N",
    @"W2AXQikFdgENwmouKxBuZESW66UJuSjR5vFNbiNGR2/qCD8648qxf0zEMBNCi24MdxjVRM1j/87Iko16jTBpKpaGpWJhNXnk",
    @"irqh2Wi51A0WpakBsFijyQWLE5TItGRWYjSdUv08fEFmcp4qc6H0DwkHAZWStCTXQybKTUmStxnbfI6GMKfZK97CyGTPrGM7",
    @"F2UGtWiohMKVGEKLtgtVXGZHVia2PlTtR4AOQWeTUVLmkU/SZlc3BI8BkbWbkazR+A7HC0toFT3B82jsziT/DY0FMwXWyRcL",
    @"zRqWK5K1B40ops1koemK2jQ0VglN9bZcyOZKrJI21YB3DF+bwO8CP1/uWLH0lmjme6+8ehykiktOsqdjobVbAUB1agGPBFZG",
    @"dJEb2TymDarlfePauC0GdkG8VOuHojWPOn4ilTAF4pa8PEA9sDAIg6iucUMwb9DLuLW6a2E55FAHEppxU7yR3YhNiT3IoWga",
    @"TVdMjSZrjS1ovUeZLOABBhLHfTsWW/xuM5X/PBUjFelmbL8xSzPy+uwCTFDFns7mNS5vkVhOIC+zJBQmzJ7GzKIM+2zrlHHt",
    @"QNQwIRVOzT3oc2IJrW8QEZq0Ys3Iktync9BUEQ6x1PcItAD1hbgK4/H4oqFtpU0Ry7GEwj1vHt4fne0+GNeEoVg0jKWGbdKe",
    @"PWcOVdeGp2SuVMh6Tf/PzfQW8HjW9c/jOJFAxfScxq3n9Ay2Oa9pCBZBm15eJPbkUnMalslsmbBPY8cBGZLiY13IXt4k5GSr",
    @"n5GICFMPNttPHowOsdfjmBwprF6x0DfY7wePstOuiSyJnZJYQW0uRxpeip0Ovgn9EbaHYLsfjC3BZ+8u58zzDKMvRYzK8bVD",
    @"LOI0M/mPFW5Dj6EPvYnMqEQ2jfQ89JO1u8adFJlzyjV/MMiautTDoerYjixRXC0ElGL6j4GNrGybnuQIklFHfkA25sqpwpup",
    @"OjeG1L6yvvdardVr21JGcGSe4cHGjmSwbxu6JroEuiTLajPuFnfhI/GejD3pkxXbH4OxJTImX3uA9qhwFDFPjs5uVKF4TQlS",
    @"/T820fy+kMM9LKOqtfxgVWrdoWCK3bTK5QHsUUWBJTepfCcwKeo7kfLWqDnbmDlrsr4zis8TdoD/4c/NSIXoUXh6npohU+Od",
    @"sxrrXrNw7rPOiNs4Q0TSY5BjsD0lNK8BxJal5NRCC8JcITjKuOMKsUktefKa/rmZ4/lsw/Ta9BIfijjFdMVQ8vtNNX8ng+8j",
    @"/PCMtsd+iVvcvdXCLxKVp9CjDGZZEGocPTQJNF8YN3PSLoDUTMENNXyQOQtv14CHzxznpTA8yl858Cxk1jyZRiHWwr3GMXaK",
    @"alGbvda4pnTQTqhPRxGaVVdDqHVc3ufmrFEiFUmdK1yq1WPIbSHzzVoTxopGYikmfD+F32ki8R6R31WRH07JyKLen805SZ2y",
    @"862OJaN0WIcK8FgRPPIYLjrK3ds0w3xB4dBgucitGXrE8vK+A2pkZbJJipT2rPbLmMyEqzKTyuyMHGWdJCmDpKYoI/vznhpq",
    @"66mQDMvnGB8zoTolrxLDpOjWRdvU9haEySlDSClcrxqoRYilofwuou+bSkSI/JaI/pJI5rNy70XdenzMZp1w/ICjyMoP/uvI",
    @"h8a9lbzHRR9l8PNry/zeF/UER3ftUL0nVQpbcvMkJtN2/AIOmRzGIZyNSSbF0a8Tw0PnXsqcSzFnEsxaIVgDfpXELBs2SfLb",
    @"e9SCRAcaqjsyEB2plljjt0QlmloHiX+X8H9GzAnjfNGnZ44BzaOmquhsyEUyPeFIfNUCKURXFV3MpJ/IobMvA6i8MOotB71E",
    @"vtPRqwNrKhPNSPHMUSdJVeaFyyRspoBEsqpJmZ2UQ8oqVnuAvfZMlgZmlshSq2LmZlBq/29Ri+m14kDUMC1jpyak3zYFSm6q",
    @"2tEW/85a0lI2Qe3fS8R3ReR/EJHMVMks0Z0+syN19LSOSx2HGSoFamiljAo6sWbOAmTCjGNz/RRWHFTkraScnnD08GQqxkvB",
    @"MX+Pw/wVCdUWkWcuwqv+Hz5KVzaT73FS6peDPHPWJdyv3T2SZdgmDaPVDZ3C5wPO1Mb+SpJqWeFoiqYiNzy31NxFdXy3Lfnv",
    @"24K0yGuDdi/KvzRb/gHpY4xsH6ytehEKqmMxQyLPBcfRDT7MVFMvB+13FNXH5uQPCsAXnvpi1TZ5e7W6t0Wy+Iza5GwUTuYm",
    @"ORQ5+VzKHy2cSTEeNJuQaFq1dkiURjsonrlH97aQLes9HCRRjW373IM+CN+I3IHd1bwtp/yXp7PcLyeWtm3vXHSlafwz1fZ/",
    @"0Ey9lnRLHeHnXd0yZUJEtbc9D4x6GOMoK4shQyfyi+PXGZShVA7MfJjxw1DwHCbyA+srVQKq2PPteKF81xRSGopOoukFGZVV",
    @"zeQUZ1dYnuuypaHZ0Jgt83j+DSkqtRDTrBxGqF2+PnbC50Y/6Wnm2tYYyxr/rC1Ja3j76v33Ylnu7HKOb5/X8682O/09Dxne",
    @"44XUaa7Zi6Oiqs5FojWTVUVIHbVZCs5LKJMLHAPIyAdM4wcf8uKz3Nw6P3Dx+rUHL6pKnu0Hc/Z4Vpezg3cj3TP8duqmP2LT",
    @"Yw/l5A1vx/PJUahFoSSRHfcrY2yEb4g6yyp+viztdB7/j+r27d6vNnx4++yzP+ZyeRP5UehpefWPWjv9b6p8UwjPCPMMSuo+",
    @"t+XNmVsVwZbCh3PMpuCS5BTN1cBJnaVZfx8udkCtHzCwvPjaczTOF1+b/5UPb0vMl6yKsj7HEcrm4lo4ipYDZgpHujp424PX",
    @"lswX7RogR1WDORhjo48r4SXTW5v4+XJpbz5af1/N/9Hj03t9ePx+bPsD7fvf/0Nevf44RZDL+fX7tpz+hln7f834JAPPTIuo",
    @"nd61h2G5JTaznK0hA3wOHzvutfegpnBmX+kFsU3mLVaShyGfYZgcieoHvPkIgvIBprh1kcp809DKc8fjZVVVWrJjicqBDgtP",
    @"SzxXd4dhk1LzROwM34v1YtR0Zks/ncQud/LF+U7+xnV/ev/uq+/p977/B/nV+z+jff7Fn7D1R8wsXr36yC7n17+5nt/+8rIu",
    @"vxajfeJDRvcwj5jTS53K3IJELYQQafPt+8zMRbDMEDlP93G8Xx7zePFneTZ0HkHlxcfNq/ODL8mLU3DLQB/clvyBr/NMi85k",
    @"O2dxOVrlx79HOMMPo+4gTmvJel7zfDZfV1pb8ovzRX85uf7m/cPn9v3Pv+N/8t0/5MsvPqPd33+Gx4aZ8urutd/dvW6fnJff",
    @"OJ+XXyb1X/Qtf9I6hMvwSHMPidgJL1iUuUG2G2wSq6lEWwoPR+b05qN8ZUKoMpMeeB+pmAe38c6XRn1p7dR4/jP1ejdjzshz",
    @"Q1FQcOzFjbyRQGT1yKKmPFXjFioikvCOj1pJkDjrIvnq9cnffnRpr16f27LE7/Xx9Lf3cf8b795/3r77p38w/r8//X2+9/0/",
    @"5quvvqB5PLBtzrt3wrosqNmI3O3N609/o9mrvxxD/0mE/orZaVUzzCwiIvoICR8aYXL71QcFEDCxWmSplXnx2tL/7FEyDfLS",
    @"6WQafXrUf+u7z/E5/7xU+ANfyw++gRd+Pj+OvmFMo85R1YnnDUgZiYywJRJFTyfRV6+lnS+5t2X/1cjrP354+uLdn335Xfve",
    @"Z380/vg7v8ef/ukf8NX7z9j6I/Lq/OMghsiZy/kTPv7oR/j0az/C27df1/P5o1jaHafl7mcv5zd/Z1kvf9Pa+Udhwb3hbowu",
    @"DJf0IA4ZlJpKrSecLaJ0jTiOHhyZ+naxh/cefbMXljxmMl5WcX+OuW9mOwiVhNtKmtsM6YtnFxE6xatZDfMjLJiJqqnUryeI",
    @"4hPVUYvv2JL/SmX88xHbf3p6esefffmn+r3P/ji++6d/xGef/1ceH7/HGI/AQD55++MMhzGUzDOn9SM+evN13rz+Gq9f/wV5",
    @"dfexvn79sb99+zVe3b19c768/iW18y/B+q0Y7Wd65xv7SPooftWnvkAnmcL0iA9N8mzc29c+MK78d437Ep69fN5Le9+KnA+w",
    @"3Yc/L18og+0Q+E5drTWlLQvr0r7bVv22mfxWav/14ddf7+P6/vHpHfcPX9q7rz6Lzz7/k/z+53/C9z77Do8Pn5E8YFaxubVW",
    @"mHAMZ9+f6DvgWuSxZybiy9J0jDvNPL8X8X9jlv9mVr8fZ/LTTn4SGX81whse38zMH6sGqIiomMDPyRxD+O8a9/b1HzCufGjc",
    @"PIDti+d9UIR86KDPp+BD4zrEbwvpKqRJSIb/l0j/fWAg+R/U7Iu28Dvryb5sy+zK7LCN3rbtMd7ff+lffvk5X375GV9++Tlf",
    @"vf8S/AF0sCxCa8r/D6rtrYSrVJ8EAAAAAElFTkSuQmCC"
    ] componentsJoinedByString:@""];
    NSData *d = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    UIImage *i = d ? [UIImage imageWithData:d scale:3.0] : nil;
    img = i ?: appsIconFallback();
  });
  return img;
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
