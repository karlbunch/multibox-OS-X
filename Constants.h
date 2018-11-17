//
//  Constants.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#ifndef Constants_h
#define Constants_h

// Set to 1 for debugging/logging of key events
#define MULTIBOXOSX_LOGKEYS 0

// Largest supported KeyCode value
#define kMBO_MaxKeyCode 256

static NSString * const kMBO_CurrentPreferencesVersion = @"3";
static NSString * const kMBO_Preference_Version = @"preferencesVersion";
static NSString * const kMBO_Preference_TargetAppPath = @"targetAppPath";
static NSString * const kMBO_Preference_FavoriteLayout = @"favoriteLayout";
static NSString * const kMBO_InstanceNumber = @"instanceNumber";
static NSString * const kMBO_Preference_KeyBindings = @"KeyBindings";

// Notifications
static NSString * const kMBO_Notification_RecordKeysButtonClicked = @"MBONoticeRecordKeysButtonClicked";

#endif /* Constants_h */
