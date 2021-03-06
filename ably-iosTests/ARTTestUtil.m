//
//  ARTTestUtil.m
//  ably-ios
//
//  Created by Jason Choy on 10/12/2014.
//  Copyright (c) 2014 Ably. All rights reserved.
//

#import "ARTTestUtil.h"
#import <XCTest/XCTest.h>

#import "ARTRest.h"
#import "ARTRealtime.h"
#import "ARTRealtimeChannel.h"
#import "ARTRealtimePresence.h"
#import "ARTDataEncoder.h"
#import "ARTProtocolMessage.h"
#import "ARTEventEmitter.h"
#import "ARTURLSessionServerTrust.h"

void waitForWithTimeout(NSUInteger *counter, NSArray *list, NSTimeInterval timeout) {
    NSTimeInterval limitInterval = [[[NSDate date] dateByAddingTimeInterval:timeout] timeIntervalSince1970];
    while (*counter != list.count && [[NSDate date] timeIntervalSince1970] < limitInterval) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
    }
}

@implementation ARTTestUtil

+ (ARTCipherDataEncoder *)getTestCipherEncoder {
    ARTCipherDataEncoder *e = nil;
    return e;
}

+ (NSString *)getFileByName:(NSString *)name {
    NSString *path =[[[[NSBundle bundleForClass: [self class]] resourcePath] stringByAppendingString:@"/"] stringByAppendingString:name];
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

+ (NSString *)getErrorsJson {
    return [ARTTestUtil getFileByName:@"ably-common/protocol/errors.json"];
}

+ (NSString *)getTestAppSetupJson {
    return [ARTTestUtil getFileByName:@"ably-common/test-resources/test-app-setup.json"];
}

+ (void)setupApp:(ARTClientOptions *)options withDebug:(BOOL)debug withAlteration:(TestAlteration)alt  appId:(NSString *)appId cb:(void (^)(ARTClientOptions *))cb {
    NSString *str = [ARTTestUtil getTestAppSetupJson];
    if (str == nil) {
        [NSException raise:@"error getting test-app-setup.json loaded. Maybe ably-common is missing" format:@""];
    }
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *topLevel = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    
    NSDictionary *d = [topLevel objectForKey:@"post_apps"];
    NSData *appSpecData = [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
     
    if (alt == TestAlterationBadWsHost) {
        options.environment = @"test";
    }
    else {
        options.environment = @"sandbox";
    }
    options.useBinaryProtocol = NO;
    if (debug) {
        options.logLevel = ARTLogLevelVerbose;
    }

    NSString *urlStr = [NSString stringWithFormat:@"https://%@:%ld/apps", options.restHost, (long)options.tlsPort];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = appSpecData;
    
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    if (debug) {
        NSLog(@"Creating test app. URL: %@, Method: %@, Body: %@, Headers: %@", req.URL, req.HTTPMethod, [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding], req.allHTTPHeaderFields);
    }

    __block CFRunLoopRef rl = CFRunLoopGetCurrent();
    
    [[[ARTURLSessionServerTrust alloc] init] get:req completion:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
            NSLog(@"Status Code: %ld", (long)response.statusCode);
            NSLog(@"Body: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            cb(nil);
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json) {
            NSLog(@"No response");
            return;
        }
        else if (debug) {
            NSLog(@"Response: %@", json);
        }

        NSDictionary *key = json[@"keys"][(alt == TestAlterationRestrictCapability ? 1 :0)];

        ARTClientOptions *testOptions = [options copy];

        // TODO: assign key[@"capability"]

        testOptions.key = key[@"keyStr"];

        if (alt == TestAlterationBadKeyId || alt == TestAlterationBadKeyValue)
        {
            testOptions.key = @"badKey";
        }

        CFRunLoopPerformBlock(rl, kCFRunLoopDefaultMode, ^{
            cb(testOptions);
        });
        CFRunLoopWakeUp(rl);
    }];
}

+ (void)setupApp:(ARTClientOptions *)options withDebug:(BOOL)debug withAlteration:(TestAlteration)alt cb:(void (^)(ARTClientOptions *))cb {
    [ARTTestUtil setupApp:options withDebug:debug withAlteration:alt appId:nil cb:cb];
}

+ (void)setupApp:(ARTClientOptions *)options withAlteration:(TestAlteration)alt cb:(void (^)(ARTClientOptions *))cb {
    [ARTTestUtil setupApp:options withDebug:NO withAlteration:alt cb:cb];
}

+ (void)setupApp:(ARTClientOptions *)options withDebug:(BOOL)debug cb:(void (^)(ARTClientOptions *))cb {
    [ARTTestUtil setupApp:options withDebug:debug withAlteration:TestAlterationNone cb:cb];
}

+ (void)setupApp:(ARTClientOptions *)options cb:(void (^)(ARTClientOptions *))cb {
    [ARTTestUtil setupApp:options withDebug:NO withAlteration:TestAlterationNone cb:cb];
}

+ (ARTClientOptions *)clientOptions {
    ARTClientOptions* options = [[ARTClientOptions alloc] init];
    options.environment = @"sandbox";
    options.useBinaryProtocol = false;
    return options;
}

+ (void)repeat:(int)count delay:(NSTimeInterval)delay block:(void (^)(int))block {
    [ARTTestUtil repeat:count i:0 delay:delay block:block];
}

+ (void)repeat:(int)count i:(int)i delay:(NSTimeInterval)delay block:(void (^)(int))block {
    if (count == 0) {
        return;
    }
    block(i);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ARTTestUtil repeat:(count - 1) i:(i + 1) delay:delay block:block];
    });
}

+ (long long)nowMilli {
    NSDate *date = [NSDate date];
    return [date timeIntervalSince1970]*1000;
}

+ (float)smallSleep {
    return 0.6;
}

+ (float)bigSleep {
    return 1.0;
}

+ (float)timeout {
    return 120.0;
}

+ (void)publishRestMessages:(NSString *)prefix count:(int)count channel:(ARTChannel *)channel completion:(void (^)())completion {
    NSString *pattern = [prefix stringByAppendingString:@"%d"];
    __block int numReceived = 0;
    __block __weak void (^weakCallback)(ARTErrorInfo *__art_nullable error);
    void (^callback)(ARTErrorInfo *__art_nullable error);

    weakCallback = callback = ^(ARTErrorInfo *error) {
        if (++numReceived != count) {
            [channel publish:nil data:[NSString stringWithFormat:pattern, numReceived] cb:weakCallback];
        }
        else {
            completion();
        }
    };

    [channel publish:nil data:[NSString stringWithFormat:pattern, numReceived] cb:callback];
}

+ (void)publishRealtimeMessages:(NSString *)prefix count:(int)count channel:(ARTRealtimeChannel *)channel completion:(void (^)())completion {
    __block int numReceived = 0;
    __block __weak void (^weakCb)(ARTErrorInfo *__art_nullable error);
    NSString * pattern = [prefix stringByAppendingString:@"%d"];
    void (^cb)(ARTErrorInfo *__art_nullable error);
    
    weakCb = cb = ^(ARTErrorInfo *errorInfo) {
        ++numReceived;
        if(numReceived !=count) {
            [channel publish:nil data:[NSString stringWithFormat:pattern, numReceived] cb:weakCb];
        }
        else {
            completion();
        }
    };
    [channel publish:nil data:[NSString stringWithFormat:pattern, numReceived] cb:cb];
    
}

+ (void)publishEnterMessages:(NSString *)clientIdPrefix count:(int)count channel:(ARTRealtimeChannel *)channel completion:(void (^)())completion {
    __block int numReceived = 0;
   __block __weak void (^weakCb)(ARTErrorInfo *__art_nullable error);
    void (^cb)(ARTErrorInfo *__art_nullable error);

    NSString *pattern = [clientIdPrefix stringByAppendingString:@"%d"];
    weakCb = cb = ^(ARTErrorInfo *errorInfo) {
        ++numReceived;
        if (numReceived != count) {
            [channel.presence enterClient:[NSString stringWithFormat:pattern, numReceived] data:@"entered" cb:weakCb];
        }
        else {
            completion();
        }
    };
    [channel.presence enterClient:[NSString stringWithFormat:pattern, numReceived] data:@"" cb:weakCb];
}

+ (void)testRest:(ARTRestConstructorCb)cb {
    [ARTTestUtil setupApp:[ARTTestUtil clientOptions] cb:^(ARTClientOptions *options) {
        ARTRest *rest = [[ARTRest alloc] initWithOptions:options];
        cb(rest);
    }];
}

+ (void)testRealtime:(ARTClientOptions *)options callback:(ARTRealtimeConstructorCb)cb {
    [ARTTestUtil setupApp:options cb:^(ARTClientOptions *options) {
        ARTRealtime *realtime = [[ARTRealtime alloc] initWithOptions:options];
        cb(realtime);
    }];
}

+ (void)testRealtime:(ARTRealtimeConstructorCb)cb {
    [ARTTestUtil setupApp:[ARTTestUtil clientOptions] cb:^(ARTClientOptions *options) {
        ARTRealtime *realtime = [[ARTRealtime alloc] initWithOptions:options];
        cb(realtime);
    }];
}

+ (void)testRealtimeV2:(XCTestCase *)testCase withDebug:(BOOL)debug callback:(ARTRealtimeTestCallback)callback {
    XCTestExpectation *expectation = [testCase expectationWithDescription:@"testRealtime"];
    [ARTTestUtil setupApp:[ARTTestUtil clientOptions] withDebug:debug cb:^(ARTClientOptions *options) {
        ARTRealtime *realtime = [[ARTRealtime alloc] initWithOptions:options];
        [realtime.connection on:^(ARTConnectionStateChange *stateChange) {
            ARTRealtimeConnectionState state = stateChange.current;
            ARTErrorInfo *errorInfo = stateChange.reason;
            if (state == ARTRealtimeFailed) {
                // FIXME: XCTFail not working outside a XCTestCase method!
                if (errorInfo) {
                    //XCTFail(@"%@", errorInfo);
                    NSLog(@"Realtime connection failed: %@", errorInfo);
                }
                else {
                    //XCTFail();
                    NSLog(@"Realtime connection failed");
                }
                [expectation fulfill];
            }
            else
                callback(realtime, state, expectation);
        }];
    }];
    [testCase waitForExpectationsWithTimeout:[ARTTestUtil timeout] handler:nil];
}

+ (ARTProtocolMessage *)newErrorProtocolMessage {
    ARTProtocolMessage* protocolMessage = [[ARTProtocolMessage alloc] init];
    protocolMessage.action = ARTProtocolMessageError;
    protocolMessage.error = [ARTErrorInfo createWithCode:0 message:@"Fail test"];
    return protocolMessage;
}

+ (void)removeAllChannels:(ARTRealtime *)realtime {
    NSMutableArray *names = [[NSMutableArray alloc] init];
    for (ARTRealtimeChannel *channel in realtime.channels) {
        [names addObject:channel.name];
    }
    for (NSString *name in names) {
        [realtime.channels release:name];
    }
}

+ (void)convertException:(void (^)())block error:(NSError *__autoreleasing  _Nullable *)error {
    @try {
        block();
        [NSException raise:NSInvalidArgumentException format:@"exception not thrown"];
    }
    @catch (NSException *exception) {
        *error = [NSError errorWithDomain:ARTAblyErrorDomain code:0 userInfo:@{NSLocalizedFailureReasonErrorKey:exception.reason}];
    }
}

@end
