//
//  ARTRealtimePresence.m
//  ably
//
//  Created by Ricardo Pereira on 12/11/15.
//  Copyright © 2015 Ably. All rights reserved.
//

#import "ARTRealtimePresence.h"

#import "ARTRealtime.h"
#import "ARTRealtimeChannel+Private.h"
#import "ARTPresenceMap.h"
#import "ARTPresenceMessage.h"
#import "ARTStatus.h"
#import "ARTPresence+Private.h"

@implementation ARTRealtimePresence

- (instancetype)initWithChannel:(ARTRealtimeChannel *)channel {
    return [super initWithChannel:channel];
}

- (ARTRealtimeChannel *)channel {
    return (ARTRealtimeChannel *)super.channel;
}

- (void)get:(ARTRealtimePresenceQuery *)query cb:(void (^)(ARTPaginatedResult<ARTPresenceMessage *> * _Nullable, NSError * _Nullable))callback {
    [[self channel] throwOnDisconnectedOrFailed];
    [super get:query cb:callback];
}

- (void)history:(void (^)(__GENERIC(ARTPaginatedResult, ARTPresenceMessage *) *, NSError *))callback {
    [self history:[[ARTRealtimeHistoryQuery alloc] init] callback:callback error:nil];
}

- (BOOL)history:(ARTRealtimeHistoryQuery *)query callback:(void (^)(__GENERIC(ARTPaginatedResult, ARTPresenceMessage *) *, NSError *))callback error:(NSError **)errorPtr {
    return [super history:query callback:callback error:errorPtr];
}

- (void)enter:(id)data {
    [self enter:data cb:nil];
}

- (void)enter:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    [self enterClient:[self channel].clientId data:data cb:cb];
}

- (void)enterClient:(NSString *)clientId data:(id)data {
    [self enterClient:clientId data:data cb:nil];
}

- (void)enterClient:(NSString *)clientId data:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    if(!clientId) {
        if (cb) cb([ARTErrorInfo createWithCode:ARTStateNoClientId message:@"attempted to publish presence message without clientId"]);
        return;
    }
    ARTPresenceMessage *msg = [[ARTPresenceMessage alloc] init];
    msg.action = ARTPresenceEnter;
    msg.clientId = clientId;
    msg.data = data;

    msg.connectionId = [self channel].realtime.connection.id;
    [[self channel] publishPresence:msg cb:cb];
}

- (void)update:(id)data {
    [self update:data cb:nil];
}

- (void)update:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    [self updateClient:[self channel].clientId data:data cb:cb];
}

- (void)updateClient:(NSString *)clientId data:(id)data {
    [self updateClient:clientId data:data cb:nil];
}

- (void)updateClient:(NSString *)clientId data:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    if (!clientId) {
        if (cb) cb([ARTErrorInfo createWithCode:ARTStateNoClientId message:@"attempted to publish presence message without clientId"]);
        return;
    }
    ARTPresenceMessage *msg = [[ARTPresenceMessage alloc] init];
    msg.action = ARTPresenceUpdate;
    msg.clientId = clientId;
    msg.data = data;
    msg.connectionId = [self channel].realtime.connection.id;

    [[self channel] publishPresence:msg cb:cb];
}

- (void)leave:(id)data {
    [self leave:data cb:nil];
}

- (void)leave:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    [self leaveClient:[self channel].clientId data:data cb:cb];
}

- (void)leaveClient:(NSString *)clientId data:(id)data {
    [self leaveClient:clientId data:data cb:nil];
}

- (void)leaveClient:(NSString *)clientId data:(id)data cb:(void (^)(ARTErrorInfo * _Nullable))cb {
    if (!clientId) {
        if (cb) cb([ARTErrorInfo createWithCode:ARTStateNoClientId message:@"attempted to publish presence message without clientId"]);
        return;
    }
    if([clientId isEqualToString:[self channel].clientId]) {
        if([self channel].lastPresenceAction != ARTPresenceEnter && [self channel].lastPresenceAction != ARTPresenceUpdate) {
            [NSException raise:@"Cannot leave a channel before you've entered it" format:@""];
        }
    }
    ARTPresenceMessage *msg = [[ARTPresenceMessage alloc] init];
    msg.action = ARTPresenceLeave;
    msg.data = data;
    msg.clientId = clientId;
    msg.connectionId = [self channel].realtime.connection.id;
    [[self channel] publishPresence:msg cb:cb];
}

- (BOOL)isSyncComplete {
    return [[self channel].presenceMap isSyncComplete];
}

- (ARTEventListener<ARTPresenceMessage *> *)subscribe:(void (^)(ARTPresenceMessage * _Nonnull))cb {
    [[self channel] attach];
    return [[self channel].presenceEventEmitter on:cb];
}

- (ARTEventListener<ARTPresenceMessage *> *)subscribe:(ARTPresenceAction)action cb:(void (^)(ARTPresenceMessage * _Nonnull))cb {
    [[self channel] attach];
    return [[self channel].presenceEventEmitter on:[NSNumber numberWithUnsignedInteger:action] call:cb];
}

- (void)unsubscribe {
    [[self channel].presenceEventEmitter off];
}

- (void)unsubscribe:(ARTEventListener<ARTPresenceMessage *> *)listener {
    [[self channel].presenceEventEmitter off:listener];
}

- (void)unsubscribe:(ARTPresenceAction)action listener:(ARTEventListener<ARTPresenceMessage *> *)listener {
    [[self channel].presenceEventEmitter off:[NSNumber numberWithUnsignedInteger:action] listener:listener];
}

@end
