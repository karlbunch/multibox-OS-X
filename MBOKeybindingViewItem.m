//
//  MBOKeybindingViewItem.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import "MainController.h"
#import "MBOKeybindingViewItem.h"
#import "MBOShortcutValidator.h"

@implementation MBOKeybindingViewItem

-(void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    if ([representedObject isKindOfClass:[MBOKeybinding class]]) {
        MBOKeybinding *originalKey = (MBOKeybinding *)representedObject;
        kMBOKeybindingAction thisAction = originalKey.action;

        // Watch out for view reuse, reset prior settings
        [self.shortcutView setShortcutValueChange:NULL];
        [self.shortcutView setShortcutValue:NULL];
        [self.shortcutView setShortcutValidator:[MBOShortcutValidator sharedValidator]];

        if (originalKey.isBound) {
            [self.shortcutView setShortcutValue:[MASShortcut shortcutWithKeyCode:originalKey.keyCode modifierFlags:originalKey.modifierFlags]];
        }

        [self.shortcutView setShortcutValueChange:^(MASShortcutView *sender) {
            MainController *mainController = (MainController *)[[NSApplication sharedApplication] delegate];
            NSMapTable *newBindings = [mainController.keyBindings copy];
            MASShortcut *shortCut = sender.shortcutValue;

            if (shortCut != nil) {
                if (originalKey.isBound == NO || shortCut.keyCode != originalKey.keyCode || shortCut.modifierFlags != originalKey.modifierFlags) {
                    NSUInteger modifierFlags = shortCut.modifierFlags;
                    if (thisAction == kMBOKeybindingActionToggleForwarding) {
                        modifierFlags = 0;
                    }
                    MBOKeybinding *newKey = [MBOKeybinding shortcutWithKeyCode:shortCut.keyCode modifierFlags:modifierFlags bindingAction:thisAction];
                    NSLog(@"keyBinding Changed: %@ => %@", originalKey.debugDescription, newKey.debugDescription);
                    if (originalKey.isBound) {
                        [newBindings removeObjectForKey:@(originalKey.keyCode)];
                    }
                    [newBindings setObject:newKey forKey:@(newKey.keyCode)];
                }
            } else {
                NSLog(@"keyBinding Deleted: %@", originalKey.debugDescription);
                [newBindings removeObjectForKey:@(originalKey.keyCode)];
            }

            [mainController setKeyBindings:newBindings];
        }];
    }
}

@end
