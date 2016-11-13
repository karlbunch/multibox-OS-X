//
//  MBOKeybinding.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import "MBOKeybinding.h"

static NSString *MBOKeybindingAction = @"Action";

@implementation MBOKeybinding

-(instancetype)initWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action {
    self = [super init];

    if (self) {
        [super initWithKeyCode:code modifierFlags:flags];
        self.action = action;
    }

    return self;
}

+(instancetype)shortcutWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action {
    return [[self alloc] initWithKeyCode:code modifierFlags:flags bindingAction:action];
}

-(NSString *)debugDescription {
    return [NSString stringWithFormat:@"[%@ keycode: %lu (%@), modifierFlags: %lu, action: %@]",
            [self className],
            (unsigned long)self.keyCode,
            self.keyCodeString,
            (unsigned long)self.modifierFlags,
            [MBOKeybinding NSStringWithMBOKeybindingAction:self.action]
    ];
}

+(NSString *)NSStringWithMBOKeybindingAction:(kMBOKeybindingAction)action {
    switch (action) {
        case kMBOKeybindingActionForward: return @"Forward";
        case kMBOKeybindingActionWhitelist: return @"Whitelist";
        case kMBOKeybindingActionIgnore: return @"Ignore";
        case kMBOKeybindingActionToggleForwarding: return @"Pause";
    }

    return [NSString stringWithFormat:@"unkown kMBOKeybindingAction(%d)", action];
}

#pragma mark NSCoding

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeInteger:self.action forKey:MBOKeybindingAction];
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        [super initWithCoder:aDecoder];
        
        NSInteger value = [aDecoder decodeIntegerForKey:MBOKeybindingAction];

        self.action = (NSUInteger)(value) % kMBO_MaxKeyCode;
    }
    return self;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark NSCopying

-(id)copyWithZone:(NSZone *)zone {
    MBOKeybinding *copy = [super copyWithZone:zone];

    copy.action = self.action;

    return copy;
}

@end
