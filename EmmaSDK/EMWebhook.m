#import "EMWebhook.h"
#import "NSNumber+ObjectIDString.h"
#import "NSObject+ObjectOrNil.h"

@implementation EMWebhookInfo

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _eventName = [dictionary[@"eventName"] stringOrNil];
        _webhookEventID = [dictionary[@"webhook_event_id"] stringOrNil];
        _webhookDescription = [dictionary[@"description"] stringOrNil];
    }
    return self;
}

@end

@implementation EMWebhook

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _webhookID = [[dictionary[@"webhook_id"] numberOrNil] objectIDStringValue];
        _url = [NSURL URLWithString:[dictionary[@"url"] stringOrNil]];
        _method = [dictionary[@"method"] stringOrNil];
        _event = [dictionary[@"event"] stringOrNil];
    }
    return self;
}

@end
