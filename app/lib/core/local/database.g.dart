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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    claimId,
    partTypeId,
    snBadPart,
    syncPending,
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
  const ClaimPart({
    required this.id,
    required this.claimId,
    required this.partTypeId,
    this.snBadPart,
    required this.syncPending,
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
    };
  }

  ClaimPart copyWith({
    String? id,
    String? claimId,
    int? partTypeId,
    Value<String?> snBadPart = const Value.absent(),
    bool? syncPending,
  }) => ClaimPart(
    id: id ?? this.id,
    claimId: claimId ?? this.claimId,
    partTypeId: partTypeId ?? this.partTypeId,
    snBadPart: snBadPart.present ? snBadPart.value : this.snBadPart,
    syncPending: syncPending ?? this.syncPending,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaimPart(')
          ..write('id: $id, ')
          ..write('claimId: $claimId, ')
          ..write('partTypeId: $partTypeId, ')
          ..write('snBadPart: $snBadPart, ')
          ..write('syncPending: $syncPending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, claimId, partTypeId, snBadPart, syncPending);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaimPart &&
          other.id == this.id &&
          other.claimId == this.claimId &&
          other.partTypeId == this.partTypeId &&
          other.snBadPart == this.snBadPart &&
          other.syncPending == this.syncPending);
}

class ClaimPartsCompanion extends UpdateCompanion<ClaimPart> {
  final Value<String> id;
  final Value<String> claimId;
  final Value<int> partTypeId;
  final Value<String?> snBadPart;
  final Value<bool> syncPending;
  final Value<int> rowid;
  const ClaimPartsCompanion({
    this.id = const Value.absent(),
    this.claimId = const Value.absent(),
    this.partTypeId = const Value.absent(),
    this.snBadPart = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimPartsCompanion.insert({
    required String id,
    required String claimId,
    required int partTypeId,
    this.snBadPart = const Value.absent(),
    this.syncPending = const Value.absent(),
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (claimId != null) 'claim_id': claimId,
      if (partTypeId != null) 'part_type_id': partTypeId,
      if (snBadPart != null) 'sn_bad_part': snBadPart,
      if (syncPending != null) 'sync_pending': syncPending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? claimId,
    Value<int>? partTypeId,
    Value<String?>? snBadPart,
    Value<bool>? syncPending,
    Value<int>? rowid,
  }) {
    return ClaimPartsCompanion(
      id: id ?? this.id,
      claimId: claimId ?? this.claimId,
      partTypeId: partTypeId ?? this.partTypeId,
      snBadPart: snBadPart ?? this.snBadPart,
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BrandsTable brands = $BrandsTable(this);
  late final $PartTypesTable partTypes = $PartTypesTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ClaimsTable claims = $ClaimsTable(this);
  late final $ClaimPartsTable claimParts = $ClaimPartsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
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
  Value<int> rowid,
});
typedef $$ClaimPartsTableUpdateCompanionBuilder = ClaimPartsCompanion Function({
  Value<String> id,
  Value<String> claimId,
  Value<int> partTypeId,
  Value<String?> snBadPart,
  Value<bool> syncPending,
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
                Value<int> rowid = const Value.absent(),
              }) => ClaimPartsCompanion(
                id: id,
                claimId: claimId,
                partTypeId: partTypeId,
                snBadPart: snBadPart,
                syncPending: syncPending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String claimId,
                required int partTypeId,
                Value<String?> snBadPart = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimPartsCompanion.insert(
                id: id,
                claimId: claimId,
                partTypeId: partTypeId,
                snBadPart: snBadPart,
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
}
