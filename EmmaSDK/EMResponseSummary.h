
@interface EMResponseSummary : NSObject

@property (nonatomic, assign) NSUInteger
    month,
    year,
    mailings,
    sent,
    delivered,
    bounced,
    opened,
    clicked_unique,
    clicked,
    forwarded,
    shared,
    shareClicked,
    webViewShared,
    webViewClicked,
    optedOut,
    signedUp;

@end
