import 'package:app/services/camera_recorder.dart';
import 'package:app/provider/command_controller.dart';
import 'package:app/provider/network_ip.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_screen_on/keep_screen_on.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  CameraRecorder? cameraRecorder;
  bool _isInitial = true;

  void onRecordingUpdate(bool shouldBeRecording) {
    if (shouldBeRecording) {
      cameraRecorder?.startRecording();
    } else {
      cameraRecorder?.stopRecording();
    }
  }

  Widget _cameraPreviewWidget() {
    if (cameraRecorder case CameraRecorder cameraRecorder) {
      return CameraRecorderPreview(recorder: cameraRecorder);
    }
    return const Text(
      'Tap a camera',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24.0,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Future<void> _initializeCameraController() async {
    final recorder = await CameraRecorder.setupCameraRecorder();
    if (!ref.context.mounted) {
      return;
    }
    if (recorder case CameraRecorder recorder) {
      cameraRecorder = recorder;
      ref.read(commandControllerProvider.notifier).turnOnAutoConnect();
      setState(() {});
      return;
    }
    setState(() {});
  }

  void _updateRecorder() {
    if (cameraRecorder case CameraRecorder recorder) {
      ref.listen<ControllerState>(commandControllerProvider, (before, now) {
        if (now case ConnectingControllerState()) {
          return;
        }

        print("Before: ${before?.state}, Now: ${now.state}");
        final wasRecording = switch (before?.state) {
          ConnectedControllerState value =>
            value.recordingState == RecordingState.recording,
          _ => false
        };

        final isRecording = switch (now.state) {
          ConnectedControllerState value =>
            value.recordingState == RecordingState.recording,
          _ => false
        };
        if (wasRecording && !isRecording) {
          print("Stopping recording now");
          recorder.stopRecording();
        }
        if (!wasRecording && isRecording) {
          print("Starting recording now");
          recorder.startRecording();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitial) {
      KeepScreenOn.turnOn();
      _initializeCameraController();
      _isInitial = false;
    }

    _updateRecorder();

    final controllerState = ref.watch(commandControllerProvider);
    final networkIP = ref.watch(networkIPProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Astra Bremen - Record'),
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              const SizedBox(
                height: 30,
              ),
              networkIP.maybeMap(
                data: (ip) =>
                    _DefaultText("This Phone's IP: ${ip.value ?? "No IP"}"),
                orElse: () => const SizedBox(),
              ),
              switch (controllerState.state) {
                DisconnectedControllerState() => Column(
                    children: [
                      const _DefaultText(
                        "Disconnected",
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(commandControllerProvider.notifier)
                            .turnOnAutoConnect(),
                        child: const _DefaultText(
                          "Try auto connecting",
                        ),
                      )
                    ],
                  ),
                ConnectingControllerState _ => Column(
                    children: [
                      const _DefaultText(
                        "Looking for the server",
                      ),
                      _DefaultText(
                        "Auto Retry: ${controllerState.isAutoConnecting ? "True" : "False"}",
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(commandControllerProvider.notifier)
                            .turnOffAutoConnect(),
                        child: const _DefaultText(
                          "Give up looking",
                        ),
                      )
                    ],
                  ),
                ConnectedControllerState value => Column(
                    children: [
                      const _DefaultText(
                        "Connected",
                      ),
                      _DefaultText(
                        "Recording: ${value.recordingState}",
                      )
                    ],
                  ),
              },
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: Center(
                    child: _cameraPreviewWidget(),
                  ),
                ),
              ),
              Text(
                  "Tip: Please turn off mobile data and connect to the server WIFI. \nThe server should have the following IP: ${ref.read(commandControllerProvider.notifier).targetServerIP}"),
              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultText extends StatelessWidget {
  final String text;
  const _DefaultText(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
