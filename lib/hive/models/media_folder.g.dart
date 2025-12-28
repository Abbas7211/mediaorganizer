// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_folder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaFolderAdapter extends TypeAdapter<MediaFolder> {
  @override
  final int typeId = 4;

  @override
  MediaFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaFolder(
      id: fields[0] as String,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MediaFolder obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
