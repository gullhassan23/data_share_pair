class DeviceInfo {
  final String name;
  final String ip;
  final int wsPort;
  final int transferPort;

  DeviceInfo({
    required this.name,
    required this.ip,
    required this.wsPort,
    required this.transferPort,
  });

  /// Returns true if this device has valid connection info for file transfer.
  bool get isValidForTransfer =>
      ip.isNotEmpty && transferPort > 0 && transferPort <= 65535;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    name: json['name'] as String,
    ip: json['ip'] as String,
    wsPort: json['wsPort'] as int,
    transferPort: json['transferPort'] as int,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'wsPort': wsPort,
    'transferPort': transferPort,
  };
}
