//
//  MainController.m
//  MultiBoxOSX
//
//  Created by dirk on 4/25/09.
//  Copyright 2009 Dirk Zimmermann. All rights reserved.
//  Copyright 2016 Karl Bunch.
//
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

#include <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import "MainController.h"

typedef struct {
    uint64_t modifierFlags;
    kMBOKeybindingAction action;
} keyActionMap_t;

@interface MainController () {
    IBOutlet NSWindow * __weak mainWindow;
    IBOutlet NSButton * __weak toggleButton;
    IBOutlet NSLevelIndicator * __weak targetIndicator;
    MBOPreferencesWindowController *preferencesWindow;

    keyActionMap_t keyActionMap[kMBO_MaxKeyCode];

    CFMachPortRef machPortKeyboard;
    CFRunLoopSourceRef machPortRunLoopSourceRefKeyboard;

    BOOL isTrusted;
    BOOL ignoreEvents;
    BOOL autoExit;
    NSInteger numPendingLaunch;
    NSMutableDictionary *targetApplicationsByPID;
    NSArray *_preferencesKeys;
}

#if DEBUG
@property (nonatomic, strong) NSTextField *debugLabel;
#endif // DEBUG

@end

@implementation MainController

- (void)awakeFromNib {
    [NSApplication sharedApplication].delegate = self;
    [mainWindow setMovableByWindowBackground:YES];
    [mainWindow setLevel:NSFloatingWindowLevel];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Setup Defaults
    NSMapTable *defaultKeyBindings = [NSMapTable strongToStrongObjectsMapTable];

    for(NSNumber *keyCode in @[ @49, @50, @13, @0, @1, @2]) {
        MBOKeybinding *key = [MBOKeybinding shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:0 bindingAction:kMBOKeybindingActionIgnore];

        [defaultKeyBindings setObject:key forKey:keyCode];
    }

    [defaultKeyBindings setObject:[MBOKeybinding shortcutWithKeyCode:113 modifierFlags:0 bindingAction:kMBOKeybindingActionToggleForwarding] forKey:@(113)];

    NSDictionary *defaultPreferences =
    @{
      kMBO_Preference_Version: @"",
      kMBO_Preference_TargetAppPath: @"/Applications/World of Warcraft/World of Warcraft.app",
      kMBO_Preference_FavoriteLayout: @[ ],
      kMBO_Preference_KeyBindings: [NSKeyedArchiver archivedDataWithRootObject:defaultKeyBindings],
    };

    _preferencesKeys = [defaultPreferences allKeys];

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultPreferences];
    [[NSUserDefaults standardUserDefaults] setValue:kMBO_CurrentPreferencesVersion forKey:kMBO_Preference_Version];

    // Listen for changes to key bindings
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kMBO_Preference_KeyBindings options:NSKeyValueObservingOptionNew context:nil];

    // Listen for Application Launch/Terminations
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];

    [center addObserver:self
               selector:@selector(processAppplicationNotifications:)
                   name:NSWorkspaceDidLaunchApplicationNotification
                 object:nil
     ];

    [center addObserver:self
               selector:@selector(processAppplicationNotifications:)
                   name:NSWorkspaceDidTerminateApplicationNotification
                 object:nil
     ];

    // Initialize Application
    [self clearTargetApplicationsByPID];

    [self compileKeyActionMap];

    ignoreEvents = FALSE;

    [self scanForTargetApplications];

    isTrusted = FALSE;
    [self checkAccessibility:YES];

    if (isTrusted) {
        [self setupEventTaps];
    }

    [self updateUI];
#if DEBUG
    _debugLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(120, 0, 40, 14)];
    [_debugLabel setStringValue:@"DEBUG"];
    [_debugLabel setFont:[NSFont systemFontOfSize:9]];
    [_debugLabel setBezeled:NO];
    [_debugLabel setEditable:NO];
    [_debugLabel setSelectable:NO];
    [_debugLabel setDrawsBackground:NO];
    [[mainWindow contentView] addSubview:_debugLabel];
#endif // DEBUG
}

- (IBAction)menuActionPreferences:(id)sender {
    if (preferencesWindow != NULL) {
        preferencesWindow = NULL;
    }

    preferencesWindow = [[MBOPreferencesWindowController alloc] initWithController:self];
    [preferencesWindow showWindow:self];
}

- (IBAction)menuActionImportSettings:(id)sender {
}

- (IBAction)menuActionExportSettings:(id)sender {
    NSLog(@"export Settings");

    NSMutableDictionary *exportDict = [[NSMutableDictionary alloc] init];
    NSDictionary *defaultsDict = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] mutableCopy];

    for(NSString *key in _preferencesKeys) {
        if (![key isEqualToString:kMBO_Preference_KeyBindings]) {
            [exportDict setObject:defaultsDict[key] forKey:key];
        }
    }

    NSDictionary *currentBindings = [self keyBindingsDictionaryRepresentation];
    NSMutableArray *keys = [[NSMutableArray alloc] init];

    for (id idx in currentBindings) {
        MBOKeybinding *key = [currentBindings objectForKey:idx];
        [keys addObject:[key toDictionary]];
    }

    [exportDict setObject:keys forKey:kMBO_Preference_KeyBindings];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportDict options:NSJSONWritingPrettyPrinted error:nil];

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSLog(@"export=%@", jsonString);
}

-(void)preferencesWindowWillClose:(id)sender {
    preferencesWindow = NULL;
}

-(NSString *)targetAppPath {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_TargetAppPath];
}

-(void)setTargetAppPath:(NSString *)targetAppPath {
    [[NSUserDefaults standardUserDefaults] setValue:targetAppPath forKey:kMBO_Preference_TargetAppPath];
}

-(nullable NSString *)targetBundleIdentifier {
    NSString *targetAppPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:self.targetAppPath];
    
    if (targetAppPath == nil)
        return nil;
    
    return [[NSBundle bundleWithPath:targetAppPath] bundleIdentifier];
}

-(NSArray *)favoriteLayout {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_FavoriteLayout];
}

-(void)setFavoriteLayout:(NSArray *)favoriteLayout {
    [[NSUserDefaults standardUserDefaults] setValue:favoriteLayout forKey:kMBO_Preference_FavoriteLayout];
}

-(void)getFavoriteLayout:(NSRect *)layout withInstanceNumber:(long)instanceNumber {
    if (instanceNumber < [self.favoriteLayout count]) {
        NSDictionary *favoriteEntry = self.favoriteLayout[instanceNumber];
        
        layout->origin = NSPointFromString(favoriteEntry[(NSString *)kAXPositionAttribute]);
        layout->size = NSSizeFromString(favoriteEntry[(NSString *)kAXSizeAttribute]);
        return;
    }

    NSLog(@"getFavoriteLayout:0x%lx withInstanceNumber:%ld - Calculating New Layout", (unsigned long)layout, instanceNumber);

    NSArray *screens = [NSScreen screens];
    NSRect newLayout = [[NSScreen mainScreen] frame];
    CGFloat sbThickness = [[NSStatusBar systemStatusBar] thickness];
#if DEBUG
    for (NSScreen *screen in screens) {
        NSRect sFrame = [screen frame];
        NSLog(@"getFavoriteLayout: Screen (%f, %f) %f x %f", sFrame.origin.x, sFrame.origin.y, sFrame.size.width, sFrame.size.height);
    }
#endif // DEBUG

    if (instanceNumber > 1 && [screens count] > 1) {
        newLayout = [screens[1] frame];
        newLayout.size.width /= 2;
        newLayout.size.height /= 2;

        if (instanceNumber == 3 || instanceNumber == 5) {
            newLayout.origin.x += newLayout.size.width;
        }

        if (instanceNumber == 4 || instanceNumber == 5) {
            newLayout.origin.y += newLayout.size.height - sbThickness;
        }
    } else {
        if ([[NSStatusBar systemStatusBar] isVertical]) {
            newLayout.origin.x += sbThickness;
            newLayout.size.width -= sbThickness;
        } else {
            newLayout.origin.y += sbThickness;
            newLayout.size.height -= sbThickness;
        }
    }

    *layout = newLayout;
}

-(void)updateFavoriteLayout {
    if (targetApplicationsByPID == NULL || [targetApplicationsByPID count] == 0) {
        return;
    }

    NSArray *keys = [targetApplicationsByPID keysSortedByValueUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1[kMBO_InstanceNumber] compare:obj2[kMBO_InstanceNumber]];
    }];

    NSMutableArray *newLayout = [NSMutableArray arrayWithArray:self.favoriteLayout];

    while([newLayout count] < [targetApplicationsByPID count]) {
        [newLayout addObject:[NSNull null]];
    }

    for(NSString *key in keys) {
        NSNumber *instanceNumber = targetApplicationsByPID[key][kMBO_InstanceNumber];
        NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:targetApplicationsByPID[key]];
        entry[kMBO_InstanceNumber] = nil;
        newLayout[[instanceNumber integerValue]] = entry;
    }

    NSLog(@"updateFavoriteLayout: newLayout = %@", newLayout);

    [self setFavoriteLayout:newLayout];
}

-(NSDictionary *)keyBindingsDictionaryRepresentation {
    NSMapTable *bindings = [self keyBindings];

    return [bindings dictionaryRepresentation];
}

-(NSMapTable *)keyBindings {
    id value = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_KeyBindings];

    if (value == NULL)
        return NULL;

    NSMapTable *map = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)value];

    return map;
}

-(void)setKeyBindings:(NSMapTable *)keyBindings {
    [[NSUserDefaults standardUserDefaults] setValue:[NSKeyedArchiver archivedDataWithRootObject:keyBindings] forKey:kMBO_Preference_KeyBindings];
}

-(void)addKeyBinding:(MBOKeybinding *)newKey {
    NSMapTable *newBindings = [[self keyBindings] copy];
    [newBindings setObject:newKey forKey:@(newKey.keyCode)];
    [self setKeyBindings:newBindings];
}

-(void)removeKeyBinding:(MBOKeybinding *)originalKey {
    NSMapTable *newBindings = [[self keyBindings] copy];
    [newBindings removeObjectForKey:@(originalKey.keyCode)];
    [self setKeyBindings:newBindings];
}

- (void)saveTargetApplicationWithPID:(pid_t)targetPID withDictionary:(NSDictionary *)newEntries {
    @synchronized (self) {
        if (targetApplicationsByPID == NULL) {
            targetApplicationsByPID = [[NSMutableDictionary alloc] init];
        }

        NSMutableDictionary *entry = targetApplicationsByPID[@(targetPID)];

        if (entry == NULL) {
            entry = [NSMutableDictionary dictionaryWithDictionary:@{ kMBO_InstanceNumber: @([targetApplicationsByPID count]) }];
        }

        [entry addEntriesFromDictionary:newEntries];

        targetApplicationsByPID[@(targetPID)] = entry;

        NSLog(@"saveTargetApplicationWithPID(%d) targetApplicationsByPID = %@", targetPID, targetApplicationsByPID);

        [self updateFavoriteLayout];
    }
}

- (void)removeTargetApplicationWithPID:(pid_t)targetPID {
    @synchronized (self) {
        if (targetApplicationsByPID != NULL) {
            targetApplicationsByPID[@(targetPID)] = nil;
            NSLog(@"removeTargetApplicationWithPID(%d) targetApplicationsByPID = %@", targetPID, targetApplicationsByPID);
        }
    }
}

-(void)clearTargetApplicationsByPID {
    @synchronized (self) {
        targetApplicationsByPID = NULL;
        targetApplicationsByPID = [[NSMutableDictionary alloc] init];
    }
}

// Watch for changes to key binding related defaults
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"[self observeValueForKeyPath:%@ ofObject: %@ change:%@ context:0x%lx]", keyPath, object, change, (unsigned long)context);

    if ([object isKindOfClass:[NSUserDefaults class]]) {
        if ([keyPath isEqualToString:kMBO_Preference_KeyBindings]) {
            [self compileKeyActionMap];
            if (preferencesWindow != NULL) {
                [preferencesWindow keyBindingsChanged];
            }
        }
    }
}

- (void)compileKeyActionMap {
    bzero(keyActionMap, sizeof(keyActionMap));

    NSLog(@"compileActionKeyMap()");

    for (id idx in self.keyBindings) {
        MBOKeybinding *key = [self.keyBindings objectForKey:idx];
        NSLog(@"compileActionKeyMap() %@", key.debugDescription);
        CGKeyCode keyCode = key.keyCode % kMBO_MaxKeyCode;
        keyActionMap[keyCode].modifierFlags = key.modifierFlags;
        keyActionMap[keyCode].action = key.action;
    }
}

- (void)processAppplicationNotifications:(NSNotification *)notification {
    NSRunningApplication *thisApp = [[notification userInfo] objectForKey:@"NSWorkspaceApplicationKey"];
    
    if (![thisApp.bundleIdentifier isEqualToString:self.targetBundleIdentifier]) {
        return;
    }

    NSString *notificationName = [notification name];

    pid_t thisPID = [thisApp processIdentifier];

    NSLog(@"processAppplicationNotifications() pid: %u %@:\n%@", thisPID, notificationName, notification);

    if ([notificationName isEqualToString:NSWorkspaceDidLaunchApplicationNotification]) {
        [self setupTargetApplicationWithPID:thisPID];

        autoExit = TRUE;

        if ([targetApplicationsByPID count] > 0) {
            ignoreEvents = TRUE;
        }

        if (numPendingLaunch > 0) {
            numPendingLaunch--;
        }

        if (numPendingLaunch > 0) {
            [self launchApplication];
        }
    } else if ([notificationName isEqualToString:NSWorkspaceDidTerminateApplicationNotification]) {
        [self removeTargetApplicationWithPID:thisPID];
    }

    NSLog(@"processAppplicationNotifications(): targetApplicationsByPID count=%lu", (unsigned long)[targetApplicationsByPID count]);

    if (autoExit && [targetApplicationsByPID count] <= 0) {
        [[NSApplication sharedApplication] terminate:self];
    }

    [self updateUI];
}

- (void)scanForTargetApplications {
    NSArray *appList = [NSRunningApplication runningApplicationsWithBundleIdentifier:self.targetBundleIdentifier];

#if DEBUG
    NSDate *startTime = [NSDate date];
#endif // DEBUG

    for (NSRunningApplication *thisApp in appList) {
        pid_t thisPID = [thisApp processIdentifier];

        NSLog(@"scanForTargetApplications(): Found Target: pid = %u", thisPID);

        [self setupTargetApplicationWithPID:thisPID];

        autoExit = TRUE;
    }

#if DEBUG
    NSTimeInterval delta = [startTime timeIntervalSinceNow] * -1.0;
    NSLog(@"scanForTargetApplications(): scan time: %f, found %lu targets", delta, [targetApplicationsByPID count]);
#endif
}

- (void)checkAccessibility:(BOOL)promptUser {
    NSDictionary *trustOptions = @{(__bridge id)kAXTrustedCheckOptionPrompt: (promptUser ? @YES : @NO)};
    isTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)trustOptions);
    NSLog(@"checkAccessibility() isTrusted = %hhu", isTrusted);
}

- (CGEventRef)tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)eventType event:(CGEventRef)event {
#if MULTIBOXOSX_LOGKEYS
    NSDate *startTime = [NSDate date];
#endif // MULTIBOXOSX_LOGKEYS
    NSRunningApplication *frontmostApp = [[NSWorkspace sharedWorkspace] frontmostApplication];

    if (![frontmostApp.bundleIdentifier isEqualToString:self.targetBundleIdentifier]) {
        return event;
    }

    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

#if MULTIBOXOSX_LOGKEYS
    NSLog(@"tapKeyboardCallbackWithProxy(type:%u, event:%@): frontmostApp=[%@]", eventType, event, frontmostApp.bundleIdentifier);
#endif // MULTIBOXOSX_LOGKEYS
    // check for special keys and ignored keys
    if (eventType == kCGEventKeyDown || eventType == kCGEventKeyUp) {
#if MULTIBOXOSX_LOGKEYS
        CGEventFlags flags = CGEventGetFlags(event);
        NSString *eventString = [self stringFromEvent:event];
        NSLog(@"tapKeyboardCallbackWithProxy(): key=[%@] code=%d flags=%llx", eventString, keycode, flags);
#endif // MULTIBOXOSX_LOGKEYS
        if (keycode < kMBO_MaxKeyCode) {
            keyActionMap_t *km = &keyActionMap[keycode];

            if (km->action == kMBOKeybindingActionToggleForwarding) {
                if (eventType == kCGEventKeyDown) {
                    ignoreEvents = !ignoreEvents;
                    NSLog(@"kMBOKeybindingActionToggleForwarding: tapKeyboardCallbackWithProxy(): ignoreEvents=%d", ignoreEvents);

                    if (!ignoreEvents) {
                        [self scanForTargetApplications];
                    }
                }

                [self updateUI];
                return event;
            }

            // TODO: Check ->flagsMask (need to support elsewhere too)
            if (km->action == kMBOKeybindingActionIgnore) {
                return event;
            }
        }
#if MULTIBOXOSX_LOGKEYS
        NSLog(@"tapKeyboardCallbackWithProxy(): keycode=%d flags=%llx eventString=[%@]", keycode, flags, eventString);
#endif // MULTIBOXOSX_LOGKEYS
    }

    if (ignoreEvents) {
        [self clearTargetApplicationsByPID];
        return event;
    }

    if (targetApplicationsByPID == NULL || [targetApplicationsByPID count] == 0) {
        NSLog(@"tapKeyboardCallbackWithProxy(), running scanForTargets because we have no targetApplicationsByPID");
        [self scanForTargetApplications];
    }

    for (NSNumber *thisProcessIdentifier in targetApplicationsByPID) {
        pid_t thisPID = (pid_t)[thisProcessIdentifier integerValue];

        // Avoid double "echo" effect, don't send to the active application
        if (thisPID == frontmostApp.processIdentifier) {
            continue;
        }

#if MULTIBOXOSX_LOGKEYS
        NSLog(@"tapKeyboardCallbackWithProxy(): forward event to %u", thisPID);
#endif // MULTIBOXOSX_LOGKEYS

        CGEventPostToPid(thisPID, event);
    }

#if MULTIBOXOSX_LOGKEYS
    NSLog(@"tapKeyboardCallbackWithProxy() keycode=%d processing lag: %f", keycode, [startTime timeIntervalSinceNow] * -1.0);
#endif // MULTIBOXOSX_LOGKEYS

    [self updateUI];

    return event;
}

CGEventRef MyKeyboardEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MainController *mc = (__bridge MainController *) refcon;

    return [mc tapKeyboardCallbackWithProxy:proxy type:type event:event];
}

- (void)setupEventTaps {
    CGEventMask maskKeyboard = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

    machPortKeyboard = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
                                        maskKeyboard, MyKeyboardEventTapCallBack, (__bridge void * _Nullable)(self));

    machPortRunLoopSourceRefKeyboard = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPortKeyboard, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);

    NSLog(@"setupEventTaps() done");
}

- (void)shutDownEventTaps {
    if (machPortRunLoopSourceRefKeyboard) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);
        CFRelease(machPortRunLoopSourceRefKeyboard);
    }
    
    if (machPortKeyboard) {
        CFRelease(machPortKeyboard);
    }
}

-(void)sendToPID:(pid_t)targetPID keys:(NSString *)keys {
    NSLog(@"SendToPID:%d keys:[%@]", targetPID, keys);
    for (int i = 0;i < [keys length];i++) {
        CGKeyCode keySpecial = 0xFFFF;
        UniChar chr = [keys characterAtIndex: i];

        switch (chr) {
            case 9:
                keySpecial = kVK_Tab;
                break;

            case 10:
                keySpecial = kVK_Return;
                break;
        }

        if (keySpecial != 0xFFFF) {
            CGEventRef keyEvent = CGEventCreateKeyboardEvent(nil, keySpecial, YES);
            CGEventPostToPid(targetPID, keyEvent);
            CFRelease(keyEvent);
            usleep(500000);
            keyEvent = CGEventCreateKeyboardEvent(nil, keySpecial, NO);
            CGEventPostToPid(targetPID, keyEvent);
            CFRelease(keyEvent);
            usleep(1000000);
        } else {
            CGEventRef keyEvent = CGEventCreateKeyboardEvent(nil, 0, YES);
            CGEventKeyboardSetUnicodeString(keyEvent, 1, &chr);
            CGEventPostToPid(targetPID, keyEvent);
            CFRelease(keyEvent);
            usleep(250000);
        }
    }
}

- (void)setupNewTargetApplicationWithPID:(pid_t)targetPID instanceNumber:(long)instanceNumber {
    AXError err;
    CFArrayRef applicationWindows = NULL;

    NSLog(@"setupNewTargetApplicationWithPID(%d) instanceNumber:%ld", targetPID, instanceNumber);

    AXUIElementRef applicationRef = AXUIElementCreateApplication(targetPID);

    if (applicationRef == NULL) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) AXUIElementCreateApplication(%d) failed!", targetPID, targetPID];
        return;
    }

    for (int retry = 0;retry < 1000 && applicationWindows == NULL;retry++) {
        err = AXUIElementCopyAttributeValues(applicationRef, kAXWindowsAttribute, 0, 100, &applicationWindows);
        usleep(10000);
    }

    if (applicationWindows == NULL) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) failed to get kAXWindowsAttribute err = %d", targetPID, err];
        return;
    }

    AXObserverRef axObserver;
    if ((err = AXObserverCreate(targetPID, axObserverCallback, &axObserver)) != kAXErrorSuccess) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) AXObserverCreate() failed with err = %d", targetPID, err];
    } else {
        // TODO: cleanup axObserver memory on shutdown?
        AXObserverAddNotification(axObserver, applicationRef, kAXWindowMovedNotification, (__bridge void *)(self));
        AXObserverAddNotification(axObserver, applicationRef, kAXWindowResizedNotification, (__bridge void *)(self));
        CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], AXObserverGetRunLoopSource(axObserver), kCFRunLoopDefaultMode);
    }

    if (CFArrayGetCount(applicationWindows) <= 0) {
        CFRelease(applicationRef);
        return;
    }

    NSRect layout;

    [self getFavoriteLayout:&layout withInstanceNumber:instanceNumber];

    AXUIElementRef windowRef = NULL;

    for (CFIndex i = 0; i < CFArrayGetCount(applicationWindows); i++) {
        windowRef = CFArrayGetValueAtIndex(applicationWindows, i);

        CFStringRef title = NULL;
        AXUIElementCopyAttributeValue(windowRef, kAXTitleAttribute, (CFTypeRef *)&title);
        if (CFStringGetLength(title) > 0) {
            break;
        }
    }

#if DEBUG
    NSPoint curPosition, curSize;
    CFTypeRef curPositionRef, curSizeRef;

    AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, &curSizeRef);
    AXValueGetValue(curSizeRef, kAXValueCGSizeType, &curSize);

    AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, &curPositionRef);
    AXValueGetValue(curPositionRef, kAXValueCGPointType, &curPosition);

    NSLog(@"setupNewTargetApplicationWithPID(%d) Current Window: (%f, %f) %f x %f", targetPID, curPosition.x, curPosition.y, curSize.x, curSize.y);
#endif // DEBUG

    NSLog(@"setupNewTargetApplicationWithPID(%d) New Window: (%f, %f) %f x %f", targetPID, layout.origin.x, layout.origin.y, layout.size.width, layout.size.height);

    if ((err = AXUIElementSetAttributeValue(windowRef, kAXFocusedAttribute, kCFBooleanTrue)) != kAXErrorSuccess) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) failed to set kAXFocusedAttribute err = %d", targetPID, err];
    }

    AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &layout.origin);
    if ((err = AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, positionRef)) != kAXErrorSuccess) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) failed to set kAXPositionAttribute err = %d", targetPID, err];
    }

    AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &layout.size);
    if ((err = AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, sizeRef)) != kAXErrorSuccess) {
        [self logError:@"setupNewTargetApplicationWithPID(%d) failed to set kAXSizeAttribute err = %d", targetPID, err];
    }

    CFRelease(applicationRef);
    CFRelease(sizeRef);
    CFRelease(positionRef);
}

- (void)setupTargetApplicationWithPID:(pid_t)targetPID {
    if (targetApplicationsByPID[@(targetPID)] == nil) {
        [self setupNewTargetApplicationWithPID:targetPID instanceNumber:[targetApplicationsByPID count]];
    }

    AXUIElementRef appRef = AXUIElementCreateApplication(targetPID);

    if (appRef == NULL) {
        [self logError:@"setupTargetApplicationWithPID(%d) AXUIElementCreateApplication(%d) failed!", targetPID, targetPID];
        return;
    }

    CFArrayRef winRefs;
    AXUIElementCopyAttributeValues(appRef, kAXWindowsAttribute, 0, 255, &winRefs);

    if (!winRefs) {
        CFRelease(appRef);
        return;
    }

    NSPoint curPosition = { .x = -1, .y = -1 };
    NSSize curSize = { .width = -1, .height = -1 };

#if DEBUG
    for (CFIndex winNum = 0;winNum < CFArrayGetCount(winRefs); winNum++) {
#else // DEBUG
    if (CFArrayGetCount(winRefs) >= 1) {
        CFIndex winNum = CFArrayGetCount(winRefs) - 1;
#endif
        AXUIElementRef winRef = (AXUIElementRef)CFArrayGetValueAtIndex(winRefs, winNum);

        CFTypeRef curPositionRef, curSizeRef;

        AXUIElementSetAttributeValue(winRef, kAXFocusedAttribute, kCFBooleanTrue);

        if (AXUIElementCopyAttributeValue(winRef, kAXSizeAttribute, &curSizeRef) == kAXErrorSuccess)
            AXValueGetValue(curSizeRef, kAXValueCGSizeType, &curSize);

        if (AXUIElementCopyAttributeValue(winRef, kAXPositionAttribute, &curPositionRef) == kAXErrorSuccess)
            AXValueGetValue(curPositionRef, kAXValueCGPointType, &curPosition);
#if DEBUG
        CFStringRef title = NULL;
        AXUIElementCopyAttributeValue(winRef, kAXTitleAttribute, (CFTypeRef *)&title);

        NSLog(@"setupTargetApplicationWithPID(%d): Window #%ld = [%@] (%f, %f) %f x %f", targetPID, winNum, title, curPosition.x, curPosition.y, curSize.width, curSize.height);
#endif // DEBUG
    }

    NSLog(@"setupTargetApplicationWithPID(%d): Main Window = (%f, %f) %f x %f", targetPID, curPosition.x, curPosition.y, curSize.width, curSize.height);

        [self saveTargetApplicationWithPID:targetPID withDictionary:
         @{
           (NSString *)kAXPositionAttribute: NSStringFromPoint(curPosition),
           (NSString *)kAXSizeAttribute: NSStringFromSize(curSize)
           }
         ];

    AXUIElementSetAttributeValue(appRef, kAXFocusedApplicationAttribute, kCFBooleanTrue);

    CFRelease(winRefs);
    CFRelease(appRef);
}

- (void)updateUI {
    if (!isTrusted) {
        [self checkAccessibility:NO];

        if (!isTrusted) {
            toggleButton.title = @"First Enable Accessibility!";
            mainWindow.backgroundColor = [NSColor purpleColor];
            // TODO: Can we detect when we get trusted via: AXObserverAddNotification ?
            // http://stackoverflow.com/questions/853833/how-can-my-app-detect-a-change-to-another-apps-window

            // Check every 1 second until we have been trusted
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1ull * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                NSLog(@"timer updateUI");
                [self updateUI];
            });
            return;
        }

        if (isTrusted) {
            [self setupEventTaps];
        }
    }

    if (ignoreEvents) {
        toggleButton.title = @"Enable MultiBoxOSX";
        [targetIndicator setDoubleValue:(double)(0)];
        mainWindow.backgroundColor = [NSColor redColor];
    } else {
        [targetIndicator setDoubleValue:(double)([targetApplicationsByPID count])];

        if ([targetApplicationsByPID count] >= 1) {
            toggleButton.title = @"Disable MultiBoxOSX";
            mainWindow.backgroundColor = [NSColor greenColor];
        } else {
            toggleButton.title = @"Launch";
            mainWindow.backgroundColor = [NSColor yellowColor];
        }
    }
}

- (IBAction)enableButtonClicked:(id)sender {
    ignoreEvents = !ignoreEvents;

    if ([targetApplicationsByPID count] == 0) {
        [self launchApplication];
    }

    [self updateUI];
}

- (IBAction)levelIndicatorClicked:(id)sender {
    NSLevelIndicator *bar = (NSLevelIndicator *)sender;

    NSInteger curCount = [targetApplicationsByPID count];
    NSInteger newCount = [bar intValue];

    if (newCount > curCount && newCount < 6) {
        numPendingLaunch = newCount - curCount;
    } else if (curCount <= 5) {
        numPendingLaunch = 1;
    }

    while (numPendingLaunch > 0) {
        [self launchApplication];
        numPendingLaunch--;
        usleep(5000);
    }

    [bar setDoubleValue:(double)([targetApplicationsByPID count])];
}

- (void)launchApplication {
    if ([targetApplicationsByPID count] >= 5) {
        return;
    }
    
    NSURL *appURL = [NSURL fileURLWithPath:self.targetAppPath];
    NSMutableDictionary *appConfig = [[NSMutableDictionary alloc] init];
    NSRunningApplication *newApp = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:appURL options:NSWorkspaceLaunchNewInstance configuration:appConfig error:nil];
#pragma unused(newApp)
    NSLog(@"Launched %@ pid: %d", appURL, [newApp processIdentifier]);
}

void axObserverCallback(AXObserverRef observer, AXUIElementRef elementRef, CFStringRef notification, void *data)
{
    MainController *mc = (__bridge MainController *)data;

    // Debounce events until they stop
    [NSObject cancelPreviousPerformRequestsWithTarget:mc selector:@selector(scanForTargetApplications) object:nil];
    [mc performSelector:@selector(scanForTargetApplications) withObject:nil afterDelay:0.25];
}

- (NSString *)stringFromEvent:(CGEventRef)event {
    UniCharCount stringLength = 32;
    UniChar unicodeString[stringLength];
    CGEventKeyboardGetUnicodeString(event, stringLength, &stringLength, unicodeString);
    NSString *uni = [NSString stringWithCharacters:unicodeString length:stringLength];

    return uni;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSLog(@"applicationShouldTerminate(%@)", sender);
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self shutDownEventTaps];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kMBO_Preference_KeyBindings context:nil];
    return NSTerminateNow;
}

- (void) logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSLogv([format stringByAppendingString:[NSString stringWithFormat:@"UNEXPECTED ERROR: "]], args);
    va_end(args);
}

@end
