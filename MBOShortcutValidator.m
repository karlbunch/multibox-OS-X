//
//  MBOShortcutValidator.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/15/16.
//
//

#import "MBOShortcutValidator.h"

@implementation MBOShortcutValidator

+ (instancetype) sharedValidator {
    static dispatch_once_t once;
    static MBOShortcutValidator *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (BOOL) isShortcutValid: (MASShortcut*) shortcut {
    return YES;
}

- (BOOL) isShortcutAlreadyTakenBySystem: (MASShortcut*) shortcut explanation: (NSString**) explanation {
    return NO;
}

@end
