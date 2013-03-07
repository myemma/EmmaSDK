#import "NSObject+ObjectOrNil.h"

@implementation NSObject (ObjectOrNil)

- (id)selfOrNilIfNotKindOfClass:(Class)class {
    if (![self isKindOfClass:class]) 
        return nil;
    return self;
}

- (NSString *)stringOrNil {
    return [self selfOrNilIfNotKindOfClass:[NSString class]];
}

- (NSNumber *)numberOrNil {
    return [self selfOrNilIfNotKindOfClass:[NSNumber class]];
}

- (NSArray *)arrayOrNil {
    return [self selfOrNilIfNotKindOfClass:[NSArray class]];
}

- (NSDictionary *)dictionaryOrNil {
    return [self selfOrNilIfNotKindOfClass:[NSDictionary class]];
}


@end