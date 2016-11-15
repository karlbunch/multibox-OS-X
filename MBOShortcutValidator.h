//
//  MBOShortcutValidator.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/15/16.
//
//

#import <MASShortcut/Shortcut.h>

@interface MBOShortcutValidator : MASShortcutValidator

+ (instancetype) sharedValidator;

- (BOOL) isShortcutValid: (MASShortcut*) shortcut;
- (BOOL) isShortcutAlreadyTakenBySystem: (MASShortcut*) shortcut explanation: (NSString**) explanation;

@end
