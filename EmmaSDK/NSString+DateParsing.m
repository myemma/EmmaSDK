#import "NSString+DateParsing.h"
#import "ISO8601DateFormatter.h"

@implementation NSString (DateParsing)

- (NSDate *)em_parseDate {    
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = NO;
    NSDate *result = [formatter dateFromString:[self stringByReplacingOccurrencesOfString:@"@D:" withString:@""]];
    return result;
}

- (NSDate *)em_parseTimestamp {    
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    NSDate *result = [formatter dateFromString:[self stringByReplacingOccurrencesOfString:@"@D:" withString:@""]];
    return result;
}

@end

@implementation NSDate (DateParsing)

- (NSString *)em_dateString {
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = NO;
    NSString *result = [formatter stringFromDate:self];
    //return result;
    return [NSString stringWithFormat:@"@D:%@", result];
}

- (NSString *)em_timestampString {
    ISO8601DateFormatter *formatter = [ISO8601DateFormatter new];
    formatter.includeTime = YES;
    NSString *result = [formatter stringFromDate:self];
    return result;
    return [NSString stringWithFormat:@"@D:%@", result];
}


@end



