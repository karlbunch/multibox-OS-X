//
//  MBOKeybindingHeaderView.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import "MBOKeybindingHeaderView.h"
#import "MBOKeybinding.h"

@interface MBOKeybindingHeaderView () {
    kMBOKeybindingAction _sectionAction;
}

-(IBAction)sectionRecordKeysButtonClicked:(NSButton *)sender;

@end

@implementation MBOKeybindingHeaderView

-(instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    NSView *view = [self viewWithTag:102];

    if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        [button setTarget:self];
        [button setAction:@selector(sectionRecordKeysButtonClicked:)];
    }

    return self;
}

-(void)prepareForReuse {
    NSView *view = [self viewWithTag:102];

    if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        [button setState:0];
    }
}

-(void)setSectionTitle:(NSString *)title withAction:(kMBOKeybindingAction)action isRecording:(BOOL)isRecording {
    _sectionAction = action;

    NSView *view = [self viewWithTag:101];
    if ([view isKindOfClass:[NSTextField class]]) {
        [(NSTextField *)view setStringValue:title];
    }

    view = [self viewWithTag:102];
    if ([view isKindOfClass:[NSButton class]]) {
        [(NSButton *)view setState:isRecording ? 1 : 0];
    }
}

- (IBAction)sectionRecordKeysButtonClicked:(NSButton *)sender {
    if (sender && [sender isKindOfClass:[NSButton class]]) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kMBO_Notification_RecordKeysButtonClicked
                          object:nil
                        userInfo:@{ @"action": @(_sectionAction), @"state": @([(NSButton *)sender state]) }
        ];
    }
}
@end
