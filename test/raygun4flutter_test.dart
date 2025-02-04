// ignore_for_file: require_trailing_commas, avoid_print, avoid_dynamic_calls

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raygun4flutter/raygun4flutter.dart';
import 'package:raygun4flutter/src/services/settings.dart';

void main() {
  dynamic capturedBody;

  setUp(() {
    capturedBody = null;
    Settings.skipIfTest = true;
    Settings.customHttpClient = MockClient((request) async {
      capturedBody = jsonDecode(request.body);
      print(capturedBody);
      return http.Response('', 204);
    });
    Settings.getConnectivityState = () async {
      return ConnectivityResult.wifi;
    };
    Settings.getIps = () async {
      return [];
    };
    Settings.listenToConnectivityChanges = false;

    Raygun.init(apiKey: 'KEY');
  });

  test('init', () {
    expect(Settings.apiKey, 'KEY');
  });

  test('init with version', () {
    Raygun.init(apiKey: 'KEY', version: 'x.y.z');
    expect(Settings.apiKey, 'KEY');
    expect(Settings.version, 'x.y.z');
  });

  test('sendException', () async {
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(capturedBody['details']['error']['message'], 'Exception: MESSAGE');
    expect(capturedBody['details']['tags'], []);
    expect(capturedBody['details']['userCustomData'], {});
  });

  test('sendException with tags', () async {
    await Raygun.sendException(
      error: Exception('MESSAGE'),
      tags: ['tag1', 'tag2'],
    );
    expect(capturedBody['details']['error']['message'], 'Exception: MESSAGE');
    expect(capturedBody['details']['tags'], ['tag1', 'tag2']);
    expect(capturedBody['details']['userCustomData'], {});
  });

  test('sendException with custom data', () async {
    await Raygun.sendException(
      error: Exception('MESSAGE'),
      customData: {'custom': 42},
    );
    expect(capturedBody['details']['error']['message'], 'Exception: MESSAGE');
    expect(capturedBody['details']['tags'], []);
    expect(capturedBody['details']['userCustomData'], {'custom': 42});
  });

  test('Breadcrumb', () async {
    Raygun.recordBreadcrumb('BREADCRUMB');
    final breadcrumbMessage = RaygunBreadcrumbMessage(
      message: 'BREADCRUMB',
    );
    expect(
      Settings.breadcrumbs.single.toJson()['message'],
      breadcrumbMessage.toJson()['message'],
    );
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(
      capturedBody['details']['breadcrumbs'].single['message'],
      breadcrumbMessage.toJson()['message'],
    );
    // should clear after send
    expect(Settings.breadcrumbs, isEmpty);
  });

  test('UserId with ID', () async {
    Raygun.setUserId('ID');
    final raygunUserInfo = RaygunUserInfo(identifier: 'ID');
    expect(
      Settings.userInfo.toJson(),
      raygunUserInfo.toJson(),
    );
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(capturedBody['details']['user'], raygunUserInfo.toJson());
  });

  test('UserId to null', () async {
    Raygun.setUserId(null);
    final raygunUserInfo = RaygunUserInfo();
    expect(
      Settings.userInfo.toJson(),
      raygunUserInfo.toJson(),
    );
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(capturedBody['details']['user'], raygunUserInfo.toJson());
  });

  test('call to onBeforeSend before sending', () async {
    bool called = false;
    Raygun.onBeforeSend = (payload) {
      called = true;
      payload.details.error!.message = 'NEW MESSAGE';
      return payload;
    };
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(called, isTrue);
    expect(capturedBody['details']['error']['message'], 'NEW MESSAGE');
    Raygun.onBeforeSend = null;
  });

  test('cancel sending message with onBeforeSend', () async {
    Raygun.onBeforeSend = (payload) {
      return null;
    };
    await Raygun.sendException(error: Exception('MESSAGE'));
    expect(capturedBody, isNull);
    Raygun.onBeforeSend = null;
  });
}
