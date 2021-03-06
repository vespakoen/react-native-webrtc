//
//  WebRTCModule+RTCPeerConnection.m
//
//  Created by one on 2015/9/24.
//  Copyright © 2015 One. All rights reserved.
//

#import "WebRTCModule+RTCPeerConnection.h"

#import "RCTLog.h"
#import "RCTUtils.h"
#import <objc/runtime.h>
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RTCICEServer.h"
#import "RTCPair.h"
#import "RTCMediaConstraints.h"
#import "RTCPeerConnection+Block.h"
#import "RTCICECandidate.h"
#import "WebRTCModule+RTCICEConnectionState.h"
#import "WebRTCModule+RTCICEGatheringState.h"
#import "WebRTCModule+RTCSignalingState.h"
#import "WebRTCModule+RTCMediaStream.h"

@implementation RTCPeerConnection (React)

- (NSNumber *)reactTag
{
  return objc_getAssociatedObject(self, _cmd);
}

- (void)setReactTag:(NSNumber *)reactTag
{
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation WebRTCModule (RTCPeerConnection)

RCT_EXPORT_METHOD(peerConnectionInit:(NSDictionary *)configuration objectID:(nonnull NSNumber *)objectID)
{
  NSArray *iceServers = [self createIceServers:configuration[@"iceServers"]];

  RTCPeerConnection *peerConnection = [self.peerConnectionFactory peerConnectionWithICEServers:iceServers constraints:[self defaultPeerConnectionConstraints] delegate:self];
  peerConnection.reactTag = objectID;
  self.peerConnections[objectID] = peerConnection;
}

RCT_EXPORT_METHOD(peerConnectionAddStream:(nonnull NSNumber *)streamID objectID:(nonnull NSNumber *)objectID)
{
  RTCMediaStream *stream = self.mediaStreams[streamID];
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  BOOL result = [peerConnection addStream:stream];
  NSLog(@"result:%i", result);
}

RCT_EXPORT_METHOD(peerConnectionRemoveStream:(nonnull NSNumber *)streamID objectID:(nonnull NSNumber *)objectID)
{
  RTCMediaStream *stream = self.mediaStreams[streamID];
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection removeStream:stream];
}


RCT_EXPORT_METHOD(peerConnectionCreateOffer:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection createOfferWithCallback:^(RTCSessionDescription *sdp, NSError *error) {
    if (error) {
      callback(@[@(NO),
                 @{@"type": @"CreateOfferFailed", @"message": error.userInfo[@"error"]}
                 ]);
    } else {
      callback(@[@(YES), @{@"sdp": sdp.description, @"type": sdp.type}]);
    }

  } constraints:nil];
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
  return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
  NSArray *mandatoryConstraints = @[
                                    [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                    [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                    ];
  RTCMediaConstraints* constraints =
  [[RTCMediaConstraints alloc]
   initWithMandatoryConstraints:mandatoryConstraints
   optionalConstraints:nil];
  return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
  NSArray *optionalConstraints = @[
                                   [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                   ];
  RTCMediaConstraints* constraints =
  [[RTCMediaConstraints alloc]
   initWithMandatoryConstraints:nil
   optionalConstraints:optionalConstraints];
  return constraints;
}

RCT_EXPORT_METHOD(peerConnectionCreateAnswer:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection createAnswerWithCallback:^(RTCSessionDescription *sdp, NSError *error) {
    if (error) {
      callback(@[@(NO),
                 @{@"type": @"CreateAnsweFailed", @"message": error.userInfo[@"error"]}
                 ]);
    } else {
      callback(@[@(YES), @{@"sdp": sdp.description, @"type": sdp.type}]);
    }

  } constraints:[self defaultAnswerConstraints]];
}

RCT_EXPORT_METHOD(peerConnectionSetLocalDescription:(NSDictionary *)sdpJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
  RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:sdpJSON[@"type"] sdp:sdpJSON[@"sdp"]];
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection setLocalDescriptionWithCallback:^(NSError *error) {
    if (error) {
      id errorResponse = @{@"name": @"SetLocalDescriptionFailed",
                           @"message": error.localizedDescription};
      callback(@[@(NO), errorResponse]);
    } else {
      callback(@[@(YES)]);
    }
  } sessionDescription:sdp];
}
RCT_EXPORT_METHOD(peerConnectionSetRemoteDescription:(NSDictionary *)sdpJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
  RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:sdpJSON[@"type"] sdp:sdpJSON[@"sdp"]];
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection setRemoteDescriptionWithCallback:^(NSError *error) {
    if (error) {
      id errorResponse = @{@"name": @"SetRemoteDescriptionFailed",
                           @"message": error.localizedDescription};
      callback(@[@(NO), errorResponse]);
    } else {
      callback(@[@(YES)]);
    }
  } sessionDescription:sdp];
}

RCT_EXPORT_METHOD(peerConnectionAddICECandidate:(NSDictionary*)candidateJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
  RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:candidateJSON[@"sdpMid"] index:[candidateJSON[@"sdpMLineIndex"] integerValue] sdp:candidateJSON[@"candidate"]];
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  BOOL result = [peerConnection addICECandidate:candidate];
  NSLog(@"addICECandidateresult:%i, %@", result, candidate);
  callback(@[@(result)]);
}

RCT_EXPORT_METHOD(peerConnectionClose:(nonnull NSNumber *)objectID)
{
  RTCPeerConnection *peerConnection = self.peerConnections[objectID];
  [peerConnection close];
  self.peerConnections[objectID] = nil;
}

- (NSArray*)createIceServers:(NSArray*)iceServersConfiguration {
  NSMutableArray *iceServers = [NSMutableArray new];
  if (iceServersConfiguration) {
    for (NSDictionary *iceServerConfiguration in iceServersConfiguration) {
      NSString *url = iceServerConfiguration[@"url"];
      NSString *username = iceServerConfiguration[@"username"];
      if (!username) {
        username = @"";
      }
      NSString *credential = iceServerConfiguration[@"credential"];
      if (!credential) {
        credential = @"";
      }

      RTCICEServer *iceServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url] username:username password:credential];
      [iceServers addObject:iceServer];
    }
  }
  return iceServers;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)newState {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionSignalingStateChanged" body:
   @{@"id": peerConnection.reactTag, @"signalingState": [self stringForSignalingState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
  NSNumber *objectID = @(self.mediaStreamId++);

  stream.reactTag = objectID;

  self.mediaStreams[objectID] = stream;
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedStream" body:
   @{@"id": peerConnection.reactTag, @"streamId": stream.reactTag}];

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {

}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionOnRenegotiationNeeded" body:
   @{@"id": peerConnection.reactTag}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceConnectionChanged" body:
   @{@"id": peerConnection.reactTag, @"iceConnectionState": [self stringForICEConnectionState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceGatheringChanged" body:
   @{@"id": peerConnection.reactTag, @"iceGatheringState": [self stringForICEGatheringState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionGotICECandidate" body:
   @{@"id": peerConnection.reactTag, @"candidate": @{@"candidate": candidate.sdp, @"sdpMLineIndex": @(candidate.sdpMLineIndex), @"sdpMid": candidate.sdpMid}}];
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {

}

@end
