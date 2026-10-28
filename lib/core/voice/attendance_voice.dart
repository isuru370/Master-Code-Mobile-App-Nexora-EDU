import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/admin/qr/data/model/scan_attendance_new/attendance_data_model.dart';
import '../features/app_features.dart';
import 'attendance_speech.dart';

/// Speaks after an attendance scan when the institute has the "tts"
/// feature (php artisan nexora:feature tts on) and it is on for this phone.
///
/// Uses the phone's own text-to-speech (Google Speech Services): works
/// without internet. The Sinhala part needs the Sinhala voice on the phone;
/// without it "Paid" / "Not paid" is said in English.
class AttendanceVoice {
  AttendanceVoice._();

  static final AttendanceVoice instance = AttendanceVoice._();

  static const String feature = 'tts';
  static const String _kEnabled = 'attendance_voice_enabled';
  static const String _kRate = 'attendance_voice_rate';
  static const double defaultRate = 0.5;

  /// Short beep (free card) from MainActivity.java (Android ToneGenerator).
  static const MethodChannel _beepChannel = MethodChannel('nexora/beep');

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _hasSinhala = false;

  /// Each new scan stops the one before: only the latest is said.
  int _turn = 0;

  /// The institute has the feature.
  bool get isAvailable => AppFeatures.isOn(feature);

  /// The phone has the Sinhala voice (after the first [announce] / [test]).
  bool get hasSinhala => _hasSinhala;

  // ---------------------------------------------------------------------
  // Settings on this phone
  // ---------------------------------------------------------------------

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    if (!value) await stop();
  }

  /// 0.3 (slow) - 0.7 (fast)
  Future<double> rate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kRate) ?? defaultRate;
  }

  Future<void> setRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRate, value);
  }

  // ---------------------------------------------------------------------
  // Speaking
  // ---------------------------------------------------------------------

  /// After a successful scan.
  Future<void> announce(AttendanceDataModel? data) async {
    if (data == null || !isAvailable || !await isEnabled()) return;

    await _say(
      english: AttendanceSpeech.english(
        name: data.student.initialName,
        subject: data.schedule.studentClass.subject,
        grade: data.schedule.studentClass.grade,
        alreadyMarked: data.attendanceResult.alreadyMarked,
      ),
      paymentStatus: data.currentMonthPayment?.status,
    );
  }

  /// "Test" button in the voice settings (also checks again for the
  /// Sinhala voice, e.g. just installed).
  Future<void> test() {
    _ready = false;
    return _say(
      english: AttendanceSpeech.english(name: 'K. Perera', subject: 'ENGLISH', grade: '10'),
      paymentStatus: 'paid',
    );
  }

  /// Get the voice ready and look for the Sinhala voice.
  Future<void> prepare() async {
    try {
      await _init();
    } catch (_) {}
  }

  Future<void> stop() async {
    _turn++;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _say({required String english, String? paymentStatus}) async {
    final turn = ++_turn;

    try {
      await _tts.stop();
      await _init();
      await _tts.setSpeechRate(await rate());

      if (english.isNotEmpty) {
        await _tts.setLanguage('en-US');
        if (turn != _turn) return;
        await _tts.speak(english);
      }

      if (turn != _turn) return;

      if (AttendanceSpeech.isFree(paymentStatus)) {
        await beep();
        return;
      }

      final words = AttendanceSpeech.payment(paymentStatus, sinhala: _hasSinhala);
      if (words == null) return;

      if (_hasSinhala) await _tts.setLanguage('si-LK');
      if (turn != _turn) return;
      await _tts.speak(words);
    } catch (e) {
      // Never stop the scanning because of the voice
      if (kDebugMode) debugPrint('ATTENDANCE VOICE: $e');
    }
  }

  Future<void> beep() async {
    try {
      await _beepChannel.invokeMethod('beep');
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _init() async {
    if (_ready) return;

    // speak() returns when the sentence is finished, so the English part,
    // then the Sinhala part, are said one after the other
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);

    try {
      _hasSinhala = (await _tts.isLanguageAvailable('si-LK')) == true;
    } catch (_) {
      _hasSinhala = false;
    }

    _ready = true;
  }
}
