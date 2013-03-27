
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

@property (nonatomic, assign) NSInteger recipientCount;
@property (nonatomic, copy) NSString *ID, *name, *sender, *subject;
@property (nonatomic, strong) NSDate *sendStarted;
@property (nonatomic, strong) NSURL *publicWebViewURL;
@property (nonatomic, assign) EMMailingStatus status;

- (id)initWithDictionary:(NSDictionary *)dict;

@end