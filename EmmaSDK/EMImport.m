#import "EMImport.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+EMDateParsing.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMImport

- (id)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [super init])) {
        _ID = [[dict[@"import_id"] numberOrNil] objectIDStringValue];
        _importStatus = [dict[@"status"] stringOrNil];
        _importStyle = [dict[@"status"] stringOrNil];
        _errorMessage = [dict[@"error_message"] stringOrNil];
        _numberOfMembersUpdated = [[dict[@"num_members_updated"] numberOrNil] intValue];
        _numberOfMembersAdded = [[dict[@"num_members_added"] numberOrNil] intValue];
        _numberSkipped = [[dict[@"num_skipped"] numberOrNil] intValue];
        _numberOfDuplicates = [[dict[@"num_duplicates"] numberOrNil] intValue];
        _importStarted = [[dict[@"import_started"] stringOrNil] em_parseTimestamp];
        _importFinished = [[dict[@"import_finished"] stringOrNil] em_parseTimestamp];
        _fieldsUpdated = [dict[@"fields_updated"] arrayOrNil];
        _groupsUpdated = [dict[@"groups_updated"] arrayOrNil];
        _sourceFilename = [dict[@"source_filename"] stringOrNil];
    }
    return self;
}

@end