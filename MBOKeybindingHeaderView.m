//
//  MBOKeybindingHeaderView.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import "MBOKeybindingHeaderView.h"

@interface MBOKeybindingHeaderView ()

@end

@implementation MBOKeybindingHeaderView

-(void) setSectionTitle:(NSString *)title {
    for (NSView *view in self.subviews) {
        if ([view isKindOfClass:[NSTextField class]]) {
            [(NSTextField *)view setStringValue:title];
            return;
        }
    }
}

@end
