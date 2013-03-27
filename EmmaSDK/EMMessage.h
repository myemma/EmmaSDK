
enum {
    MessageDeliveryTypeDelivered,
    MessageDeliveryTypeHardBounce,
    MessageDeliveryTypeSoftBounce
};
typedef NSUInteger MessageDeliveryType;

@interface EMMessage : NSObject

@property (nonatomic, copy) NSString *mailingID, *subject, *name, *plaintext, *htmlBody;
@property (nonatomic, strong) NSDate *delivered, *clicked, *opened, *shared, *forwarded;
@property (nonatomic, assign) MessageDeliveryType type;

- (id)initWithDictionary:(NSDictionary *)dict;

@end
