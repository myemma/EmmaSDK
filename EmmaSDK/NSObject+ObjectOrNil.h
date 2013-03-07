
// this is good for doing some basic input validation on data
// returned from the server. for example, we don't want to assume that
// the JSON parser got a number when in fact it got null, and then end 
// up sending the intValue message to NSNull and crashing the whole program.
@interface NSObject (ObjectOrNil)

- (NSString *)stringOrNil;
- (NSNumber *)numberOrNil;
- (NSArray *)arrayOrNil;
- (NSDictionary *)dictionaryOrNil;

@end
