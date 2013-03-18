
enum {
    MessageDeliveryTypeDelivered,
    MessageDeliveryTypeHardBounce,
    MessageDeliveryTypeSoftBounce
};
typedef NSUInteger MessageDeliveryType;

@interface EMMessage : NSObject

@property (nonatomic, readonly) NSString *mailingID, *subject, *name;
@property (nonatomic, readonly) NSDate *delivered, *clicked, *opened, *shared, *forwarded;
@property (nonatomic, readonly) MessageDeliveryType type;

- (id)initWithDictionary:(NSDictionary *)dict;

@end
