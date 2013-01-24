#import "EMMember.h"

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

@interface EMMailingResponseEvent : NSObject

@property (nonatomic, readonly) NSDate *timestamp;
@property (nonatomic, readonly) EMMember *member;

@end
