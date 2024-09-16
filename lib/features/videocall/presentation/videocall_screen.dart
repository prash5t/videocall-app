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
  bool _isConnected = false;
  List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _handlePermissions();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _handlePermissions() async {
    print("Handling permissions...");
    final status = await _requestPermissions();
    print("Permission status: $status");
    if (status) {
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
      // Permissions were denied but not permanently
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

  void _setupSocketListeners() {
    widget.socket.on('ice_candidate', (data) async {
      print("Received ICE candidate");
      if (data['target_email'] == widget.userEmail) {
        RTCIceCandidate candidate = RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );

        if (_remoteDescriptionSet) {
          await _addCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }
      }
    });

    widget.socket.on('offer', (data) async {
      print("Received offer");
      if (data['target_email'] == widget.userEmail) {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
        );
        _remoteDescriptionSet = true;
        _processPendingCandidates();

        final answer = await _peerConnection?.createAnswer();
        await _peerConnection?.setLocalDescription(answer!);
        widget.socket.emit('answer', {
          'target_email': widget.otherUserEmail,
          'sdp': answer?.toMap(),
        });
      }
    });

    widget.socket.on('answer', (data) async {
      print("Received answer");
      if (data['target_email'] == widget.userEmail) {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
        );
        _remoteDescriptionSet = true;
        _processPendingCandidates();
      }
    });

    widget.socket.on('call_ended', (data) {
      Navigator.of(context).pop();
    });
  }

  Future<void> _addCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      print("Error adding ICE candidate: $e");
    }
  }

  void _processPendingCandidates() {
    print("Processing ${_pendingCandidates.length} pending candidates");
    _pendingCandidates.forEach(_addCandidate);
    _pendingCandidates.clear();
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config, {});

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _localRenderer.srcObject = _localStream;

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
          _isConnected = true;
        });
      }
    };

    // Only create and send offer if this is the caller
    if (widget.userEmail == widget.callId.split('_')[0]) {
      final offer = await _peerConnection?.createOffer();
      await _peerConnection?.setLocalDescription(offer!);
      widget.socket.emit('offer', {
        'target_email': widget.otherUserEmail,
        'sdp': offer?.toMap(),
      });
    }
  }

  void _endCall() {
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
      body: Stack(
        children: [
          if (_isConnected)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Center(child: CircularProgressIndicator()),
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              width: 100,
              height: 150,
              child: RTCVideoView(_localRenderer, mirror: true),
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
                // style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }
}
