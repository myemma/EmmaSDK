#import "EMMailingResponseEvent.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+DateParsing.h"

EMDeliveryStatus EMDeliveryStatusFromString(NSString *statusString) {
    return [@{
             @"delivered":@(EMDeliveryStatusDelivered),
             @"hard":@(EMDeliveryStatusHardBounce),
             @"soft":@(EMDeliveryStatusSoftBounce)}[statusString] intValue];
}

NSString *EMDeliveryStatusToString(EMDeliveryStatus status) {
    if (status == EMDeliveryStatusAll)
        return @"all";
    
    NSArray *types = @[];
    
    if ((status & EMDeliveryStatusDelivered))
        types = [types arrayByAddingObject:@"delivered"];
    
    if ((status & EMDeliveryStatusHardBounce))
        types = [types arrayByAddingObject:@"hard"];
    
    if ((status & EMDeliveryStatusSoftBounce))
        types = [types arrayByAddingObject:@"soft"];
    
    return [types componentsJoinedByString:@","];
}


@implementation EMMailingResponseEvent

- (id)initWithDictionary:(NSDictionary *)dict accountFields:(NSArray *)accountFields {
    if ((self = [super init])) {
        _timestamp = [[dict[@"timestamp"] stringOrNil] parseISO8601Timestamp];
        _linkID = [[dict[@"link_id"] numberOrNil] stringValue];
        _deliveryStatus = EMDeliveryStatusFromString(dict[@"delivery_type"]);
        _forwardMailingID = [[dict[@"forward_mailing_id"] numberOrNil] stringValue];
        _member = [[EMMember alloc] initWithDictionary:dict accountFields:accountFields];
    }
    return self;
}

@end
