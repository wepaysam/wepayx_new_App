class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.title,
    required this.address,
    required this.network,
    this.assetHint = '',
    required this.createdAtMs,
  });

  final String id;
  final String title;
  final String address;
  final String network;
  final String assetHint;
  final int createdAtMs;

  SavedAddress copyWith({
    String? title,
    String? address,
    String? network,
    String? assetHint,
  }) {
    return SavedAddress(
      id: id,
      title: title ?? this.title,
      address: address ?? this.address,
      network: network ?? this.network,
      assetHint: assetHint ?? this.assetHint,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'address': address,
        'network': network,
        'assetHint': assetHint,
        'createdAtMs': createdAtMs,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Saved address',
      address: json['address']?.toString() ?? '',
      network: json['network']?.toString() ?? '',
      assetHint: json['assetHint']?.toString() ?? '',
      createdAtMs: int.tryParse('${json['createdAtMs']}') ?? 0,
    );
  }
}
