
enum {
    EMMessageDeliveryTypeDelivered,
    EMMessageDeliveryTypeHardBounce,
    EMMessageDeliveryTypeSoftBounce
};
typedef NSUInteger EMMessageDeliveryType;

@interface EMMessage : NSObject

@property (nonatomic, copy) NSString *mailingID, *subject, *name, *plaintext, *htmlBody;
@property (nonatomic, strong) NSDate *delivered, *clicked, *opened, *shared, *forwarded;
@property (nonatomic, assign) EMMessageDeliveryType type;

@end
