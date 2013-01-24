
enum {
    EMMemberStatusAll,
    EMMemberStatusActive,
    EMMemberStatusError,
    EMMemberStatusOptout,
    EMMemberStatusForwarded
    };
typedef NSInteger EMMemberStatus;
    
NSString *EMMemberStatusGetName(EMMemberStatus status);
NSString *EMMemberStatusGetShortName(EMMemberStatus status);

@interface NSValue (EMMemberStatusValue)

- (EMMemberStatus)memberStatusValue;
+ (NSValue *)valueWithMemberStatus:(EMMemberStatus)status;

@end

@interface EMMember : NSObject

@property (nonatomic, readonly) NSString *ID, *email;
@property (nonatomic, readonly) NSDate *memberSince;
@property (nonatomic, readonly) EMMemberStatus status;
@property (nonatomic, readonly) NSArray *memberFields;
@property (nonatomic, readonly) NSString *fullName;

@end
