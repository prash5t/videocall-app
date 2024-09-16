import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String userEmail;
  final String otherUserEmail;
  final IO.Socket socket;

  const VideoCallScreen({
    Key? key,
    required this.callId,
    required this.userEmail,
    required this.otherUserEmail,
    required this.socket,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _localStreamReady = false;
  bool _remoteStreamReady = false;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    print("Initializing call...");
    await _initRenderers();
    await _handlePermissions();
  }

  Future<void> _initRenderers() async {
    print("Initializing renderers...");
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    print("Renderers initialized");
  }

  Future<void> _handlePermissions() async {
    print("Handling permissions...");
    final status = await _requestPermissions();
    print("Permission status: $status");
    if (status) {
      await _initLocalStream();
      await _createPeerConnection();
      _setupSocketListeners();
    } else {
      print("Permissions not granted, returning to previous screen");
      Navigator.of(context).pop();
    }
  }

  Future<bool> _requestPermissions() async {
    print("Requesting permissions...");
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    print("Camera status: ${statuses[Permission.camera]}");
    print("Microphone status: ${statuses[Permission.microphone]}");

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      return true;
    } else if (statuses[Permission.camera]!.isPermanentlyDenied ||
        statuses[Permission.microphone]!.isPermanentlyDenied) {
      _showOpenSettingsDialog();
      return false;
    } else {
      return false;
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions Required'),
          content: Text(
              'Camera and microphone permissions are permanently denied. Please enable them in your device settings to use video calls.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initLocalStream() async {
    print("Initializing local stream...");
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    _localRenderer.srcObject = _localStream;
    setState(() {
      _localStreamReady = true;
    });
    print("Local stream initialized");
  }

  void _setupSocketListeners() {
    print("Setting up socket listeners...");
    widget.socket.on('ice_candidate', (data) async {
      print("Received ICE candidate");
      if (data['target_email'] == widget.userEmail) {
        await _peerConnection?.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      }
    });

    widget.socket.on('offer', (data) async {
      print("Received offer");
      if (data['target_email'] == widget.userEmail) {
        try {
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
          );
          final answer = await _peerConnection?.createAnswer();
          await _peerConnection?.setLocalDescription(answer!);
          widget.socket.emit('answer', {
            'target_email': widget.otherUserEmail,
            'sdp': answer?.toMap(),
          });
        } catch (e) {
          print("Error setting remote description: $e");
        }
      }
    });

    widget.socket.on('answer', (data) async {
      print("Received answer");
      if (data['target_email'] == widget.userEmail) {
        try {
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
          );
        } catch (e) {
          print("Error setting remote description: $e");
        }
      }
    });

    widget.socket.on('call_ended', (data) {
      print("Call ended");
      Navigator.of(context).pop();
    });
  }

  Future<void> _createPeerConnection() async {
    print("Creating peer connection...");
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config, {});

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onIceCandidate = (candidate) {
      print("Sending ICE candidate");
      widget.socket.emit('ice_candidate', {
        'target_email': widget.otherUserEmail,
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection?.onTrack = (event) {
      print("Received remote track: ${event.track.kind}");
      if (event.track.kind == 'video') {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
          _remoteStreamReady = true;
        });
      }
    };

    // Only create and send offer if this is the caller
    if (widget.userEmail == widget.callId.split('_')[0]) {
      print("Creating and sending offer");
      final offer = await _peerConnection?.createOffer();
      await _peerConnection?.setLocalDescription(offer!);
      widget.socket.emit('offer', {
        'target_email': widget.otherUserEmail,
        'sdp': offer?.toMap(),
      });
    }
    print("Peer connection created");
  }

  void _endCall() {
    print("Ending call");
    widget.socket.emit('end_call', {
      'target_email': widget.otherUserEmail,
      'call_id': widget.callId,
      'caller_email': widget.userEmail,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Call')),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Stack(
            children: [
              Positioned.fill(
                child: _remoteStreamReady
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Center(child: CircularProgressIndicator()),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: Container(
                  width: 100,
                  height: 150,
                  child: _localStreamReady
                      ? RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(color: Colors.black),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _endCall,
                    child: Text('End Call'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    print("Disposing VideoCallScreen");
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }
}
