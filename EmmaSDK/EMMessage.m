//
//  EMMessage.m
//  EmmaSDK
//
//  Created by Benjamin van der Veen on 1/23/13.
//  Copyright (c) 2013 Emma, Inc. All rights reserved.
//

#import "EMMessage.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "NSString+DateParsing.h"

@implementation EMMessage

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _mailingID = [[[dict objectForKey:@"mailing_id"] numberOrNil] objectIDStringValue];
        _subject = [dict objectForKey:@"subject"];
        _name = [[dict objectForKey:@"name"] copy];
        _clicked = [[[dict objectForKey:@"clicked"] stringOrNil] parseISO8601Timestamp];
        _delivered = [[[dict objectForKey:@"delivery_ts"] stringOrNil] parseISO8601Timestamp];
        _opened = [[[dict objectForKey:@"opened"] stringOrNil] parseISO8601Timestamp];
        _shared = [[[dict objectForKey:@"shared"] stringOrNil] parseISO8601Timestamp];
        _forwarded = [[[dict objectForKey:@"forwarded"] stringOrNil] parseISO8601Timestamp];
        
        NSString *deliveryType = [dict objectForKey:@"delivery_type"];
        
        if ([deliveryType isEqual:@"d"])
            _type = MessageDeliveryTypeDelivered;
        else if ([deliveryType isEqual:@"b"])
            _type = MessageDeliveryTypeHardBounce;
        else if ([deliveryType isEqual:@"s"])
            _type = MessageDeliveryTypeSoftBounce;
        else
            NSLog(@"-[MemberMailing initWithDictionary]: unknown delivery type '%@'", deliveryType);
    }
    return self;
}


@end
