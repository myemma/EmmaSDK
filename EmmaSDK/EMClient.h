#import <ReactiveCocoa/ReactiveCocoa.h>
#import "EmmaSDK.h"

struct EMResultRange {
    NSInteger start, end;
};
typedef struct EMResultRange EMResultRange;

EMResultRange EMResultRangeMake(NSInteger start, NSInteger end);
extern EMResultRange EMResultRangeAll;

@protocol EMClient <NSObject>

// fields

- (RACSignal *)getFieldCount;
- (RACSignal *)getFieldsInRange:(EMResultRange)range;
- (RACSignal *)getFieldID:(NSString *)fieldID;
- (RACSignal *)createField:(EMField *)field;
- (RACSignal *)deleteFieldID:(NSString *)fieldID;
- (RACSignal *)clearFieldID:(NSString *)fieldID;
- (RACSignal *)updateField:(EMField *)field;

// groups

- (RACSignal *)getGroupCountWithType:(EMGroupType)groupType;
- (RACSignal *)getGroupsWithType:(EMGroupType)groupType inRange:(EMResultRange)range; // returns NSArray of EMGroup

- (RACSignal *)createGroupsWithNames:(NSArray *)names;
- (RACSignal *)getGroupID:(NSString *)groupID;
- (RACSignal *)updateGroup:(EMGroup *)group;
- (RACSignal *)deleteGroupID:(NSString *)groupID;

- (RACSignal *)getMemberCountInGroupID:(NSString *)groupID includeDeleted:(BOOL)deleted; // returns NSNumber
- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range includeDeleted:(BOOL)deleted; // returns NSArray of EMMember

- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID;

- (RACSignal *)removeMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)groupID;
- (RACSignal *)copyMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)fromGroupID toGroupID:(NSString *)toGroupID;

// mailings

- (RACSignal *)getMailingCountWithStatuses:(EMMailingStatus)statuses; // returns NSNumber
- (RACSignal *)getMailingsWithStatuses:(EMMailingStatus)statuses inRange:(EMResultRange)range; // returns NSArray of EMMailing

- (RACSignal *)getMailingWithID:(NSString *)mailingID;

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
- (RACSignal *)resendMailingID:(NSString *)mailingID headsUpAddresses:(NSArray *)headsUpAddresses recipientAddresses:(NSArray *)recipientAddresses recipientGroupIDs:(NSArray *)recipientGroupIDs recipientSearchIDs:(NSArray *)recipientSearchIDs;
- (RACSignal *)getHeadsupAddressesForMailingID:(NSString *)mailingID; // returns NSArray of NSString
- (RACSignal *)validateMailingWithBody:(NSString *)htmlBody plaintext:(NSString *)plaintext andSubject:(NSString *)subject; // returns @YES if mailing is valid, otherwise result should contain info about errors
- (RACSignal *)declareWinnerID:(NSString *)winner forMailingID:(NSString *)mailingID;

// members

- (RACSignal *)getMemberCountIncludeDeleted:(BOOL)deleted; // returns NSNumber
- (RACSignal *)getMembersInRange:(EMResultRange)range includeDeleted:(BOOL)deleted; // returns NSArray of EMMember
- (RACSignal *)getMemberWithID:(NSString *)memberID;
- (RACSignal *)getMemberWithEmail:(NSString *)email;
- (RACSignal *)getOptoutInfoForMemberID:(NSString *)memberID; // XXX response format undefined
- (RACSignal *)optoutMemberWithEmail:(NSString *)email;

// Members should be an array of EMMember objects. All fields except email are ignored. Returns import ID (NSString)
- (RACSignal *)createMembers:(NSArray *)members withSourceName:(NSString *)sourceName addOnly:(BOOL)addOnly groupIDs:(NSArray *)groupIDs;

- (RACSignal *)createMember:(EMMember *)member; // returns member id as NSString
- (RACSignal *)deleteMembersWithIDs:(NSArray *)memberIDs;
- (RACSignal *)updateMemberIDs:(NSArray *)memberIDs withStatus:(EMMemberStatus)status;
- (RACSignal *)updateMember:(EMMember *)member;
// - (RACSignal *)deleteMemberWithID:(NSString *)memberID // redundant, skip
- (RACSignal *)getGroupsForMemberID:(NSString *)memberID;
 - (RACSignal *)addMemberID:(NSString *)memberID toGroupIDs:(NSArray *)groupIDs;
//- (RACSignal *)removeMemberID:(NSString *)memberID fromGroupIDs:(NSArray *)groupIDs; // redundant, skip
- (RACSignal *)deleteMembersWithStatus:(EMMemberStatus)status;
- (RACSignal *)removeMemberFromAllGroups:(NSString *)memberID;
- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupIDs:(NSArray *)groupIDs;
- (RACSignal *)getMailingHistoryForMemberID:(NSString *)memberID;
- (RACSignal *)getMembersForImportID:(NSString *)importID;
- (RACSignal *)getImportID:(NSString *)importID;
- (RACSignal *)getImports;
//- (RACSignal *)deleteImport;
- (RACSignal *)copyMembersWithStatuses:(EMMemberStatus)status toGroup:(NSString *)groupID;
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

// triggers
- (RACSignal *)getTriggerCount;
- (RACSignal *)getTriggersInRange:(EMResultRange)range; // returns NSArray of EMTrigger
- (RACSignal *)createTrigger:(EMTrigger *)trigger;
- (RACSignal *)getTriggerWithID:(NSString *)triggerID;
- (RACSignal *)updateTrigger:(EMTrigger *)trigger;
- (RACSignal *)deleteTriggerWithID:(NSString *)triggerID;
- (RACSignal *)getMailingCountForTriggerID:(NSString *)triggerID;
- (RACSignal *)getMailingsForTriggerID:(NSString *)triggerID inRange:(EMResultRange)range; // returns NSArray of EMMailing

// webhooks
- (RACSignal *)getWebhookCount;
- (RACSignal *)getWebhooksInRange:(EMResultRange)range; // returns NSArray of EMWebhook
- (RACSignal *)getWebhookEvents; // returns NSArray of EMWebhookEvent
- (RACSignal *)createWebhook:(EMWebhook *)webhook withPublicKey:(NSString *)publicKey;
- (RACSignal *)updateWebhook:(EMWebhook *)webhook;
- (RACSignal *)deleteWebhookWithID:(NSString *)webhookID;
- (RACSignal *)deleteAllWebhooks;

// response

// calls getResponseSummaryInRange:includeArchived: with nil range string and NO includeArchived
- (RACSignal *)getResponseSummary; // returns NSArray of EMResponseSummary.
- (RACSignal *)getResponseSummaryInRange:(NSString *)rangeString includeArchived:(BOOL)includeArchived; // returns NSArray of EMResponseSummary

- (RACSignal *)getResponseForMailingID:(NSString *)mailingID; // returns EMMailingResponse

- (RACSignal *)getSendsForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent
- (RACSignal *)getInProgressForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent (timestamps are nil)
- (RACSignal *)getDeliveriesForMailingID:(NSString *)mailingID withDeliveryStatus:(EMDeliveryStatus)status; // returns NSArray of EMMailingResponseEvent (populates deliveryStatus)
- (RACSignal *)getOpensForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent

- (RACSignal *)getLinksForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingLinkResponse

- (RACSignal *)getClicksForMailingID:(NSString *)mailingID memberID:(NSString *)memberID linkID:(NSString *)linkID; // returns NSArray of EMMailingResponseEvent (populates linkID)
- (RACSignal *)getForwardsForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent (populates forwardMailingID)
- (RACSignal *)getOptoutsForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent
- (RACSignal *)getSignupsForMailingID:(NSString *)mailingID; // returns NSArray of EMMailingResponseEvent (populates referringMemberID)

- (RACSignal *)getSharesForMailingID:(NSString *)mailingID; // returns NSArray of EMShare (populates memberID, network, clicks)
- (RACSignal *)getCustomerSharesForMailingID:(NSString *)mailingID; // returns NSArray of EMShare (populates timestamp, network)
- (RACSignal *)getCustomerShareClicksForMailingID:(NSString *)mailingID; // returns NSArray of EMShare (populates timestamp, network, clicks)
- (RACSignal *)getCustomerShareID:(NSString *)shareID; // returns EMShare (timestamp, network, share_status)
- (RACSignal *)getSharesOverviewForMailingID:(NSString *)mailingID; // returns EMShareSummary

@end

@interface EMClient : NSObject <EMClient>

// required information for requests
@property (nonatomic, copy) NSString *accountID;

// basic auth w/ key pair
@property (nonatomic, copy) NSString *publicKey, *privateKey;

// oauth
@property (nonatomic, copy) NSString *oauthToken;

+ (EMClient *)shared;

@end