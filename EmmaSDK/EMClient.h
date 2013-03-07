#import <ReactiveCocoa/ReactiveCocoa.h>
#import "EMGroup.h"
#import "EMMailing.h"
#import "EMMember.h"
#import "EMMailingResponse.h"
#import "EMMailingLinkResponse.h"
#import "EMMailingResponseEvent.h"

struct EMResultRange {
    NSInteger start, end;
};
typedef struct EMResultRange EMResultRange;

@protocol EMClient <NSObject>

- (RACSignal *)getGroupCountWithType:(EMGroupType)groupType;
- (RACSignal *)getGroupsWithType:(EMGroupType)groupType inRange:(EMResultRange)range; // returns NSArray of EMGroup

- (RACSignal *)createGroupsWithNames:(NSArray *)names;
- (RACSignal *)updateGroup:(EMGroup *)group;
- (RACSignal *)deleteGroupID:(NSString *)groupID;
- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID;

- (RACSignal *)getMailingWithID:(NSString *)mailingID;

- (RACSignal *)getMailingCountWithStatuses:(EMMailingStatus)statuses; // returns NSNumber
- (RACSignal *)getMailingsWithStatuses:(EMMailingStatus)statuses inRange:(EMResultRange)range; // returns NSArray of EMMailing

- (RACSignal *)getMemberCount; // returns NSNumber
- (RACSignal *)getMembersInRange:(EMResultRange)range; // returns NSArray of EMMember

- (RACSignal *)getMemberCountInGroupID:(NSString *)groupID; // returns NSNumber
- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range; // returns NSArray of EMMember

- (RACSignal *)getMemberCountInSearchID:(NSString *)searchID; // returns NSNumber
- (RACSignal *)getMembersInSearchID:(NSString *)searchID inRange:(EMResultRange)range; // returns NSArray of EMMember

- (RACSignal *)getMemberWithID:(NSString *)memberID;
- (RACSignal *)createMember:(EMMember *)member;
- (RACSignal *)updateMember:(EMMember *)member;
- (RACSignal *)deleteMembersWithIDs:(NSArray *)memberIDs;
- (RACSignal *)addMemberID:(NSString *)memberID toGroupIDs:(NSArray *)groupIDs;
- (RACSignal *)removeMemberID:(NSString *)memberID fromGroupIDs:(NSArray *)groupIDs;

- (RACSignal *)getMessageCountForMemberID:(NSString *)memberID; // returns NSNumber
- (RACSignal *)getMessagesForMemberID:(NSString *)memberID inRange:(EMResultRange)range; // returns NSArray of EMMessage

- (RACSignal *)getSearchesInRange:(EMResultRange)range; // returns NSArray of EMSearch

- (RACSignal *)getResponseForMailingID:(NSString *)mailingID; // returns EMMailingResponse
- (RACSignal *)getLinkResponseForMailingID:(NSString *)mailingID; // returns EMMailingLinkResponse

- (RACSignal *)getEventCountOfType:(EMResponseEventType)type forMailingID:(NSString *)mailingID; // returns NSNumber
- (RACSignal *)getEventsOfType:(EMResponseEventType)type forMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent

- (RACSignal *)getClickCountOfLinkID:(NSString *)linkID forMailingID:(NSString *)mailingID; // returns NSNumber
- (RACSignal *)getClicksOfLinkID:(NSString *)linkID forMailingID:(NSString *)mailingID inRange:(EMResultRange)range; // returns NSArray of EMMailingResponseEvent;

@end

@interface EMClient : NSObject <EMClient>

+ (EMClient *)shared;

@end