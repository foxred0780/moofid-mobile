import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('moofid.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    final path = join(docsDirectory.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // Ensure SyncMetadata table exists (for databases created before sync feature)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS SyncMetadata (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        ServerId TEXT NOT NULL,
        SyncSecretKey TEXT NOT NULL,
        ServerIp TEXT NOT NULL,
        LastSyncTime TEXT NULL
      )
    ''');

    // Ensure new sync tables exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS SyncOperations (
        Id TEXT PRIMARY KEY,
        Timestamp TEXT NOT NULL,
        DeviceId TEXT NOT NULL DEFAULT 'android',
        EntityType TEXT NOT NULL,
        EntityId TEXT NOT NULL,
        OperationType TEXT NOT NULL DEFAULT 'Update',
        Data TEXT NOT NULL DEFAULT '{}',
        ChangedFields TEXT DEFAULT '',
        Status TEXT NOT NULL DEFAULT 'Pending',
        VectorClock TEXT DEFAULT '{}',
        BatchId TEXT,
        AcknowledgedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS RevisionLogs (
        Id TEXT PRIMARY KEY,
        EntityId TEXT NOT NULL,
        EntityType TEXT NOT NULL,
        OldData TEXT NOT NULL DEFAULT '{}',
        NewData TEXT NOT NULL DEFAULT '{}',
        ResolutionType TEXT DEFAULT 'LWW',
        WinnerDevice TEXT DEFAULT '',
        LoserDevice TEXT DEFAULT '',
        ConflictedFields TEXT DEFAULT '',
        ResolvedAt TEXT NOT NULL
      )
    ''');
    
    // Add missing columns to existing tables (safe migration)
    final migrations = [
      'ALTER TABLE Customers ADD COLUMN IsDeleted INTEGER DEFAULT 0',
      'ALTER TABLE Customers ADD COLUMN SyncStatus INTEGER DEFAULT 0',
      'ALTER TABLE Customers ADD COLUMN VectorClock TEXT DEFAULT "{}"',
      'ALTER TABLE Invoices ADD COLUMN IsDeleted INTEGER DEFAULT 0',
      'ALTER TABLE Invoices ADD COLUMN SyncStatus INTEGER DEFAULT 0',
      'ALTER TABLE Invoices ADD COLUMN VectorClock TEXT DEFAULT "{}"',
      'ALTER TABLE Installments ADD COLUMN IsDeleted INTEGER DEFAULT 0',
      'ALTER TABLE Installments ADD COLUMN SyncStatus INTEGER DEFAULT 0',
      'ALTER TABLE Installments ADD COLUMN VectorClock TEXT DEFAULT "{}"',
      'ALTER TABLE PaymentTransactions ADD COLUMN IsDeleted INTEGER DEFAULT 0',
      'ALTER TABLE PaymentTransactions ADD COLUMN SyncStatus INTEGER DEFAULT 0',
      'ALTER TABLE PaymentTransactions ADD COLUMN VectorClock TEXT DEFAULT "{}"',
    ];
    for (final sql in migrations) {
      try { await db.execute(sql); } catch (_) {} // Ignore if column already exists
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Users (
        Id TEXT PRIMARY KEY,
        Username TEXT NOT NULL UNIQUE,
        Password TEXT NOT NULL,
        StoreName TEXT DEFAULT '',
        CreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Customers (
        Id TEXT PRIMARY KEY,
        CreatedAt TEXT NOT NULL,
        LastModified TEXT NOT NULL,
        UserId TEXT NOT NULL,
        Name TEXT NOT NULL,
        Phone TEXT DEFAULT '',
        Address TEXT DEFAULT '',
        Notes TEXT DEFAULT '',
        IsDeleted INTEGER DEFAULT 0,
        SyncStatus INTEGER DEFAULT 0,
        VectorClock TEXT DEFAULT '{}',
        FOREIGN KEY (UserId) REFERENCES Users (Id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Invoices (
        Id TEXT PRIMARY KEY,
        CreatedAt TEXT NOT NULL,
        LastModified TEXT NOT NULL,
        CustomerId TEXT NOT NULL,
        ItemName TEXT NOT NULL,
        TotalAmount REAL NOT NULL,
        DownPayment REAL DEFAULT 0,
        Currency TEXT DEFAULT 'IQD',
        NumberOfMonths INTEGER DEFAULT 0,
        IsFullyPaid INTEGER DEFAULT 0,
        IsDeleted INTEGER DEFAULT 0,
        SyncStatus INTEGER DEFAULT 0,
        VectorClock TEXT DEFAULT '{}',
        FOREIGN KEY (CustomerId) REFERENCES Customers (Id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Installments (
        Id TEXT PRIMARY KEY,
        CreatedAt TEXT NOT NULL,
        LastModified TEXT NOT NULL,
        InvoiceId TEXT NOT NULL,
        InstallmentNumber INTEGER NOT NULL,
        Amount REAL NOT NULL,
        PaidAmount REAL DEFAULT 0,
        DueDate TEXT NOT NULL,
        IsPaid INTEGER DEFAULT 0,
        PaidDate TEXT NULL,
        IsDeleted INTEGER DEFAULT 0,
        SyncStatus INTEGER DEFAULT 0,
        VectorClock TEXT DEFAULT '{}',
        FOREIGN KEY (InvoiceId) REFERENCES Invoices (Id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS PaymentTransactions (
        Id TEXT PRIMARY KEY,
        CreatedAt TEXT NOT NULL,
        LastModified TEXT NOT NULL,
        UserId TEXT NOT NULL,
        InvoiceId TEXT NOT NULL,
        InstallmentId TEXT NULL,
        AmountPaid REAL NOT NULL,
        PaymentDate TEXT NOT NULL,
        Notes TEXT DEFAULT '',
        IsDeleted INTEGER DEFAULT 0,
        SyncStatus INTEGER DEFAULT 0,
        VectorClock TEXT DEFAULT '{}',
        FOREIGN KEY (InvoiceId) REFERENCES Invoices (Id) ON DELETE CASCADE,
        FOREIGN KEY (InstallmentId) REFERENCES Installments (Id) ON DELETE SET NULL,
        FOREIGN KEY (UserId) REFERENCES Users (Id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS SystemSettings (
        Id TEXT PRIMARY KEY,
        CreatedAt TEXT NOT NULL,
        LastModified TEXT NOT NULL,
        UserId TEXT NOT NULL,
        StoreName TEXT DEFAULT '',
        StorePhone TEXT DEFAULT '',
        StoreAddress TEXT DEFAULT '',
        DefaultCurrency TEXT DEFAULT 'IQD',
        ExchangeRate REAL DEFAULT 0,
        EnableOverdueAlerts INTEGER DEFAULT 1,
        IsDeleted INTEGER DEFAULT 0,
        SyncStatus INTEGER DEFAULT 0,
        FOREIGN KEY (UserId) REFERENCES Users (Id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS SyncMetadata (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        ServerId TEXT NOT NULL,
        SyncSecretKey TEXT NOT NULL,
        ServerIp TEXT NOT NULL,
        LastSyncTime TEXT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS SyncOperations (
        Id TEXT PRIMARY KEY,
        Timestamp TEXT NOT NULL,
        DeviceId TEXT NOT NULL DEFAULT 'android',
        EntityType TEXT NOT NULL,
        EntityId TEXT NOT NULL,
        OperationType TEXT NOT NULL DEFAULT 'Update',
        Data TEXT NOT NULL DEFAULT '{}',
        ChangedFields TEXT DEFAULT '',
        Status TEXT NOT NULL DEFAULT 'Pending',
        VectorClock TEXT DEFAULT '{}',
        BatchId TEXT,
        AcknowledgedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS RevisionLogs (
        Id TEXT PRIMARY KEY,
        EntityId TEXT NOT NULL,
        EntityType TEXT NOT NULL,
        OldData TEXT NOT NULL DEFAULT '{}',
        NewData TEXT NOT NULL DEFAULT '{}',
        ResolutionType TEXT DEFAULT 'LWW',
        WinnerDevice TEXT DEFAULT '',
        LoserDevice TEXT DEFAULT '',
        ConflictedFields TEXT DEFAULT '',
        ResolvedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('Users');
      await txn.delete('Customers');
      await txn.delete('Invoices');
      await txn.delete('Installments');
      await txn.delete('PaymentTransactions');
      await txn.delete('SystemSettings');
      await txn.delete('SyncMetadata');
      await txn.delete('SyncOperations');
      await txn.delete('RevisionLogs');
    });
  }

  /// Migration from v1 to v2: add VectorClock columns and new sync tables
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // VectorClock columns added via _onConfigure migrations (safe ALTER)
      // New tables added via _onConfigure CREATE IF NOT EXISTS
      // Nothing extra needed here — _onConfigure handles it all
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<String> getDbPath() async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    return join(docsDirectory.path, 'moofid.db');
  }

  // Backup: Uses share_plus to export the database file
  Future<void> createBackup() async {
    final dbPath = await getDbPath();
    final file = File(dbPath);
    
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(dbPath)],
        subject: 'نسخة احتياطية لقاعدة بيانات مفيد',
        text: 'ملف قاعدة بيانات SQLite لتطبيق مفيد للأقساط.',
      );
    } else {
      throw Exception('ملف قاعدة البيانات غير موجود');
    }
  }

  // Restore: Uses file_picker to pick a .db file and overwrite current one
  Future<void> restoreBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any, // .db files sometimes don't have a MIME type on Android
    );

    if (result != null && result.files.single.path != null) {
      final pickedPath = result.files.single.path!;
      
      // Safety check: ensure it's likely a DB file
      if (!pickedPath.endsWith('.db')) {
        throw Exception('يرجى اختيار ملف قاعدة بيانات صحيح ينتهي بـ .db');
      }

      // 1. Close current database
      await close();

      // 2. Delete existing WAL/SHM files to prevent corruption
      final dbPath = await getDbPath();
      final walFile = File("$dbPath-wal");
      final shmFile = File("$dbPath-shm");
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 3. Overwrite the file
      await File(pickedPath).copy(dbPath);
      
      // Note: The UI should trigger an app restart or navigation to splash
    } else {
      // User cancelled
    }
  }
}
