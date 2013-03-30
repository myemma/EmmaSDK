
@interface EMShareSummary : NSObject

@property (nonatomic, copy) NSString *network;
@property (nonatomic, assign) NSUInteger shareClicks, shareCount;

@end

@interface EMShare : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *network, *memberID, *shareStatus;
@property (nonatomic, assign) NSUInteger clicks;

@end
