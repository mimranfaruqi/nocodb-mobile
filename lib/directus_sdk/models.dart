import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
sealed class DirectusAuthResponse with _$DirectusAuthResponse {
  const factory DirectusAuthResponse({
    required String access_token,
    required int expires,
    String? refresh_token,
  }) = _DirectusAuthResponse;

  factory DirectusAuthResponse.fromJson(Map<String, dynamic> json) =>
      _$DirectusAuthResponseFromJson(json);
}

@freezed
sealed class DirectusUser with _$DirectusUser {
  const factory DirectusUser({
    required String id,
    String? first_name,
    String? last_name,
    required String email,
    String? avatar,
    String? role,
  }) = _DirectusUser;

  factory DirectusUser.fromJson(Map<String, dynamic> json) =>
      _$DirectusUserFromJson(json);
}

@freezed
sealed class DirectusCollection with _$DirectusCollection {
  const factory DirectusCollection({
    required String collection,
    String? note,
    bool? hidden,
    bool? singleton,
    String? icon,
    Map<String, dynamic>? meta,
  }) = _DirectusCollection;

  factory DirectusCollection.fromJson(Map<String, dynamic> json) =>
      _$DirectusCollectionFromJson(json);
}

@freezed
sealed class DirectusField with _$DirectusField {
  const factory DirectusField({
    required String field,
    required String type,
    String? collection,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? schema,
  }) = _DirectusField;

  factory DirectusField.fromJson(Map<String, dynamic> json) =>
      _$DirectusFieldFromJson(json);
}

@freezed
sealed class DirectusMeta with _$DirectusMeta {
  const factory DirectusMeta({
    int? total_count,
    int? filter_count,
  }) = _DirectusMeta;

  factory DirectusMeta.fromJson(Map<String, dynamic> json) =>
      _$DirectusMetaFromJson(json);
}

class DirectusItemsResponse {
  DirectusItemsResponse({
    required this.data,
    this.meta,
  });

  final List<dynamic> data;
  final DirectusMeta? meta;
}
