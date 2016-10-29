//
//  MBOButtonKeybind.h
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

#import <Cocoa/Cocoa.h>

@interface MBOButtonKeybind : NSButton

@property (nonatomic, assign) IBInspectable NSString *defaultsKeyName;

@end
