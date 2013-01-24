
@interface EMMailingLinkResponse : NSObject

@property (nonatomic, readonly) NSInteger clicks, uniqueClicks;
@property (nonatomic, readonly) NSString *ID, *name;
@property (nonatomic, readonly) NSURL *target;
@property (nonatomic, readonly, getter = isPlaintext) BOOL plaintext;

@end
