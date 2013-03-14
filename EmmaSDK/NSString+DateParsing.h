
@interface NSString (DateParsing)

- (NSDate *)parseISO8601Date;
- (NSDate *)parseISO8601Timestamp;

@end

@interface NSDate (DateParsing)

- (NSString *)apiDateStringValue;
- (NSString *)apiTimestampStringValue;
- (NSString *)shortDateString;
- (NSString *)shortDateTimeString;

@end
