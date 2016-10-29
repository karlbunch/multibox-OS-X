//
//  MainController.h
//  MultiBoxOSX
//
//  Created by dirk on 4/25/09.
//  Copyright 2009 Dirk Zimmermann. All rights reserved.
//  Copyright 2016 Karl Bunch.
//
//
// This file is part of Multibox-OS-X.
//
// Multibox-OS-X is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// Multibox-OS-X is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Multibox-OS-X.  If not, see <http://www.gnu.org/licenses/>.

#import <Cocoa/Cocoa.h>

// Default Application Name we will target
#define MULTIBOXOSX_DEFAULT_TARGET_APPLICATION @"World of Warcraft"

// Set to 1 for debugging/logging of key events
#define MULTIBOXOSX_LOGKEYS 0

static NSString * const kMBO_Preference_TargetApplication = @"targetApplication";
static NSString * const kMBO_Preference_TargetAppPath = @"targetAppPath";
static NSString * const kMBO_Preference_KeyPause = @"keyPause";
static NSString * const kMBO_Preference_IgnoreKeys = @"ignoreKeys";

#define kMBO_MaxKeyCode 256

enum keyActionFunction {
    kMBO_Forward = 1,
    kMBO_Pause   = 2,
    kMBO_Ignore  = 3,
};

typedef struct {
    uint64_t flagsMask;
    enum keyActionFunction action;
} keyActionMap_t;

@interface MainController : NSObject <NSApplicationDelegate> {
	IBOutlet NSWindow *mainWindow;
    IBOutlet NSButton *toggleButton;
    IBOutlet NSLevelIndicator *targetIndicator;
    IBOutlet NSTextField *targetAppVersionTextField;

    keyActionMap_t keyActionMap[kMBO_MaxKeyCode];

	CFMachPortRef machPortKeyboard;
	CFRunLoopSourceRef machPortRunLoopSourceRefKeyboard;

    Boolean isTrusted;
	BOOL ignoreEvents;
    BOOL autoExit;
    int numPendingLaunch;
    NSDictionary *targetApps;
}

@property (atomic, strong) NSString *targetApplication;
@property (atomic, strong) NSString *targetAppPath;
@property (atomic, strong) NSString *keyPause;
@property (atomic, strong) NSArray *ignoreKeys;

#if DEBUG
@property (atomic, strong) NSTextField *debugLabel;
#endif // DEBUG

- (IBAction)enableButtonClicked:(id)sender;
- (IBAction)levelIndicatorClicked:(id)sender;
- (IBAction)browseButtonClicked:(id)sender;

@end
