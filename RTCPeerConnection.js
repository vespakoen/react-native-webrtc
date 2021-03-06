'use strict';

var React = require('react-native');
var {
  DeviceEventEmitter,
  NativeModules,
} = React;
var WebRTCModule = NativeModules.WebRTCModule;

var RTCSessionDescription = require('./RTCSessionDescription');
var RTCIceCandidate = require('./RTCIceCandidate');
var RTCMediaStream = require('./RTCMediaStream');
var RTCIceCandidateEvent = require('./RTCIceCandidateEvent');
var MediaStreamEvent = require('./MediaStreamEvent');
var RTCEvent = require('./RTCEvent');

var RTCPeerConnectionBase = require('./RTCPeerConnectionBase');

var PeerConnectionId = 0;

class RTCPeerConnection extends RTCPeerConnectionBase {
  _peerConnectionId: number;
  _subs: any;

  constructorImpl(configuration) {
    this._peerConnectionId = PeerConnectionId++;
    WebRTCModule.peerConnectionInit(configuration, this._peerConnectionId);
    this._registerEvents(this._peerConnectionId);
  }
  addStreamImpl(stream) {
    WebRTCModule.peerConnectionAddStream(stream._streamId, this._peerConnectionId);
  }
  removeStreamImpl(stream) {
    WebRTCModule.peerConnectionRemoveStream(stream._streamId, this._peerConnectionId);
  }
  createOfferImpl(success: ?Function, failure: ?Function, constraints) {
    WebRTCModule.peerConnectionCreateOffer(this._peerConnectionId, (successful, data) => {
      if (successful) {
        var sessionDescription = new RTCSessionDescription(data);
        success(sessionDescription);
      } else {
        failure(data); // TODO: convert to NavigatorUserMediaError
      }
    });
  }
  createAnswerImpl(success: ?Function, failure: ?Function, constraints) {
    WebRTCModule.peerConnectionCreateAnswer(this._peerConnectionId, (successful, data) => {
      if (successful) {
        var sessionDescription = new RTCSessionDescription(data);
        success(sessionDescription);
      } else {
        failure(data);
      }
    });
  }
  setLocalDescriptionImpl(sessionDescription: RTCSessionDescription, success: ?Function, failure: ?Function, constraints) {
    WebRTCModule.peerConnectionSetLocalDescription(sessionDescription.toJSON(), this._peerConnectionId, (successful, data) => {
      if (successful) {
        this.localDescription = sessionDescription;
        success();
      } else {
        failure(data);
      }
    });
  }
  setRemoteDescriptionImpl(sessionDescription: RTCSessionDescription, success: ?Function, failure: ?Function) {
    WebRTCModule.peerConnectionSetRemoteDescription(sessionDescription.toJSON(), this._peerConnectionId, (successful, data) => {
      if (successful) {
        this.remoteDescription = sessionDescription;
        success();
      } else {
        failure(data);
      }
    });
  }
  addIceCandidateImpl(candidate, success, failure) { // TODO: success, failure
    WebRTCModule.peerConnectionAddICECandidate(candidate.toJSON(), this._peerConnectionId, (successful) => {
      if (successful) {
        success && success();
      } else {
        failure && failure();
      }
    });
  }
  closeImpl() {
    WebRTCModule.peerConnectionClose(this._peerConnectionId);
  }
  _registerEvents(id: number): void {
    this._subs = [
      DeviceEventEmitter.addListener('peerConnectionOnRenegotiationNeeded', ev => {
        if (ev.id !== id) {
          return;
        }
        this.onnegotiationneeded && this.onnegotiationneeded();
      }),
      DeviceEventEmitter.addListener('peerConnectionIceConnectionChanged', ev => {
        if (ev.id !== id) {
          return;
        }
        this.iceConnectionState = ev.iceConnectionState;
        var event = new RTCEvent('iceconnectionstatechange', {target: this});
        this.oniceconnectionstatechange && this.oniceconnectionstatechange(event);
      }),
      DeviceEventEmitter.addListener('peerConnectionSignalingStateChanged', ev => {
        if (ev.id !== id) {
          return;
        }
        this.signalingState = ev.signalingState;
        var event = new RTCEvent('signalingstatechange', {target: this});
        this.onsignalingstatechange && this.onsignalingstatechange(event);
      }),
      DeviceEventEmitter.addListener('peerConnectionAddedStream', ev => {
        if (ev.id !== id) {
          return;
        }
        var stream = new RTCMediaStream(ev.streamId);
        var event = new MediaStreamEvent('addstream', {target: this, stream: stream});
        this.onaddstream && this.onaddstream(event);
      }),
      DeviceEventEmitter.addListener('peerConnectionGotICECandidate', ev => {
        if (ev.id !== id) {
          return;
        }
        var candidate = new RTCIceCandidate(ev.candidate);
        var event = new RTCIceCandidateEvent('icecandidate', {target: this, candidate: candidate});
        this.onicecandidate && this.onicecandidate(event);
      }),
      DeviceEventEmitter.addListener('peerConnectionIceGatheringChanged', ev => {
        if (ev.id !== id) {
          return;
        }
        this.iceGatheringState = ev.iceGatheringState;
        var event = new RTCEvent('icegatheringstatechange', {target: this});
        this.onicegatheringstatechange && this.onicegatheringstatechange(event);
      })
    ];
  }
}

module.exports = RTCPeerConnection;
