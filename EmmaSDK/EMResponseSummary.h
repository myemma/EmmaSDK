
@interface EMResponseSummary : NSObject

@property (nonatomic, assign) NSUInteger
    month,
    year,
    mailings,
    sent,
    delivered,
    bounced,
    opened,
    clickedUnique,
    clicked,
    forwarded,
    shared,
    shareClicked,
    webViewShared,
    webViewShareClicked,
    optedOut,
    signedUp;

@end
