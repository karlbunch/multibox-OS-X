//
//  Constants.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#ifndef Constants_h
#define Constants_h

// Default Application Name we will target
#define MULTIBOXOSX_DEFAULT_TARGET_APPLICATION @"World of Warcraft"

// Set to 1 for debugging/logging of key events
#define MULTIBOXOSX_LOGKEYS 0

static NSString * const kMBO_Preference_TargetApplication = @"targetApplication";
static NSString * const kMBO_Preference_TargetAppPath = @"targetAppPath";
static NSString * const kMBO_Preference_FavoriteLayout = @"favoriteLayout";
static NSString * const kMBO_InstanceNumber = @"instanceNumber";
static NSString * const kMBO_Shortcut_Pause = @"ShortcutPause";
static NSString * const kMBO_Shortcut_IgnoreList = @"ShortcutIgnoreList";

#endif /* Constants_h */
