//
//  MBOKeybinding.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import "MBOKeybinding.h"

static NSString *MBOKeybindingAction = @"Action";
static NSString *MBOKeybindingBound = @"Bound";

@implementation MBOKeybinding

-(instancetype)initWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action {
    self = [super initWithKeyCode:code modifierFlags:flags];

    if (self) {
        self.action = action;
        self.isBound = YES;
    }

    return self;
}

-(instancetype)initWithAction:(kMBOKeybindingAction)action {
    self = [super init];

    if (self) {
        self.action = action;
        self.isBound = NO;
    }

    return self;
}

+(instancetype)shortcutWithKeyCode:(NSUInteger)code modifierFlags:(NSUInteger)flags bindingAction:(kMBOKeybindingAction)action {
    return [[self alloc] initWithKeyCode:code modifierFlags:flags bindingAction:action];
}

+(instancetype)unboundShortcutWithAction:(kMBOKeybindingAction)action {
    return [[self alloc] initWithAction:action];
}

-(NSString *)debugDescription {
    if (self.isBound) {
        return [NSString stringWithFormat:@"[%@ keycode: %lu (%@), modifierFlags: %lu, action: %@]",
                [self className],
                (unsigned long)self.keyCode,
                self.keyCodeString,
                (unsigned long)self.modifierFlags,
                [MBOKeybinding NSStringWithMBOKeybindingAction:self.action]
                ];
    } else {
        return [NSString stringWithFormat:@"[%@ <Unbound>, action: %@]",
                [self className],
                [MBOKeybinding NSStringWithMBOKeybindingAction:self.action]
                ];
    }
}

-(NSDictionary *)toDictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @(self.keyCode), @"keyCode",
            @(self.modifierFlags), @"modifierFlags",
            [MBOKeybinding NSStringWithMBOKeybindingAction:self.action], @"action",
            @(self.isBound), @"isBound",
            nil];
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
    [aCoder encodeBool:self.isBound forKey:MBOKeybindingBound];
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        NSInteger value = [aDecoder decodeIntegerForKey:MBOKeybindingAction];
        self.action = (NSUInteger)(value) % kMBO_MaxKeyCode;
        self.isBound = [aDecoder decodeBoolForKey:MBOKeybindingBound];
    }
    return self;
}

-(NSUInteger)hash {
    return self.keyCode ^ self.modifierFlags ^ self.action ^ self.isBound;
}

-(BOOL)isEqual:(id)anObject {
    if (self == anObject) {
        return YES;
    }

    if ([anObject isKindOfClass:[self class]]) {
        MBOKeybinding *otherKey = (MBOKeybinding *)anObject;

        if (self.keyCode == otherKey.keyCode && self.modifierFlags == otherKey.modifierFlags && self.action == otherKey.action && self.isBound == otherKey.isBound) {
            return YES;
        }
    }

    return NO;
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
