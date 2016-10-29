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

#import "MainController.h"

@implementation MainController

- (void)awakeFromNib {
    [NSApplication sharedApplication].delegate = self;
    [mainWindow setMovableByWindowBackground:YES];
    [mainWindow setLevel:NSFloatingWindowLevel];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Setup Defaults
    NSDictionary *defaultPreferences =
    @{
      kMBO_Preference_TargetApplication: @"World of Warcraft",
      kMBO_Preference_TargetAppPath: @"/Applications/World of Warcraft/World of Warcraft.app",

      // Pause/Break Key on PC Keyboard
      kMBO_Preference_KeyPause: @"keycode:113",

      // Tilde/backtick, w, a, s, d
      kMBO_Preference_IgnoreKeys: @[ @"keycode:50", @"keycode:13", @"keycode:0", @"keycode:1", @"keycode:2" ],
    };

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultPreferences];

    // Listen for changes to key bindings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults addObserver:self
               forKeyPath:kMBO_Preference_KeyPause
                  options:NSKeyValueObservingOptionNew
                  context:nil
     ];

    [defaults addObserver:self
               forKeyPath:kMBO_Preference_IgnoreKeys
                  options:NSKeyValueObservingOptionNew
                  context:nil
     ];
    
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
    [self compileKeyActionMap];

    ignoreEvents = FALSE;

    [self scanForTargets];

    isTrusted = FALSE;
    [self checkAccessibility:YES];

    if (isTrusted) {
        [self setUpEventTaps];
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

- (NSString *)targetApplication {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_TargetApplication];
}

- (void) setTargetApplication:(NSString *)targetApplication {
    [[NSUserDefaults standardUserDefaults] setValue:targetApplication forKey:kMBO_Preference_TargetApplication];
}

- (NSString *)targetAppPath {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_TargetAppPath];
}

- (void)setTargetAppPath:(NSString *)targetAppPath {
    [[NSUserDefaults standardUserDefaults] setValue:targetAppPath forKey:kMBO_Preference_TargetAppPath];
}

- (NSString *)keyPause {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_KeyPause];
}

-(void)setKeyPause:(NSString *)keyPause {
    [[NSUserDefaults standardUserDefaults] setValue:keyPause forKey:kMBO_Preference_KeyPause];
}

-(NSArray *)ignoreKeys {
    NSArray *keyStrings = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_IgnoreKeys];

    for (NSObject *obj in keyStrings) {
        if (![obj isKindOfClass:[NSString class]]) {
            [self logError:@"user default for ignoreKeys should be an array of all strings, resetting to defaults."];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ignoreKeys"];
            return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_IgnoreKeys];
        }
    }

    return keyStrings;
}

-(void)setIgnoreKeys:(NSArray *)keyStrings {
    for (NSObject *obj in keyStrings) {
        if (![obj isKindOfClass:[NSString class]]) {
            [self logError:@"setIgnoreKeys: Expected array of NSString, ignoring attempt to set to: %@", keyStrings];
            return;
        }
    }
    [[NSUserDefaults standardUserDefaults] setValue:keyStrings forKey:kMBO_Preference_IgnoreKeys];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"[self observeValueForKeyPath:%@ ofObject: %@ change:%@ context:0x%lx]", keyPath, object, change, (unsigned long)context);

    if ([object isKindOfClass:[NSUserDefaults class]]) {
        if ([keyPath isEqualToString:kMBO_Preference_KeyPause] || [keyPath isEqualToString:kMBO_Preference_IgnoreKeys]) {
            [self compileKeyActionMap];
        }
    }
}

- (BOOL)parseKeyString:(NSString *)keyString keyCode:(CGKeyCode *)keyCode withFlags:(CGEventFlags *)flags {
    *keyCode = 0;
    *flags = 0;

    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern: @"keycode:((?:0x|)[0-9a-f]+)(?:/mod:((?:0x|)[0-9a-z]+)|.*)"
        options: NSRegularExpressionCaseInsensitive
        error: &error];

    if (error) {
        NSLog(@"regex error!? %@", error);
        return NO;
    }

    NSArray *matches = [regex matchesInString:keyString options:0 range:NSMakeRange(0, [keyString length])];

    for (NSTextCheckingResult *match in matches) {
        for (NSUInteger i = 1; i < [match numberOfRanges]; i++) {
            NSRange matched = [match rangeAtIndex:i];

            if (matched.length > 0) {
                NSString *hit = [keyString substringWithRange:matched];

                NSScanner *scan = [NSScanner scannerWithString:hit];

                int val = 0;

                if ([hit hasPrefix:@"0x"]) {
                    uint uVal = 0;

                    if ([scan scanHexInt:&uVal]) {
                        val = uVal;
                    } else {
                        NSLog(@"failed to parse!");
                        return NO;
                    }
                } else {
                    if (![scan scanInt:&val]) {
                        NSLog(@"failed to parse!");
                        return NO;
                    }
                }

                if (i == 1) {
                    *keyCode = val;
                } else {
                    *flags = val;
                }
            }
        }
    }

    NSLog(@"parseKeyString(%@) keyCode: 0x%x flags: 0x%llx", keyString, *keyCode, *flags);

    return YES;
}

- (void)compileKeyActionMap {
    bzero(keyActionMap, sizeof(keyActionMap));

    CGKeyCode keyCode = 0;
    CGEventFlags flagsMask = 0;

    NSLog(@"compileActionKeyMap() %@=%@", kMBO_Preference_KeyPause, self.keyPause);

    if ([self parseKeyString:self.keyPause keyCode:&keyCode withFlags:&flagsMask]) {
        keyCode %= kMBO_MaxKeyCode;
        keyActionMap[keyCode].flagsMask = flagsMask;
        keyActionMap[keyCode].action = kMBO_Pause;
    }

    NSLog(@"compileActionKeyMap() %@=%@", kMBO_Preference_IgnoreKeys, self.ignoreKeys);

    for (NSString *ignoreKey in self.ignoreKeys) {
        NSLog(@"Ignore %@", ignoreKey);

        if ([self parseKeyString:ignoreKey keyCode:&keyCode withFlags:&flagsMask]) {
            keyCode %= kMBO_MaxKeyCode;
            keyActionMap[keyCode].flagsMask = flagsMask;
            keyActionMap[keyCode].action = kMBO_Ignore;
        }
    }
}

- (void)processAppplicationNotifications:(NSNotification *)notification {
    if (![[[notification userInfo] objectForKey:@"NSApplicationName"] isEqualToString:self.targetApplication]) {
        return;
    }

    NSString *notificationName = [notification name];

    pid_t thisPID = [[[notification userInfo] objectForKey:@"NSApplicationProcessIdentifier"] longValue];

    NSLog(@"processAppplicationNotifications() pid: %u %@:\n%@", thisPID, notificationName, notification);

    NSMutableDictionary *newTargets = [targetApps mutableCopy];

    if ([notificationName isEqualToString:NSWorkspaceDidLaunchApplicationNotification]) {
        [self focusFirstWindowOfPid:thisPID];
        [newTargets setObject:@(TRUE) forKey:@(thisPID)];
        autoExit = TRUE;

        if ([targetApps count] > 0) {
            ignoreEvents = TRUE;
        }

        [self positionAppWindowByPID:thisPID instanceNumber:[newTargets count]];

        if (numPendingLaunch > 0) {
            numPendingLaunch--;
        }

        if (numPendingLaunch > 0) {
            [self launchApplication];
        }
    } else if ([notificationName isEqualToString:NSWorkspaceDidTerminateApplicationNotification]) {
        [newTargets removeObjectForKey:@(thisPID)];
    }

    targetApps = newTargets;

    NSLog(@"processAppplicationNotifications(): targetApps count=%lu", (unsigned long)[targetApps count]);

    if (autoExit && [targetApps count] <= 0) {
        [[NSApplication sharedApplication] terminate:self];
    }

    [self updateUI];
}

- (void)scanForTargets {
    NSMutableDictionary *newTargets = [[NSMutableDictionary alloc] init];
    NSArray *appNames = [[NSWorkspace sharedWorkspace] runningApplications];

#if DEBUG
    NSDate *startTime = [NSDate date];
#endif // DEBUG

    for (NSRunningApplication *thisApp in appNames) {
        if ([thisApp.localizedName isEqualToString:self.targetApplication]) {
            pid_t thisPID = [thisApp processIdentifier];

            NSLog(@"scanForTargets(): Found Target: pid = %u", thisPID);
#if DEBUG
            [self dumpWindowListOfPid:thisPID];
#endif // DEBUG
            [self focusFirstWindowOfPid:thisPID];

            autoExit = TRUE;

            [newTargets setObject:@(TRUE) forKey:@(thisPID)];
        }
    }

    targetApps = newTargets;

#if DEBUG
    NSTimeInterval delta = [startTime timeIntervalSinceNow] * -1.0;
    NSLog(@"scanForTargets(): scan time: %f, found %lu targets", delta, [targetApps count]);
#endif
}

- (void)checkAccessibility:(BOOL)promptUser {
    NSDictionary *trustOptions = @{(__bridge id)kAXTrustedCheckOptionPrompt: (promptUser ? @YES : @NO)};
    isTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)trustOptions);
    NSLog(@"checkAccessibility() isTrusted = %hhu", isTrusted);
}

- (CGEventRef)tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)eventType event:(CGEventRef)event {
#if DEBUG
    NSDate *startTime = [NSDate date];
#endif // DEBUG
    NSDictionary *currentApp = [[NSWorkspace sharedWorkspace] activeApplication];
    NSNumber *currentAppProcessIdentifier = (NSNumber *)[currentApp objectForKey:@"NSApplicationProcessIdentifier"];
    NSString *currentAppName = (NSString *)[currentApp objectForKey:@"NSApplicationName"];

    if (![currentAppName isEqualToString:self.targetApplication]) {
        return event;
    }

    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

#if MULTIBOXOSX_LOGKEYS
    NSLog(@"tapKeyboardCallbackWithProxy(type:%u, event:%@): currentApp=[%@]", eventType, event, currentAppName);
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

            if (km->action == kMBO_Pause) {
                if (eventType == kCGEventKeyDown) {
                    ignoreEvents = !ignoreEvents;
                    NSLog(@"kMBO_Pause(): tapKeyboardCallbackWithProxy(): ignoreEvents=%d", ignoreEvents);

                    if (!ignoreEvents) {
                        [self scanForTargets];
                    }
                }

                [self updateUI];
                return event;
            }

            // TODO: Check ->flagsMask (need to support elsewhere too)
            if (km->action == kMBO_Ignore) {
                return event;
            }
        }
#if MULTIBOXOSX_LOGKEYS
        NSLog(@"tapKeyboardCallbackWithProxy(): keycode=%d flags=%llx eventString=[%@]", keycode, flags, eventString);
#endif // MULTIBOXOSX_LOGKEYS
    }

    if (ignoreEvents) {
        if (targetApps != NULL) {
            [targetApps dealloc];
            targetApps = NULL;
        }

        return event;
    }

    if (targetApps == NULL || [targetApps count] == 0) {
        NSLog(@"tapKeyboardCallbackWithProxy(), running scanForTargets because we have no targetApps");
        [self scanForTargets];
    }

    for (NSNumber *thisProcessIdentifier in targetApps) {
        // Avoid double "echo" effect, don't send to the active application
        if ([thisProcessIdentifier isEqual:currentAppProcessIdentifier]) {
            continue;
        }

        pid_t thisPID = [thisProcessIdentifier longValue];

#if MULTIBOXOSX_LOGKEYS
        NSLog(@"tapKeyboardCallbackWithProxy(): forward event to %u", thisPID);
#endif // MULTIBOXOSX_LOGKEYS

        CGEventPostToPid(thisPID, event);
    }

#if DEBUG
    NSLog(@"tapKeyboardCallbackWithProxy() keycode=%d processing lag: %f", keycode, [startTime timeIntervalSinceNow] * -1.0);
#endif

    [self updateUI];

    return event;
}

CGEventRef MyKeyboardEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MainController *mc = (MainController *) refcon;

    return [mc tapKeyboardCallbackWithProxy:proxy type:type event:event];
}

- (void)setUpEventTaps {
    CGEventMask maskKeyboard = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

    machPortKeyboard = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
                                        maskKeyboard, MyKeyboardEventTapCallBack, self);

    machPortRunLoopSourceRefKeyboard = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPortKeyboard, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);

    NSLog(@"setUpEventTaps() done");
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

#if DEBUG
- (void)dumpWindowListOfPid:(pid_t)pid {
    AXUIElementRef appRef = AXUIElementCreateApplication(pid);

    if (!appRef) {
        NSLog(@"dumpWindowListOfPid(%d): failed to create application reference!", pid);
        return;
    }

    CFArrayRef winRefs;
    AXUIElementCopyAttributeValues(appRef, kAXWindowsAttribute, 0, 255, &winRefs);

    if (!winRefs) {
        NSLog(@"dumpWindowListOfPid(%d): failed to create windows reference!", pid);
        CFRelease(appRef);
        return;
    }

    for (int i = 0; i < CFArrayGetCount(winRefs); i++) {
        AXUIElementRef winRef = (AXUIElementRef)CFArrayGetValueAtIndex(winRefs, i);
        CFStringRef titleRef = NULL;
        AXUIElementCopyAttributeValue(winRef, kAXTitleAttribute, (const void**)&titleRef);

        char buf[1024];
        buf[0] = '\0';

        strcpy(buf, "*EMPTY*");

        if (!CFStringGetCString(titleRef, buf, 1023, kCFStringEncodingUTF8))
            break;

        if (titleRef != NULL) {
            CFRelease(titleRef);
        }

        NSPoint curPosition = { .x = -1, .y = -1 }, curSize = { .x = -1, .y = -1 };
        CFTypeRef curPositionRef, curSizeRef;

        if (AXUIElementCopyAttributeValue(winRef, kAXSizeAttribute, &curSizeRef) == kAXErrorSuccess)
            AXValueGetValue(curSizeRef, kAXValueCGSizeType, &curSize);

        if (AXUIElementCopyAttributeValue(winRef, kAXPositionAttribute, &curPositionRef) == kAXErrorSuccess)
            AXValueGetValue(curPositionRef, kAXValueCGPointType, &curPosition);

        NSLog(@"dumpWindowListOfPid(%d): Window #%d = [%s] (%f, %f) %f x %f", pid, i, buf, curPosition.x, curPosition.y, curSize.x, curSize.y);
    }

    CFRelease(winRefs);
    CFRelease(appRef);
}

#endif // DEBUG

// taken from clone keys
- (void)focusFirstWindowOfPid:(pid_t)pid {
    AXUIElementRef appRef = AXUIElementCreateApplication(pid);

    if (!appRef) {
        return;
    }

    CFArrayRef winRefs;
    AXUIElementCopyAttributeValues(appRef, kAXWindowsAttribute, 0, 255, &winRefs);

    if (!winRefs) {
        CFRelease(appRef);
        return;
    }

#if !DEBUG
    for (int i = 0; i < CFArrayGetCount(winRefs); i++) {
        AXUIElementRef winRef = (AXUIElementRef)CFArrayGetValueAtIndex(winRefs, i);
        CFStringRef titleRef = NULL;
        AXUIElementCopyAttributeValue(winRef, kAXTitleAttribute, (const void**)&titleRef);

        char buf[1024];
        buf[0] = '\0';

        if (!CFStringGetCString(titleRef, buf, 1023, kCFStringEncodingUTF8))
            break;

        if (titleRef != NULL) {
            CFRelease(titleRef);
        }

        NSLog(@"focusFirstWindowOfPid(%d): Window #%d = [%s]", pid, i, buf);

        if (strlen(buf) != 0) {
            AXUIElementSetAttributeValue(winRef, kAXFocusedAttribute, kCFBooleanTrue);
            break;
        }
    }
#else // DEBUG
    if (CFArrayGetCount(winRefs) >= 1) {
        AXUIElementRef winRef = (AXUIElementRef)CFArrayGetValueAtIndex(winRefs, 0);
        AXUIElementSetAttributeValue(winRef, kAXFocusedAttribute, kCFBooleanTrue);
    }
#endif // DEBUG

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
            [self setUpEventTaps];
        }
    }

    if (ignoreEvents) {
        toggleButton.title = @"Enable MultiBoxOSX";
        [targetIndicator setDoubleValue:(double)(0)];
        mainWindow.backgroundColor = [NSColor redColor];
    } else {
        [targetIndicator setDoubleValue:(double)([targetApps count])];

        if ([targetApps count] >= 1) {
            toggleButton.title = @"Disable MultiBoxOSX";
            mainWindow.backgroundColor = [NSColor greenColor];
        } else {
            toggleButton.title = [NSString stringWithFormat:@"Start %@", self.targetApplication];
            mainWindow.backgroundColor = [NSColor yellowColor];
        }
    }
}

- (IBAction)enableButtonClicked:(id)sender {
    ignoreEvents = !ignoreEvents;

    if ([targetApps count] == 0) {
        [self launchApplication];
    }

    [self updateUI];
}

- (IBAction)levelIndicatorClicked:(id)sender {
    NSLevelIndicator *bar = (NSLevelIndicator *)sender;

    int curCount = [targetApps count];
    int newCount = [bar intValue];

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

    [bar setDoubleValue:(double)([targetApps count])];
}

- (void)launchApplication {
    if ([targetApps count] >= 5) {
        return;
    }
    
    NSURL *appURL = [NSURL fileURLWithPath:self.targetAppPath];
    NSMutableDictionary *appConfig = CFBridgingRelease([[NSMutableDictionary alloc] init]);
    NSRunningApplication *newApp = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:appURL options:NSWorkspaceLaunchNewInstance configuration:appConfig error:nil];
#pragma unused(newApp)
    NSLog(@"Launched %@ pid: %d", appURL, [newApp processIdentifier]);
}

- (void)positionAppWindowByPID:(pid_t)targetPID instanceNumber:(int)instanceNumber {
    AXUIElementRef applicationRef = AXUIElementCreateApplication(targetPID);
    CFArrayRef applicationWindows = NULL;
    int retry = 1000;

    while (retry > 0 && applicationWindows == NULL) {
        retry--;
        AXUIElementCopyAttributeValues(applicationRef, kAXWindowsAttribute, 0, 100, &applicationWindows);
        usleep(10000);
    }

    if (applicationWindows == NULL) {
        NSLog(@"Failed to find application windows!?");
        return;
    }

#if DEBUG
    [self dumpWindowListOfPid:targetPID];
#endif // DEBUG

    NSArray *screens = [NSScreen screens];
    NSRect f = [[NSScreen mainScreen] frame];
    CGFloat sbThickness = [[NSStatusBar systemStatusBar] thickness];

#if DEBUG

    for (NSScreen *screen in screens) {
        NSRect sFrame = [screen frame];
        NSLog(@"Screen (%f, %f) %f x %f", sFrame.origin.x, sFrame.origin.y, sFrame.size.width, sFrame.size.height);
    }
#endif

    if (instanceNumber > 1 && [screens count] > 1) {
        f = [screens[1] frame];
        f.size.width /= 2;
        f.size.height /= 2;

        if (instanceNumber == 3 || instanceNumber == 5) {
            f.origin.x += f.size.width;
        }

        if (instanceNumber == 4 || instanceNumber == 5) {
            f.origin.y += f.size.height - sbThickness;
        }
    } else {
        if ([[NSStatusBar systemStatusBar] isVertical]) {
            f.origin.x += sbThickness;
            f.size.width -= sbThickness;
        } else {
            f.origin.y += sbThickness;
            f.size.height -= sbThickness;
        }
    }

    if (CFArrayGetCount(applicationWindows) > 0) {
        AXError ret = 0;
        AXUIElementRef windowRef = NULL;
        CFStringRef titleRef = NULL;

        for (CFIndex i = 0; i < CFArrayGetCount(applicationWindows); i++) {
            windowRef = CFArrayGetValueAtIndex(applicationWindows, i);
            AXUIElementCopyAttributeValue(windowRef, kAXTitleAttribute, (const void**)&titleRef);

            if (titleRef != NULL) {
                if (CFStringGetLength(titleRef) > 0)
                    break;
            }
        }

        NSPoint curPosition, curSize;
        CFTypeRef curPositionRef, curSizeRef;

        AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, &curSizeRef);
        AXValueGetValue(curSizeRef, kAXValueCGSizeType, &curSize);

        AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, &curPositionRef);
        AXValueGetValue(curPositionRef, kAXValueCGPointType, &curPosition);

        NSLog(@"Current Window: (%f, %f) %f x %f", curPosition.x, curPosition.y, curSize.x, curSize.y);
        NSLog(@"Setup Window: (%f, %f) %f x %f", f.origin.x, f.origin.y, f.size.width, f.size.height);

        ret = AXUIElementSetAttributeValue(windowRef, kAXFocusedAttribute, kCFBooleanTrue);
        NSLog(@"kAXFocusedAttribute ret = %d", ret);

        AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &f.origin);
        ret = AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, positionRef);
        NSLog(@"kAXPositionAttribute ret = %d", ret);

        AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &f.size);
        ret = AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, sizeRef);
        NSLog(@"kAXSizeAttribute ret = %d", ret);
    }
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

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults removeObserver:self forKeyPath:kMBO_Preference_KeyPause];
    [defaults removeObserver:self forKeyPath:kMBO_Preference_IgnoreKeys];

    return NSTerminateNow;
}

- (void)dealloc {
    NSLog(@"dealloc()");
    [super dealloc];
}

- (void) logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSLogv([format stringByAppendingString:[NSString stringWithFormat:@"UNEXPECTED ERROR: "]], args);
    va_end(args);
}

@end
