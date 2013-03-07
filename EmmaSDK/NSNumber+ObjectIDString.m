#import "NSNumber+ObjectIDString.h"

@implementation NSNumber (ObjectIDString)

+ (NSNumberFormatter *)objectIDStringFormatter {
    static NSNumberFormatter *formatter;
    
    if (!formatter)
        formatter = [[NSNumberFormatter alloc] init];
    
    return formatter;
}

+ (NSNumber *)numberWithObjectIDString:(NSString *)string {
    return [[NSNumber objectIDStringFormatter] numberFromString:string];
}

- (NSString *)objectIDStringValue {
    return [[NSNumber objectIDStringFormatter] stringFromNumber:self];
}

@end