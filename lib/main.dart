import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Tuner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TunerScreen(),
    );
  }
}

class TunerScreen extends StatefulWidget {
  @override
  _TunerScreenState createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  FlutterSoundRecorder? _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _mRecorderIsInited = false;
  String? _recordingPath;

  double _currentFrequency = 0;
  FFT? fft;
  List<double> myData = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _processAudioData();
    });
    _initializeRecorder();
  }

  Future<void> _checkPermissions() async {
    PermissionStatus status = await Permission.microphone.status;

    if (status.isDenied) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
      ].request();
      print(statuses[Permission.microphone]);
    }

    if (await Permission.microphone.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _initializeRecorder() async {
    await _recorder!.openRecorder();
    Directory tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/recording.pcm';
    setState(() {
      _mRecorderIsInited = true;
    });
  }

  void _processAudioData() {
    if (fft == null) return;
    final freq = fft!.realFft(myData);
    if (freq != null && freq.isNotEmpty) {
      double frequency = _calculateFrequency(freq as List<double>);
      setState(() {
        _currentFrequency = frequency;
      });
    }
  }

  double _calculateFrequency(List<double> data) {
    return data.reduce((value, element) => value + element) / data.length;
  }

  Future<void> _startRecording() async {
    await _checkPermissions();
    await _recorder!.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16,
    );
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    _processRecording();
  }

  Future<void> _processRecording() async {
    myData = await _fetchAudioData();
    fft = FFT(myData.length);
    _processAudioData();
  }

  Future<List<double>> _fetchAudioData() async {
    final file = File(_recordingPath!);
    final rawData = await file.readAsBytes();
    return rawData.map((byte) => byte.toDouble()).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder!.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Guitar Tuner'),
      ),
      body: Center(
        child: SfRadialGauge(
          axes: <RadialAxis>[
            RadialAxis(minimum: 0, maximum: 1000, pointers: <GaugePointer>[
              NeedlePointer(value: _currentFrequency)
            ], annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                  widget: Text('$_currentFrequency Hz'),
                  angle: 90,
                  positionFactor: 0.5)
            ])
          ],
        ),
      ),
      floatingActionButton: _mRecorderIsInited
          ? FloatingActionButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
              child: Icon(_isRecording ? Icons.stop : Icons.mic),
            )
          : null,
    );
  }
}
