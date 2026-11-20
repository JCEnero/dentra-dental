import 'local_device_response.dart';

Future<String> localNetworkPermission() async => 'prompt';

Future<LocalDeviceResponse> fetchLocalDevice(String path,
        {Map<String, String>? body}) =>
    throw UnsupportedError('Browser only');
