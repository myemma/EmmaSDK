#import "EMMember.h"


typedef enum {
    EMDeliveryStatusDelivered = 1,
    EMDeliveryStatusHardBounce = 1 << 1,
    EMDeliveryStatusSoftBounce = 1 << 2
} EMDeliveryStatus;
#define EMDeliveryStatusBounced (EMDeliveryStatusHardBounce | EMDeliveryStatusSoftBounce)
#define EMDeliveryStatusAll (EMDeliveryStatusDelivered | EMDeliveryStatusBounced)

@interface EMMailingResponseEvent : NSObject

@property (nonatomic, assign) EMDeliveryStatus deliveryStatus;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *linkID, *forwardMailingID, *referringMemberID;
@property (nonatomic, strong) EMMember *member;

@end
