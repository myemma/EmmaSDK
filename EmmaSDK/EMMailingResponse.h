
@interface EMMailingResponse : NSObject

@property (nonatomic, readonly) NSInteger
    sent,
    delivered,
    bounced,
    opened,
    clickedUnique,
    clicked,
    forwarded,
    optedOut,
    signedUp,
    shared,
    shareClicked,
    webviewShared,
    webviewShareClicked;
@end
