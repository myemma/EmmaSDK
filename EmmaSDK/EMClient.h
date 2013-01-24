#import <ReactiveCocoa/ReactiveCocoa.h>

@protocol EMResultsBatch <NSObject>

@property (nonatomic, strong) NSArray *results;

- (RACSignal *)getNextBatch; // return id<EMResultsBatch>

@end

@protocol EMSearch <NSObject>

@end

@protocol EMClient <NSObject>

- (RACSignal *)getGroupsWithType:(EMGroupType)groupType; // returns id<EMResultsBatch> of EMGroup
- (RACSignal *)createGroupsWithNames:(NSArray *)names;
- (RACSignal *)updateGroup:(EMGroup)group;
- (RACSignal *)deleteGroupID:(NSString *)groupID;
- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID;

- (RACSignal *)getMailingWithID:(NSString *)mailingID;
- (RACSignal *)getMailingsWithStatuses:(EMMailingStatus)statuses;

- (RACSignal *)getMembers; // returns id<EMResultsBatch> of EMMember
- (RACSignal *)getMembersInGroupID:(NSString *)groupID; // returns id<EMResultsBatch> of EMMember
- (RACSignal *)getMembersInSearchID:(NSString *)searchID; // returns id<EMResultsBatch> of EMMember
- (RACSignal *)getMemberWithID:(NSString *)memberID;
- (RACSignal *)createMember:(EMMember *)member;
- (RACSignal *)updateMember:(EMMember *)member;
- (RACSignal *)deleteMembersWithIDs:(NSArray *)memberIDs;
- (RACSignal *)addMemberID:(NSString *)memberID toGroupIDs:(NSArray *)groupIDs;
- (RACSignal *)removeMemberID:(NSString *)memberID fromGroupIDs:(NSArray *)groupIDs;
- (RACSignal *)getMessagesForMemberID:(NSString *)memberID; // returns id<EMResultsBatch> of EMMessage

- (RACSignal *)getSearches; // returns id<EMResultsBatch> of EMSearch

- (RACSignal *)getResponseForMailingID:(NSString *)mailingID; // returns EMMailingResponse
- (RACSignal *)getLinkResponseForMailingID:(NSString *)mailingID; // returns EMMailingLinkResponse
- (RACSignal *)getEventsOfType:(EMResponseEventType)type forMailingID:(NSString *)mailingID; // returns id<EMResultsBatch> of EMMailingResponseEvent
- (RACSignal *)getClicksOfLinkID:(NSString *)linkID forMailingID:(NSString *)mailingID; // returns id<EMResultsBatch> of EMMailingResponseEvent;

@end

@interface EMClient : NSObject



@end