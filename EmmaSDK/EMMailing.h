
enum {
    EMMailingStatusAll = 0,
    EMMailingStatusPending = 1 << 0,
    EMMailingStatusPaused = 1 << 1,
    EMMailingStatusSending = 1 << 2,
    EMMailingStatusCanceled = 1 << 3,
    EMMailingStatusComplete = 1 << 4,
    EMMailingStatusFailed = 1 << 5
};
typedef NSUInteger EMMailingStatus;

@interface EMMailing : NSObject

@property (nonatomic, readonly) NSInteger recipientCount;
@property (nonatomic, readonly) NSString *ID, *name, *sender, *subject;
@property (nonatomic, readonly) NSDate *sendStarted;
@property (nonatomic, readonly) NSURL *publicWebViewURL;
@property (nonatomic, readonly) EMMailingStatus status;

- (id)initWithDictionary:(NSDictionary *)dict;

@end