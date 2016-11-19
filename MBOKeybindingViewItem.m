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

-(void)prepareForReuse {
    [self.shortcutView setShortcutValueChange:NULL];
    [self.shortcutView setShortcutValue:NULL];
}

-(void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    if ([representedObject isKindOfClass:[MBOKeybinding class]]) {
        MBOKeybinding *originalKey = (MBOKeybinding *)representedObject;
        kMBOKeybindingAction thisAction = originalKey.action;

        [self.shortcutView setShortcutValidator:[MBOShortcutValidator sharedValidator]];

        if (originalKey.isBound) {
            [self.shortcutView setShortcutValue:[MASShortcut shortcutWithKeyCode:originalKey.keyCode modifierFlags:originalKey.modifierFlags]];
        }

        [self.shortcutView setShortcutValueChange:^(MASShortcutView *sender) {
            MainController *mainController = (MainController *)[[NSApplication sharedApplication] delegate];
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
                        [mainController removeKeyBinding:originalKey];
                    }
                    [mainController addKeyBinding:newKey];
                }
            } else {
                NSLog(@"keyBinding Deleted: %@", originalKey.debugDescription);
                [mainController removeKeyBinding:originalKey];
            }
        }];
    }
}

@end
