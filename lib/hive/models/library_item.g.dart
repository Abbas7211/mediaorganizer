// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LibraryItemAdapter extends TypeAdapter<LibraryItem> {
  @override
  final int typeId = 1;

  @override
  LibraryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LibraryItem(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      createdAt: fields[3] as DateTime,
      thumbnailPath: fields[4] as String?,
      url: fields[5] as String?,
      isFavorite: fields[6] as bool,
      folderId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LibraryItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.thumbnailPath)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.isFavorite)
      ..writeByte(7)
      ..write(obj.folderId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
