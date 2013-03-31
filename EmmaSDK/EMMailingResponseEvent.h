#import "EMMember.h"

typedef enum {
    EMDeliveryStatusAll = 1,
    EMDeliveryStatusDelivered = 1 << 1,
    EMDeliveryStatusHardBounce = 1 << 2,
    EMDeliveryStatusSoftBounce = 1 << 3
} EMDeliveryStatus;
#define EMDeliveryStatusBounced (EMDeliveryStatusHardBounce | EMDeliveryStatusSoftBounce)

@interface EMMailingResponseEvent : NSObject

@property (nonatomic, assign) EMDeliveryStatus deliveryStatus;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *linkID, *forwardMailingID, *referringMemberID;
@property (nonatomic, strong) EMMember *member;

@end
