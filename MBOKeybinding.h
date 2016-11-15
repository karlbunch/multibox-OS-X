//
//  MBOKeybinding.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import <MASShortcut/Shortcut.h>

typedef NS_ENUM(unsigned short, kMBOKeybindingAction) {
    kMBOKeybindingActionForward = 0,
    kMBOKeybindingActionWhitelist = 1,
    kMBOKeybindingActionIgnore = 2,
    kMBOKeybindingActionToggleForwarding = 3,
};

@interface MBOKeybinding : MASShortcut <NSSecureCoding, NSCopying>

@property (atomic) kMBOKeybindingAction action;
@property (nonatomic) BOOL isBound;

-(NSString *)debugDescription;
-(instancetype)initWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action;
-(instancetype)initWithAction:(kMBOKeybindingAction)action;

+(instancetype)shortcutWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action;
+(instancetype)unboundShortcutWithAction:(kMBOKeybindingAction)action;
+(NSString *)NSStringWithMBOKeybindingAction:(kMBOKeybindingAction)action;

@end
