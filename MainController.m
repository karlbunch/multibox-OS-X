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

CGEventRef MyKeyboardEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MainController *mc = (MainController *) refcon;
    return [mc tapKeyboardCallbackWithProxy:proxy type:type event:event];
}
#if MULTIBOXOSX_FORWARD_MOUSE
CGEventRef MyMouseEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MainController *mc = (MainController *) refcon;
    return [mc tapMouseCallbackWithProxy:proxy type:type event:event];
}
#endif // MULTIBOXOSX_FORWARD_MOUSE

@implementation MainController

- (void) awakeFromNib {
    [NSApplication sharedApplication].delegate = self;
    [self setUpEventTaps];
    [self updateUI];
    [mainWindow setMovableByWindowBackground:YES];
}

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
- (CGEventRef) tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event {
    numTargets = 0;

    NSDictionary *currentApp = [[NSWorkspace sharedWorkspace] activeApplication];

    NSLog(@"currentApp=[%@]", (NSString *)[currentApp objectForKey:@"NSApplicationName"]);
    
    if(![(NSString *)[currentApp objectForKey:@"NSApplicationName"] isEqualToString:MULTIBOXOSX_TARGET_APPLICATION]) {
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
    
    if (pidFocused == NULL)
        pidFocused = [[NSMutableDictionary alloc] init];
    
    NSArray *appNames = [[NSWorkspace sharedWorkspace] runningApplications];
    NSDate *startTime = [NSDate date];
    
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

    NSTimeInterval delta = [startTime timeIntervalSinceNow] * -1.0;
    NSLog(@"processing lag: %f", delta);
    [self updateUI];
    return event;
}
#else // MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
- (CGEventRef) tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event {
    numTargets = 0;
    ProcessSerialNumber frontPSN;
    OSErr err = GetFrontProcess(&frontPSN);
    
    if (err) {
        NSLog(@"could not determine current process");
        return event;
    }
    
    if (![self isTargetProcessWithPSN:&frontPSN]) {
        return event;
    }
    
    NSLog(@"%u,%u target in foreground", (unsigned int)frontPSN.highLongOfPSN, (unsigned int)frontPSN.lowLongOfPSN);
    
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
        return event;
    }
    
    NSDate *startTime = [NSDate date];
    ProcessSerialNumber nextPSN = { 0, kNoProcess };
    while (GetNextProcess(&nextPSN) != procNotFound) {
        Boolean same;
        
        // Same as the current process?
        SameProcess(&nextPSN, &frontPSN, &same);
        
        // Skip if same as foreground or if this process isn't a target
        if (same || ![self isTargetProcessWithPSN:&nextPSN]) {
            continue;
        }
        
        //NSLog(@"%u,%u target in background", (unsigned int)frontPSN.highLongOfPSN, (unsigned int)frontPSN.lowLongOfPSN);
        numTargets++;
        
        // Have we already focused the first window of this process?
        SameProcess(&nextPSN, &lastFrontPSN, &same);
        if (!same) {
            NSLog(@"%u,%u foucsFirstWindow", (unsigned int)nextPSN.highLongOfPSN, (unsigned int)nextPSN.lowLongOfPSN);
            pid_t cur_pid;
            GetProcessPID(&nextPSN, &cur_pid);
            NSLog(@"focusing pid %d", cur_pid);
            [self focusFirstWindowOfPid:cur_pid];
            lastFrontPSN = nextPSN;
        }

        CGEventPostToPSN(&nextPSN, event);
    }

    NSTimeInterval delta = [startTime timeIntervalSinceNow] * -1.0;
    NSLog(@"processing lag: %f", delta);
    [self updateUI];
    return event;
}
#endif // MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9

#if MULTIBOXOSX_FORWARD_MOUSE
- (CGEventRef) tapMouseCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event {
    ProcessSerialNumber current;
    OSErr err = GetFrontProcess(&current);
    ProcessSerialNumber psn = { 0, kNoProcess };
    err = 0;
    while ((err = GetNextProcess(&psn)) != procNotFound) {
        Boolean same;
        SameProcess(&psn, &current, &same);
        //NSLog(@"%@ same %d", pn, same);
        if (!same) {
            if ([self isTargetProcessWithPSN:&psn]) {
                SameProcess(&psn, &lastFrontPSN, &same);
                if (!same) {
                    pid_t cur_pid;
                    GetProcessPID(&psn, &cur_pid);
                    //NSLog(@"mouse focusing %d", cur_pid);
                    [self focusFirstWindowOfPid:cur_pid];
                    lastFrontPSN = psn;
                }
            }
        }
    }
    return event;
}

- (NSString *) processNameFromPSN:(ProcessSerialNumber *)psn {
    NSString *pn = nil;
    OSStatus st = CopyProcessName(psn, (CFStringRef *) &pn);
    if (st) {
        NSLog(@"%s could not get process name", __FUNCTION__);
    }
    return pn;
}

- (BOOL) isTargetProcessWithPSN:(ProcessSerialNumber *)psn {
    NSString *pn = [self processNameFromPSN:psn];
    return [pn isEqual:MULTIBOXOSX_TARGET_APPLICATION];
    //return [pn isEqual:@"TextEdit"];
}
#endif // MULTIBOXOSX_FORWARD_MOUSE

- (void) setUpEventTaps {
    CGEventMask maskKeyboard = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

    machPortKeyboard = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
                                        maskKeyboard, MyKeyboardEventTapCallBack, self);

    machPortRunLoopSourceRefKeyboard = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPortKeyboard, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);

#if MULTIBOXOSX_FORWARD_MOUSE
    CGEventMask maskMouse = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown) |
    CGEventMaskBit(kCGEventOtherMouseDown);
    machPortMouse = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
                                     maskMouse, MyMouseEventTapCallBack, self);
    machPortRunLoopSourceRefMouse = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPortMouse, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefMouse, kCFRunLoopDefaultMode);
#endif // MULTIBOXOSX_FORWARD_MOUSE
}

- (void) shutDownEventTaps {
    if (machPortRunLoopSourceRefKeyboard) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefKeyboard, kCFRunLoopDefaultMode);
        CFRelease(machPortRunLoopSourceRefKeyboard);
    }
    if (machPortKeyboard) {
        CFRelease(machPortKeyboard);
    }
#if MULTIBOXOSX_FORWARD_MOUSE
    if (machPortRunLoopSourceRefMouse) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), machPortRunLoopSourceRefMouse, kCFRunLoopDefaultMode);
        CFRelease(machPortRunLoopSourceRefMouse);
    }
    if (machPortMouse) {
        CFRelease(machPortMouse);
    }
#endif // MULTIBOXOSX_FORWARD_MOUSE
}

// taken from clone keys
- (void) focusFirstWindowOfPid:(pid_t)pid {
    AXUIElementRef appRef = AXUIElementCreateApplication(pid);
    
    CFArrayRef winRefs;
    AXUIElementCopyAttributeValues(appRef, kAXWindowsAttribute, 0, 255, &winRefs);
    if (!winRefs) return;
    
    for (int i = 0; i < CFArrayGetCount(winRefs); i++) {
        AXUIElementRef winRef = (AXUIElementRef)CFArrayGetValueAtIndex(winRefs, i);
        CFStringRef titleRef = NULL;
        AXUIElementCopyAttributeValue( winRef, kAXTitleAttribute, (const void**)&titleRef);
        
        char buf[1024];
        buf[0] = '\0';
        if (!titleRef) {
            strcpy(buf, "null");
        }
        if (!CFStringGetCString(titleRef, buf, 1023, kCFStringEncodingUTF8)) return;
        
        if (titleRef != NULL)
            CFRelease(titleRef);
        
        if (strlen(buf) != 0) {
            AXError result = AXUIElementSetAttributeValue(winRef, kAXFocusedAttribute, kCFBooleanTrue);
            // CFRelease(winRef);
            // syslog(LOG_NOTICE, "result %d of setting window %s focus of pid %d", result, buf, pid);
            if (result != 0) {
                // syslog(LOG_NOTICE, "result %d of setting window %s focus of pid %d", result, buf, pid);
            }
            break;
        }
        else {
            // syslog(LOG_NOTICE, "Skipping setting window %s focus of pid %d", buf, pid);
        }
    }
    
    AXUIElementSetAttributeValue(appRef, kAXFocusedApplicationAttribute, kCFBooleanTrue);
    
    CFRelease(winRefs);
    CFRelease(appRef);
}

- (void) updateUI {
    if (ignoreEvents) {
        toggleButton.title = @"Enable MultiBoxOSX";
        mainWindow.backgroundColor = [NSColor redColor];
    } else {
        toggleButton.title = @"Disable MultiBoxOSX";
        [targetIndicator setDoubleValue:(double)(numTargets)];
        if (numTargets > 1) {
            mainWindow.backgroundColor = [NSColor greenColor];
        } else {
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
