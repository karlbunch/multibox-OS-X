//
//  MBOButtonKeybind.m
//  MultiBoxOSX
//
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

#import "MBOButtonKeybind.h"

@implementation MBOButtonKeybind

-(instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        [self setTarget:self];
        [self setAction:@selector(startKeyBind:)];
    }

    return self;
}

-(void)setDefaultsKeyName:(NSString *)defaultsKeyName {
    _defaultsKeyName = defaultsKeyName;
    NSLog(@"[%@ setDefaultsKeyName]: defaultsKeyName=%@", [self className], self.defaultsKeyName);

    NSString *value = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:self.defaultsKeyName];

    [self setTitle:value];
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *keyStr = [NSString stringWithFormat:@"keycode:%d", theEvent.keyCode];

    [[NSUserDefaults standardUserDefaults] setValue:keyStr forKey:self.defaultsKeyName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[self window] makeFirstResponder:nil];
    [self setTitle:keyStr];

    NSLog(@"[%@ keyDown:%@]: set %@ = %@", [self className], theEvent, self.defaultsKeyName, keyStr);
}

-(void)startKeyBind:(id)sender {
    NSLog(@"startKeyBind %@", self.defaultsKeyName);
    [self setTitle:@"<hit any key>"];
    [[self window] makeFirstResponder:self];
}

@end
