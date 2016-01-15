//
//  ARTAuth+Private.h
//  ably
//
//  Created by Ricardo Pereira on 03/10/2015.
//  Copyright (c) 2015 Ably. All rights reserved.
//

#import "ARTAuth.h"

ART_ASSUME_NONNULL_BEGIN

@interface ARTAuth (Private)

- (ARTAuthOptions *)mergeOptions:(ARTAuthOptions *)customOptions;
- (ARTAuthTokenParams *)mergeParams:(ARTAuthTokenParams *)customParams;

- (NSURL *)buildURL:(ARTAuthOptions *)options withParams:(ARTAuthTokenParams *)params;
- (NSMutableURLRequest *)buildRequest:(ARTAuthOptions *)options withParams:(ARTAuthTokenParams *)params;

// Execute the received ARTAuthTokenRequest
- (void)executeTokenRequest:(ARTAuthTokenRequest *)tokenRequest callback:(void (^)(ARTAuthTokenDetails *__art_nullable tokenDetails, NSError *__art_nullable error))callback;

// CONNECTED ProtocolMessage may contain a clientId
- (void)setProtocolClientId:(NSString *)clientId;

@end

ART_ASSUME_NONNULL_END
