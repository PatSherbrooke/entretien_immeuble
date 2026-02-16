// lib/services/local_db_service.dart
// ============================================
// SERVICE DE BASE DE DONNÉES LOCALE (SQLite)
// ============================================
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/task_history_model.dart';
import '../models/immeuble_model.dart';

class LocalDbService {
  static Database? _database;
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path =
        join(await getDatabasesPath(), 'entretien_immeuble.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table des utilisateurs
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        identifiant TEXT UNIQUE NOT NULL,
        mot_de_passe_hash TEXT NOT NULL,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        telephone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        role TEXT NOT NULL DEFAULT 'executant',
        archived INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Table des tâches
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        task_number INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        immeuble TEXT NOT NULL,
        etage TEXT DEFAULT '',
        chambre TEXT DEFAULT '',
        description TEXT NOT NULL,
        done INTEGER DEFAULT 0,
        done_date TEXT,
        done_by TEXT DEFAULT '',
        execution_note TEXT DEFAULT '',
        last_modified_by TEXT DEFAULT '',
        created_by TEXT DEFAULT '',
        photo_url TEXT DEFAULT '',
        photo_local_path TEXT DEFAULT '',
        archived INTEGER DEFAULT 0,
        planned_date TEXT,
        deleted INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Table historique des modifications
    await db.execute('''
      CREATE TABLE task_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        task_id TEXT NOT NULL,
        champ_modifie TEXT NOT NULL,
        ancienne_valeur TEXT DEFAULT '',
        nouvelle_valeur TEXT DEFAULT '',
        modified_by TEXT DEFAULT '',
        modified_by_name TEXT DEFAULT '',
        modified_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Table des immeubles
    await db.execute('''
      CREATE TABLE immeubles (
        id TEXT PRIMARY KEY,
        nom TEXT UNIQUE NOT NULL,
        adresse TEXT DEFAULT '',
        archived INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // ============================================
    // CRÉER L'ADMINISTRATEUR PAR DÉFAUT
    // Identifiant : admin
    // Mot de passe : admin123
    // ============================================
    await db.insert('profiles', {
      'id': 'admin-default-001',
      'identifiant': 'admin',
      'mot_de_passe_hash':
          '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
      'nom': 'Administrateur',
      'prenom': 'Principal',
      'telephone': '',
      'email': '',
      'role': 'administrateur',
      'archived': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Migration de la base de données
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN created_by TEXT DEFAULT ""');
      } catch (e) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN execution_note TEXT DEFAULT ""');
      } catch (e) {}
    }
  }

  // ============================================
  // OPÉRATIONS SUR LES UTILISATEURS
  // ============================================

  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(
      'profiles',
      user.toMapLocal(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update(
      'profiles',
      user.toMapLocal(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<UserModel?> getUserByIdentifiant(String identifiant) async {
    final db = await database;
    final results = await db.query(
      'profiles',
      where: 'identifiant = ?',
      whereArgs: [identifiant],
    );
    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final results = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final results =
        await db.query('profiles', orderBy: 'nom ASC');
    return results.map((map) => UserModel.fromMap(map)).toList();
  }

  Future<List<UserModel>> getActiveUsers() async {
    final db = await database;
    final results = await db.query(
      'profiles',
      where: 'archived = 0',
      orderBy: 'nom ASC',
    );
    return results.map((map) => UserModel.fromMap(map)).toList();
  }

  // ============================================
  // OPÉRATIONS SUR LES TÂCHES
  // ============================================

  Future<void> insertTask(TaskModel task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMapLocal(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(TaskModel task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMapLocal(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String taskId) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<TaskModel?> getTaskById(String id) async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return TaskModel.fromMap(results.first);
  }

  // Tâches actives (non archivées, non supprimées)
  Future<List<TaskModel>> getActiveTasks() async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'archived = 0 AND deleted = 0',
      orderBy: 'created_at DESC',
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Tâches en cours uniquement (non faites, non archivées, non supprimées)
  Future<List<TaskModel>> getPendingTasks() async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'archived = 0 AND deleted = 0 AND done = 0',
      orderBy: 'created_at DESC',
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Tâches terminées (faites mais non archivées, non supprimées)
  Future<List<TaskModel>> getDoneTasks() async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'archived = 0 AND deleted = 0 AND done = 1',
      orderBy: 'done_date DESC',
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Tâches en attente de synchronisation
  Future<List<TaskModel>> getPendingSyncTasks() async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Supprimer les tâches archivées du stockage local
  Future<void> removeArchivedTasksLocally() async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'archived = 1 AND sync_status = ?',
      whereArgs: ['synced'],
    );
  }

  // Tâches planifiées pour une date
  Future<List<TaskModel>> getTasksForDate(DateTime date) async {
    final db = await database;
    String dateStr = date.toIso8601String().split('T')[0];
    final results = await db.query(
      'tasks',
      where: 'planned_date = ? AND deleted = 0',
      whereArgs: [dateStr],
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Toutes les tâches avec date planifiée
  Future<List<TaskModel>> getAllPlannedTasks() async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where:
          'planned_date IS NOT NULL AND planned_date != "" AND deleted = 0',
      orderBy: 'planned_date ASC',
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Obtenir le prochain numéro de tâche local
  Future<int> getNextTaskNumber() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(task_number) as max_num FROM tasks',
    );
    int maxNum = 0;
    if (result.isNotEmpty && result.first['max_num'] != null) {
      maxNum = result.first['max_num'] as int;
    }
    return maxNum + 1;
  }

  // ============================================
  // OPÉRATIONS SUR L'HISTORIQUE
  // ============================================

  Future<void> insertHistory(TaskHistoryModel history) async {
    final db = await database;
    await db.insert('task_history', history.toMapLocal());
  }

  Future<List<TaskHistoryModel>> getHistoryForTask(
      String taskId) async {
    final db = await database;
    final results = await db.query(
      'task_history',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'modified_at DESC',
    );
    return results
        .map((map) => TaskHistoryModel.fromMap(map))
        .toList();
  }

  Future<List<TaskHistoryModel>> getPendingSyncHistory() async {
    final db = await database;
    final results = await db.query(
      'task_history',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return results
        .map((map) => TaskHistoryModel.fromMap(map))
        .toList();
  }

  Future<void> updateHistorySyncStatus(int id, String status,
      {int? serverId}) async {
    final db = await database;
    Map<String, dynamic> values = {'sync_status': status};
    if (serverId != null) values['server_id'] = serverId;
    await db.update(
      'task_history',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // OPÉRATIONS SUR LES IMMEUBLES
  // ============================================

  Future<void> insertImmeuble(ImmeubleModel immeuble) async {
    final db = await database;
    await db.insert(
      'immeubles',
      immeuble.toMapLocal(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateImmeuble(ImmeubleModel immeuble) async {
    final db = await database;
    await db.update(
      'immeubles',
      immeuble.toMapLocal(),
      where: 'id = ?',
      whereArgs: [immeuble.id],
    );
  }

  Future<void> deleteImmeuble(String immeubleId) async {
    final db = await database;
    await db.delete(
      'immeubles',
      where: 'id = ?',
      whereArgs: [immeubleId],
    );
  }

  Future<List<ImmeubleModel>> getActiveImmeubles() async {
    final db = await database;
    final results = await db.query(
      'immeubles',
      where: 'archived = 0',
      orderBy: 'nom ASC',
    );
    return results
        .map((map) => ImmeubleModel.fromMap(map))
        .toList();
  }

  Future<List<ImmeubleModel>> getAllImmeubles() async {
    final db = await database;
    final results =
        await db.query('immeubles', orderBy: 'nom ASC');
    return results
        .map((map) => ImmeubleModel.fromMap(map))
        .toList();
  }

  Future<void> replaceAllImmeubles(
      List<ImmeubleModel> immeubles) async {
    final db = await database;
    await db.delete('immeubles');
    for (var immeuble in immeubles) {
      await db.insert('immeubles', immeuble.toMapLocal(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Ajouter un immeuble s'il n'existe pas encore (par nom, insensible à la casse)
  Future<void> insertImmeubleIfNotExists(String nom) async {
    final db = await database;
    final existing = await db.query(
      'immeubles',
      where: 'LOWER(nom) = LOWER(?)',
      whereArgs: [nom],
    );

    if (existing.isEmpty) {
      await db.insert('immeubles', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'nom': nom,
        'adresse': '',
        'archived': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // Mettre à jour le nom de l'immeuble dans toutes les tâches
  Future<void> updateTasksImmeubleName(
      String oldName, String newName) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE tasks SET immeuble = ?, sync_status = CASE WHEN sync_status = ? THEN ? ELSE ? END WHERE immeuble = ?',
      [
        newName,
        'synced',
        'pending_update',
        'pending_update',
        oldName
      ],
    );
  }

  // Tâches actives pour un immeuble donné
  Future<List<TaskModel>> getActiveTasksForImmeuble(
      String immeubleName) async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'immeuble = ? AND archived = 0 AND deleted = 0',
      whereArgs: [immeubleName],
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // Toutes les tâches pour un immeuble donné (y compris archivées)
  Future<List<TaskModel>> getAllTasksForImmeuble(
      String immeubleName) async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'immeuble = ? AND deleted = 0',
      whereArgs: [immeubleName],
    );
    return results.map((map) => TaskModel.fromMap(map)).toList();
  }

  // ============================================
  // UTILITAIRES
  // ============================================

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('task_history');
    await db.delete('immeubles');
  }

  Future<void> replaceAllUsers(List<UserModel> users) async {
    final db = await database;
    await db.delete('profiles');
    for (var user in users) {
      await db.insert('profiles', user.toMapLocal(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}