class DeviceInfo {
  final String name;
  final String ip;
  final int? wsPort;
  final int transferPort;
  final bool isBluetooth;
  final String? bluetoothDeviceId;

  DeviceInfo({
    required this.name,
    required this.ip,
    this.wsPort,
    required this.transferPort,
    this.isBluetooth = false,
    this.bluetoothDeviceId,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        name: (json['name'] as String?) ?? 'Unknown',
        ip: (json['ip'] as String?) ?? '',
        wsPort: json['wsPort'] as int?,
        transferPort: (json['transferPort'] as num?)?.toInt() ?? 0,
        isBluetooth: json['isBluetooth'] as bool? ?? false,
        bluetoothDeviceId: json['bluetoothDeviceId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        if (wsPort != null) 'wsPort': wsPort,
        'transferPort': transferPort,
        if (isBluetooth) 'isBluetooth': isBluetooth,
        if (bluetoothDeviceId != null) 'bluetoothDeviceId': bluetoothDeviceId,
      };
}
