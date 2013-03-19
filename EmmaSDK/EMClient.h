#import <ReactiveCocoa/ReactiveCocoa.h>
#import "EMGroup.h"
#import "EMMailing.h"
#import "EMMember.h"
#import "EMMessage.h"
#import "EMSearch.h"
#import "EMMailingResponse.h"
#import "EMMailingLinkResponse.h"
#import "EMMailingResponseEvent.h"


struct EMResultRange {
    NSInteger start, end;
};
typedef struct EMResultRange EMResultRange;

@protocol EMClient <NSObject>

// groups

- (RACSignal *)getGroupCountWithType:(EMGroupType)groupType;
- (RACSignal *)getGroupsWithType:(EMGroupType)groupType inRange:(EMResultRange)range; // returns NSArray of EMGroup

- (RACSignal *)createGroupsWithNames:(NSArray *)names;
- (RACSignal *)updateGroup:(EMGroup *)group;
- (RACSignal *)deleteGroupID:(NSString *)groupID;
- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID;

- (RACSignal *)getMemberCountInGroupID:(NSString *)groupID includeDeleted:(BOOL)deleted; // returns NSNumber
- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range includeDeleted:(BOOL)deleted; // returns NSArray of EMMember

// mailings

- (RACSignal *)getMailingWithID:(NSString *)mailingID;

- (RACSignal *)getMailingCountWithStatuses:(EMMailingStatus)statuses; // returns NSNumber
- (RACSignal *)getMailingsWithStatuses:(EMMailingStatus)statuses inRange:(EMResultRange)range; // returns NSArray of EMMailing

- (RACSignal *)getMembersCountForMailingID:(NSString *)mailingID; // returns NSNumber
- (RACSignal *)getMembersForMailingID:(NSString *)mailingID inRange:(EMResultRange)range; // returns NSArray of EMMailing

- (RACSignal *)getMessageToMemberID:(NSString *)memberID forMailingID:(NSString *)mailingID; // returns EMMessageContent

- (RACSignal *)getGroupCountForMailingID:(NSString *)mailingID; // returns NSNumber
- (RACSignal *)getGroupsForMailingID:(NSString *)mailingID inRange:(EMResultRange)range; // returns NSArray of EMGroup

- (RACSignal *)getSearchCountForMailingID:(NSString *)mailingID; // returns NSNumber
- (RACSignal *)getSearchesForMailingID:(NSString *)mailingID inRange:(EMResultRange)range; // returns NSArray of EMSearch

- (RACSignal *)updateMailingID:(NSString *)mailingID withStatus:(EMMailingStatus)status;
- (RACSignal *)archiveMailingID:(NSString *)mailingID;
- (RACSignal *)cancelMailingID:(NSString *)mailingID;
- (RACSignal *)forwardMailingID:(NSString *)mailingID fromMemberID:(NSString *)memberID toRecipients:(NSArray *)recipients withNote:(NSString *)note; // returns NSNumber (new mailing ID)
- (RACSignal *)getHeadsupAddressesForMailingID:(NSString *)mailingID; // returns NSArray of NSString
- (RACSignal *)validateMailingID:(NSString *)mailingID; // returns @YES if mailing is valid, otherwise result should contain info about errors
- (RACSignal *)declareWinnerID:(NSString *)winner forMailingID:(NSString *)mailingID;

// members

- (RACSignal *)getMemberCount; // returns NSNumber
- (RACSignal *)getMembersInRange:(EMResultRange)range; // returns NSArray of EMMember

- (RACSignal *)getMemberWithID:(NSString *)memberID;
- (RACSignal *)getMemberWithEmail:(NSString *)email;
- (RACSignal *)getOptoutInfoForMemberID:(NSString *)memberID; // XXX response format undefined
- (RACSignal *)optoutMemberWithEmail:(NSString *)email;
- (RACSignal *)createMembers:(NSArray *)members withSourceName:(NSString *)sourceName addOnly:(BOOL)addOnly groupIDs:(NSArray *)groupIDs;
- (RACSignal *)createMember:(EMMember *)member;
- (RACSignal *)deleteMembersWithIDs:(NSArray *)memberIDs;
- (RACSignal *)updateMemberIDs:(NSArray *)memberIDs withStatus:(EMMemberStatus)status;
- (RACSignal *)updateMember:(EMMember *)member;
// - (RACSignal *)deleteMemberWithID:(NSString *)memberID // redundant, skip
- (RACSignal *)getGroupsForMemberID:(NSString *)memberID;
 - (RACSignal *)addMemberID:(NSString *)memberID toGroupIDs:(NSArray *)groupIDs;
//- (RACSignal *)removeMemberID:(NSString *)memberID fromGroupIDs:(NSArray *)groupIDs; // redundant, skip
- (RACSignal *)deleteMembersWithStatus:(EMMemberStatus)status;
- (RACSignal *)removeMemberFromAllGroups:(NSString *)member;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupIDs:(NSArray *)groupIDs;
- (RACSignal *)getMailingHistoryForMemberID:(NSString *)memberID;
- (RACSignal *)getMembersForImportID:(NSString *)importID;
- (RACSignal *)getImportID:(NSString *)importID;
- (RACSignal *)getImports;
//- (RACSignal *)deleteImport;
- (RACSignal *)copyMembersWithStatuses:(EMMemberStatus)status toGroup:(NSString *)groupIDs;
- (RACSignal *)updateMembersWithStatus:(EMMemberStatus)fromStatus toStatus:(EMMemberStatus)toStatus limitByGroupID:(NSString *)groupID;

// searches

- (RACSignal *)getSearchCount; // returns NSArray of EMSearch
- (RACSignal *)getSearchesInRange:(EMResultRange)range; // returns NSArray of EMSearch
- (RACSignal *)getSearchID:(NSString *)searchID;
- (RACSignal *)createSearch:(EMSearch *)search;
- (RACSignal *)updateSearch:(EMSearch *)search;
- (RACSignal *)deleteSearchID:(NSString *)searchID;
- (RACSignal *)getMemberCountInSearchID:(NSString *)searchID; // returns NSNumber
- (RACSignal *)getMembersInSearchID:(NSString *)searchID inRange:(EMResultRange)range; // returns NSArray of EMMember

- (RACSignal *)getMessageCountForMemberID:(NSString *)memberID; // returns NSNumber
- (RACSignal *)getMessagesForMemberID:(NSString *)memberID inRange:(EMResultRange)range; // returns NSArray of EMMessage


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