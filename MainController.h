//
//  MainController.h
//  MultiBoxOSX
//
//  Created by dirk on 4/25/09.
//  Copyright 2009 Dirk Zimmermann. All rights reserved.
//  Copyright 2016 Karl Bunch.
//
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
#import <MASShortcut/Shortcut.h>
#import "MBOKeybinding.h"
#import "MBOPreferencesWindowController.h"

@interface MainController : NSObject <NSApplicationDelegate>
@property (nonatomic, weak) NSString *targetApplication;
@property (nonatomic, weak) NSString *targetAppPath;
@property (nonatomic, weak) NSArray *favoriteLayout;
@property (nonatomic, weak) NSDictionary *keyBindingsDictionaryRepresentation;

- (IBAction)enableButtonClicked:(id)sender;
- (IBAction)levelIndicatorClicked:(id)sender;
- (IBAction)menuActionPreferences:(id)sender;
-(void)preferencesWindowWillClose:(id)sender;
-(void)addKeyBinding:(MBOKeybinding *)newKey;
-(void)removeKeyBinding:(MBOKeybinding *)originalKey;

@end
