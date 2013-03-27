
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

@property (nonatomic, copy) NSString *ID, *email;
@property (nonatomic, strong) NSDate *memberSince;
@property (nonatomic, assign) EMMemberStatus status;
@property (nonatomic, copy) NSArray *memberFields;
@property (nonatomic, copy) NSString *fullName;

- (id)initWithDictionary:(NSDictionary *)dict;

@end
