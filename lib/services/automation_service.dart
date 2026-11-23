import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';

class AutomationService {
  static final Telephony _telephony = Telephony.instance;

  static Future<void> runAutoSms({
    required String alarmId,
    required String phoneNumber,
    required String message,
  }) async {
    final alarmBox = Hive.box('timering_alarms');
    final existing = Map<String, dynamic>.from(alarmBox.get(alarmId) ?? {});

    final bool? permissionsGranted = await _telephony.requestSmsPermissions;
    if (permissionsGranted != true) {
      existing['status'] = 'PENDING - SMS Permission Required';
      await alarmBox.put(alarmId, existing);
      await NotificationService.showInstantNotification(
        id: alarmId.hashCode.abs() % 100000,
        title: 'SMS அனுப்ப முடியவில்லை (Pending)',
        body: '$phoneNumber - Permission அனுமதி வழங்கி OK தட்டவும்.',
        playAlarmSound: true,
      );
      return;
    }

    try {
      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) async {
          if (status == SendStatus.SENT || status == SendStatus.DELIVERED) {
            existing['status'] = 'COMPLETED - SMS Sent';
            await alarmBox.put(alarmId, existing);
            await NotificationService.showInstantNotification(
              id: alarmId.hashCode.abs() % 100000,
              title: 'SMS வெற்றிகரமாக அனுப்பப்பட்டது',
              body: '$phoneNumber - செய்தி அனுப்பப்பட்டுவிட்டது.',
              playAlarmSound: false,
            );
          } else {
            existing['status'] = 'PENDING - Balance / Network Issue';
            await alarmBox.put(alarmId, existing);
            await NotificationService.showInstantNotification(
              id: alarmId.hashCode.abs() % 100000,
              title: 'SMS நிலுவையில் உள்ளது (Pending)',
              body: '$phoneNumber - Balance/Network சரிபார்த்து OK தட்டவும்.',
              playAlarmSound: true,
            );
          }
        },
      );
    } catch (_) {
      existing['status'] = 'PENDING - Balance / SIM Error';
      await alarmBox.put(alarmId, existing);
      await NotificationService.showInstantNotification(
        id: alarmId.hashCode.abs() % 100000,
        title: 'SMS Pending (Balance / Signal)',
        body: '$phoneNumber - சரிபார்த்து OK அழுத்தவும்.',
        playAlarmSound: true,
      );
    }
  }

  static Future<void> runAutoCall({
    required String alarmId,
    required String phoneNumber,
    int holdMuteSeconds = 7,
  }) async {
    final alarmBox = Hive.box('timering_alarms');
    final existing = Map<String, dynamic>.from(alarmBox.get(alarmId) ?? {});

    try {
      final bool? called = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (called == true) {
        existing['status'] = 'CALLING (20s Max Limit)';
        await alarmBox.put(alarmId, existing);

        await NotificationService.showInstantNotification(
          id: alarmId.hashCode.abs() % 100000,
          title: 'Auto Call தொடங்கப்பட்டது',
          body: '$phoneNumber - 20 வினாடிகளில் தானாக முடியும். முதல் $holdMuteSeconds வினாடி அமைதி/காத்திருப்பு.',
          playAlarmSound: false,
        );

        Timer(Duration(seconds: holdMuteSeconds), () async {
          await NotificationService.showInstantNotification(
            id: (alarmId.hashCode.abs() + 1) % 100000,
            title: 'Call Voice Window',
            body: 'முதல் $holdMuteSeconds வினாடிகள் முடிந்தது. இப்போது பேசலாம்.',
            playAlarmSound: false,
          );
        });

        Timer(const Duration(seconds: 20), () async {
          existing['status'] = 'COMPLETED - 20s Call Finished';
          await alarmBox.put(alarmId, existing);
          await NotificationService.showInstantNotification(
            id: (alarmId.hashCode.abs() + 2) % 100000,
            title: '20 வினாடி Call முடிந்தது',
            body: '$phoneNumber - Call 20s வரம்பை அடைந்தது.',
            playAlarmSound: true,
          );
        });
      } else {
        existing['status'] = 'PENDING - Call Not Placed (Balance/SIM)';
        await alarmBox.put(alarmId, existing);
        await NotificationService.showInstantNotification(
          id: alarmId.hashCode.abs() % 100000,
          title: 'Call Pending',
          body: '$phoneNumber - Balance/SIM சரிபார்த்து OK அழுத்தவும்.',
          playAlarmSound: true,
        );
      }
    } catch (_) {
      existing['status'] = 'PENDING - Call Failed';
      await alarmBox.put(alarmId, existing);
    }
  }

  static Future<void> openWhatsAppOneTap({
    required String alarmId,
    required String phoneNumber,
    required String message,
    bool isVoiceReminder = false,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final textToSend = isVoiceReminder
        ? (message.isEmpty ? 'Voice record நினைவூட்டல்' : message)
        : message;

    final Uri waUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(textToSend)}',
    );

    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      final alarmBox = Hive.box('timering_alarms');
      final existing = Map<String, dynamic>.from(alarmBox.get(alarmId) ?? {});
      existing['status'] = 'OPENED VIA 1-TAP (SAFE MODE)';
      await alarmBox.put(alarmId, existing);
    } else {
      debugPrint('Could not launch WhatsApp for $cleanPhone');
    }
  }
}
