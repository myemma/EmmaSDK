#import "EMWebhook.h"
#import "NSNumber+ObjectIDString.h"
#import "NSObject+ObjectOrNil.h"

@implementation EMWebhookInfo

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _eventName = [dictionary[@"event_name"] stringOrNil];
        _webhookEventID = [[dictionary[@"webhook_event_id"] numberOrNil] objectIDStringValue];
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

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"url": _url.absoluteString,
        @"method": _method,
        @"event": _event
    };
}

@end
