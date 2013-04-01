
@interface NSString (DateParsing)

- (NSDate *)em_parseDate;
- (NSDate *)em_parseTimestamp;

@end

@interface NSDate (DateParsing)

- (NSString *)em_dateString;
- (NSString *)em_timestampString;

@end
