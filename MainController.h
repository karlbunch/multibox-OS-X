//
//  MainController.h
//  MultiBoxOSX
//
//  Created by dirk on 4/25/09.
//  Copyright 2009 Dirk Zimmermann. All rights reserved.
//  Copyright 2016 Karl Bunch.
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

#define MULTIBOXOSX_FORWARD_MOUSE 0  // Not sure if these even work, if you enable you will need to fix it!

@interface MainController : NSObject<NSApplicationDelegate> {

	IBOutlet NSButton *toggleButton;
    IBOutlet NSLevelIndicator *targetIndicator;
	IBOutlet NSWindow *mainWindow;

	CFMachPortRef machPortKeyboard;
	CFRunLoopSourceRef machPortRunLoopSourceRefKeyboard;

#if MULTIBOXOSX_FORWARD_MOUSE
    CFMachPortRef machPortMouse;
	CFRunLoopSourceRef machPortRunLoopSourceRefMouse;
#endif // MULTIBOXOSX_FORWARD_MOUSE
    
	BOOL ignoreEvents;
    int numTargets;
	ProcessSerialNumber lastFrontPSN;
}

- (CGEventRef) tapKeyboardCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event;
#if MULTIBOXOSX_FORWARD_MOUSE
- (CGEventRef) tapMouseCallbackWithProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event;
#endif // MULTIBOXOSX_FORWARD_MOUSE
- (void) setUpEventTaps;
- (void) shutDownEventTaps;
- (NSString *) processNameFromPSN:(ProcessSerialNumber *)psn;
//- (void) cycleThroughProcesses;

// returns YES if this PSN belongs to an application that we should target
- (BOOL) isTargetProcessWithPSN:(ProcessSerialNumber *)psn;

// taken from clone keys
- (void) focusFirstWindowOfPid:(pid_t)pid;

- (NSString *) stringFromEvent:(CGEventRef)event;

- (void) updateUI;
- (IBAction) enableButton:(id)sender;

@end
