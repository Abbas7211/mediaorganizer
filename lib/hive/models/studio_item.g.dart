// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudioItemAdapter extends TypeAdapter<StudioItem> {
  @override
  final int typeId = 3;

  @override
  StudioItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudioItem(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      createdAt: fields[3] as DateTime,
      sizeBytes: fields[4] as int,
      sourceUrl: fields[5] as String?,
      folderId: fields[6] as String?,
      thumbnailPath: fields[7] as String?,
      isSelected: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StudioItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.sizeBytes)
      ..writeByte(5)
      ..write(obj.sourceUrl)
      ..writeByte(6)
      ..write(obj.folderId)
      ..writeByte(7)
      ..write(obj.thumbnailPath)
      ..writeByte(8)
      ..write(obj.isSelected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
