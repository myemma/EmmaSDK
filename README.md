# Emma SDK

An Objective-C client library for the [Emma HTTP API](http://api.myemma.com/). Builds a static library for iOSuse as well as a Cocoa framework for OS X.

# Cloning

EmmaSDK uses submodules to manage its dependency tree.

- Clone the repository:

    `git clone git@github.com:myemma/emma-sdk.git`
   
- Clone the dependency tree:

    `git submodule update --init --recursive`

# Integrating the SDK

We recommend adding EmmaSDK as a submodule of your project. Ensure that you have properly cloned EmmaSDK and recursively cloned its dependencies as described above. 

- Drag the `EmmaSDK.xcodeproj` into the Xcode project explorer pane of your project. 
- Select your project from the explorer pane, then select your application target. Select the **Build Phases** tab.
- Add the `EmmaSDKiOS` static library target (for iOS projects) or the `EmmaSDK` framework target (for OS X projects) under **Target Dependencies**.
- Add the output of the target dependency (`libEmmaSDK.a` or `EmmaSDK.framework`) in the **Link Binary With Libraries** area.
- Use `#import "EmmaSDK.h"` anywhere you wish to use the Emma SDK.

# Using the SDK

Initialize the SDK with your account info:

    #import "EmmaSDK.h"
   
    …
    
    EMClient.shared.publicKey = @"Your Public API Key";
    EMClient.shared.privateKey = @"Your Public API Key";
    EMClient.shared.accountID = @"Your Account ID";
    
    …


Use the client to make API calls. The API client performs asynchronous operations using [ReactiveCocoa](http://github.com/ReactiveCocoa/ReactiveCocoa).

    [[EMClient.shared 
        getMembersInRange:(EMResultRange){ .start = 0, .end = 50 }] 
        subscribeNext:^ void (NSArray *members) {
        NSLog(@"Got members: %@", members);
    }];