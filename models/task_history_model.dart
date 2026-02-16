// lib/models/task_history_model.dart
// ============================================
// MODÈLE POUR L'HISTORIQUE DES MODIFICATIONS
// ============================================

class TaskHistoryModel {
  final int? id;
  final int? serverId;
  final String taskId;
  final String champModifie;
  final String ancienneValeur;
  final String nouvelleValeur;
  final String modifiedBy;
  final String modifiedByName;
  final DateTime modifiedAt;
  final String syncStatus;

  TaskHistoryModel({
    this.id,
    this.serverId,
    required this.taskId,
    required this.champModifie,
    this.ancienneValeur = '',
    this.nouvelleValeur = '',
    this.modifiedBy = '',
    this.modifiedByName = '',
    DateTime? modifiedAt,
    this.syncStatus = 'synced',
  }) : modifiedAt = modifiedAt ?? DateTime.now();

  factory TaskHistoryModel.fromMap(Map<String, dynamic> map) {
    return TaskHistoryModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),
      serverId: map['server_id'] is int
          ? map['server_id']
          : int.tryParse(map['server_id']?.toString() ?? ''),
      taskId: map['task_id'] ?? '',
      champModifie: map['champ_modifie'] ?? '',
      ancienneValeur: map['ancienne_valeur'] ?? '',
      nouvelleValeur: map['nouvelle_valeur'] ?? '',
      modifiedBy: map['modified_by'] ?? '',
      modifiedByName: map['modified_by_name'] ?? '',
      modifiedAt: map['modified_at'] != null
          ? DateTime.tryParse(map['modified_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      syncStatus: map['sync_status'] ?? 'synced',
    );
  }

  Map<String, dynamic> toMapSupabase() {
    return {
      'task_id': taskId,
      'champ_modifie': champModifie,
      'ancienne_valeur': ancienneValeur,
      'nouvelle_valeur': nouvelleValeur,
      'modified_by': modifiedBy,
      'modified_by_name': modifiedByName,
      'modified_at': modifiedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMapLocal() {
    return {
      'server_id': serverId,
      'task_id': taskId,
      'champ_modifie': champModifie,
      'ancienne_valeur': ancienneValeur,
      'nouvelle_valeur': nouvelleValeur,
      'modified_by': modifiedBy,
      'modified_by_name': modifiedByName,
      'modified_at': modifiedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  // Nom lisible du champ modifié
  String get champLabel {
    switch (champModifie) {
      case 'immeuble':
        return 'Immeuble';
      case 'etage':
        return 'Étage';
      case 'chambre':
        return 'Chambre';
      case 'description':
        return 'Description';
      case 'done':
        return 'Statut';
      case 'done_date':
        return 'Date d\'exécution';
      case 'done_by':
        return 'Exécutant';
      case 'execution_note':
        return 'Note d\'exécution';
      case 'photo_url':
        return 'Photo';
      case 'archived':
        return 'Archivage';
      case 'planned_date':
        return 'Date planifiée';
      default:
        return champModifie;
    }
  }
}