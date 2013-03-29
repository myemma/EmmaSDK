
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

// of MailingResponseStat
@property (nonatomic, readonly) NSArray *sendOff, *response;

@end

enum {
    EMResponseEventDelivery,
    EMResponseEventBounce,
    EMResponseEventOpen,
    EMResponseEventClick,
    EMResponseEventForward,
    EMResponseEventShare,
    EMResponseEventSignup,
    EMResponseEventOptout
};
typedef NSInteger EMResponseEventType;

@interface EMMailingResponseStat : NSObject

@property (nonatomic, retain) NSString *title;
@property (nonatomic, assign) NSUInteger value;
@property (nonatomic, assign) EMResponseEventType type;

+ (EMMailingResponseStat *)statWithTitle:(NSString *)title value:(NSUInteger)value type:(EMResponseEventType)type;

@end
