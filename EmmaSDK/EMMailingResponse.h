
@interface EMMailingResponse : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger
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
