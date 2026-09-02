// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BrandsTable extends Brands with TableInfo<$BrandsTable, Brand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aktifMeta = const VerificationMeta('aktif');
  @override
  late final GeneratedColumn<bool> aktif = GeneratedColumn<bool>(
    'aktif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aktif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, nama, aktif];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brands';
  @override
  VerificationContext validateIntegrity(
    Insertable<Brand> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('aktif')) {
      context.handle(
        _aktifMeta,
        aktif.isAcceptableOrUnknown(data['aktif']!, _aktifMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Brand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Brand(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      aktif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aktif'],
      )!,
    );
  }

  @override
  $BrandsTable createAlias(String alias) {
    return $BrandsTable(attachedDatabase, alias);
  }
}

class Brand extends DataClass implements Insertable<Brand> {
  final int id;
  final String nama;
  final bool aktif;
  const Brand({required this.id, required this.nama, required this.aktif});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nama'] = Variable<String>(nama);
    map['aktif'] = Variable<bool>(aktif);
    return map;
  }

  BrandsCompanion toCompanion(bool nullToAbsent) {
    return BrandsCompanion(
      id: Value(id),
      nama: Value(nama),
      aktif: Value(aktif),
    );
  }

  factory Brand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Brand(
      id: serializer.fromJson<int>(json['id']),
      nama: serializer.fromJson<String>(json['nama']),
      aktif: serializer.fromJson<bool>(json['aktif']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nama': serializer.toJson<String>(nama),
      'aktif': serializer.toJson<bool>(aktif),
    };
  }

  Brand copyWith({int? id, String? nama, bool? aktif}) => Brand(
    id: id ?? this.id,
    nama: nama ?? this.nama,
    aktif: aktif ?? this.aktif,
  );
  Brand copyWithCompanion(BrandsCompanion data) {
    return Brand(
      id: data.id.present ? data.id.value : this.id,
      nama: data.nama.present ? data.nama.value : this.nama,
      aktif: data.aktif.present ? data.aktif.value : this.aktif,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Brand(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('aktif: $aktif')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nama, aktif);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Brand &&
          other.id == this.id &&
          other.nama == this.nama &&
          other.aktif == this.aktif);
}

class BrandsCompanion extends UpdateCompanion<Brand> {
  final Value<int> id;
  final Value<String> nama;
  final Value<bool> aktif;
  const BrandsCompanion({
    this.id = const Value.absent(),
    this.nama = const Value.absent(),
    this.aktif = const Value.absent(),
  });
  BrandsCompanion.insert({
    this.id = const Value.absent(),
    required String nama,
    this.aktif = const Value.absent(),
  }) : nama = Value(nama);
  static Insertable<Brand> custom({
    Expression<int>? id,
    Expression<String>? nama,
    Expression<bool>? aktif,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nama != null) 'nama': nama,
      if (aktif != null) 'aktif': aktif,
    });
  }

  BrandsCompanion copyWith({
    Value<int>? id,
    Value<String>? nama,
    Value<bool>? aktif,
  }) {
    return BrandsCompanion(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      aktif: aktif ?? this.aktif,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (aktif.present) {
      map['aktif'] = Variable<bool>(aktif.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrandsCompanion(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('aktif: $aktif')
          ..write(')'))
        .toString();
  }
}

class $PartTypesTable extends PartTypes
    with TableInfo<$PartTypesTable, PartType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kodeMeta = const VerificationMeta('kode');
  @override
  late final GeneratedColumn<String> kode = GeneratedColumn<String>(
    'kode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aktifMeta = const VerificationMeta('aktif');
  @override
  late final GeneratedColumn<bool> aktif = GeneratedColumn<bool>(
    'aktif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aktif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, kode, nama, aktif];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'part_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kode')) {
      context.handle(
        _kodeMeta,
        kode.isAcceptableOrUnknown(data['kode']!, _kodeMeta),
      );
    } else if (isInserting) {
      context.missing(_kodeMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('aktif')) {
      context.handle(
        _aktifMeta,
        aktif.isAcceptableOrUnknown(data['aktif']!, _aktifMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      aktif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aktif'],
      )!,
    );
  }

  @override
  $PartTypesTable createAlias(String alias) {
    return $PartTypesTable(attachedDatabase, alias);
  }
}

class PartType extends DataClass implements Insertable<PartType> {
  final int id;
  final String kode;
  final String nama;
  final bool aktif;
  const PartType({
    required this.id,
    required this.kode,
    required this.nama,
    required this.aktif,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kode'] = Variable<String>(kode);
    map['nama'] = Variable<String>(nama);
    map['aktif'] = Variable<bool>(aktif);
    return map;
  }

  PartTypesCompanion toCompanion(bool nullToAbsent) {
    return PartTypesCompanion(
      id: Value(id),
      kode: Value(kode),
      nama: Value(nama),
      aktif: Value(aktif),
    );
  }

  factory PartType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartType(
      id: serializer.fromJson<int>(json['id']),
      kode: serializer.fromJson<String>(json['kode']),
      nama: serializer.fromJson<String>(json['nama']),
      aktif: serializer.fromJson<bool>(json['aktif']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kode': serializer.toJson<String>(kode),
      'nama': serializer.toJson<String>(nama),
      'aktif': serializer.toJson<bool>(aktif),
    };
  }

  PartType copyWith({int? id, String? kode, String? nama, bool? aktif}) =>
      PartType(
        id: id ?? this.id,
        kode: kode ?? this.kode,
        nama: nama ?? this.nama,
        aktif: aktif ?? this.aktif,
      );
  PartType copyWithCompanion(PartTypesCompanion data) {
    return PartType(
      id: data.id.present ? data.id.value : this.id,
      kode: data.kode.present ? data.kode.value : this.kode,
      nama: data.nama.present ? data.nama.value : this.nama,
      aktif: data.aktif.present ? data.aktif.value : this.aktif,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartType(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('nama: $nama, ')
          ..write('aktif: $aktif')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kode, nama, aktif);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartType &&
          other.id == this.id &&
          other.kode == this.kode &&
          other.nama == this.nama &&
          other.aktif == this.aktif);
}

class PartTypesCompanion extends UpdateCompanion<PartType> {
  final Value<int> id;
  final Value<String> kode;
  final Value<String> nama;
  final Value<bool> aktif;
  const PartTypesCompanion({
    this.id = const Value.absent(),
    this.kode = const Value.absent(),
    this.nama = const Value.absent(),
    this.aktif = const Value.absent(),
  });
  PartTypesCompanion.insert({
    this.id = const Value.absent(),
    required String kode,
    required String nama,
    this.aktif = const Value.absent(),
  }) : kode = Value(kode),
       nama = Value(nama);
  static Insertable<PartType> custom({
    Expression<int>? id,
    Expression<String>? kode,
    Expression<String>? nama,
    Expression<bool>? aktif,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kode != null) 'kode': kode,
      if (nama != null) 'nama': nama,
      if (aktif != null) 'aktif': aktif,
    });
  }

  PartTypesCompanion copyWith({
    Value<int>? id,
    Value<String>? kode,
    Value<String>? nama,
    Value<bool>? aktif,
  }) {
    return PartTypesCompanion(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      aktif: aktif ?? this.aktif,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kode.present) {
      map['kode'] = Variable<String>(kode.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (aktif.present) {
      map['aktif'] = Variable<bool>(aktif.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartTypesCompanion(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('nama: $nama, ')
          ..write('aktif: $aktif')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aktifMeta = const VerificationMeta('aktif');
  @override
  late final GeneratedColumn<bool> aktif = GeneratedColumn<bool>(
    'aktif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aktif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, nama, role, aktif];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('aktif')) {
      context.handle(
        _aktifMeta,
        aktif.isAcceptableOrUnknown(data['aktif']!, _aktifMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      aktif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aktif'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String nama;
  final String role;
  final bool aktif;
  const Profile({
    required this.id,
    required this.nama,
    required this.role,
    required this.aktif,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nama'] = Variable<String>(nama);
    map['role'] = Variable<String>(role);
    map['aktif'] = Variable<bool>(aktif);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      nama: Value(nama),
      role: Value(role),
      aktif: Value(aktif),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      nama: serializer.fromJson<String>(json['nama']),
      role: serializer.fromJson<String>(json['role']),
      aktif: serializer.fromJson<bool>(json['aktif']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nama': serializer.toJson<String>(nama),
      'role': serializer.toJson<String>(role),
      'aktif': serializer.toJson<bool>(aktif),
    };
  }

  Profile copyWith({String? id, String? nama, String? role, bool? aktif}) =>
      Profile(
        id: id ?? this.id,
        nama: nama ?? this.nama,
        role: role ?? this.role,
        aktif: aktif ?? this.aktif,
      );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      nama: data.nama.present ? data.nama.value : this.nama,
      role: data.role.present ? data.role.value : this.role,
      aktif: data.aktif.present ? data.aktif.value : this.aktif,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('role: $role, ')
          ..write('aktif: $aktif')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nama, role, aktif);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.nama == this.nama &&
          other.role == this.role &&
          other.aktif == this.aktif);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> nama;
  final Value<String> role;
  final Value<bool> aktif;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.nama = const Value.absent(),
    this.role = const Value.absent(),
    this.aktif = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String nama,
    required String role,
    this.aktif = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nama = Value(nama),
       role = Value(role);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? nama,
    Expression<String>? role,
    Expression<bool>? aktif,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nama != null) 'nama': nama,
      if (role != null) 'role': role,
      if (aktif != null) 'aktif': aktif,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? nama,
    Value<String>? role,
    Value<bool>? aktif,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      role: role ?? this.role,
      aktif: aktif ?? this.aktif,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (aktif.present) {
      map['aktif'] = Variable<bool>(aktif.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('role: $role, ')
          ..write('aktif: $aktif, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaimsTable extends Claims with TableInfo<$ClaimsTable, Claim> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tanggalMeta = const VerificationMeta(
    'tanggal',
  );
  @override
  late final GeneratedColumn<DateTime> tanggal = GeneratedColumn<DateTime>(
    'tanggal',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandIdMeta = const VerificationMeta(
    'brandId',
  );
  @override
  late final GeneratedColumn<int> brandId = GeneratedColumn<int>(
    'brand_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaPelangganMeta = const VerificationMeta(
    'namaPelanggan',
  );
  @override
  late final GeneratedColumn<String> namaPelanggan = GeneratedColumn<String>(
    'nama_pelanggan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telpMeta = const VerificationMeta('telp');
  @override
  late final GeneratedColumn<String> telp = GeneratedColumn<String>(
    'telp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snMeta = const VerificationMeta('sn');
  @override
  late final GeneratedColumn<String> sn = GeneratedColumn<String>(
    'sn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teknisiIdMeta = const VerificationMeta(
    'teknisiId',
  );
  @override
  late final GeneratedColumn<String> teknisiId = GeneratedColumn<String>(
    'teknisi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keluhanMeta = const VerificationMeta(
    'keluhan',
  );
  @override
  late final GeneratedColumn<String> keluhan = GeneratedColumn<String>(
    'keluhan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noPerbaikanMeta = const VerificationMeta(
    'noPerbaikan',
  );
  @override
  late final GeneratedColumn<String> noPerbaikan = GeneratedColumn<String>(
    'no_perbaikan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _catatanMeta = const VerificationMeta(
    'catatan',
  );
  @override
  late final GeneratedColumn<String> catatan = GeneratedColumn<String>(
    'catatan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tanggal,
    brandId,
    namaPelanggan,
    telp,
    sn,
    teknisiId,
    keluhan,
    noPerbaikan,
    status,
    catatan,
    createdBy,
    createdAt,
    updatedAt,
    syncPending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claims';
  @override
  VerificationContext validateIntegrity(
    Insertable<Claim> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tanggal')) {
      context.handle(
        _tanggalMeta,
        tanggal.isAcceptableOrUnknown(data['tanggal']!, _tanggalMeta),
      );
    } else if (isInserting) {
      context.missing(_tanggalMeta);
    }
    if (data.containsKey('brand_id')) {
      context.handle(
        _brandIdMeta,
        brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_brandIdMeta);
    }
    if (data.containsKey('nama_pelanggan')) {
      context.handle(
        _namaPelangganMeta,
        namaPelanggan.isAcceptableOrUnknown(
          data['nama_pelanggan']!,
          _namaPelangganMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_namaPelangganMeta);
    }
    if (data.containsKey('telp')) {
      context.handle(
        _telpMeta,
        telp.isAcceptableOrUnknown(data['telp']!, _telpMeta),
      );
    }
    if (data.containsKey('sn')) {
      context.handle(_snMeta, sn.isAcceptableOrUnknown(data['sn']!, _snMeta));
    } else if (isInserting) {
      context.missing(_snMeta);
    }
    if (data.containsKey('teknisi_id')) {
      context.handle(
        _teknisiIdMeta,
        teknisiId.isAcceptableOrUnknown(data['teknisi_id']!, _teknisiIdMeta),
      );
    }
    if (data.containsKey('keluhan')) {
      context.handle(
        _keluhanMeta,
        keluhan.isAcceptableOrUnknown(data['keluhan']!, _keluhanMeta),
      );
    }
    if (data.containsKey('no_perbaikan')) {
      context.handle(
        _noPerbaikanMeta,
        noPerbaikan.isAcceptableOrUnknown(
          data['no_perbaikan']!,
          _noPerbaikanMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Claim map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Claim(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tanggal: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal'],
      )!,
      brandId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}brand_id'],
      )!,
      namaPelanggan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama_pelanggan'],
      )!,
      telp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telp'],
      ),
      sn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sn'],
      )!,
      teknisiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teknisi_id'],
      ),
      keluhan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keluhan'],
      ),
      noPerbaikan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_perbaikan'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
    );
  }

  @override
  $ClaimsTable createAlias(String alias) {
    return $ClaimsTable(attachedDatabase, alias);
  }
}

class Claim extends DataClass implements Insertable<Claim> {
  final String id;
  final DateTime tanggal;
  final int brandId;
  final String namaPelanggan;
  final String? telp;
  final String sn;
  final String? teknisiId;
  final String? keluhan;
  final String? noPerbaikan;
  final String status;
  final String? catatan;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// true = ada perubahan lokal yang belum sampai ke Supabase.
  final bool syncPending;
  const Claim({
    required this.id,
    required this.tanggal,
    required this.brandId,
    required this.namaPelanggan,
    this.telp,
    required this.sn,
    this.teknisiId,
    this.keluhan,
    this.noPerbaikan,
    required this.status,
    this.catatan,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.syncPending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tanggal'] = Variable<DateTime>(tanggal);
    map['brand_id'] = Variable<int>(brandId);
    map['nama_pelanggan'] = Variable<String>(namaPelanggan);
    if (!nullToAbsent || telp != null) {
      map['telp'] = Variable<String>(telp);
    }
    map['sn'] = Variable<String>(sn);
    if (!nullToAbsent || teknisiId != null) {
      map['teknisi_id'] = Variable<String>(teknisiId);
    }
    if (!nullToAbsent || keluhan != null) {
      map['keluhan'] = Variable<String>(keluhan);
    }
    if (!nullToAbsent || noPerbaikan != null) {
      map['no_perbaikan'] = Variable<String>(noPerbaikan);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_pending'] = Variable<bool>(syncPending);
    return map;
  }

  ClaimsCompanion toCompanion(bool nullToAbsent) {
    return ClaimsCompanion(
      id: Value(id),
      tanggal: Value(tanggal),
      brandId: Value(brandId),
      namaPelanggan: Value(namaPelanggan),
      telp: telp == null && nullToAbsent ? const Value.absent() : Value(telp),
      sn: Value(sn),
      teknisiId: teknisiId == null && nullToAbsent
          ? const Value.absent()
          : Value(teknisiId),
      keluhan: keluhan == null && nullToAbsent
          ? const Value.absent()
          : Value(keluhan),
      noPerbaikan: noPerbaikan == null && nullToAbsent
          ? const Value.absent()
          : Value(noPerbaikan),
      status: Value(status),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncPending: Value(syncPending),
    );
  }

  factory Claim.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Claim(
      id: serializer.fromJson<String>(json['id']),
      tanggal: serializer.fromJson<DateTime>(json['tanggal']),
      brandId: serializer.fromJson<int>(json['brandId']),
      namaPelanggan: serializer.fromJson<String>(json['namaPelanggan']),
      telp: serializer.fromJson<String?>(json['telp']),
      sn: serializer.fromJson<String>(json['sn']),
      teknisiId: serializer.fromJson<String?>(json['teknisiId']),
      keluhan: serializer.fromJson<String?>(json['keluhan']),
      noPerbaikan: serializer.fromJson<String?>(json['noPerbaikan']),
      status: serializer.fromJson<String>(json['status']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tanggal': serializer.toJson<DateTime>(tanggal),
      'brandId': serializer.toJson<int>(brandId),
      'namaPelanggan': serializer.toJson<String>(namaPelanggan),
      'telp': serializer.toJson<String?>(telp),
      'sn': serializer.toJson<String>(sn),
      'teknisiId': serializer.toJson<String?>(teknisiId),
      'keluhan': serializer.toJson<String?>(keluhan),
      'noPerbaikan': serializer.toJson<String?>(noPerbaikan),
      'status': serializer.toJson<String>(status),
      'catatan': serializer.toJson<String?>(catatan),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncPending': serializer.toJson<bool>(syncPending),
    };
  }

  Claim copyWith({
    String? id,
    DateTime? tanggal,
    int? brandId,
    String? namaPelanggan,
    Value<String?> telp = const Value.absent(),
    String? sn,
    Value<String?> teknisiId = const Value.absent(),
    Value<String?> keluhan = const Value.absent(),
    Value<String?> noPerbaikan = const Value.absent(),
    String? status,
    Value<String?> catatan = const Value.absent(),
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncPending,
  }) => Claim(
    id: id ?? this.id,
    tanggal: tanggal ?? this.tanggal,
    brandId: brandId ?? this.brandId,
    namaPelanggan: namaPelanggan ?? this.namaPelanggan,
    telp: telp.present ? telp.value : this.telp,
    sn: sn ?? this.sn,
    teknisiId: teknisiId.present ? teknisiId.value : this.teknisiId,
    keluhan: keluhan.present ? keluhan.value : this.keluhan,
    noPerbaikan: noPerbaikan.present ? noPerbaikan.value : this.noPerbaikan,
    status: status ?? this.status,
    catatan: catatan.present ? catatan.value : this.catatan,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncPending: syncPending ?? this.syncPending,
  );
  Claim copyWithCompanion(ClaimsCompanion data) {
    return Claim(
      id: data.id.present ? data.id.value : this.id,
      tanggal: data.tanggal.present ? data.tanggal.value : this.tanggal,
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      namaPelanggan: data.namaPelanggan.present
          ? data.namaPelanggan.value
          : this.namaPelanggan,
      telp: data.telp.present ? data.telp.value : this.telp,
      sn: data.sn.present ? data.sn.value : this.sn,
      teknisiId: data.teknisiId.present ? data.teknisiId.value : this.teknisiId,
      keluhan: data.keluhan.present ? data.keluhan.value : this.keluhan,
      noPerbaikan: data.noPerbaikan.present
          ? data.noPerbaikan.value
          : this.noPerbaikan,
      status: data.status.present ? data.status.value : this.status,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Claim(')
          ..write('id: $id, ')
          ..write('tanggal: $tanggal, ')
          ..write('brandId: $brandId, ')
          ..write('namaPelanggan: $namaPelanggan, ')
          ..write('telp: $telp, ')
          ..write('sn: $sn, ')
          ..write('teknisiId: $teknisiId, ')
          ..write('keluhan: $keluhan, ')
          ..write('noPerbaikan: $noPerbaikan, ')
          ..write('status: $status, ')
          ..write('catatan: $catatan, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncPending: $syncPending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tanggal,
    brandId,
    namaPelanggan,
    telp,
    sn,
    teknisiId,
    keluhan,
    noPerbaikan,
    status,
    catatan,
    createdBy,
    createdAt,
    updatedAt,
    syncPending,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Claim &&
          other.id == this.id &&
          other.tanggal == this.tanggal &&
          other.brandId == this.brandId &&
          other.namaPelanggan == this.namaPelanggan &&
          other.telp == this.telp &&
          other.sn == this.sn &&
          other.teknisiId == this.teknisiId &&
          other.keluhan == this.keluhan &&
          other.noPerbaikan == this.noPerbaikan &&
          other.status == this.status &&
          other.catatan == this.catatan &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncPending == this.syncPending);
}

class ClaimsCompanion extends UpdateCompanion<Claim> {
  final Value<String> id;
  final Value<DateTime> tanggal;
  final Value<int> brandId;
  final Value<String> namaPelanggan;
  final Value<String?> telp;
  final Value<String> sn;
  final Value<String?> teknisiId;
  final Value<String?> keluhan;
  final Value<String?> noPerbaikan;
  final Value<String> status;
  final Value<String?> catatan;
  final Value<String> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> syncPending;
  final Value<int> rowid;
  const ClaimsCompanion({
    this.id = const Value.absent(),
    this.tanggal = const Value.absent(),
    this.brandId = const Value.absent(),
    this.namaPelanggan = const Value.absent(),
    this.telp = const Value.absent(),
    this.sn = const Value.absent(),
    this.teknisiId = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.noPerbaikan = const Value.absent(),
    this.status = const Value.absent(),
    this.catatan = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimsCompanion.insert({
    required String id,
    required DateTime tanggal,
    required int brandId,
    required String namaPelanggan,
    this.telp = const Value.absent(),
    required String sn,
    this.teknisiId = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.noPerbaikan = const Value.absent(),
    this.status = const Value.absent(),
    this.catatan = const Value.absent(),
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncPending = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tanggal = Value(tanggal),
       brandId = Value(brandId),
       namaPelanggan = Value(namaPelanggan),
       sn = Value(sn),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Claim> custom({
    Expression<String>? id,
    Expression<DateTime>? tanggal,
    Expression<int>? brandId,
    Expression<String>? namaPelanggan,
    Expression<String>? telp,
    Expression<String>? sn,
    Expression<String>? teknisiId,
    Expression<String>? keluhan,
    Expression<String>? noPerbaikan,
    Expression<String>? status,
    Expression<String>? catatan,
    Expression<String>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? syncPending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tanggal != null) 'tanggal': tanggal,
      if (brandId != null) 'brand_id': brandId,
      if (namaPelanggan != null) 'nama_pelanggan': namaPelanggan,
      if (telp != null) 'telp': telp,
      if (sn != null) 'sn': sn,
      if (teknisiId != null) 'teknisi_id': teknisiId,
      if (keluhan != null) 'keluhan': keluhan,
      if (noPerbaikan != null) 'no_perbaikan': noPerbaikan,
      if (status != null) 'status': status,
      if (catatan != null) 'catatan': catatan,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncPending != null) 'sync_pending': syncPending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? tanggal,
    Value<int>? brandId,
    Value<String>? namaPelanggan,
    Value<String?>? telp,
    Value<String>? sn,
    Value<String?>? teknisiId,
    Value<String?>? keluhan,
    Value<String?>? noPerbaikan,
    Value<String>? status,
    Value<String?>? catatan,
    Value<String>? createdBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? syncPending,
    Value<int>? rowid,
  }) {
    return ClaimsCompanion(
      id: id ?? this.id,
      tanggal: tanggal ?? this.tanggal,
      brandId: brandId ?? this.brandId,
      namaPelanggan: namaPelanggan ?? this.namaPelanggan,
      telp: telp ?? this.telp,
      sn: sn ?? this.sn,
      teknisiId: teknisiId ?? this.teknisiId,
      keluhan: keluhan ?? this.keluhan,
      noPerbaikan: noPerbaikan ?? this.noPerbaikan,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncPending: syncPending ?? this.syncPending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tanggal.present) {
      map['tanggal'] = Variable<DateTime>(tanggal.value);
    }
    if (brandId.present) {
      map['brand_id'] = Variable<int>(brandId.value);
    }
    if (namaPelanggan.present) {
      map['nama_pelanggan'] = Variable<String>(namaPelanggan.value);
    }
    if (telp.present) {
      map['telp'] = Variable<String>(telp.value);
    }
    if (sn.present) {
      map['sn'] = Variable<String>(sn.value);
    }
    if (teknisiId.present) {
      map['teknisi_id'] = Variable<String>(teknisiId.value);
    }
    if (keluhan.present) {
      map['keluhan'] = Variable<String>(keluhan.value);
    }
    if (noPerbaikan.present) {
      map['no_perbaikan'] = Variable<String>(noPerbaikan.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaimsCompanion(')
          ..write('id: $id, ')
          ..write('tanggal: $tanggal, ')
          ..write('brandId: $brandId, ')
          ..write('namaPelanggan: $namaPelanggan, ')
          ..write('telp: $telp, ')
          ..write('sn: $sn, ')
          ..write('teknisiId: $teknisiId, ')
          ..write('keluhan: $keluhan, ')
          ..write('noPerbaikan: $noPerbaikan, ')
          ..write('status: $status, ')
          ..write('catatan: $catatan, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncPending: $syncPending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaimPartsTable extends ClaimParts
    with TableInfo<$ClaimPartsTable, ClaimPart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimIdMeta = const VerificationMeta(
    'claimId',
  );
  @override
  late final GeneratedColumn<String> claimId = GeneratedColumn<String>(
    'claim_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partTypeIdMeta = const VerificationMeta(
    'partTypeId',
  );
  @override
  late final GeneratedColumn<int> partTypeId = GeneratedColumn<int>(
    'part_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snBadPartMeta = const VerificationMeta(
    'snBadPart',
  );
  @override
  late final GeneratedColumn<String> snBadPart = GeneratedColumn<String>(
    'sn_bad_part',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingDeleteMeta = const VerificationMeta(
    'pendingDelete',
  );
  @override
  late final GeneratedColumn<bool> pendingDelete = GeneratedColumn<bool>(
    'pending_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    claimId,
    partTypeId,
    snBadPart,
    syncPending,
    pendingDelete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claim_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaimPart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('claim_id')) {
      context.handle(
        _claimIdMeta,
        claimId.isAcceptableOrUnknown(data['claim_id']!, _claimIdMeta),
      );
    } else if (isInserting) {
      context.missing(_claimIdMeta);
    }
    if (data.containsKey('part_type_id')) {
      context.handle(
        _partTypeIdMeta,
        partTypeId.isAcceptableOrUnknown(
          data['part_type_id']!,
          _partTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_partTypeIdMeta);
    }
    if (data.containsKey('sn_bad_part')) {
      context.handle(
        _snBadPartMeta,
        snBadPart.isAcceptableOrUnknown(data['sn_bad_part']!, _snBadPartMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('pending_delete')) {
      context.handle(
        _pendingDeleteMeta,
        pendingDelete.isAcceptableOrUnknown(
          data['pending_delete']!,
          _pendingDeleteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClaimPart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaimPart(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      claimId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claim_id'],
      )!,
      partTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_type_id'],
      )!,
      snBadPart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sn_bad_part'],
      ),
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      pendingDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_delete'],
      )!,
    );
  }

  @override
  $ClaimPartsTable createAlias(String alias) {
    return $ClaimPartsTable(attachedDatabase, alias);
  }
}

class ClaimPart extends DataClass implements Insertable<ClaimPart> {
  final String id;
  final String claimId;
  final int partTypeId;
  final String? snBadPart;
  final bool syncPending;

  /// Ditandai hapus, tapi belum sempat dihapus di server.
  ///
  /// Baris tidak langsung dibuang supaya penghapusan yang dilakukan saat
  /// offline tetap sampai ke server. Baris ini disembunyikan dari tampilan
  /// dan dibuang setelah server mengonfirmasi.
  final bool pendingDelete;
  const ClaimPart({
    required this.id,
    required this.claimId,
    required this.partTypeId,
    this.snBadPart,
    required this.syncPending,
    required this.pendingDelete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['claim_id'] = Variable<String>(claimId);
    map['part_type_id'] = Variable<int>(partTypeId);
    if (!nullToAbsent || snBadPart != null) {
      map['sn_bad_part'] = Variable<String>(snBadPart);
    }
    map['sync_pending'] = Variable<bool>(syncPending);
    map['pending_delete'] = Variable<bool>(pendingDelete);
    return map;
  }

  ClaimPartsCompanion toCompanion(bool nullToAbsent) {
    return ClaimPartsCompanion(
      id: Value(id),
      claimId: Value(claimId),
      partTypeId: Value(partTypeId),
      snBadPart: snBadPart == null && nullToAbsent
          ? const Value.absent()
          : Value(snBadPart),
      syncPending: Value(syncPending),
      pendingDelete: Value(pendingDelete),
    );
  }

  factory ClaimPart.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaimPart(
      id: serializer.fromJson<String>(json['id']),
      claimId: serializer.fromJson<String>(json['claimId']),
      partTypeId: serializer.fromJson<int>(json['partTypeId']),
      snBadPart: serializer.fromJson<String?>(json['snBadPart']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      pendingDelete: serializer.fromJson<bool>(json['pendingDelete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'claimId': serializer.toJson<String>(claimId),
      'partTypeId': serializer.toJson<int>(partTypeId),
      'snBadPart': serializer.toJson<String?>(snBadPart),
      'syncPending': serializer.toJson<bool>(syncPending),
      'pendingDelete': serializer.toJson<bool>(pendingDelete),
    };
  }

  ClaimPart copyWith({
    String? id,
    String? claimId,
    int? partTypeId,
    Value<String?> snBadPart = const Value.absent(),
    bool? syncPending,
    bool? pendingDelete,
  }) => ClaimPart(
    id: id ?? this.id,
    claimId: claimId ?? this.claimId,
    partTypeId: partTypeId ?? this.partTypeId,
    snBadPart: snBadPart.present ? snBadPart.value : this.snBadPart,
    syncPending: syncPending ?? this.syncPending,
    pendingDelete: pendingDelete ?? this.pendingDelete,
  );
  ClaimPart copyWithCompanion(ClaimPartsCompanion data) {
    return ClaimPart(
      id: data.id.present ? data.id.value : this.id,
      claimId: data.claimId.present ? data.claimId.value : this.claimId,
      partTypeId: data.partTypeId.present
          ? data.partTypeId.value
          : this.partTypeId,
      snBadPart: data.snBadPart.present ? data.snBadPart.value : this.snBadPart,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      pendingDelete: data.pendingDelete.present
          ? data.pendingDelete.value
          : this.pendingDelete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaimPart(')
          ..write('id: $id, ')
          ..write('claimId: $claimId, ')
          ..write('partTypeId: $partTypeId, ')
          ..write('snBadPart: $snBadPart, ')
          ..write('syncPending: $syncPending, ')
          ..write('pendingDelete: $pendingDelete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    claimId,
    partTypeId,
    snBadPart,
    syncPending,
    pendingDelete,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaimPart &&
          other.id == this.id &&
          other.claimId == this.claimId &&
          other.partTypeId == this.partTypeId &&
          other.snBadPart == this.snBadPart &&
          other.syncPending == this.syncPending &&
          other.pendingDelete == this.pendingDelete);
}

class ClaimPartsCompanion extends UpdateCompanion<ClaimPart> {
  final Value<String> id;
  final Value<String> claimId;
  final Value<int> partTypeId;
  final Value<String?> snBadPart;
  final Value<bool> syncPending;
  final Value<bool> pendingDelete;
  final Value<int> rowid;
  const ClaimPartsCompanion({
    this.id = const Value.absent(),
    this.claimId = const Value.absent(),
    this.partTypeId = const Value.absent(),
    this.snBadPart = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimPartsCompanion.insert({
    required String id,
    required String claimId,
    required int partTypeId,
    this.snBadPart = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       claimId = Value(claimId),
       partTypeId = Value(partTypeId);
  static Insertable<ClaimPart> custom({
    Expression<String>? id,
    Expression<String>? claimId,
    Expression<int>? partTypeId,
    Expression<String>? snBadPart,
    Expression<bool>? syncPending,
    Expression<bool>? pendingDelete,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (claimId != null) 'claim_id': claimId,
      if (partTypeId != null) 'part_type_id': partTypeId,
      if (snBadPart != null) 'sn_bad_part': snBadPart,
      if (syncPending != null) 'sync_pending': syncPending,
      if (pendingDelete != null) 'pending_delete': pendingDelete,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? claimId,
    Value<int>? partTypeId,
    Value<String?>? snBadPart,
    Value<bool>? syncPending,
    Value<bool>? pendingDelete,
    Value<int>? rowid,
  }) {
    return ClaimPartsCompanion(
      id: id ?? this.id,
      claimId: claimId ?? this.claimId,
      partTypeId: partTypeId ?? this.partTypeId,
      snBadPart: snBadPart ?? this.snBadPart,
      syncPending: syncPending ?? this.syncPending,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (claimId.present) {
      map['claim_id'] = Variable<String>(claimId.value);
    }
    if (partTypeId.present) {
      map['part_type_id'] = Variable<int>(partTypeId.value);
    }
    if (snBadPart.present) {
      map['sn_bad_part'] = Variable<String>(snBadPart.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (pendingDelete.present) {
      map['pending_delete'] = Variable<bool>(pendingDelete.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaimPartsCompanion(')
          ..write('id: $id, ')
          ..write('claimId: $claimId, ')
          ..write('partTypeId: $partTypeId, ')
          ..write('snBadPart: $snBadPart, ')
          ..write('syncPending: $syncPending, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String key;
  final String value;
  const SyncMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaData copyWith({String? key, String? value}) =>
      SyncMetaData(key: key ?? this.key, value: value ?? this.value);
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrandFeeEntriesTable extends BrandFeeEntries
    with TableInfo<$BrandFeeEntriesTable, BrandFeeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrandFeeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brandIdMeta = const VerificationMeta(
    'brandId',
  );
  @override
  late final GeneratedColumn<int> brandId = GeneratedColumn<int>(
    'brand_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<double> fee = GeneratedColumn<double>(
    'fee',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _berlakuDariMeta = const VerificationMeta(
    'berlakuDari',
  );
  @override
  late final GeneratedColumn<DateTime> berlakuDari = GeneratedColumn<DateTime>(
    'berlaku_dari',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, brandId, fee, berlakuDari];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brand_fee_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrandFeeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand_id')) {
      context.handle(
        _brandIdMeta,
        brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_brandIdMeta);
    }
    if (data.containsKey('fee')) {
      context.handle(
        _feeMeta,
        fee.isAcceptableOrUnknown(data['fee']!, _feeMeta),
      );
    } else if (isInserting) {
      context.missing(_feeMeta);
    }
    if (data.containsKey('berlaku_dari')) {
      context.handle(
        _berlakuDariMeta,
        berlakuDari.isAcceptableOrUnknown(
          data['berlaku_dari']!,
          _berlakuDariMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_berlakuDariMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BrandFeeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrandFeeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      brandId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}brand_id'],
      )!,
      fee: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fee'],
      )!,
      berlakuDari: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}berlaku_dari'],
      )!,
    );
  }

  @override
  $BrandFeeEntriesTable createAlias(String alias) {
    return $BrandFeeEntriesTable(attachedDatabase, alias);
  }
}

class BrandFeeEntry extends DataClass implements Insertable<BrandFeeEntry> {
  final int id;
  final int brandId;
  final double fee;
  final DateTime berlakuDari;
  const BrandFeeEntry({
    required this.id,
    required this.brandId,
    required this.fee,
    required this.berlakuDari,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['brand_id'] = Variable<int>(brandId);
    map['fee'] = Variable<double>(fee);
    map['berlaku_dari'] = Variable<DateTime>(berlakuDari);
    return map;
  }

  BrandFeeEntriesCompanion toCompanion(bool nullToAbsent) {
    return BrandFeeEntriesCompanion(
      id: Value(id),
      brandId: Value(brandId),
      fee: Value(fee),
      berlakuDari: Value(berlakuDari),
    );
  }

  factory BrandFeeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrandFeeEntry(
      id: serializer.fromJson<int>(json['id']),
      brandId: serializer.fromJson<int>(json['brandId']),
      fee: serializer.fromJson<double>(json['fee']),
      berlakuDari: serializer.fromJson<DateTime>(json['berlakuDari']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'brandId': serializer.toJson<int>(brandId),
      'fee': serializer.toJson<double>(fee),
      'berlakuDari': serializer.toJson<DateTime>(berlakuDari),
    };
  }

  BrandFeeEntry copyWith({
    int? id,
    int? brandId,
    double? fee,
    DateTime? berlakuDari,
  }) => BrandFeeEntry(
    id: id ?? this.id,
    brandId: brandId ?? this.brandId,
    fee: fee ?? this.fee,
    berlakuDari: berlakuDari ?? this.berlakuDari,
  );
  BrandFeeEntry copyWithCompanion(BrandFeeEntriesCompanion data) {
    return BrandFeeEntry(
      id: data.id.present ? data.id.value : this.id,
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      fee: data.fee.present ? data.fee.value : this.fee,
      berlakuDari: data.berlakuDari.present
          ? data.berlakuDari.value
          : this.berlakuDari,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrandFeeEntry(')
          ..write('id: $id, ')
          ..write('brandId: $brandId, ')
          ..write('fee: $fee, ')
          ..write('berlakuDari: $berlakuDari')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, brandId, fee, berlakuDari);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrandFeeEntry &&
          other.id == this.id &&
          other.brandId == this.brandId &&
          other.fee == this.fee &&
          other.berlakuDari == this.berlakuDari);
}

class BrandFeeEntriesCompanion extends UpdateCompanion<BrandFeeEntry> {
  final Value<int> id;
  final Value<int> brandId;
  final Value<double> fee;
  final Value<DateTime> berlakuDari;
  const BrandFeeEntriesCompanion({
    this.id = const Value.absent(),
    this.brandId = const Value.absent(),
    this.fee = const Value.absent(),
    this.berlakuDari = const Value.absent(),
  });
  BrandFeeEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int brandId,
    required double fee,
    required DateTime berlakuDari,
  }) : brandId = Value(brandId),
       fee = Value(fee),
       berlakuDari = Value(berlakuDari);
  static Insertable<BrandFeeEntry> custom({
    Expression<int>? id,
    Expression<int>? brandId,
    Expression<double>? fee,
    Expression<DateTime>? berlakuDari,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brandId != null) 'brand_id': brandId,
      if (fee != null) 'fee': fee,
      if (berlakuDari != null) 'berlaku_dari': berlakuDari,
    });
  }

  BrandFeeEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? brandId,
    Value<double>? fee,
    Value<DateTime>? berlakuDari,
  }) {
    return BrandFeeEntriesCompanion(
      id: id ?? this.id,
      brandId: brandId ?? this.brandId,
      fee: fee ?? this.fee,
      berlakuDari: berlakuDari ?? this.berlakuDari,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (brandId.present) {
      map['brand_id'] = Variable<int>(brandId.value);
    }
    if (fee.present) {
      map['fee'] = Variable<double>(fee.value);
    }
    if (berlakuDari.present) {
      map['berlaku_dari'] = Variable<DateTime>(berlakuDari.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrandFeeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('brandId: $brandId, ')
          ..write('fee: $fee, ')
          ..write('berlakuDari: $berlakuDari')
          ..write(')'))
        .toString();
  }
}

class $RevenueConfigsTable extends RevenueConfigs
    with TableInfo<$RevenueConfigsTable, RevenueConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevenueConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _persenTokoMeta = const VerificationMeta(
    'persenToko',
  );
  @override
  late final GeneratedColumn<double> persenToko = GeneratedColumn<double>(
    'persen_toko',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persenAdminMeta = const VerificationMeta(
    'persenAdmin',
  );
  @override
  late final GeneratedColumn<double> persenAdmin = GeneratedColumn<double>(
    'persen_admin',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persenTeknisiMeta = const VerificationMeta(
    'persenTeknisi',
  );
  @override
  late final GeneratedColumn<double> persenTeknisi = GeneratedColumn<double>(
    'persen_teknisi',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metodeTeknisiMeta = const VerificationMeta(
    'metodeTeknisi',
  );
  @override
  late final GeneratedColumn<String> metodeTeknisi = GeneratedColumn<String>(
    'metode_teknisi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    persenToko,
    persenAdmin,
    persenTeknisi,
    metodeTeknisi,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revenue_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RevenueConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('persen_toko')) {
      context.handle(
        _persenTokoMeta,
        persenToko.isAcceptableOrUnknown(data['persen_toko']!, _persenTokoMeta),
      );
    } else if (isInserting) {
      context.missing(_persenTokoMeta);
    }
    if (data.containsKey('persen_admin')) {
      context.handle(
        _persenAdminMeta,
        persenAdmin.isAcceptableOrUnknown(
          data['persen_admin']!,
          _persenAdminMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_persenAdminMeta);
    }
    if (data.containsKey('persen_teknisi')) {
      context.handle(
        _persenTeknisiMeta,
        persenTeknisi.isAcceptableOrUnknown(
          data['persen_teknisi']!,
          _persenTeknisiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_persenTeknisiMeta);
    }
    if (data.containsKey('metode_teknisi')) {
      context.handle(
        _metodeTeknisiMeta,
        metodeTeknisi.isAcceptableOrUnknown(
          data['metode_teknisi']!,
          _metodeTeknisiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_metodeTeknisiMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RevenueConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RevenueConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      persenToko: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_toko'],
      )!,
      persenAdmin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_admin'],
      )!,
      persenTeknisi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_teknisi'],
      )!,
      metodeTeknisi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metode_teknisi'],
      )!,
    );
  }

  @override
  $RevenueConfigsTable createAlias(String alias) {
    return $RevenueConfigsTable(attachedDatabase, alias);
  }
}

class RevenueConfig extends DataClass implements Insertable<RevenueConfig> {
  final int id;
  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;
  final String metodeTeknisi;
  const RevenueConfig({
    required this.id,
    required this.persenToko,
    required this.persenAdmin,
    required this.persenTeknisi,
    required this.metodeTeknisi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['persen_toko'] = Variable<double>(persenToko);
    map['persen_admin'] = Variable<double>(persenAdmin);
    map['persen_teknisi'] = Variable<double>(persenTeknisi);
    map['metode_teknisi'] = Variable<String>(metodeTeknisi);
    return map;
  }

  RevenueConfigsCompanion toCompanion(bool nullToAbsent) {
    return RevenueConfigsCompanion(
      id: Value(id),
      persenToko: Value(persenToko),
      persenAdmin: Value(persenAdmin),
      persenTeknisi: Value(persenTeknisi),
      metodeTeknisi: Value(metodeTeknisi),
    );
  }

  factory RevenueConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RevenueConfig(
      id: serializer.fromJson<int>(json['id']),
      persenToko: serializer.fromJson<double>(json['persenToko']),
      persenAdmin: serializer.fromJson<double>(json['persenAdmin']),
      persenTeknisi: serializer.fromJson<double>(json['persenTeknisi']),
      metodeTeknisi: serializer.fromJson<String>(json['metodeTeknisi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'persenToko': serializer.toJson<double>(persenToko),
      'persenAdmin': serializer.toJson<double>(persenAdmin),
      'persenTeknisi': serializer.toJson<double>(persenTeknisi),
      'metodeTeknisi': serializer.toJson<String>(metodeTeknisi),
    };
  }

  RevenueConfig copyWith({
    int? id,
    double? persenToko,
    double? persenAdmin,
    double? persenTeknisi,
    String? metodeTeknisi,
  }) => RevenueConfig(
    id: id ?? this.id,
    persenToko: persenToko ?? this.persenToko,
    persenAdmin: persenAdmin ?? this.persenAdmin,
    persenTeknisi: persenTeknisi ?? this.persenTeknisi,
    metodeTeknisi: metodeTeknisi ?? this.metodeTeknisi,
  );
  RevenueConfig copyWithCompanion(RevenueConfigsCompanion data) {
    return RevenueConfig(
      id: data.id.present ? data.id.value : this.id,
      persenToko: data.persenToko.present
          ? data.persenToko.value
          : this.persenToko,
      persenAdmin: data.persenAdmin.present
          ? data.persenAdmin.value
          : this.persenAdmin,
      persenTeknisi: data.persenTeknisi.present
          ? data.persenTeknisi.value
          : this.persenTeknisi,
      metodeTeknisi: data.metodeTeknisi.present
          ? data.metodeTeknisi.value
          : this.metodeTeknisi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RevenueConfig(')
          ..write('id: $id, ')
          ..write('persenToko: $persenToko, ')
          ..write('persenAdmin: $persenAdmin, ')
          ..write('persenTeknisi: $persenTeknisi, ')
          ..write('metodeTeknisi: $metodeTeknisi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, persenToko, persenAdmin, persenTeknisi, metodeTeknisi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevenueConfig &&
          other.id == this.id &&
          other.persenToko == this.persenToko &&
          other.persenAdmin == this.persenAdmin &&
          other.persenTeknisi == this.persenTeknisi &&
          other.metodeTeknisi == this.metodeTeknisi);
}

class RevenueConfigsCompanion extends UpdateCompanion<RevenueConfig> {
  final Value<int> id;
  final Value<double> persenToko;
  final Value<double> persenAdmin;
  final Value<double> persenTeknisi;
  final Value<String> metodeTeknisi;
  const RevenueConfigsCompanion({
    this.id = const Value.absent(),
    this.persenToko = const Value.absent(),
    this.persenAdmin = const Value.absent(),
    this.persenTeknisi = const Value.absent(),
    this.metodeTeknisi = const Value.absent(),
  });
  RevenueConfigsCompanion.insert({
    this.id = const Value.absent(),
    required double persenToko,
    required double persenAdmin,
    required double persenTeknisi,
    required String metodeTeknisi,
  }) : persenToko = Value(persenToko),
       persenAdmin = Value(persenAdmin),
       persenTeknisi = Value(persenTeknisi),
       metodeTeknisi = Value(metodeTeknisi);
  static Insertable<RevenueConfig> custom({
    Expression<int>? id,
    Expression<double>? persenToko,
    Expression<double>? persenAdmin,
    Expression<double>? persenTeknisi,
    Expression<String>? metodeTeknisi,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (persenToko != null) 'persen_toko': persenToko,
      if (persenAdmin != null) 'persen_admin': persenAdmin,
      if (persenTeknisi != null) 'persen_teknisi': persenTeknisi,
      if (metodeTeknisi != null) 'metode_teknisi': metodeTeknisi,
    });
  }

  RevenueConfigsCompanion copyWith({
    Value<int>? id,
    Value<double>? persenToko,
    Value<double>? persenAdmin,
    Value<double>? persenTeknisi,
    Value<String>? metodeTeknisi,
  }) {
    return RevenueConfigsCompanion(
      id: id ?? this.id,
      persenToko: persenToko ?? this.persenToko,
      persenAdmin: persenAdmin ?? this.persenAdmin,
      persenTeknisi: persenTeknisi ?? this.persenTeknisi,
      metodeTeknisi: metodeTeknisi ?? this.metodeTeknisi,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (persenToko.present) {
      map['persen_toko'] = Variable<double>(persenToko.value);
    }
    if (persenAdmin.present) {
      map['persen_admin'] = Variable<double>(persenAdmin.value);
    }
    if (persenTeknisi.present) {
      map['persen_teknisi'] = Variable<double>(persenTeknisi.value);
    }
    if (metodeTeknisi.present) {
      map['metode_teknisi'] = Variable<String>(metodeTeknisi.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevenueConfigsCompanion(')
          ..write('id: $id, ')
          ..write('persenToko: $persenToko, ')
          ..write('persenAdmin: $persenAdmin, ')
          ..write('persenTeknisi: $persenTeknisi, ')
          ..write('metodeTeknisi: $metodeTeknisi')
          ..write(')'))
        .toString();
  }
}

class $BrandShareEntriesTable extends BrandShareEntries
    with TableInfo<$BrandShareEntriesTable, BrandShareEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrandShareEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _brandIdMeta = const VerificationMeta(
    'brandId',
  );
  @override
  late final GeneratedColumn<int> brandId = GeneratedColumn<int>(
    'brand_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persenMeta = const VerificationMeta('persen');
  @override
  late final GeneratedColumn<double> persen = GeneratedColumn<double>(
    'persen',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [brandId, profileId, persen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brand_share_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrandShareEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('brand_id')) {
      context.handle(
        _brandIdMeta,
        brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_brandIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('persen')) {
      context.handle(
        _persenMeta,
        persen.isAcceptableOrUnknown(data['persen']!, _persenMeta),
      );
    } else if (isInserting) {
      context.missing(_persenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {brandId, profileId};
  @override
  BrandShareEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrandShareEntry(
      brandId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}brand_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      persen: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen'],
      )!,
    );
  }

  @override
  $BrandShareEntriesTable createAlias(String alias) {
    return $BrandShareEntriesTable(attachedDatabase, alias);
  }
}

class BrandShareEntry extends DataClass implements Insertable<BrandShareEntry> {
  final int brandId;
  final String profileId;
  final double persen;
  const BrandShareEntry({
    required this.brandId,
    required this.profileId,
    required this.persen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['brand_id'] = Variable<int>(brandId);
    map['profile_id'] = Variable<String>(profileId);
    map['persen'] = Variable<double>(persen);
    return map;
  }

  BrandShareEntriesCompanion toCompanion(bool nullToAbsent) {
    return BrandShareEntriesCompanion(
      brandId: Value(brandId),
      profileId: Value(profileId),
      persen: Value(persen),
    );
  }

  factory BrandShareEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrandShareEntry(
      brandId: serializer.fromJson<int>(json['brandId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      persen: serializer.fromJson<double>(json['persen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'brandId': serializer.toJson<int>(brandId),
      'profileId': serializer.toJson<String>(profileId),
      'persen': serializer.toJson<double>(persen),
    };
  }

  BrandShareEntry copyWith({int? brandId, String? profileId, double? persen}) =>
      BrandShareEntry(
        brandId: brandId ?? this.brandId,
        profileId: profileId ?? this.profileId,
        persen: persen ?? this.persen,
      );
  BrandShareEntry copyWithCompanion(BrandShareEntriesCompanion data) {
    return BrandShareEntry(
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      persen: data.persen.present ? data.persen.value : this.persen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrandShareEntry(')
          ..write('brandId: $brandId, ')
          ..write('profileId: $profileId, ')
          ..write('persen: $persen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(brandId, profileId, persen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrandShareEntry &&
          other.brandId == this.brandId &&
          other.profileId == this.profileId &&
          other.persen == this.persen);
}

class BrandShareEntriesCompanion extends UpdateCompanion<BrandShareEntry> {
  final Value<int> brandId;
  final Value<String> profileId;
  final Value<double> persen;
  final Value<int> rowid;
  const BrandShareEntriesCompanion({
    this.brandId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.persen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrandShareEntriesCompanion.insert({
    required int brandId,
    required String profileId,
    required double persen,
    this.rowid = const Value.absent(),
  }) : brandId = Value(brandId),
       profileId = Value(profileId),
       persen = Value(persen);
  static Insertable<BrandShareEntry> custom({
    Expression<int>? brandId,
    Expression<String>? profileId,
    Expression<double>? persen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (brandId != null) 'brand_id': brandId,
      if (profileId != null) 'profile_id': profileId,
      if (persen != null) 'persen': persen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrandShareEntriesCompanion copyWith({
    Value<int>? brandId,
    Value<String>? profileId,
    Value<double>? persen,
    Value<int>? rowid,
  }) {
    return BrandShareEntriesCompanion(
      brandId: brandId ?? this.brandId,
      profileId: profileId ?? this.profileId,
      persen: persen ?? this.persen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (brandId.present) {
      map['brand_id'] = Variable<int>(brandId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (persen.present) {
      map['persen'] = Variable<double>(persen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrandShareEntriesCompanion(')
          ..write('brandId: $brandId, ')
          ..write('profileId: $profileId, ')
          ..write('persen: $persen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrandRuleEntriesTable extends BrandRuleEntries
    with TableInfo<$BrandRuleEntriesTable, BrandRuleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrandRuleEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _brandIdMeta = const VerificationMeta(
    'brandId',
  );
  @override
  late final GeneratedColumn<int> brandId = GeneratedColumn<int>(
    'brand_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _persenTokoMeta = const VerificationMeta(
    'persenToko',
  );
  @override
  late final GeneratedColumn<double> persenToko = GeneratedColumn<double>(
    'persen_toko',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persenAdminMeta = const VerificationMeta(
    'persenAdmin',
  );
  @override
  late final GeneratedColumn<double> persenAdmin = GeneratedColumn<double>(
    'persen_admin',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persenTeknisiMeta = const VerificationMeta(
    'persenTeknisi',
  );
  @override
  late final GeneratedColumn<double> persenTeknisi = GeneratedColumn<double>(
    'persen_teknisi',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    brandId,
    persenToko,
    persenAdmin,
    persenTeknisi,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brand_rule_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrandRuleEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('brand_id')) {
      context.handle(
        _brandIdMeta,
        brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta),
      );
    }
    if (data.containsKey('persen_toko')) {
      context.handle(
        _persenTokoMeta,
        persenToko.isAcceptableOrUnknown(data['persen_toko']!, _persenTokoMeta),
      );
    } else if (isInserting) {
      context.missing(_persenTokoMeta);
    }
    if (data.containsKey('persen_admin')) {
      context.handle(
        _persenAdminMeta,
        persenAdmin.isAcceptableOrUnknown(
          data['persen_admin']!,
          _persenAdminMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_persenAdminMeta);
    }
    if (data.containsKey('persen_teknisi')) {
      context.handle(
        _persenTeknisiMeta,
        persenTeknisi.isAcceptableOrUnknown(
          data['persen_teknisi']!,
          _persenTeknisiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_persenTeknisiMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {brandId};
  @override
  BrandRuleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrandRuleEntry(
      brandId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}brand_id'],
      )!,
      persenToko: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_toko'],
      )!,
      persenAdmin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_admin'],
      )!,
      persenTeknisi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}persen_teknisi'],
      )!,
    );
  }

  @override
  $BrandRuleEntriesTable createAlias(String alias) {
    return $BrandRuleEntriesTable(attachedDatabase, alias);
  }
}

class BrandRuleEntry extends DataClass implements Insertable<BrandRuleEntry> {
  final int brandId;
  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;
  const BrandRuleEntry({
    required this.brandId,
    required this.persenToko,
    required this.persenAdmin,
    required this.persenTeknisi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['brand_id'] = Variable<int>(brandId);
    map['persen_toko'] = Variable<double>(persenToko);
    map['persen_admin'] = Variable<double>(persenAdmin);
    map['persen_teknisi'] = Variable<double>(persenTeknisi);
    return map;
  }

  BrandRuleEntriesCompanion toCompanion(bool nullToAbsent) {
    return BrandRuleEntriesCompanion(
      brandId: Value(brandId),
      persenToko: Value(persenToko),
      persenAdmin: Value(persenAdmin),
      persenTeknisi: Value(persenTeknisi),
    );
  }

  factory BrandRuleEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrandRuleEntry(
      brandId: serializer.fromJson<int>(json['brandId']),
      persenToko: serializer.fromJson<double>(json['persenToko']),
      persenAdmin: serializer.fromJson<double>(json['persenAdmin']),
      persenTeknisi: serializer.fromJson<double>(json['persenTeknisi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'brandId': serializer.toJson<int>(brandId),
      'persenToko': serializer.toJson<double>(persenToko),
      'persenAdmin': serializer.toJson<double>(persenAdmin),
      'persenTeknisi': serializer.toJson<double>(persenTeknisi),
    };
  }

  BrandRuleEntry copyWith({
    int? brandId,
    double? persenToko,
    double? persenAdmin,
    double? persenTeknisi,
  }) => BrandRuleEntry(
    brandId: brandId ?? this.brandId,
    persenToko: persenToko ?? this.persenToko,
    persenAdmin: persenAdmin ?? this.persenAdmin,
    persenTeknisi: persenTeknisi ?? this.persenTeknisi,
  );
  BrandRuleEntry copyWithCompanion(BrandRuleEntriesCompanion data) {
    return BrandRuleEntry(
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      persenToko: data.persenToko.present
          ? data.persenToko.value
          : this.persenToko,
      persenAdmin: data.persenAdmin.present
          ? data.persenAdmin.value
          : this.persenAdmin,
      persenTeknisi: data.persenTeknisi.present
          ? data.persenTeknisi.value
          : this.persenTeknisi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrandRuleEntry(')
          ..write('brandId: $brandId, ')
          ..write('persenToko: $persenToko, ')
          ..write('persenAdmin: $persenAdmin, ')
          ..write('persenTeknisi: $persenTeknisi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(brandId, persenToko, persenAdmin, persenTeknisi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrandRuleEntry &&
          other.brandId == this.brandId &&
          other.persenToko == this.persenToko &&
          other.persenAdmin == this.persenAdmin &&
          other.persenTeknisi == this.persenTeknisi);
}

class BrandRuleEntriesCompanion extends UpdateCompanion<BrandRuleEntry> {
  final Value<int> brandId;
  final Value<double> persenToko;
  final Value<double> persenAdmin;
  final Value<double> persenTeknisi;
  const BrandRuleEntriesCompanion({
    this.brandId = const Value.absent(),
    this.persenToko = const Value.absent(),
    this.persenAdmin = const Value.absent(),
    this.persenTeknisi = const Value.absent(),
  });
  BrandRuleEntriesCompanion.insert({
    this.brandId = const Value.absent(),
    required double persenToko,
    required double persenAdmin,
    required double persenTeknisi,
  }) : persenToko = Value(persenToko),
       persenAdmin = Value(persenAdmin),
       persenTeknisi = Value(persenTeknisi);
  static Insertable<BrandRuleEntry> custom({
    Expression<int>? brandId,
    Expression<double>? persenToko,
    Expression<double>? persenAdmin,
    Expression<double>? persenTeknisi,
  }) {
    return RawValuesInsertable({
      if (brandId != null) 'brand_id': brandId,
      if (persenToko != null) 'persen_toko': persenToko,
      if (persenAdmin != null) 'persen_admin': persenAdmin,
      if (persenTeknisi != null) 'persen_teknisi': persenTeknisi,
    });
  }

  BrandRuleEntriesCompanion copyWith({
    Value<int>? brandId,
    Value<double>? persenToko,
    Value<double>? persenAdmin,
    Value<double>? persenTeknisi,
  }) {
    return BrandRuleEntriesCompanion(
      brandId: brandId ?? this.brandId,
      persenToko: persenToko ?? this.persenToko,
      persenAdmin: persenAdmin ?? this.persenAdmin,
      persenTeknisi: persenTeknisi ?? this.persenTeknisi,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (brandId.present) {
      map['brand_id'] = Variable<int>(brandId.value);
    }
    if (persenToko.present) {
      map['persen_toko'] = Variable<double>(persenToko.value);
    }
    if (persenAdmin.present) {
      map['persen_admin'] = Variable<double>(persenAdmin.value);
    }
    if (persenTeknisi.present) {
      map['persen_teknisi'] = Variable<double>(persenTeknisi.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrandRuleEntriesCompanion(')
          ..write('brandId: $brandId, ')
          ..write('persenToko: $persenToko, ')
          ..write('persenAdmin: $persenAdmin, ')
          ..write('persenTeknisi: $persenTeknisi')
          ..write(')'))
        .toString();
  }
}

class $ServiceOrderEntriesTable extends ServiceOrderEntries
    with TableInfo<$ServiceOrderEntriesTable, ServiceOrderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceOrderEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noNotaMeta = const VerificationMeta('noNota');
  @override
  late final GeneratedColumn<String> noNota = GeneratedColumn<String>(
    'no_nota',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tanggalMasukMeta = const VerificationMeta(
    'tanggalMasuk',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalMasuk = GeneratedColumn<DateTime>(
    'tanggal_masuk',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimasiSelesaiMeta = const VerificationMeta(
    'estimasiSelesai',
  );
  @override
  late final GeneratedColumn<DateTime> estimasiSelesai =
      GeneratedColumn<DateTime>(
        'estimasi_selesai',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _customerNamaMeta = const VerificationMeta(
    'customerNama',
  );
  @override
  late final GeneratedColumn<String> customerNama = GeneratedColumn<String>(
    'customer_nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerTelpMeta = const VerificationMeta(
    'customerTelp',
  );
  @override
  late final GeneratedColumn<String> customerTelp = GeneratedColumn<String>(
    'customer_telp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatorIdMeta = const VerificationMeta(
    'operatorId',
  );
  @override
  late final GeneratedColumn<String> operatorId = GeneratedColumn<String>(
    'operator_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barangNamaMeta = const VerificationMeta(
    'barangNama',
  );
  @override
  late final GeneratedColumn<String> barangNama = GeneratedColumn<String>(
    'barang_nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _barangTypeMeta = const VerificationMeta(
    'barangType',
  );
  @override
  late final GeneratedColumn<String> barangType = GeneratedColumn<String>(
    'barang_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barangSnMeta = const VerificationMeta(
    'barangSn',
  );
  @override
  late final GeneratedColumn<String> barangSn = GeneratedColumn<String>(
    'barang_sn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kelengkapanMeta = const VerificationMeta(
    'kelengkapan',
  );
  @override
  late final GeneratedColumn<String> kelengkapan = GeneratedColumn<String>(
    'kelengkapan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keluhanMeta = const VerificationMeta(
    'keluhan',
  );
  @override
  late final GeneratedColumn<String> keluhan = GeneratedColumn<String>(
    'keluhan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _teknisiIdMeta = const VerificationMeta(
    'teknisiId',
  );
  @override
  late final GeneratedColumn<String> teknisiId = GeneratedColumn<String>(
    'teknisi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _perbaikanMeta = const VerificationMeta(
    'perbaikan',
  );
  @override
  late final GeneratedColumn<String> perbaikan = GeneratedColumn<String>(
    'perbaikan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _garansiMeta = const VerificationMeta(
    'garansi',
  );
  @override
  late final GeneratedColumn<bool> garansi = GeneratedColumn<bool>(
    'garansi',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("garansi" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _claimIdMeta = const VerificationMeta(
    'claimId',
  );
  @override
  late final GeneratedColumn<String> claimId = GeneratedColumn<String>(
    'claim_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biayaMeta = const VerificationMeta('biaya');
  @override
  late final GeneratedColumn<double> biaya = GeneratedColumn<double>(
    'biaya',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _caraBayarMeta = const VerificationMeta(
    'caraBayar',
  );
  @override
  late final GeneratedColumn<String> caraBayar = GeneratedColumn<String>(
    'cara_bayar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tanggalLunasMeta = const VerificationMeta(
    'tanggalLunas',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalLunas = GeneratedColumn<DateTime>(
    'tanggal_lunas',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keteranganMeta = const VerificationMeta(
    'keterangan',
  );
  @override
  late final GeneratedColumn<String> keterangan = GeneratedColumn<String>(
    'keterangan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noNota,
    tanggalMasuk,
    estimasiSelesai,
    customerNama,
    customerTelp,
    operatorId,
    barangNama,
    barangType,
    barangSn,
    kelengkapan,
    keluhan,
    teknisiId,
    perbaikan,
    garansi,
    claimId,
    status,
    biaya,
    caraBayar,
    tanggalLunas,
    keterangan,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_order_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceOrderEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('no_nota')) {
      context.handle(
        _noNotaMeta,
        noNota.isAcceptableOrUnknown(data['no_nota']!, _noNotaMeta),
      );
    } else if (isInserting) {
      context.missing(_noNotaMeta);
    }
    if (data.containsKey('tanggal_masuk')) {
      context.handle(
        _tanggalMasukMeta,
        tanggalMasuk.isAcceptableOrUnknown(
          data['tanggal_masuk']!,
          _tanggalMasukMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tanggalMasukMeta);
    }
    if (data.containsKey('estimasi_selesai')) {
      context.handle(
        _estimasiSelesaiMeta,
        estimasiSelesai.isAcceptableOrUnknown(
          data['estimasi_selesai']!,
          _estimasiSelesaiMeta,
        ),
      );
    }
    if (data.containsKey('customer_nama')) {
      context.handle(
        _customerNamaMeta,
        customerNama.isAcceptableOrUnknown(
          data['customer_nama']!,
          _customerNamaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNamaMeta);
    }
    if (data.containsKey('customer_telp')) {
      context.handle(
        _customerTelpMeta,
        customerTelp.isAcceptableOrUnknown(
          data['customer_telp']!,
          _customerTelpMeta,
        ),
      );
    }
    if (data.containsKey('operator_id')) {
      context.handle(
        _operatorIdMeta,
        operatorId.isAcceptableOrUnknown(data['operator_id']!, _operatorIdMeta),
      );
    }
    if (data.containsKey('barang_nama')) {
      context.handle(
        _barangNamaMeta,
        barangNama.isAcceptableOrUnknown(data['barang_nama']!, _barangNamaMeta),
      );
    } else if (isInserting) {
      context.missing(_barangNamaMeta);
    }
    if (data.containsKey('barang_type')) {
      context.handle(
        _barangTypeMeta,
        barangType.isAcceptableOrUnknown(data['barang_type']!, _barangTypeMeta),
      );
    }
    if (data.containsKey('barang_sn')) {
      context.handle(
        _barangSnMeta,
        barangSn.isAcceptableOrUnknown(data['barang_sn']!, _barangSnMeta),
      );
    }
    if (data.containsKey('kelengkapan')) {
      context.handle(
        _kelengkapanMeta,
        kelengkapan.isAcceptableOrUnknown(
          data['kelengkapan']!,
          _kelengkapanMeta,
        ),
      );
    }
    if (data.containsKey('keluhan')) {
      context.handle(
        _keluhanMeta,
        keluhan.isAcceptableOrUnknown(data['keluhan']!, _keluhanMeta),
      );
    }
    if (data.containsKey('teknisi_id')) {
      context.handle(
        _teknisiIdMeta,
        teknisiId.isAcceptableOrUnknown(data['teknisi_id']!, _teknisiIdMeta),
      );
    }
    if (data.containsKey('perbaikan')) {
      context.handle(
        _perbaikanMeta,
        perbaikan.isAcceptableOrUnknown(data['perbaikan']!, _perbaikanMeta),
      );
    }
    if (data.containsKey('garansi')) {
      context.handle(
        _garansiMeta,
        garansi.isAcceptableOrUnknown(data['garansi']!, _garansiMeta),
      );
    }
    if (data.containsKey('claim_id')) {
      context.handle(
        _claimIdMeta,
        claimId.isAcceptableOrUnknown(data['claim_id']!, _claimIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('biaya')) {
      context.handle(
        _biayaMeta,
        biaya.isAcceptableOrUnknown(data['biaya']!, _biayaMeta),
      );
    }
    if (data.containsKey('cara_bayar')) {
      context.handle(
        _caraBayarMeta,
        caraBayar.isAcceptableOrUnknown(data['cara_bayar']!, _caraBayarMeta),
      );
    }
    if (data.containsKey('tanggal_lunas')) {
      context.handle(
        _tanggalLunasMeta,
        tanggalLunas.isAcceptableOrUnknown(
          data['tanggal_lunas']!,
          _tanggalLunasMeta,
        ),
      );
    }
    if (data.containsKey('keterangan')) {
      context.handle(
        _keteranganMeta,
        keterangan.isAcceptableOrUnknown(data['keterangan']!, _keteranganMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceOrderEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceOrderEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noNota: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_nota'],
      )!,
      tanggalMasuk: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_masuk'],
      )!,
      estimasiSelesai: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}estimasi_selesai'],
      ),
      customerNama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_nama'],
      )!,
      customerTelp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_telp'],
      ),
      operatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_id'],
      ),
      barangNama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barang_nama'],
      )!,
      barangType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barang_type'],
      ),
      barangSn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barang_sn'],
      ),
      kelengkapan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kelengkapan'],
      ),
      keluhan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keluhan'],
      ),
      teknisiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teknisi_id'],
      ),
      perbaikan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}perbaikan'],
      ),
      garansi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}garansi'],
      )!,
      claimId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claim_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      biaya: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}biaya'],
      )!,
      caraBayar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cara_bayar'],
      ),
      tanggalLunas: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_lunas'],
      ),
      keterangan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keterangan'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ServiceOrderEntriesTable createAlias(String alias) {
    return $ServiceOrderEntriesTable(attachedDatabase, alias);
  }
}

class ServiceOrderEntry extends DataClass
    implements Insertable<ServiceOrderEntry> {
  final String id;
  final String noNota;
  final DateTime tanggalMasuk;
  final DateTime? estimasiSelesai;
  final String customerNama;
  final String? customerTelp;
  final String? operatorId;
  final String barangNama;
  final String? barangType;
  final String? barangSn;
  final String? kelengkapan;
  final String? keluhan;
  final String? teknisiId;
  final String? perbaikan;
  final bool garansi;
  final String? claimId;
  final String status;
  final double biaya;
  final String? caraBayar;
  final DateTime? tanggalLunas;
  final String? keterangan;
  final DateTime updatedAt;
  const ServiceOrderEntry({
    required this.id,
    required this.noNota,
    required this.tanggalMasuk,
    this.estimasiSelesai,
    required this.customerNama,
    this.customerTelp,
    this.operatorId,
    required this.barangNama,
    this.barangType,
    this.barangSn,
    this.kelengkapan,
    this.keluhan,
    this.teknisiId,
    this.perbaikan,
    required this.garansi,
    this.claimId,
    required this.status,
    required this.biaya,
    this.caraBayar,
    this.tanggalLunas,
    this.keterangan,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['no_nota'] = Variable<String>(noNota);
    map['tanggal_masuk'] = Variable<DateTime>(tanggalMasuk);
    if (!nullToAbsent || estimasiSelesai != null) {
      map['estimasi_selesai'] = Variable<DateTime>(estimasiSelesai);
    }
    map['customer_nama'] = Variable<String>(customerNama);
    if (!nullToAbsent || customerTelp != null) {
      map['customer_telp'] = Variable<String>(customerTelp);
    }
    if (!nullToAbsent || operatorId != null) {
      map['operator_id'] = Variable<String>(operatorId);
    }
    map['barang_nama'] = Variable<String>(barangNama);
    if (!nullToAbsent || barangType != null) {
      map['barang_type'] = Variable<String>(barangType);
    }
    if (!nullToAbsent || barangSn != null) {
      map['barang_sn'] = Variable<String>(barangSn);
    }
    if (!nullToAbsent || kelengkapan != null) {
      map['kelengkapan'] = Variable<String>(kelengkapan);
    }
    if (!nullToAbsent || keluhan != null) {
      map['keluhan'] = Variable<String>(keluhan);
    }
    if (!nullToAbsent || teknisiId != null) {
      map['teknisi_id'] = Variable<String>(teknisiId);
    }
    if (!nullToAbsent || perbaikan != null) {
      map['perbaikan'] = Variable<String>(perbaikan);
    }
    map['garansi'] = Variable<bool>(garansi);
    if (!nullToAbsent || claimId != null) {
      map['claim_id'] = Variable<String>(claimId);
    }
    map['status'] = Variable<String>(status);
    map['biaya'] = Variable<double>(biaya);
    if (!nullToAbsent || caraBayar != null) {
      map['cara_bayar'] = Variable<String>(caraBayar);
    }
    if (!nullToAbsent || tanggalLunas != null) {
      map['tanggal_lunas'] = Variable<DateTime>(tanggalLunas);
    }
    if (!nullToAbsent || keterangan != null) {
      map['keterangan'] = Variable<String>(keterangan);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ServiceOrderEntriesCompanion toCompanion(bool nullToAbsent) {
    return ServiceOrderEntriesCompanion(
      id: Value(id),
      noNota: Value(noNota),
      tanggalMasuk: Value(tanggalMasuk),
      estimasiSelesai: estimasiSelesai == null && nullToAbsent
          ? const Value.absent()
          : Value(estimasiSelesai),
      customerNama: Value(customerNama),
      customerTelp: customerTelp == null && nullToAbsent
          ? const Value.absent()
          : Value(customerTelp),
      operatorId: operatorId == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorId),
      barangNama: Value(barangNama),
      barangType: barangType == null && nullToAbsent
          ? const Value.absent()
          : Value(barangType),
      barangSn: barangSn == null && nullToAbsent
          ? const Value.absent()
          : Value(barangSn),
      kelengkapan: kelengkapan == null && nullToAbsent
          ? const Value.absent()
          : Value(kelengkapan),
      keluhan: keluhan == null && nullToAbsent
          ? const Value.absent()
          : Value(keluhan),
      teknisiId: teknisiId == null && nullToAbsent
          ? const Value.absent()
          : Value(teknisiId),
      perbaikan: perbaikan == null && nullToAbsent
          ? const Value.absent()
          : Value(perbaikan),
      garansi: Value(garansi),
      claimId: claimId == null && nullToAbsent
          ? const Value.absent()
          : Value(claimId),
      status: Value(status),
      biaya: Value(biaya),
      caraBayar: caraBayar == null && nullToAbsent
          ? const Value.absent()
          : Value(caraBayar),
      tanggalLunas: tanggalLunas == null && nullToAbsent
          ? const Value.absent()
          : Value(tanggalLunas),
      keterangan: keterangan == null && nullToAbsent
          ? const Value.absent()
          : Value(keterangan),
      updatedAt: Value(updatedAt),
    );
  }

  factory ServiceOrderEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceOrderEntry(
      id: serializer.fromJson<String>(json['id']),
      noNota: serializer.fromJson<String>(json['noNota']),
      tanggalMasuk: serializer.fromJson<DateTime>(json['tanggalMasuk']),
      estimasiSelesai: serializer.fromJson<DateTime?>(json['estimasiSelesai']),
      customerNama: serializer.fromJson<String>(json['customerNama']),
      customerTelp: serializer.fromJson<String?>(json['customerTelp']),
      operatorId: serializer.fromJson<String?>(json['operatorId']),
      barangNama: serializer.fromJson<String>(json['barangNama']),
      barangType: serializer.fromJson<String?>(json['barangType']),
      barangSn: serializer.fromJson<String?>(json['barangSn']),
      kelengkapan: serializer.fromJson<String?>(json['kelengkapan']),
      keluhan: serializer.fromJson<String?>(json['keluhan']),
      teknisiId: serializer.fromJson<String?>(json['teknisiId']),
      perbaikan: serializer.fromJson<String?>(json['perbaikan']),
      garansi: serializer.fromJson<bool>(json['garansi']),
      claimId: serializer.fromJson<String?>(json['claimId']),
      status: serializer.fromJson<String>(json['status']),
      biaya: serializer.fromJson<double>(json['biaya']),
      caraBayar: serializer.fromJson<String?>(json['caraBayar']),
      tanggalLunas: serializer.fromJson<DateTime?>(json['tanggalLunas']),
      keterangan: serializer.fromJson<String?>(json['keterangan']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noNota': serializer.toJson<String>(noNota),
      'tanggalMasuk': serializer.toJson<DateTime>(tanggalMasuk),
      'estimasiSelesai': serializer.toJson<DateTime?>(estimasiSelesai),
      'customerNama': serializer.toJson<String>(customerNama),
      'customerTelp': serializer.toJson<String?>(customerTelp),
      'operatorId': serializer.toJson<String?>(operatorId),
      'barangNama': serializer.toJson<String>(barangNama),
      'barangType': serializer.toJson<String?>(barangType),
      'barangSn': serializer.toJson<String?>(barangSn),
      'kelengkapan': serializer.toJson<String?>(kelengkapan),
      'keluhan': serializer.toJson<String?>(keluhan),
      'teknisiId': serializer.toJson<String?>(teknisiId),
      'perbaikan': serializer.toJson<String?>(perbaikan),
      'garansi': serializer.toJson<bool>(garansi),
      'claimId': serializer.toJson<String?>(claimId),
      'status': serializer.toJson<String>(status),
      'biaya': serializer.toJson<double>(biaya),
      'caraBayar': serializer.toJson<String?>(caraBayar),
      'tanggalLunas': serializer.toJson<DateTime?>(tanggalLunas),
      'keterangan': serializer.toJson<String?>(keterangan),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ServiceOrderEntry copyWith({
    String? id,
    String? noNota,
    DateTime? tanggalMasuk,
    Value<DateTime?> estimasiSelesai = const Value.absent(),
    String? customerNama,
    Value<String?> customerTelp = const Value.absent(),
    Value<String?> operatorId = const Value.absent(),
    String? barangNama,
    Value<String?> barangType = const Value.absent(),
    Value<String?> barangSn = const Value.absent(),
    Value<String?> kelengkapan = const Value.absent(),
    Value<String?> keluhan = const Value.absent(),
    Value<String?> teknisiId = const Value.absent(),
    Value<String?> perbaikan = const Value.absent(),
    bool? garansi,
    Value<String?> claimId = const Value.absent(),
    String? status,
    double? biaya,
    Value<String?> caraBayar = const Value.absent(),
    Value<DateTime?> tanggalLunas = const Value.absent(),
    Value<String?> keterangan = const Value.absent(),
    DateTime? updatedAt,
  }) => ServiceOrderEntry(
    id: id ?? this.id,
    noNota: noNota ?? this.noNota,
    tanggalMasuk: tanggalMasuk ?? this.tanggalMasuk,
    estimasiSelesai: estimasiSelesai.present
        ? estimasiSelesai.value
        : this.estimasiSelesai,
    customerNama: customerNama ?? this.customerNama,
    customerTelp: customerTelp.present ? customerTelp.value : this.customerTelp,
    operatorId: operatorId.present ? operatorId.value : this.operatorId,
    barangNama: barangNama ?? this.barangNama,
    barangType: barangType.present ? barangType.value : this.barangType,
    barangSn: barangSn.present ? barangSn.value : this.barangSn,
    kelengkapan: kelengkapan.present ? kelengkapan.value : this.kelengkapan,
    keluhan: keluhan.present ? keluhan.value : this.keluhan,
    teknisiId: teknisiId.present ? teknisiId.value : this.teknisiId,
    perbaikan: perbaikan.present ? perbaikan.value : this.perbaikan,
    garansi: garansi ?? this.garansi,
    claimId: claimId.present ? claimId.value : this.claimId,
    status: status ?? this.status,
    biaya: biaya ?? this.biaya,
    caraBayar: caraBayar.present ? caraBayar.value : this.caraBayar,
    tanggalLunas: tanggalLunas.present ? tanggalLunas.value : this.tanggalLunas,
    keterangan: keterangan.present ? keterangan.value : this.keterangan,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ServiceOrderEntry copyWithCompanion(ServiceOrderEntriesCompanion data) {
    return ServiceOrderEntry(
      id: data.id.present ? data.id.value : this.id,
      noNota: data.noNota.present ? data.noNota.value : this.noNota,
      tanggalMasuk: data.tanggalMasuk.present
          ? data.tanggalMasuk.value
          : this.tanggalMasuk,
      estimasiSelesai: data.estimasiSelesai.present
          ? data.estimasiSelesai.value
          : this.estimasiSelesai,
      customerNama: data.customerNama.present
          ? data.customerNama.value
          : this.customerNama,
      customerTelp: data.customerTelp.present
          ? data.customerTelp.value
          : this.customerTelp,
      operatorId: data.operatorId.present
          ? data.operatorId.value
          : this.operatorId,
      barangNama: data.barangNama.present
          ? data.barangNama.value
          : this.barangNama,
      barangType: data.barangType.present
          ? data.barangType.value
          : this.barangType,
      barangSn: data.barangSn.present ? data.barangSn.value : this.barangSn,
      kelengkapan: data.kelengkapan.present
          ? data.kelengkapan.value
          : this.kelengkapan,
      keluhan: data.keluhan.present ? data.keluhan.value : this.keluhan,
      teknisiId: data.teknisiId.present ? data.teknisiId.value : this.teknisiId,
      perbaikan: data.perbaikan.present ? data.perbaikan.value : this.perbaikan,
      garansi: data.garansi.present ? data.garansi.value : this.garansi,
      claimId: data.claimId.present ? data.claimId.value : this.claimId,
      status: data.status.present ? data.status.value : this.status,
      biaya: data.biaya.present ? data.biaya.value : this.biaya,
      caraBayar: data.caraBayar.present ? data.caraBayar.value : this.caraBayar,
      tanggalLunas: data.tanggalLunas.present
          ? data.tanggalLunas.value
          : this.tanggalLunas,
      keterangan: data.keterangan.present
          ? data.keterangan.value
          : this.keterangan,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceOrderEntry(')
          ..write('id: $id, ')
          ..write('noNota: $noNota, ')
          ..write('tanggalMasuk: $tanggalMasuk, ')
          ..write('estimasiSelesai: $estimasiSelesai, ')
          ..write('customerNama: $customerNama, ')
          ..write('customerTelp: $customerTelp, ')
          ..write('operatorId: $operatorId, ')
          ..write('barangNama: $barangNama, ')
          ..write('barangType: $barangType, ')
          ..write('barangSn: $barangSn, ')
          ..write('kelengkapan: $kelengkapan, ')
          ..write('keluhan: $keluhan, ')
          ..write('teknisiId: $teknisiId, ')
          ..write('perbaikan: $perbaikan, ')
          ..write('garansi: $garansi, ')
          ..write('claimId: $claimId, ')
          ..write('status: $status, ')
          ..write('biaya: $biaya, ')
          ..write('caraBayar: $caraBayar, ')
          ..write('tanggalLunas: $tanggalLunas, ')
          ..write('keterangan: $keterangan, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noNota,
    tanggalMasuk,
    estimasiSelesai,
    customerNama,
    customerTelp,
    operatorId,
    barangNama,
    barangType,
    barangSn,
    kelengkapan,
    keluhan,
    teknisiId,
    perbaikan,
    garansi,
    claimId,
    status,
    biaya,
    caraBayar,
    tanggalLunas,
    keterangan,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceOrderEntry &&
          other.id == this.id &&
          other.noNota == this.noNota &&
          other.tanggalMasuk == this.tanggalMasuk &&
          other.estimasiSelesai == this.estimasiSelesai &&
          other.customerNama == this.customerNama &&
          other.customerTelp == this.customerTelp &&
          other.operatorId == this.operatorId &&
          other.barangNama == this.barangNama &&
          other.barangType == this.barangType &&
          other.barangSn == this.barangSn &&
          other.kelengkapan == this.kelengkapan &&
          other.keluhan == this.keluhan &&
          other.teknisiId == this.teknisiId &&
          other.perbaikan == this.perbaikan &&
          other.garansi == this.garansi &&
          other.claimId == this.claimId &&
          other.status == this.status &&
          other.biaya == this.biaya &&
          other.caraBayar == this.caraBayar &&
          other.tanggalLunas == this.tanggalLunas &&
          other.keterangan == this.keterangan &&
          other.updatedAt == this.updatedAt);
}

class ServiceOrderEntriesCompanion extends UpdateCompanion<ServiceOrderEntry> {
  final Value<String> id;
  final Value<String> noNota;
  final Value<DateTime> tanggalMasuk;
  final Value<DateTime?> estimasiSelesai;
  final Value<String> customerNama;
  final Value<String?> customerTelp;
  final Value<String?> operatorId;
  final Value<String> barangNama;
  final Value<String?> barangType;
  final Value<String?> barangSn;
  final Value<String?> kelengkapan;
  final Value<String?> keluhan;
  final Value<String?> teknisiId;
  final Value<String?> perbaikan;
  final Value<bool> garansi;
  final Value<String?> claimId;
  final Value<String> status;
  final Value<double> biaya;
  final Value<String?> caraBayar;
  final Value<DateTime?> tanggalLunas;
  final Value<String?> keterangan;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ServiceOrderEntriesCompanion({
    this.id = const Value.absent(),
    this.noNota = const Value.absent(),
    this.tanggalMasuk = const Value.absent(),
    this.estimasiSelesai = const Value.absent(),
    this.customerNama = const Value.absent(),
    this.customerTelp = const Value.absent(),
    this.operatorId = const Value.absent(),
    this.barangNama = const Value.absent(),
    this.barangType = const Value.absent(),
    this.barangSn = const Value.absent(),
    this.kelengkapan = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.teknisiId = const Value.absent(),
    this.perbaikan = const Value.absent(),
    this.garansi = const Value.absent(),
    this.claimId = const Value.absent(),
    this.status = const Value.absent(),
    this.biaya = const Value.absent(),
    this.caraBayar = const Value.absent(),
    this.tanggalLunas = const Value.absent(),
    this.keterangan = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceOrderEntriesCompanion.insert({
    required String id,
    required String noNota,
    required DateTime tanggalMasuk,
    this.estimasiSelesai = const Value.absent(),
    required String customerNama,
    this.customerTelp = const Value.absent(),
    this.operatorId = const Value.absent(),
    required String barangNama,
    this.barangType = const Value.absent(),
    this.barangSn = const Value.absent(),
    this.kelengkapan = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.teknisiId = const Value.absent(),
    this.perbaikan = const Value.absent(),
    this.garansi = const Value.absent(),
    this.claimId = const Value.absent(),
    required String status,
    this.biaya = const Value.absent(),
    this.caraBayar = const Value.absent(),
    this.tanggalLunas = const Value.absent(),
    this.keterangan = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noNota = Value(noNota),
       tanggalMasuk = Value(tanggalMasuk),
       customerNama = Value(customerNama),
       barangNama = Value(barangNama),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ServiceOrderEntry> custom({
    Expression<String>? id,
    Expression<String>? noNota,
    Expression<DateTime>? tanggalMasuk,
    Expression<DateTime>? estimasiSelesai,
    Expression<String>? customerNama,
    Expression<String>? customerTelp,
    Expression<String>? operatorId,
    Expression<String>? barangNama,
    Expression<String>? barangType,
    Expression<String>? barangSn,
    Expression<String>? kelengkapan,
    Expression<String>? keluhan,
    Expression<String>? teknisiId,
    Expression<String>? perbaikan,
    Expression<bool>? garansi,
    Expression<String>? claimId,
    Expression<String>? status,
    Expression<double>? biaya,
    Expression<String>? caraBayar,
    Expression<DateTime>? tanggalLunas,
    Expression<String>? keterangan,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noNota != null) 'no_nota': noNota,
      if (tanggalMasuk != null) 'tanggal_masuk': tanggalMasuk,
      if (estimasiSelesai != null) 'estimasi_selesai': estimasiSelesai,
      if (customerNama != null) 'customer_nama': customerNama,
      if (customerTelp != null) 'customer_telp': customerTelp,
      if (operatorId != null) 'operator_id': operatorId,
      if (barangNama != null) 'barang_nama': barangNama,
      if (barangType != null) 'barang_type': barangType,
      if (barangSn != null) 'barang_sn': barangSn,
      if (kelengkapan != null) 'kelengkapan': kelengkapan,
      if (keluhan != null) 'keluhan': keluhan,
      if (teknisiId != null) 'teknisi_id': teknisiId,
      if (perbaikan != null) 'perbaikan': perbaikan,
      if (garansi != null) 'garansi': garansi,
      if (claimId != null) 'claim_id': claimId,
      if (status != null) 'status': status,
      if (biaya != null) 'biaya': biaya,
      if (caraBayar != null) 'cara_bayar': caraBayar,
      if (tanggalLunas != null) 'tanggal_lunas': tanggalLunas,
      if (keterangan != null) 'keterangan': keterangan,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceOrderEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? noNota,
    Value<DateTime>? tanggalMasuk,
    Value<DateTime?>? estimasiSelesai,
    Value<String>? customerNama,
    Value<String?>? customerTelp,
    Value<String?>? operatorId,
    Value<String>? barangNama,
    Value<String?>? barangType,
    Value<String?>? barangSn,
    Value<String?>? kelengkapan,
    Value<String?>? keluhan,
    Value<String?>? teknisiId,
    Value<String?>? perbaikan,
    Value<bool>? garansi,
    Value<String?>? claimId,
    Value<String>? status,
    Value<double>? biaya,
    Value<String?>? caraBayar,
    Value<DateTime?>? tanggalLunas,
    Value<String?>? keterangan,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ServiceOrderEntriesCompanion(
      id: id ?? this.id,
      noNota: noNota ?? this.noNota,
      tanggalMasuk: tanggalMasuk ?? this.tanggalMasuk,
      estimasiSelesai: estimasiSelesai ?? this.estimasiSelesai,
      customerNama: customerNama ?? this.customerNama,
      customerTelp: customerTelp ?? this.customerTelp,
      operatorId: operatorId ?? this.operatorId,
      barangNama: barangNama ?? this.barangNama,
      barangType: barangType ?? this.barangType,
      barangSn: barangSn ?? this.barangSn,
      kelengkapan: kelengkapan ?? this.kelengkapan,
      keluhan: keluhan ?? this.keluhan,
      teknisiId: teknisiId ?? this.teknisiId,
      perbaikan: perbaikan ?? this.perbaikan,
      garansi: garansi ?? this.garansi,
      claimId: claimId ?? this.claimId,
      status: status ?? this.status,
      biaya: biaya ?? this.biaya,
      caraBayar: caraBayar ?? this.caraBayar,
      tanggalLunas: tanggalLunas ?? this.tanggalLunas,
      keterangan: keterangan ?? this.keterangan,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noNota.present) {
      map['no_nota'] = Variable<String>(noNota.value);
    }
    if (tanggalMasuk.present) {
      map['tanggal_masuk'] = Variable<DateTime>(tanggalMasuk.value);
    }
    if (estimasiSelesai.present) {
      map['estimasi_selesai'] = Variable<DateTime>(estimasiSelesai.value);
    }
    if (customerNama.present) {
      map['customer_nama'] = Variable<String>(customerNama.value);
    }
    if (customerTelp.present) {
      map['customer_telp'] = Variable<String>(customerTelp.value);
    }
    if (operatorId.present) {
      map['operator_id'] = Variable<String>(operatorId.value);
    }
    if (barangNama.present) {
      map['barang_nama'] = Variable<String>(barangNama.value);
    }
    if (barangType.present) {
      map['barang_type'] = Variable<String>(barangType.value);
    }
    if (barangSn.present) {
      map['barang_sn'] = Variable<String>(barangSn.value);
    }
    if (kelengkapan.present) {
      map['kelengkapan'] = Variable<String>(kelengkapan.value);
    }
    if (keluhan.present) {
      map['keluhan'] = Variable<String>(keluhan.value);
    }
    if (teknisiId.present) {
      map['teknisi_id'] = Variable<String>(teknisiId.value);
    }
    if (perbaikan.present) {
      map['perbaikan'] = Variable<String>(perbaikan.value);
    }
    if (garansi.present) {
      map['garansi'] = Variable<bool>(garansi.value);
    }
    if (claimId.present) {
      map['claim_id'] = Variable<String>(claimId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (biaya.present) {
      map['biaya'] = Variable<double>(biaya.value);
    }
    if (caraBayar.present) {
      map['cara_bayar'] = Variable<String>(caraBayar.value);
    }
    if (tanggalLunas.present) {
      map['tanggal_lunas'] = Variable<DateTime>(tanggalLunas.value);
    }
    if (keterangan.present) {
      map['keterangan'] = Variable<String>(keterangan.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceOrderEntriesCompanion(')
          ..write('id: $id, ')
          ..write('noNota: $noNota, ')
          ..write('tanggalMasuk: $tanggalMasuk, ')
          ..write('estimasiSelesai: $estimasiSelesai, ')
          ..write('customerNama: $customerNama, ')
          ..write('customerTelp: $customerTelp, ')
          ..write('operatorId: $operatorId, ')
          ..write('barangNama: $barangNama, ')
          ..write('barangType: $barangType, ')
          ..write('barangSn: $barangSn, ')
          ..write('kelengkapan: $kelengkapan, ')
          ..write('keluhan: $keluhan, ')
          ..write('teknisiId: $teknisiId, ')
          ..write('perbaikan: $perbaikan, ')
          ..write('garansi: $garansi, ')
          ..write('claimId: $claimId, ')
          ..write('status: $status, ')
          ..write('biaya: $biaya, ')
          ..write('caraBayar: $caraBayar, ')
          ..write('tanggalLunas: $tanggalLunas, ')
          ..write('keterangan: $keterangan, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShipmentEntriesTable extends ShipmentEntries
    with TableInfo<$ShipmentEntriesTable, ShipmentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShipmentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tanggalKirimMeta = const VerificationMeta(
    'tanggalKirim',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalKirim = GeneratedColumn<DateTime>(
    'tanggal_kirim',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dariCabangMeta = const VerificationMeta(
    'dariCabang',
  );
  @override
  late final GeneratedColumn<String> dariCabang = GeneratedColumn<String>(
    'dari_cabang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keCabangMeta = const VerificationMeta(
    'keCabang',
  );
  @override
  late final GeneratedColumn<String> keCabang = GeneratedColumn<String>(
    'ke_cabang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNamaMeta = const VerificationMeta(
    'userNama',
  );
  @override
  late final GeneratedColumn<String> userNama = GeneratedColumn<String>(
    'user_nama',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barangNamaMeta = const VerificationMeta(
    'barangNama',
  );
  @override
  late final GeneratedColumn<String> barangNama = GeneratedColumn<String>(
    'barang_nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serialNumberMeta = const VerificationMeta(
    'serialNumber',
  );
  @override
  late final GeneratedColumn<String> serialNumber = GeneratedColumn<String>(
    'serial_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keluhanMeta = const VerificationMeta(
    'keluhan',
  );
  @override
  late final GeneratedColumn<String> keluhan = GeneratedColumn<String>(
    'keluhan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kelengkapanMeta = const VerificationMeta(
    'kelengkapan',
  );
  @override
  late final GeneratedColumn<String> kelengkapan = GeneratedColumn<String>(
    'kelengkapan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tanggalKembaliMeta = const VerificationMeta(
    'tanggalKembali',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalKembali =
      GeneratedColumn<DateTime>(
        'tanggal_kembali',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _keteranganMeta = const VerificationMeta(
    'keterangan',
  );
  @override
  late final GeneratedColumn<String> keterangan = GeneratedColumn<String>(
    'keterangan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tanggalKirim,
    dariCabang,
    keCabang,
    userNama,
    barangNama,
    serialNumber,
    keluhan,
    kelengkapan,
    status,
    tanggalKembali,
    keterangan,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shipment_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShipmentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tanggal_kirim')) {
      context.handle(
        _tanggalKirimMeta,
        tanggalKirim.isAcceptableOrUnknown(
          data['tanggal_kirim']!,
          _tanggalKirimMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tanggalKirimMeta);
    }
    if (data.containsKey('dari_cabang')) {
      context.handle(
        _dariCabangMeta,
        dariCabang.isAcceptableOrUnknown(data['dari_cabang']!, _dariCabangMeta),
      );
    } else if (isInserting) {
      context.missing(_dariCabangMeta);
    }
    if (data.containsKey('ke_cabang')) {
      context.handle(
        _keCabangMeta,
        keCabang.isAcceptableOrUnknown(data['ke_cabang']!, _keCabangMeta),
      );
    } else if (isInserting) {
      context.missing(_keCabangMeta);
    }
    if (data.containsKey('user_nama')) {
      context.handle(
        _userNamaMeta,
        userNama.isAcceptableOrUnknown(data['user_nama']!, _userNamaMeta),
      );
    }
    if (data.containsKey('barang_nama')) {
      context.handle(
        _barangNamaMeta,
        barangNama.isAcceptableOrUnknown(data['barang_nama']!, _barangNamaMeta),
      );
    } else if (isInserting) {
      context.missing(_barangNamaMeta);
    }
    if (data.containsKey('serial_number')) {
      context.handle(
        _serialNumberMeta,
        serialNumber.isAcceptableOrUnknown(
          data['serial_number']!,
          _serialNumberMeta,
        ),
      );
    }
    if (data.containsKey('keluhan')) {
      context.handle(
        _keluhanMeta,
        keluhan.isAcceptableOrUnknown(data['keluhan']!, _keluhanMeta),
      );
    }
    if (data.containsKey('kelengkapan')) {
      context.handle(
        _kelengkapanMeta,
        kelengkapan.isAcceptableOrUnknown(
          data['kelengkapan']!,
          _kelengkapanMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('tanggal_kembali')) {
      context.handle(
        _tanggalKembaliMeta,
        tanggalKembali.isAcceptableOrUnknown(
          data['tanggal_kembali']!,
          _tanggalKembaliMeta,
        ),
      );
    }
    if (data.containsKey('keterangan')) {
      context.handle(
        _keteranganMeta,
        keterangan.isAcceptableOrUnknown(data['keterangan']!, _keteranganMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShipmentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShipmentEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tanggalKirim: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_kirim'],
      )!,
      dariCabang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dari_cabang'],
      )!,
      keCabang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ke_cabang'],
      )!,
      userNama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_nama'],
      ),
      barangNama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barang_nama'],
      )!,
      serialNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial_number'],
      ),
      keluhan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keluhan'],
      ),
      kelengkapan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kelengkapan'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      tanggalKembali: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_kembali'],
      ),
      keterangan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keterangan'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ShipmentEntriesTable createAlias(String alias) {
    return $ShipmentEntriesTable(attachedDatabase, alias);
  }
}

class ShipmentEntry extends DataClass implements Insertable<ShipmentEntry> {
  final String id;
  final DateTime tanggalKirim;
  final String dariCabang;
  final String keCabang;
  final String? userNama;
  final String barangNama;
  final String? serialNumber;
  final String? keluhan;
  final String? kelengkapan;
  final String status;
  final DateTime? tanggalKembali;
  final String? keterangan;
  final DateTime updatedAt;
  const ShipmentEntry({
    required this.id,
    required this.tanggalKirim,
    required this.dariCabang,
    required this.keCabang,
    this.userNama,
    required this.barangNama,
    this.serialNumber,
    this.keluhan,
    this.kelengkapan,
    required this.status,
    this.tanggalKembali,
    this.keterangan,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tanggal_kirim'] = Variable<DateTime>(tanggalKirim);
    map['dari_cabang'] = Variable<String>(dariCabang);
    map['ke_cabang'] = Variable<String>(keCabang);
    if (!nullToAbsent || userNama != null) {
      map['user_nama'] = Variable<String>(userNama);
    }
    map['barang_nama'] = Variable<String>(barangNama);
    if (!nullToAbsent || serialNumber != null) {
      map['serial_number'] = Variable<String>(serialNumber);
    }
    if (!nullToAbsent || keluhan != null) {
      map['keluhan'] = Variable<String>(keluhan);
    }
    if (!nullToAbsent || kelengkapan != null) {
      map['kelengkapan'] = Variable<String>(kelengkapan);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || tanggalKembali != null) {
      map['tanggal_kembali'] = Variable<DateTime>(tanggalKembali);
    }
    if (!nullToAbsent || keterangan != null) {
      map['keterangan'] = Variable<String>(keterangan);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ShipmentEntriesCompanion toCompanion(bool nullToAbsent) {
    return ShipmentEntriesCompanion(
      id: Value(id),
      tanggalKirim: Value(tanggalKirim),
      dariCabang: Value(dariCabang),
      keCabang: Value(keCabang),
      userNama: userNama == null && nullToAbsent
          ? const Value.absent()
          : Value(userNama),
      barangNama: Value(barangNama),
      serialNumber: serialNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(serialNumber),
      keluhan: keluhan == null && nullToAbsent
          ? const Value.absent()
          : Value(keluhan),
      kelengkapan: kelengkapan == null && nullToAbsent
          ? const Value.absent()
          : Value(kelengkapan),
      status: Value(status),
      tanggalKembali: tanggalKembali == null && nullToAbsent
          ? const Value.absent()
          : Value(tanggalKembali),
      keterangan: keterangan == null && nullToAbsent
          ? const Value.absent()
          : Value(keterangan),
      updatedAt: Value(updatedAt),
    );
  }

  factory ShipmentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShipmentEntry(
      id: serializer.fromJson<String>(json['id']),
      tanggalKirim: serializer.fromJson<DateTime>(json['tanggalKirim']),
      dariCabang: serializer.fromJson<String>(json['dariCabang']),
      keCabang: serializer.fromJson<String>(json['keCabang']),
      userNama: serializer.fromJson<String?>(json['userNama']),
      barangNama: serializer.fromJson<String>(json['barangNama']),
      serialNumber: serializer.fromJson<String?>(json['serialNumber']),
      keluhan: serializer.fromJson<String?>(json['keluhan']),
      kelengkapan: serializer.fromJson<String?>(json['kelengkapan']),
      status: serializer.fromJson<String>(json['status']),
      tanggalKembali: serializer.fromJson<DateTime?>(json['tanggalKembali']),
      keterangan: serializer.fromJson<String?>(json['keterangan']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tanggalKirim': serializer.toJson<DateTime>(tanggalKirim),
      'dariCabang': serializer.toJson<String>(dariCabang),
      'keCabang': serializer.toJson<String>(keCabang),
      'userNama': serializer.toJson<String?>(userNama),
      'barangNama': serializer.toJson<String>(barangNama),
      'serialNumber': serializer.toJson<String?>(serialNumber),
      'keluhan': serializer.toJson<String?>(keluhan),
      'kelengkapan': serializer.toJson<String?>(kelengkapan),
      'status': serializer.toJson<String>(status),
      'tanggalKembali': serializer.toJson<DateTime?>(tanggalKembali),
      'keterangan': serializer.toJson<String?>(keterangan),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ShipmentEntry copyWith({
    String? id,
    DateTime? tanggalKirim,
    String? dariCabang,
    String? keCabang,
    Value<String?> userNama = const Value.absent(),
    String? barangNama,
    Value<String?> serialNumber = const Value.absent(),
    Value<String?> keluhan = const Value.absent(),
    Value<String?> kelengkapan = const Value.absent(),
    String? status,
    Value<DateTime?> tanggalKembali = const Value.absent(),
    Value<String?> keterangan = const Value.absent(),
    DateTime? updatedAt,
  }) => ShipmentEntry(
    id: id ?? this.id,
    tanggalKirim: tanggalKirim ?? this.tanggalKirim,
    dariCabang: dariCabang ?? this.dariCabang,
    keCabang: keCabang ?? this.keCabang,
    userNama: userNama.present ? userNama.value : this.userNama,
    barangNama: barangNama ?? this.barangNama,
    serialNumber: serialNumber.present ? serialNumber.value : this.serialNumber,
    keluhan: keluhan.present ? keluhan.value : this.keluhan,
    kelengkapan: kelengkapan.present ? kelengkapan.value : this.kelengkapan,
    status: status ?? this.status,
    tanggalKembali: tanggalKembali.present
        ? tanggalKembali.value
        : this.tanggalKembali,
    keterangan: keterangan.present ? keterangan.value : this.keterangan,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ShipmentEntry copyWithCompanion(ShipmentEntriesCompanion data) {
    return ShipmentEntry(
      id: data.id.present ? data.id.value : this.id,
      tanggalKirim: data.tanggalKirim.present
          ? data.tanggalKirim.value
          : this.tanggalKirim,
      dariCabang: data.dariCabang.present
          ? data.dariCabang.value
          : this.dariCabang,
      keCabang: data.keCabang.present ? data.keCabang.value : this.keCabang,
      userNama: data.userNama.present ? data.userNama.value : this.userNama,
      barangNama: data.barangNama.present
          ? data.barangNama.value
          : this.barangNama,
      serialNumber: data.serialNumber.present
          ? data.serialNumber.value
          : this.serialNumber,
      keluhan: data.keluhan.present ? data.keluhan.value : this.keluhan,
      kelengkapan: data.kelengkapan.present
          ? data.kelengkapan.value
          : this.kelengkapan,
      status: data.status.present ? data.status.value : this.status,
      tanggalKembali: data.tanggalKembali.present
          ? data.tanggalKembali.value
          : this.tanggalKembali,
      keterangan: data.keterangan.present
          ? data.keterangan.value
          : this.keterangan,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShipmentEntry(')
          ..write('id: $id, ')
          ..write('tanggalKirim: $tanggalKirim, ')
          ..write('dariCabang: $dariCabang, ')
          ..write('keCabang: $keCabang, ')
          ..write('userNama: $userNama, ')
          ..write('barangNama: $barangNama, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('keluhan: $keluhan, ')
          ..write('kelengkapan: $kelengkapan, ')
          ..write('status: $status, ')
          ..write('tanggalKembali: $tanggalKembali, ')
          ..write('keterangan: $keterangan, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tanggalKirim,
    dariCabang,
    keCabang,
    userNama,
    barangNama,
    serialNumber,
    keluhan,
    kelengkapan,
    status,
    tanggalKembali,
    keterangan,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShipmentEntry &&
          other.id == this.id &&
          other.tanggalKirim == this.tanggalKirim &&
          other.dariCabang == this.dariCabang &&
          other.keCabang == this.keCabang &&
          other.userNama == this.userNama &&
          other.barangNama == this.barangNama &&
          other.serialNumber == this.serialNumber &&
          other.keluhan == this.keluhan &&
          other.kelengkapan == this.kelengkapan &&
          other.status == this.status &&
          other.tanggalKembali == this.tanggalKembali &&
          other.keterangan == this.keterangan &&
          other.updatedAt == this.updatedAt);
}

class ShipmentEntriesCompanion extends UpdateCompanion<ShipmentEntry> {
  final Value<String> id;
  final Value<DateTime> tanggalKirim;
  final Value<String> dariCabang;
  final Value<String> keCabang;
  final Value<String?> userNama;
  final Value<String> barangNama;
  final Value<String?> serialNumber;
  final Value<String?> keluhan;
  final Value<String?> kelengkapan;
  final Value<String> status;
  final Value<DateTime?> tanggalKembali;
  final Value<String?> keterangan;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ShipmentEntriesCompanion({
    this.id = const Value.absent(),
    this.tanggalKirim = const Value.absent(),
    this.dariCabang = const Value.absent(),
    this.keCabang = const Value.absent(),
    this.userNama = const Value.absent(),
    this.barangNama = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.kelengkapan = const Value.absent(),
    this.status = const Value.absent(),
    this.tanggalKembali = const Value.absent(),
    this.keterangan = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShipmentEntriesCompanion.insert({
    required String id,
    required DateTime tanggalKirim,
    required String dariCabang,
    required String keCabang,
    this.userNama = const Value.absent(),
    required String barangNama,
    this.serialNumber = const Value.absent(),
    this.keluhan = const Value.absent(),
    this.kelengkapan = const Value.absent(),
    required String status,
    this.tanggalKembali = const Value.absent(),
    this.keterangan = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tanggalKirim = Value(tanggalKirim),
       dariCabang = Value(dariCabang),
       keCabang = Value(keCabang),
       barangNama = Value(barangNama),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ShipmentEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? tanggalKirim,
    Expression<String>? dariCabang,
    Expression<String>? keCabang,
    Expression<String>? userNama,
    Expression<String>? barangNama,
    Expression<String>? serialNumber,
    Expression<String>? keluhan,
    Expression<String>? kelengkapan,
    Expression<String>? status,
    Expression<DateTime>? tanggalKembali,
    Expression<String>? keterangan,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tanggalKirim != null) 'tanggal_kirim': tanggalKirim,
      if (dariCabang != null) 'dari_cabang': dariCabang,
      if (keCabang != null) 'ke_cabang': keCabang,
      if (userNama != null) 'user_nama': userNama,
      if (barangNama != null) 'barang_nama': barangNama,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (keluhan != null) 'keluhan': keluhan,
      if (kelengkapan != null) 'kelengkapan': kelengkapan,
      if (status != null) 'status': status,
      if (tanggalKembali != null) 'tanggal_kembali': tanggalKembali,
      if (keterangan != null) 'keterangan': keterangan,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShipmentEntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? tanggalKirim,
    Value<String>? dariCabang,
    Value<String>? keCabang,
    Value<String?>? userNama,
    Value<String>? barangNama,
    Value<String?>? serialNumber,
    Value<String?>? keluhan,
    Value<String?>? kelengkapan,
    Value<String>? status,
    Value<DateTime?>? tanggalKembali,
    Value<String?>? keterangan,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ShipmentEntriesCompanion(
      id: id ?? this.id,
      tanggalKirim: tanggalKirim ?? this.tanggalKirim,
      dariCabang: dariCabang ?? this.dariCabang,
      keCabang: keCabang ?? this.keCabang,
      userNama: userNama ?? this.userNama,
      barangNama: barangNama ?? this.barangNama,
      serialNumber: serialNumber ?? this.serialNumber,
      keluhan: keluhan ?? this.keluhan,
      kelengkapan: kelengkapan ?? this.kelengkapan,
      status: status ?? this.status,
      tanggalKembali: tanggalKembali ?? this.tanggalKembali,
      keterangan: keterangan ?? this.keterangan,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tanggalKirim.present) {
      map['tanggal_kirim'] = Variable<DateTime>(tanggalKirim.value);
    }
    if (dariCabang.present) {
      map['dari_cabang'] = Variable<String>(dariCabang.value);
    }
    if (keCabang.present) {
      map['ke_cabang'] = Variable<String>(keCabang.value);
    }
    if (userNama.present) {
      map['user_nama'] = Variable<String>(userNama.value);
    }
    if (barangNama.present) {
      map['barang_nama'] = Variable<String>(barangNama.value);
    }
    if (serialNumber.present) {
      map['serial_number'] = Variable<String>(serialNumber.value);
    }
    if (keluhan.present) {
      map['keluhan'] = Variable<String>(keluhan.value);
    }
    if (kelengkapan.present) {
      map['kelengkapan'] = Variable<String>(kelengkapan.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (tanggalKembali.present) {
      map['tanggal_kembali'] = Variable<DateTime>(tanggalKembali.value);
    }
    if (keterangan.present) {
      map['keterangan'] = Variable<String>(keterangan.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShipmentEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tanggalKirim: $tanggalKirim, ')
          ..write('dariCabang: $dariCabang, ')
          ..write('keCabang: $keCabang, ')
          ..write('userNama: $userNama, ')
          ..write('barangNama: $barangNama, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('keluhan: $keluhan, ')
          ..write('kelengkapan: $kelengkapan, ')
          ..write('status: $status, ')
          ..write('tanggalKembali: $tanggalKembali, ')
          ..write('keterangan: $keterangan, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BrandsTable brands = $BrandsTable(this);
  late final $PartTypesTable partTypes = $PartTypesTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ClaimsTable claims = $ClaimsTable(this);
  late final $ClaimPartsTable claimParts = $ClaimPartsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $BrandFeeEntriesTable brandFeeEntries = $BrandFeeEntriesTable(
    this,
  );
  late final $RevenueConfigsTable revenueConfigs = $RevenueConfigsTable(this);
  late final $BrandShareEntriesTable brandShareEntries =
      $BrandShareEntriesTable(this);
  late final $BrandRuleEntriesTable brandRuleEntries = $BrandRuleEntriesTable(
    this,
  );
  late final $ServiceOrderEntriesTable serviceOrderEntries =
      $ServiceOrderEntriesTable(this);
  late final $ShipmentEntriesTable shipmentEntries = $ShipmentEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    brands,
    partTypes,
    profiles,
    claims,
    claimParts,
    syncMeta,
    brandFeeEntries,
    revenueConfigs,
    brandShareEntries,
    brandRuleEntries,
    serviceOrderEntries,
    shipmentEntries,
  ];
}

typedef $$BrandsTableCreateCompanionBuilder = BrandsCompanion Function({
  Value<int> id,
  required String nama,
  Value<bool> aktif,
});
typedef $$BrandsTableUpdateCompanionBuilder = BrandsCompanion Function({
  Value<int> id,
  Value<String> nama,
  Value<bool> aktif,
});

class $$BrandsTableFilterComposer
    extends Composer<_$AppDatabase, $BrandsTable> {
  $$BrandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrandsTableOrderingComposer
    extends Composer<_$AppDatabase, $BrandsTable> {
  $$BrandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrandsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrandsTable> {
  $$BrandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<bool> get aktif =>
      $composableBuilder(column: $table.aktif, builder: (column) => column);
}

class $$BrandsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrandsTable,
          Brand,
          $$BrandsTableFilterComposer,
          $$BrandsTableOrderingComposer,
          $$BrandsTableAnnotationComposer,
          $$BrandsTableCreateCompanionBuilder,
          $$BrandsTableUpdateCompanionBuilder,
          (Brand, BaseReferences<_$AppDatabase, $BrandsTable, Brand>),
          Brand,
          PrefetchHooks Function()
        > {
  $$BrandsTableTableManager(_$AppDatabase db, $BrandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nama = const Value.absent(),
            Value<bool> aktif = const Value.absent(),
          }) => BrandsCompanion(id: id, nama: nama, aktif: aktif),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nama,
            Value<bool> aktif = const Value.absent(),
          }) => BrandsCompanion.insert(id: id, nama: nama, aktif: aktif),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrandsTable,
      Brand,
      $$BrandsTableFilterComposer,
      $$BrandsTableOrderingComposer,
      $$BrandsTableAnnotationComposer,
      $$BrandsTableCreateCompanionBuilder,
      $$BrandsTableUpdateCompanionBuilder,
      (Brand, BaseReferences<_$AppDatabase, $BrandsTable, Brand>),
      Brand,
      PrefetchHooks Function()
    >;
typedef $$PartTypesTableCreateCompanionBuilder = PartTypesCompanion Function({
  Value<int> id,
  required String kode,
  required String nama,
  Value<bool> aktif,
});
typedef $$PartTypesTableUpdateCompanionBuilder = PartTypesCompanion Function({
  Value<int> id,
  Value<String> kode,
  Value<String> nama,
  Value<bool> aktif,
});

class $$PartTypesTableFilterComposer
    extends Composer<_$AppDatabase, $PartTypesTable> {
  $$PartTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PartTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $PartTypesTable> {
  $$PartTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartTypesTable> {
  $$PartTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kode =>
      $composableBuilder(column: $table.kode, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<bool> get aktif =>
      $composableBuilder(column: $table.aktif, builder: (column) => column);
}

class $$PartTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartTypesTable,
          PartType,
          $$PartTypesTableFilterComposer,
          $$PartTypesTableOrderingComposer,
          $$PartTypesTableAnnotationComposer,
          $$PartTypesTableCreateCompanionBuilder,
          $$PartTypesTableUpdateCompanionBuilder,
          (PartType, BaseReferences<_$AppDatabase, $PartTypesTable, PartType>),
          PartType,
          PrefetchHooks Function()
        > {
  $$PartTypesTableTableManager(_$AppDatabase db, $PartTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kode = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<bool> aktif = const Value.absent(),
              }) => PartTypesCompanion(
                id: id,
                kode: kode,
                nama: nama,
                aktif: aktif,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kode,
                required String nama,
                Value<bool> aktif = const Value.absent(),
              }) => PartTypesCompanion.insert(
                id: id,
                kode: kode,
                nama: nama,
                aktif: aktif,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PartTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartTypesTable,
      PartType,
      $$PartTypesTableFilterComposer,
      $$PartTypesTableOrderingComposer,
      $$PartTypesTableAnnotationComposer,
      $$PartTypesTableCreateCompanionBuilder,
      $$PartTypesTableUpdateCompanionBuilder,
      (PartType, BaseReferences<_$AppDatabase, $PartTypesTable, PartType>),
      PartType,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String nama,
  required String role,
  Value<bool> aktif,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> nama,
  Value<String> role,
  Value<bool> aktif,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aktif => $composableBuilder(
    column: $table.aktif,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get aktif =>
      $composableBuilder(column: $table.aktif, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> aktif = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                nama: nama,
                role: role,
                aktif: aktif,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nama,
                required String role,
                Value<bool> aktif = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                nama: nama,
                role: role,
                aktif: aktif,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$ClaimsTableCreateCompanionBuilder = ClaimsCompanion Function({
  required String id,
  required DateTime tanggal,
  required int brandId,
  required String namaPelanggan,
  Value<String?> telp,
  required String sn,
  Value<String?> teknisiId,
  Value<String?> keluhan,
  Value<String?> noPerbaikan,
  Value<String> status,
  Value<String?> catatan,
  required String createdBy,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> syncPending,
  Value<int> rowid,
});
typedef $$ClaimsTableUpdateCompanionBuilder = ClaimsCompanion Function({
  Value<String> id,
  Value<DateTime> tanggal,
  Value<int> brandId,
  Value<String> namaPelanggan,
  Value<String?> telp,
  Value<String> sn,
  Value<String?> teknisiId,
  Value<String?> keluhan,
  Value<String?> noPerbaikan,
  Value<String> status,
  Value<String?> catatan,
  Value<String> createdBy,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> syncPending,
  Value<int> rowid,
});

class $$ClaimsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggal => $composableBuilder(
    column: $table.tanggal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get namaPelanggan => $composableBuilder(
    column: $table.namaPelanggan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telp => $composableBuilder(
    column: $table.telp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sn => $composableBuilder(
    column: $table.sn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teknisiId => $composableBuilder(
    column: $table.teknisiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noPerbaikan => $composableBuilder(
    column: $table.noPerbaikan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClaimsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggal => $composableBuilder(
    column: $table.tanggal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get namaPelanggan => $composableBuilder(
    column: $table.namaPelanggan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telp => $composableBuilder(
    column: $table.telp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sn => $composableBuilder(
    column: $table.sn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teknisiId => $composableBuilder(
    column: $table.teknisiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noPerbaikan => $composableBuilder(
    column: $table.noPerbaikan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClaimsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggal =>
      $composableBuilder(column: $table.tanggal, builder: (column) => column);

  GeneratedColumn<int> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<String> get namaPelanggan => $composableBuilder(
    column: $table.namaPelanggan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get telp =>
      $composableBuilder(column: $table.telp, builder: (column) => column);

  GeneratedColumn<String> get sn =>
      $composableBuilder(column: $table.sn, builder: (column) => column);

  GeneratedColumn<String> get teknisiId =>
      $composableBuilder(column: $table.teknisiId, builder: (column) => column);

  GeneratedColumn<String> get keluhan =>
      $composableBuilder(column: $table.keluhan, builder: (column) => column);

  GeneratedColumn<String> get noPerbaikan => $composableBuilder(
    column: $table.noPerbaikan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );
}

class $$ClaimsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaimsTable,
          Claim,
          $$ClaimsTableFilterComposer,
          $$ClaimsTableOrderingComposer,
          $$ClaimsTableAnnotationComposer,
          $$ClaimsTableCreateCompanionBuilder,
          $$ClaimsTableUpdateCompanionBuilder,
          (Claim, BaseReferences<_$AppDatabase, $ClaimsTable, Claim>),
          Claim,
          PrefetchHooks Function()
        > {
  $$ClaimsTableTableManager(_$AppDatabase db, $ClaimsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> tanggal = const Value.absent(),
                Value<int> brandId = const Value.absent(),
                Value<String> namaPelanggan = const Value.absent(),
                Value<String?> telp = const Value.absent(),
                Value<String> sn = const Value.absent(),
                Value<String?> teknisiId = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> noPerbaikan = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion(
                id: id,
                tanggal: tanggal,
                brandId: brandId,
                namaPelanggan: namaPelanggan,
                telp: telp,
                sn: sn,
                teknisiId: teknisiId,
                keluhan: keluhan,
                noPerbaikan: noPerbaikan,
                status: status,
                catatan: catatan,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncPending: syncPending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime tanggal,
                required int brandId,
                required String namaPelanggan,
                Value<String?> telp = const Value.absent(),
                required String sn,
                Value<String?> teknisiId = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> noPerbaikan = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                required String createdBy,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> syncPending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion.insert(
                id: id,
                tanggal: tanggal,
                brandId: brandId,
                namaPelanggan: namaPelanggan,
                telp: telp,
                sn: sn,
                teknisiId: teknisiId,
                keluhan: keluhan,
                noPerbaikan: noPerbaikan,
                status: status,
                catatan: catatan,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncPending: syncPending,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClaimsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaimsTable,
      Claim,
      $$ClaimsTableFilterComposer,
      $$ClaimsTableOrderingComposer,
      $$ClaimsTableAnnotationComposer,
      $$ClaimsTableCreateCompanionBuilder,
      $$ClaimsTableUpdateCompanionBuilder,
      (Claim, BaseReferences<_$AppDatabase, $ClaimsTable, Claim>),
      Claim,
      PrefetchHooks Function()
    >;
typedef $$ClaimPartsTableCreateCompanionBuilder = ClaimPartsCompanion Function({
  required String id,
  required String claimId,
  required int partTypeId,
  Value<String?> snBadPart,
  Value<bool> syncPending,
  Value<bool> pendingDelete,
  Value<int> rowid,
});
typedef $$ClaimPartsTableUpdateCompanionBuilder = ClaimPartsCompanion Function({
  Value<String> id,
  Value<String> claimId,
  Value<int> partTypeId,
  Value<String?> snBadPart,
  Value<bool> syncPending,
  Value<bool> pendingDelete,
  Value<int> rowid,
});

class $$ClaimPartsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaimPartsTable> {
  $$ClaimPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimId => $composableBuilder(
    column: $table.claimId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partTypeId => $composableBuilder(
    column: $table.partTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snBadPart => $composableBuilder(
    column: $table.snBadPart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClaimPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaimPartsTable> {
  $$ClaimPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimId => $composableBuilder(
    column: $table.claimId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partTypeId => $composableBuilder(
    column: $table.partTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snBadPart => $composableBuilder(
    column: $table.snBadPart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClaimPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaimPartsTable> {
  $$ClaimPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get claimId =>
      $composableBuilder(column: $table.claimId, builder: (column) => column);

  GeneratedColumn<int> get partTypeId => $composableBuilder(
    column: $table.partTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snBadPart =>
      $composableBuilder(column: $table.snBadPart, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => column,
  );
}

class $$ClaimPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaimPartsTable,
          ClaimPart,
          $$ClaimPartsTableFilterComposer,
          $$ClaimPartsTableOrderingComposer,
          $$ClaimPartsTableAnnotationComposer,
          $$ClaimPartsTableCreateCompanionBuilder,
          $$ClaimPartsTableUpdateCompanionBuilder,
          (
            ClaimPart,
            BaseReferences<_$AppDatabase, $ClaimPartsTable, ClaimPart>,
          ),
          ClaimPart,
          PrefetchHooks Function()
        > {
  $$ClaimPartsTableTableManager(_$AppDatabase db, $ClaimPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> claimId = const Value.absent(),
                Value<int> partTypeId = const Value.absent(),
                Value<String?> snBadPart = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimPartsCompanion(
                id: id,
                claimId: claimId,
                partTypeId: partTypeId,
                snBadPart: snBadPart,
                syncPending: syncPending,
                pendingDelete: pendingDelete,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String claimId,
                required int partTypeId,
                Value<String?> snBadPart = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimPartsCompanion.insert(
                id: id,
                claimId: claimId,
                partTypeId: partTypeId,
                snBadPart: snBadPart,
                syncPending: syncPending,
                pendingDelete: pendingDelete,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClaimPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaimPartsTable,
      ClaimPart,
      $$ClaimPartsTableFilterComposer,
      $$ClaimPartsTableOrderingComposer,
      $$ClaimPartsTableAnnotationComposer,
      $$ClaimPartsTableCreateCompanionBuilder,
      $$ClaimPartsTableUpdateCompanionBuilder,
      (ClaimPart, BaseReferences<_$AppDatabase, $ClaimPartsTable, ClaimPart>),
      ClaimPart,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;
typedef $$BrandFeeEntriesTableCreateCompanionBuilder =
    BrandFeeEntriesCompanion Function({
      Value<int> id,
      required int brandId,
      required double fee,
      required DateTime berlakuDari,
    });
typedef $$BrandFeeEntriesTableUpdateCompanionBuilder =
    BrandFeeEntriesCompanion Function({
      Value<int> id,
      Value<int> brandId,
      Value<double> fee,
      Value<DateTime> berlakuDari,
    });

class $$BrandFeeEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BrandFeeEntriesTable> {
  $$BrandFeeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get berlakuDari => $composableBuilder(
    column: $table.berlakuDari,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrandFeeEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BrandFeeEntriesTable> {
  $$BrandFeeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get berlakuDari => $composableBuilder(
    column: $table.berlakuDari,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrandFeeEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrandFeeEntriesTable> {
  $$BrandFeeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<double> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<DateTime> get berlakuDari => $composableBuilder(
    column: $table.berlakuDari,
    builder: (column) => column,
  );
}

class $$BrandFeeEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrandFeeEntriesTable,
          BrandFeeEntry,
          $$BrandFeeEntriesTableFilterComposer,
          $$BrandFeeEntriesTableOrderingComposer,
          $$BrandFeeEntriesTableAnnotationComposer,
          $$BrandFeeEntriesTableCreateCompanionBuilder,
          $$BrandFeeEntriesTableUpdateCompanionBuilder,
          (
            BrandFeeEntry,
            BaseReferences<_$AppDatabase, $BrandFeeEntriesTable, BrandFeeEntry>,
          ),
          BrandFeeEntry,
          PrefetchHooks Function()
        > {
  $$BrandFeeEntriesTableTableManager(
    _$AppDatabase db,
    $BrandFeeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrandFeeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrandFeeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrandFeeEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> brandId = const Value.absent(),
                Value<double> fee = const Value.absent(),
                Value<DateTime> berlakuDari = const Value.absent(),
              }) => BrandFeeEntriesCompanion(
                id: id,
                brandId: brandId,
                fee: fee,
                berlakuDari: berlakuDari,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int brandId,
                required double fee,
                required DateTime berlakuDari,
              }) => BrandFeeEntriesCompanion.insert(
                id: id,
                brandId: brandId,
                fee: fee,
                berlakuDari: berlakuDari,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrandFeeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrandFeeEntriesTable,
      BrandFeeEntry,
      $$BrandFeeEntriesTableFilterComposer,
      $$BrandFeeEntriesTableOrderingComposer,
      $$BrandFeeEntriesTableAnnotationComposer,
      $$BrandFeeEntriesTableCreateCompanionBuilder,
      $$BrandFeeEntriesTableUpdateCompanionBuilder,
      (
        BrandFeeEntry,
        BaseReferences<_$AppDatabase, $BrandFeeEntriesTable, BrandFeeEntry>,
      ),
      BrandFeeEntry,
      PrefetchHooks Function()
    >;
typedef $$RevenueConfigsTableCreateCompanionBuilder =
    RevenueConfigsCompanion Function({
      Value<int> id,
      required double persenToko,
      required double persenAdmin,
      required double persenTeknisi,
      required String metodeTeknisi,
    });
typedef $$RevenueConfigsTableUpdateCompanionBuilder =
    RevenueConfigsCompanion Function({
      Value<int> id,
      Value<double> persenToko,
      Value<double> persenAdmin,
      Value<double> persenTeknisi,
      Value<String> metodeTeknisi,
    });

class $$RevenueConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $RevenueConfigsTable> {
  $$RevenueConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metodeTeknisi => $composableBuilder(
    column: $table.metodeTeknisi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RevenueConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $RevenueConfigsTable> {
  $$RevenueConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metodeTeknisi => $composableBuilder(
    column: $table.metodeTeknisi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RevenueConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RevenueConfigsTable> {
  $$RevenueConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => column,
  );

  GeneratedColumn<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metodeTeknisi => $composableBuilder(
    column: $table.metodeTeknisi,
    builder: (column) => column,
  );
}

class $$RevenueConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RevenueConfigsTable,
          RevenueConfig,
          $$RevenueConfigsTableFilterComposer,
          $$RevenueConfigsTableOrderingComposer,
          $$RevenueConfigsTableAnnotationComposer,
          $$RevenueConfigsTableCreateCompanionBuilder,
          $$RevenueConfigsTableUpdateCompanionBuilder,
          (
            RevenueConfig,
            BaseReferences<_$AppDatabase, $RevenueConfigsTable, RevenueConfig>,
          ),
          RevenueConfig,
          PrefetchHooks Function()
        > {
  $$RevenueConfigsTableTableManager(
    _$AppDatabase db,
    $RevenueConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RevenueConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevenueConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevenueConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> persenToko = const Value.absent(),
                Value<double> persenAdmin = const Value.absent(),
                Value<double> persenTeknisi = const Value.absent(),
                Value<String> metodeTeknisi = const Value.absent(),
              }) => RevenueConfigsCompanion(
                id: id,
                persenToko: persenToko,
                persenAdmin: persenAdmin,
                persenTeknisi: persenTeknisi,
                metodeTeknisi: metodeTeknisi,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double persenToko,
                required double persenAdmin,
                required double persenTeknisi,
                required String metodeTeknisi,
              }) => RevenueConfigsCompanion.insert(
                id: id,
                persenToko: persenToko,
                persenAdmin: persenAdmin,
                persenTeknisi: persenTeknisi,
                metodeTeknisi: metodeTeknisi,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RevenueConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RevenueConfigsTable,
      RevenueConfig,
      $$RevenueConfigsTableFilterComposer,
      $$RevenueConfigsTableOrderingComposer,
      $$RevenueConfigsTableAnnotationComposer,
      $$RevenueConfigsTableCreateCompanionBuilder,
      $$RevenueConfigsTableUpdateCompanionBuilder,
      (
        RevenueConfig,
        BaseReferences<_$AppDatabase, $RevenueConfigsTable, RevenueConfig>,
      ),
      RevenueConfig,
      PrefetchHooks Function()
    >;
typedef $$BrandShareEntriesTableCreateCompanionBuilder =
    BrandShareEntriesCompanion Function({
      required int brandId,
      required String profileId,
      required double persen,
      Value<int> rowid,
    });
typedef $$BrandShareEntriesTableUpdateCompanionBuilder =
    BrandShareEntriesCompanion Function({
      Value<int> brandId,
      Value<String> profileId,
      Value<double> persen,
      Value<int> rowid,
    });

class $$BrandShareEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BrandShareEntriesTable> {
  $$BrandShareEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persen => $composableBuilder(
    column: $table.persen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrandShareEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BrandShareEntriesTable> {
  $$BrandShareEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persen => $composableBuilder(
    column: $table.persen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrandShareEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrandShareEntriesTable> {
  $$BrandShareEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<double> get persen =>
      $composableBuilder(column: $table.persen, builder: (column) => column);
}

class $$BrandShareEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrandShareEntriesTable,
          BrandShareEntry,
          $$BrandShareEntriesTableFilterComposer,
          $$BrandShareEntriesTableOrderingComposer,
          $$BrandShareEntriesTableAnnotationComposer,
          $$BrandShareEntriesTableCreateCompanionBuilder,
          $$BrandShareEntriesTableUpdateCompanionBuilder,
          (
            BrandShareEntry,
            BaseReferences<
              _$AppDatabase,
              $BrandShareEntriesTable,
              BrandShareEntry
            >,
          ),
          BrandShareEntry,
          PrefetchHooks Function()
        > {
  $$BrandShareEntriesTableTableManager(
    _$AppDatabase db,
    $BrandShareEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrandShareEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrandShareEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrandShareEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> brandId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<double> persen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrandShareEntriesCompanion(
                brandId: brandId,
                profileId: profileId,
                persen: persen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int brandId,
                required String profileId,
                required double persen,
                Value<int> rowid = const Value.absent(),
              }) => BrandShareEntriesCompanion.insert(
                brandId: brandId,
                profileId: profileId,
                persen: persen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrandShareEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrandShareEntriesTable,
      BrandShareEntry,
      $$BrandShareEntriesTableFilterComposer,
      $$BrandShareEntriesTableOrderingComposer,
      $$BrandShareEntriesTableAnnotationComposer,
      $$BrandShareEntriesTableCreateCompanionBuilder,
      $$BrandShareEntriesTableUpdateCompanionBuilder,
      (
        BrandShareEntry,
        BaseReferences<_$AppDatabase, $BrandShareEntriesTable, BrandShareEntry>,
      ),
      BrandShareEntry,
      PrefetchHooks Function()
    >;
typedef $$BrandRuleEntriesTableCreateCompanionBuilder =
    BrandRuleEntriesCompanion Function({
      Value<int> brandId,
      required double persenToko,
      required double persenAdmin,
      required double persenTeknisi,
    });
typedef $$BrandRuleEntriesTableUpdateCompanionBuilder =
    BrandRuleEntriesCompanion Function({
      Value<int> brandId,
      Value<double> persenToko,
      Value<double> persenAdmin,
      Value<double> persenTeknisi,
    });

class $$BrandRuleEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BrandRuleEntriesTable> {
  $$BrandRuleEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrandRuleEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BrandRuleEntriesTable> {
  $$BrandRuleEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrandRuleEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrandRuleEntriesTable> {
  $$BrandRuleEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<double> get persenToko => $composableBuilder(
    column: $table.persenToko,
    builder: (column) => column,
  );

  GeneratedColumn<double> get persenAdmin => $composableBuilder(
    column: $table.persenAdmin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get persenTeknisi => $composableBuilder(
    column: $table.persenTeknisi,
    builder: (column) => column,
  );
}

class $$BrandRuleEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrandRuleEntriesTable,
          BrandRuleEntry,
          $$BrandRuleEntriesTableFilterComposer,
          $$BrandRuleEntriesTableOrderingComposer,
          $$BrandRuleEntriesTableAnnotationComposer,
          $$BrandRuleEntriesTableCreateCompanionBuilder,
          $$BrandRuleEntriesTableUpdateCompanionBuilder,
          (
            BrandRuleEntry,
            BaseReferences<
              _$AppDatabase,
              $BrandRuleEntriesTable,
              BrandRuleEntry
            >,
          ),
          BrandRuleEntry,
          PrefetchHooks Function()
        > {
  $$BrandRuleEntriesTableTableManager(
    _$AppDatabase db,
    $BrandRuleEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrandRuleEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrandRuleEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrandRuleEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> brandId = const Value.absent(),
                Value<double> persenToko = const Value.absent(),
                Value<double> persenAdmin = const Value.absent(),
                Value<double> persenTeknisi = const Value.absent(),
              }) => BrandRuleEntriesCompanion(
                brandId: brandId,
                persenToko: persenToko,
                persenAdmin: persenAdmin,
                persenTeknisi: persenTeknisi,
              ),
          createCompanionCallback:
              ({
                Value<int> brandId = const Value.absent(),
                required double persenToko,
                required double persenAdmin,
                required double persenTeknisi,
              }) => BrandRuleEntriesCompanion.insert(
                brandId: brandId,
                persenToko: persenToko,
                persenAdmin: persenAdmin,
                persenTeknisi: persenTeknisi,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrandRuleEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrandRuleEntriesTable,
      BrandRuleEntry,
      $$BrandRuleEntriesTableFilterComposer,
      $$BrandRuleEntriesTableOrderingComposer,
      $$BrandRuleEntriesTableAnnotationComposer,
      $$BrandRuleEntriesTableCreateCompanionBuilder,
      $$BrandRuleEntriesTableUpdateCompanionBuilder,
      (
        BrandRuleEntry,
        BaseReferences<_$AppDatabase, $BrandRuleEntriesTable, BrandRuleEntry>,
      ),
      BrandRuleEntry,
      PrefetchHooks Function()
    >;
typedef $$ServiceOrderEntriesTableCreateCompanionBuilder =
    ServiceOrderEntriesCompanion Function({
      required String id,
      required String noNota,
      required DateTime tanggalMasuk,
      Value<DateTime?> estimasiSelesai,
      required String customerNama,
      Value<String?> customerTelp,
      Value<String?> operatorId,
      required String barangNama,
      Value<String?> barangType,
      Value<String?> barangSn,
      Value<String?> kelengkapan,
      Value<String?> keluhan,
      Value<String?> teknisiId,
      Value<String?> perbaikan,
      Value<bool> garansi,
      Value<String?> claimId,
      required String status,
      Value<double> biaya,
      Value<String?> caraBayar,
      Value<DateTime?> tanggalLunas,
      Value<String?> keterangan,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ServiceOrderEntriesTableUpdateCompanionBuilder =
    ServiceOrderEntriesCompanion Function({
      Value<String> id,
      Value<String> noNota,
      Value<DateTime> tanggalMasuk,
      Value<DateTime?> estimasiSelesai,
      Value<String> customerNama,
      Value<String?> customerTelp,
      Value<String?> operatorId,
      Value<String> barangNama,
      Value<String?> barangType,
      Value<String?> barangSn,
      Value<String?> kelengkapan,
      Value<String?> keluhan,
      Value<String?> teknisiId,
      Value<String?> perbaikan,
      Value<bool> garansi,
      Value<String?> claimId,
      Value<String> status,
      Value<double> biaya,
      Value<String?> caraBayar,
      Value<DateTime?> tanggalLunas,
      Value<String?> keterangan,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ServiceOrderEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceOrderEntriesTable> {
  $$ServiceOrderEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noNota => $composableBuilder(
    column: $table.noNota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalMasuk => $composableBuilder(
    column: $table.tanggalMasuk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get estimasiSelesai => $composableBuilder(
    column: $table.estimasiSelesai,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerNama => $composableBuilder(
    column: $table.customerNama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerTelp => $composableBuilder(
    column: $table.customerTelp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorId => $composableBuilder(
    column: $table.operatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barangType => $composableBuilder(
    column: $table.barangType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barangSn => $composableBuilder(
    column: $table.barangSn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teknisiId => $composableBuilder(
    column: $table.teknisiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perbaikan => $composableBuilder(
    column: $table.perbaikan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get garansi => $composableBuilder(
    column: $table.garansi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimId => $composableBuilder(
    column: $table.claimId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get biaya => $composableBuilder(
    column: $table.biaya,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caraBayar => $composableBuilder(
    column: $table.caraBayar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceOrderEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceOrderEntriesTable> {
  $$ServiceOrderEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noNota => $composableBuilder(
    column: $table.noNota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalMasuk => $composableBuilder(
    column: $table.tanggalMasuk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get estimasiSelesai => $composableBuilder(
    column: $table.estimasiSelesai,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerNama => $composableBuilder(
    column: $table.customerNama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerTelp => $composableBuilder(
    column: $table.customerTelp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorId => $composableBuilder(
    column: $table.operatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barangType => $composableBuilder(
    column: $table.barangType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barangSn => $composableBuilder(
    column: $table.barangSn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teknisiId => $composableBuilder(
    column: $table.teknisiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perbaikan => $composableBuilder(
    column: $table.perbaikan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get garansi => $composableBuilder(
    column: $table.garansi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimId => $composableBuilder(
    column: $table.claimId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get biaya => $composableBuilder(
    column: $table.biaya,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caraBayar => $composableBuilder(
    column: $table.caraBayar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceOrderEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceOrderEntriesTable> {
  $$ServiceOrderEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noNota =>
      $composableBuilder(column: $table.noNota, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalMasuk => $composableBuilder(
    column: $table.tanggalMasuk,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get estimasiSelesai => $composableBuilder(
    column: $table.estimasiSelesai,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerNama => $composableBuilder(
    column: $table.customerNama,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerTelp => $composableBuilder(
    column: $table.customerTelp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operatorId => $composableBuilder(
    column: $table.operatorId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barangType => $composableBuilder(
    column: $table.barangType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barangSn =>
      $composableBuilder(column: $table.barangSn, builder: (column) => column);

  GeneratedColumn<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keluhan =>
      $composableBuilder(column: $table.keluhan, builder: (column) => column);

  GeneratedColumn<String> get teknisiId =>
      $composableBuilder(column: $table.teknisiId, builder: (column) => column);

  GeneratedColumn<String> get perbaikan =>
      $composableBuilder(column: $table.perbaikan, builder: (column) => column);

  GeneratedColumn<bool> get garansi =>
      $composableBuilder(column: $table.garansi, builder: (column) => column);

  GeneratedColumn<String> get claimId =>
      $composableBuilder(column: $table.claimId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get biaya =>
      $composableBuilder(column: $table.biaya, builder: (column) => column);

  GeneratedColumn<String> get caraBayar =>
      $composableBuilder(column: $table.caraBayar, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ServiceOrderEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceOrderEntriesTable,
          ServiceOrderEntry,
          $$ServiceOrderEntriesTableFilterComposer,
          $$ServiceOrderEntriesTableOrderingComposer,
          $$ServiceOrderEntriesTableAnnotationComposer,
          $$ServiceOrderEntriesTableCreateCompanionBuilder,
          $$ServiceOrderEntriesTableUpdateCompanionBuilder,
          (
            ServiceOrderEntry,
            BaseReferences<
              _$AppDatabase,
              $ServiceOrderEntriesTable,
              ServiceOrderEntry
            >,
          ),
          ServiceOrderEntry,
          PrefetchHooks Function()
        > {
  $$ServiceOrderEntriesTableTableManager(
    _$AppDatabase db,
    $ServiceOrderEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceOrderEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceOrderEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ServiceOrderEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noNota = const Value.absent(),
                Value<DateTime> tanggalMasuk = const Value.absent(),
                Value<DateTime?> estimasiSelesai = const Value.absent(),
                Value<String> customerNama = const Value.absent(),
                Value<String?> customerTelp = const Value.absent(),
                Value<String?> operatorId = const Value.absent(),
                Value<String> barangNama = const Value.absent(),
                Value<String?> barangType = const Value.absent(),
                Value<String?> barangSn = const Value.absent(),
                Value<String?> kelengkapan = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> teknisiId = const Value.absent(),
                Value<String?> perbaikan = const Value.absent(),
                Value<bool> garansi = const Value.absent(),
                Value<String?> claimId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> biaya = const Value.absent(),
                Value<String?> caraBayar = const Value.absent(),
                Value<DateTime?> tanggalLunas = const Value.absent(),
                Value<String?> keterangan = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceOrderEntriesCompanion(
                id: id,
                noNota: noNota,
                tanggalMasuk: tanggalMasuk,
                estimasiSelesai: estimasiSelesai,
                customerNama: customerNama,
                customerTelp: customerTelp,
                operatorId: operatorId,
                barangNama: barangNama,
                barangType: barangType,
                barangSn: barangSn,
                kelengkapan: kelengkapan,
                keluhan: keluhan,
                teknisiId: teknisiId,
                perbaikan: perbaikan,
                garansi: garansi,
                claimId: claimId,
                status: status,
                biaya: biaya,
                caraBayar: caraBayar,
                tanggalLunas: tanggalLunas,
                keterangan: keterangan,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noNota,
                required DateTime tanggalMasuk,
                Value<DateTime?> estimasiSelesai = const Value.absent(),
                required String customerNama,
                Value<String?> customerTelp = const Value.absent(),
                Value<String?> operatorId = const Value.absent(),
                required String barangNama,
                Value<String?> barangType = const Value.absent(),
                Value<String?> barangSn = const Value.absent(),
                Value<String?> kelengkapan = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> teknisiId = const Value.absent(),
                Value<String?> perbaikan = const Value.absent(),
                Value<bool> garansi = const Value.absent(),
                Value<String?> claimId = const Value.absent(),
                required String status,
                Value<double> biaya = const Value.absent(),
                Value<String?> caraBayar = const Value.absent(),
                Value<DateTime?> tanggalLunas = const Value.absent(),
                Value<String?> keterangan = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ServiceOrderEntriesCompanion.insert(
                id: id,
                noNota: noNota,
                tanggalMasuk: tanggalMasuk,
                estimasiSelesai: estimasiSelesai,
                customerNama: customerNama,
                customerTelp: customerTelp,
                operatorId: operatorId,
                barangNama: barangNama,
                barangType: barangType,
                barangSn: barangSn,
                kelengkapan: kelengkapan,
                keluhan: keluhan,
                teknisiId: teknisiId,
                perbaikan: perbaikan,
                garansi: garansi,
                claimId: claimId,
                status: status,
                biaya: biaya,
                caraBayar: caraBayar,
                tanggalLunas: tanggalLunas,
                keterangan: keterangan,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServiceOrderEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceOrderEntriesTable,
      ServiceOrderEntry,
      $$ServiceOrderEntriesTableFilterComposer,
      $$ServiceOrderEntriesTableOrderingComposer,
      $$ServiceOrderEntriesTableAnnotationComposer,
      $$ServiceOrderEntriesTableCreateCompanionBuilder,
      $$ServiceOrderEntriesTableUpdateCompanionBuilder,
      (
        ServiceOrderEntry,
        BaseReferences<
          _$AppDatabase,
          $ServiceOrderEntriesTable,
          ServiceOrderEntry
        >,
      ),
      ServiceOrderEntry,
      PrefetchHooks Function()
    >;
typedef $$ShipmentEntriesTableCreateCompanionBuilder =
    ShipmentEntriesCompanion Function({
      required String id,
      required DateTime tanggalKirim,
      required String dariCabang,
      required String keCabang,
      Value<String?> userNama,
      required String barangNama,
      Value<String?> serialNumber,
      Value<String?> keluhan,
      Value<String?> kelengkapan,
      required String status,
      Value<DateTime?> tanggalKembali,
      Value<String?> keterangan,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ShipmentEntriesTableUpdateCompanionBuilder =
    ShipmentEntriesCompanion Function({
      Value<String> id,
      Value<DateTime> tanggalKirim,
      Value<String> dariCabang,
      Value<String> keCabang,
      Value<String?> userNama,
      Value<String> barangNama,
      Value<String?> serialNumber,
      Value<String?> keluhan,
      Value<String?> kelengkapan,
      Value<String> status,
      Value<DateTime?> tanggalKembali,
      Value<String?> keterangan,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ShipmentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ShipmentEntriesTable> {
  $$ShipmentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalKirim => $composableBuilder(
    column: $table.tanggalKirim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dariCabang => $composableBuilder(
    column: $table.dariCabang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keCabang => $composableBuilder(
    column: $table.keCabang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userNama => $composableBuilder(
    column: $table.userNama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalKembali => $composableBuilder(
    column: $table.tanggalKembali,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShipmentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShipmentEntriesTable> {
  $$ShipmentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalKirim => $composableBuilder(
    column: $table.tanggalKirim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dariCabang => $composableBuilder(
    column: $table.dariCabang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keCabang => $composableBuilder(
    column: $table.keCabang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userNama => $composableBuilder(
    column: $table.userNama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keluhan => $composableBuilder(
    column: $table.keluhan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalKembali => $composableBuilder(
    column: $table.tanggalKembali,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShipmentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShipmentEntriesTable> {
  $$ShipmentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalKirim => $composableBuilder(
    column: $table.tanggalKirim,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dariCabang => $composableBuilder(
    column: $table.dariCabang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keCabang =>
      $composableBuilder(column: $table.keCabang, builder: (column) => column);

  GeneratedColumn<String> get userNama =>
      $composableBuilder(column: $table.userNama, builder: (column) => column);

  GeneratedColumn<String> get barangNama => $composableBuilder(
    column: $table.barangNama,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keluhan =>
      $composableBuilder(column: $table.keluhan, builder: (column) => column);

  GeneratedColumn<String> get kelengkapan => $composableBuilder(
    column: $table.kelengkapan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalKembali => $composableBuilder(
    column: $table.tanggalKembali,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ShipmentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShipmentEntriesTable,
          ShipmentEntry,
          $$ShipmentEntriesTableFilterComposer,
          $$ShipmentEntriesTableOrderingComposer,
          $$ShipmentEntriesTableAnnotationComposer,
          $$ShipmentEntriesTableCreateCompanionBuilder,
          $$ShipmentEntriesTableUpdateCompanionBuilder,
          (
            ShipmentEntry,
            BaseReferences<_$AppDatabase, $ShipmentEntriesTable, ShipmentEntry>,
          ),
          ShipmentEntry,
          PrefetchHooks Function()
        > {
  $$ShipmentEntriesTableTableManager(
    _$AppDatabase db,
    $ShipmentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShipmentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShipmentEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShipmentEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> tanggalKirim = const Value.absent(),
                Value<String> dariCabang = const Value.absent(),
                Value<String> keCabang = const Value.absent(),
                Value<String?> userNama = const Value.absent(),
                Value<String> barangNama = const Value.absent(),
                Value<String?> serialNumber = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> kelengkapan = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> tanggalKembali = const Value.absent(),
                Value<String?> keterangan = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShipmentEntriesCompanion(
                id: id,
                tanggalKirim: tanggalKirim,
                dariCabang: dariCabang,
                keCabang: keCabang,
                userNama: userNama,
                barangNama: barangNama,
                serialNumber: serialNumber,
                keluhan: keluhan,
                kelengkapan: kelengkapan,
                status: status,
                tanggalKembali: tanggalKembali,
                keterangan: keterangan,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime tanggalKirim,
                required String dariCabang,
                required String keCabang,
                Value<String?> userNama = const Value.absent(),
                required String barangNama,
                Value<String?> serialNumber = const Value.absent(),
                Value<String?> keluhan = const Value.absent(),
                Value<String?> kelengkapan = const Value.absent(),
                required String status,
                Value<DateTime?> tanggalKembali = const Value.absent(),
                Value<String?> keterangan = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ShipmentEntriesCompanion.insert(
                id: id,
                tanggalKirim: tanggalKirim,
                dariCabang: dariCabang,
                keCabang: keCabang,
                userNama: userNama,
                barangNama: barangNama,
                serialNumber: serialNumber,
                keluhan: keluhan,
                kelengkapan: kelengkapan,
                status: status,
                tanggalKembali: tanggalKembali,
                keterangan: keterangan,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShipmentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShipmentEntriesTable,
      ShipmentEntry,
      $$ShipmentEntriesTableFilterComposer,
      $$ShipmentEntriesTableOrderingComposer,
      $$ShipmentEntriesTableAnnotationComposer,
      $$ShipmentEntriesTableCreateCompanionBuilder,
      $$ShipmentEntriesTableUpdateCompanionBuilder,
      (
        ShipmentEntry,
        BaseReferences<_$AppDatabase, $ShipmentEntriesTable, ShipmentEntry>,
      ),
      ShipmentEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db, _db.brands);
  $$PartTypesTableTableManager get partTypes =>
      $$PartTypesTableTableManager(_db, _db.partTypes);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ClaimsTableTableManager get claims =>
      $$ClaimsTableTableManager(_db, _db.claims);
  $$ClaimPartsTableTableManager get claimParts =>
      $$ClaimPartsTableTableManager(_db, _db.claimParts);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$BrandFeeEntriesTableTableManager get brandFeeEntries =>
      $$BrandFeeEntriesTableTableManager(_db, _db.brandFeeEntries);
  $$RevenueConfigsTableTableManager get revenueConfigs =>
      $$RevenueConfigsTableTableManager(_db, _db.revenueConfigs);
  $$BrandShareEntriesTableTableManager get brandShareEntries =>
      $$BrandShareEntriesTableTableManager(_db, _db.brandShareEntries);
  $$BrandRuleEntriesTableTableManager get brandRuleEntries =>
      $$BrandRuleEntriesTableTableManager(_db, _db.brandRuleEntries);
  $$ServiceOrderEntriesTableTableManager get serviceOrderEntries =>
      $$ServiceOrderEntriesTableTableManager(_db, _db.serviceOrderEntries);
  $$ShipmentEntriesTableTableManager get shipmentEntries =>
      $$ShipmentEntriesTableTableManager(_db, _db.shipmentEntries);
}
