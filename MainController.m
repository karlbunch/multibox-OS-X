//
//  MainController.m
//  MultiBoxOSX
//
//  Created by dirk on 4/25/09.
//  Copyright 2009 Dirk Zimmermann. All rights reserved.
//  Copyright 2016 Karl Bunch.
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

#if !DEBUG
#define NSLog(...)
#endif // DEBUG

CGEventRef MyKeyboardEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MainController *mc = (MainController *) refcon;
    return [mc tapKeyboardCallbackWithProxy:proxy type:type event:event];
}

@implementation MainController

- (void) awakeFromNib {
    [NSApplication sharedApplication].delegate = self;
    [mainWindow setMovableByWindowBackground:YES];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
#if DEBUG
    NSTextField *debugLabel;
    
    debugLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(120, 0, 40, 14)];
    [debugLabel setStringValue:@"DEBUG"];
    [debugLabel setFont:[NSFont systemFontOfSize:9]];
    [debugLabel setBezeled:NO];
    [debugLabel setEditable:NO];
    [debugLabel setSelectable:NO];
    [debugLabel setDrawsBackground:NO];
    [[mainWindow contentView] addSubview:debugLabel];
#endif // DEBUG
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    
    // Listen for Application Launch/Terminations
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
    pidFocused = [[NSMutableDictionary alloc] init];

    isTrusted = FALSE;
    [self checkAccessibility:YES];
    
    if (isTrusted)
        [self setUpEventTaps];
    
    [self updateUI];
}

- (void)processAppplicationNotifications:(NSNotification *)notification
{
    if (![[[notification userInfo] objectForKey:@"NSApplicationName"] isEqualToString:MULTIBOXOSX_TARGET_APPLICATION])
        return;

    NSString *notificationName = [notification name];
    
    NSLog(@"%@: %@", notificationName, notification);
    
    if ([notificationName isEqualToString:NSWorkspaceDidLaunchApplicationNotification]) {
        numTargets++;
        autoExit = TRUE;
    } else if ([notificationName isEqualToString:NSWorkspaceDidTerminateApplicationNotification]) {
        numTargets--;
        
        if (autoExit && numTargets <= 0) {
            [[NSApplication sharedApplication] terminate:self];
        }
    }
    
    [self updateUI];
}

- (void) checkAccessibility:(BOOL) promptUser {
    NSDictionary *trustOptions = @{(__bridge id)kAXTrustedCheckOptionPrompt: (promptUser ? @YES : @NO)};
    isTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)trustOptions);
    NSLog(@"checkAccessibility = %hhu", isTrusted);
}

- (CGEventRef) tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event {
    numTargets = 0;

    NSDictionary *currentApp = [[NSWorkspace sharedWorkspace] activeApplication];
    NSString *currentAppName = (NSString *)[currentApp objectForKey:@"NSApplicationName"];
    
    NSLog(@"currentApp=[%@]", currentAppName);
    
    if(![currentAppName isEqualToString:MULTIBOXOSX_TARGET_APPLICATION]) {
        return event;
    }

    numTargets = 1;
    
    // check for special keys and ignored keys
    if (type == kCGEventKeyDown) {
        CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        NSString *eventString = [self stringFromEvent:event];
        NSLog(@"key=[%@] code=%d", eventString, keycode);
        
        if (keycode == 113) { // PAUSE/BREAK KEY
            ignoreEvents = !ignoreEvents;
            [self updateUI];
            return event;
        }
        
        if (eventString.length == 1) {
            char c = (char) [eventString characterAtIndex:0];
            switch (c) {
                    /*                case '#': // Toggle Event Forwarding
                     ignoreEvents = !ignoreEvents;
                     [self updateUI];
                     return event;
                     break;
                     */
                case 'w': // Ignore movement keys
                case 'a':
                case 's':
                case 'd':
                    return event;
                    break;
            }
        }
    }
    
    if (ignoreEvents) {
        [pidFocused dealloc];
        pidFocused = NULL;
        return event;
    }
    
    NSArray *appNames = [[NSWorkspace sharedWorkspace] runningApplications];

#if DEBUG
    NSDate *startTime = [NSDate date];
#endif // DEBUG
    
    for (NSRunningApplication *thisApp in appNames) {
        // Avoid double "echo" effect, don't send to the active application
        if (thisApp.isActive)
            continue;

        // Only forward to the target applications
        if(![thisApp.localizedName isEqualToString:MULTIBOXOSX_TARGET_APPLICATION])
            continue;
        
        numTargets++;
        
        pid_t thisPID = [thisApp processIdentifier];
        
        NSLog(@"thisPID = %u", thisPID);
        
        if (![pidFocused objectForKey:@(thisPID)]) {
            NSLog(@"focusing pid %d", thisPID);
            [self focusFirstWindowOfPid:thisPID];
            [pidFocused setObject:@(TRUE) forKey:@(thisPID)];
        }
        CGEventPostToPid([thisApp processIdentifier], event);
    }

#if DEBUG
    NSTimeInterval delta = [startTime timeIntervalSinceNow] * -1.0;
    NSLog(@"processing lag: %f", delta);
#endif

    [self updateUI];
    return event;
}

- (void) setUpEventTaps {
    CGEventMask maskKeyboard = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

    machPortKeyboard = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
                                        maskKeyboard, MyKeyboardEventTapCallBack, self);

    machPortRunLoopSourceRefKeyboard = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPortKeyboard, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);

    NSLog(@"setupEventTaps ran");
}

- (void) shutDownEventTaps {
    if (machPortRunLoopSourceRefKeyboard) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);
        CFRelease(machPortRunLoopSourceRefKeyboard);
    }
    if (machPortKeyboard) {
        CFRelease(machPortKeyboard);
    }
}

// taken from clone keys
- (void) focusFirstWindowOfPid:(pid_t)pid {
    AXUIElementRef appRef = AXUIElementCreateApplication(pid);
    
    if (!appRef)
        return;
    
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
        
        if (titleRef != NULL)
            CFRelease(titleRef);

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

- (void) updateUI {
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
        
        if (isTrusted)
            [self setUpEventTaps];
    }
    
    if (ignoreEvents) {
        toggleButton.title = @"Enable MultiBoxOSX";
        [targetIndicator setDoubleValue:(double)(0)];
        mainWindow.backgroundColor = [NSColor redColor];
    } else {
        [targetIndicator setDoubleValue:(double)(numTargets)];
        if (numTargets >= 1) {
            toggleButton.title = @"Disable MultiBoxOSX";
            mainWindow.backgroundColor = [NSColor greenColor];
        } else {
            toggleButton.title = [NSString stringWithFormat:@"Start %@", MULTIBOXOSX_TARGET_APPLICATION];
            mainWindow.backgroundColor = [NSColor yellowColor];
        }
    }
}

- (IBAction) enableButton:(id)sender {
    ignoreEvents = !ignoreEvents;
    [self updateUI];
}

- (NSString *) stringFromEvent:(CGEventRef)event {
    UniCharCount stringLength = 32;
    UniChar unicodeString[stringLength];
    CGEventKeyboardGetUnicodeString(event, stringLength, &stringLength, unicodeString);
    NSString *uni = [NSString stringWithCharacters:unicodeString length:stringLength];
    return uni;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSLog(@"applicationShouldTerminate");
    [self shutDownEventTaps];
    return NSTerminateNow;
}

- (void) dealloc {
    NSLog(@"dealloc");
    [super dealloc];
}

@end
