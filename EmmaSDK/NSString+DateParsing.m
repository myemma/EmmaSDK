#import "NSString+DateParsing.h"
#import "ISO8601DateFormatter.h"

@implementation NSString (DateParsing)

- (NSDate *)parseISO8601Date {    
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = NO;
    NSDate *result = [formatter dateFromString:[self stringByReplacingOccurrencesOfString:@"@D:" withString:@""]];
    return result;
}

- (NSDate *)parseISO8601Timestamp {    
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    NSDate *result = [formatter dateFromString:[self stringByReplacingOccurrencesOfString:@"@D:" withString:@""]];
    return result;
}

@end

@implementation NSDate (DateParsing)

- (NSString *)apiDateStringValue {
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = NO;
    NSString *result = [formatter stringFromDate:self];
    //return result;
    return [NSString stringWithFormat:@"@D:%@", result];
}

- (NSString *)apiTimestampStringValue {
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = YES;
    NSString *result = [formatter stringFromDate:self];
    return result;
    return [NSString stringWithFormat:@"@D:%@", result];
}

- (NSString *)shortDateString {
    return [NSDateFormatter localizedStringFromDate:self dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
}

- (NSString *)shortDateTimeString {
    return [NSDateFormatter localizedStringFromDate:self dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
}

@end



