// lib/screens/immeuble_management_screen.dart
// ============================================
// ÉCRAN GESTION DES IMMEUBLES (ADMIN UNIQUEMENT)
// ============================================
import 'package:flutter/material.dart';
import '../models/immeuble_model.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_text_field.dart';

class ImmeubleManagementScreen extends StatefulWidget {
  const ImmeubleManagementScreen({super.key});

  @override
  State<ImmeubleManagementScreen> createState() =>
      _ImmeubleManagementScreenState();
}

class _ImmeubleManagementScreenState extends State<ImmeubleManagementScreen> {
  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  List<ImmeubleModel> _immeubles = [];
  bool _isLoading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadImmeubles();
  }

  Future<void> _loadImmeubles() async {
    setState(() => _isLoading = true);

    List<ImmeubleModel> immeubles;
    if (_showArchived) {
      immeubles = await _localDb.getAllImmeubles();
    } else {
      immeubles = await _localDb.getActiveImmeubles();
    }

    if (mounted) {
      setState(() {
        _immeubles = immeubles;
        _isLoading = false;
      });
    }
  }

  // ============================================
  // AJOUTER UN IMMEUBLE
  // ============================================
  void _showAddDialog() {
    final nomController = TextEditingController();
    final adresseController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_business, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Ajouter un immeuble'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nomController,
                labelText: 'Nom de l\'immeuble *',
                prefixIcon: const Icon(Icons.apartment),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  // Vérifier si le nom existe déjà
                  if (_immeubles.any((i) =>
                      i.nom.toLowerCase() == value.trim().toLowerCase())) {
                    return 'Ce nom existe déjà';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: adresseController,
                labelText: 'Adresse',
                prefixIcon: const Icon(Icons.location_on),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _addImmeuble(
                  nomController.text.trim(),
                  adresseController.text.trim(),
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addImmeuble(String nom, String adresse) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final immeuble = ImmeubleModel(
        id: id,
        nom: nom,
        adresse: adresse,
      );

      // Sauvegarder en local
      await _localDb.insertImmeuble(immeuble);

      // Synchroniser si connecté
      if (await SyncService().hasConnection()) {
        try {
          await _supabase.upsertImmeuble(immeuble);
        } catch (e) {
          // Sera synchronisé plus tard
        }
      }

      await _loadImmeubles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Immeuble "$nom" ajouté'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ============================================
  // MODIFIER UN IMMEUBLE
  // ============================================
  void _showEditDialog(ImmeubleModel immeuble) {
    final nomController = TextEditingController(text: immeuble.nom);
    final adresseController = TextEditingController(text: immeuble.adresse);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Modifier l\'immeuble'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nomController,
                labelText: 'Nom de l\'immeuble *',
                prefixIcon: const Icon(Icons.apartment),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  // Vérifier si le nom existe déjà (sauf pour l'immeuble en cours)
                  if (_immeubles.any((i) =>
                      i.id != immeuble.id &&
                      i.nom.toLowerCase() == value.trim().toLowerCase())) {
                    return 'Ce nom existe déjà';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: adresseController,
                labelText: 'Adresse',
                prefixIcon: const Icon(Icons.location_on),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _updateImmeuble(
                  immeuble,
                  nomController.text.trim(),
                  adresseController.text.trim(),
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateImmeuble(
      ImmeubleModel immeuble, String newNom, String newAdresse) async {
    try {
      final oldNom = immeuble.nom;
      final updatedImmeuble = ImmeubleModel(
        id: immeuble.id,
        nom: newNom,
        adresse: newAdresse,
        archived: immeuble.archived,
        createdAt: immeuble.createdAt,
      );

      // Mettre à jour en local
      await _localDb.updateImmeuble(updatedImmeuble);

      // Si le nom a changé, mettre à jour toutes les tâches associées
      if (oldNom != newNom) {
        await _localDb.updateTasksImmeubleName(oldNom, newNom);
      }

      // Synchroniser si connecté
      if (await SyncService().hasConnection()) {
        try {
          await _supabase.upsertImmeuble(updatedImmeuble);
          // Mettre à jour le nom dans les tâches sur le serveur
          if (oldNom != newNom) {
            await _supabase.updateTasksImmeubleName(oldNom, newNom);
          }
        } catch (e) {
          // Sera synchronisé plus tard
        }
      }

      await _loadImmeubles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Immeuble "$newNom" modifié'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ============================================
  // ARCHIVER / DÉSARCHIVER UN IMMEUBLE
  // ============================================
  Future<void> _toggleArchive(ImmeubleModel immeuble) async {
    final newArchived = !immeuble.archived;
    final action = newArchived ? 'Archiver' : 'Désarchiver';

    // Vérifier s'il y a des tâches actives liées à cet immeuble
    if (newArchived) {
      final activeTasks =
          await _localDb.getActiveTasksForImmeuble(immeuble.nom);
      if (activeTasks.isNotEmpty) {
        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Attention'),
              content: Text(
                'Cet immeuble a ${activeTasks.length} tâche(s) active(s).\n\n'
                'L\'archivage empêchera la création de nouvelles tâches pour cet immeuble.\n\n'
                'Les tâches existantes ne seront pas affectées.\n\n'
                'Voulez-vous continuer ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
      } else {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$action l\'immeuble ?'),
            content: Text('Voulez-vous $action "${immeuble.nom}" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$action l\'immeuble ?'),
          content: Text('Voulez-vous $action "${immeuble.nom}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final updatedImmeuble = ImmeubleModel(
        id: immeuble.id,
        nom: immeuble.nom,
        adresse: immeuble.adresse,
        archived: newArchived,
        createdAt: immeuble.createdAt,
      );

      await _localDb.updateImmeuble(updatedImmeuble);

      // Synchroniser si connecté
      if (await SyncService().hasConnection()) {
        try {
          await _supabase.upsertImmeuble(updatedImmeuble);
        } catch (e) {
          // Sera synchronisé plus tard
        }
      }

      await _loadImmeubles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newArchived
                ? '✅ Immeuble archivé'
                : '✅ Immeuble désarchivé'),
            backgroundColor:
                newArchived ? AppTheme.archiveColor : AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ============================================
  // SUPPRIMER UN IMMEUBLE
  // ============================================
  Future<void> _deleteImmeuble(ImmeubleModel immeuble) async {
    // Vérifier s'il y a des tâches liées
    final allTasks = await _localDb.getAllTasksForImmeuble(immeuble.nom);

    if (allTasks.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Impossible de supprimer : ${allTasks.length} tâche(s) liée(s) à cet immeuble.\n'
              'Archivez-le plutôt.',
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'immeuble ?'),
        content: Text(
          'Voulez-vous vraiment supprimer "${immeuble.nom}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _localDb.deleteImmeuble(immeuble.id);

      // Supprimer sur le serveur si connecté
      if (await SyncService().hasConnection()) {
        try {
          await _supabase.deleteImmeuble(immeuble.id);
        } catch (e) {
          // Ignorer
        }
      }

      await _loadImmeubles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Immeuble "${immeuble.nom}" supprimé'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ============================================
  // CONSTRUCTION DE L'INTERFACE
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des immeubles'),
        actions: [
          FilterChip(
            label: Text(
              _showArchived ? 'Tous' : 'Actifs',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: _showArchived,
            onSelected: (value) {
              setState(() => _showArchived = value);
              _loadImmeubles();
            },
            backgroundColor: Colors.white70,
            selectedColor: Colors.white,
            checkmarkColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Ajouter un immeuble',
        child: const Icon(Icons.add_business),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _immeubles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apartment,
                          size: 80,
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun immeuble',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un immeuble'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadImmeubles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _immeubles.length,
                    itemBuilder: (context, index) {
                      final immeuble = _immeubles[index];
                      return _buildImmeubleCard(immeuble);
                    },
                  ),
                ),
    );
  }

  Widget _buildImmeubleCard(ImmeubleModel immeuble) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: immeuble.archived
              ? AppTheme.archiveColor
              : AppTheme.primaryColor,
          child: const Icon(Icons.apartment, color: Colors.white),
        ),
        title: Text(
          immeuble.nom,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: immeuble.archived
                ? AppTheme.archiveColor
                : AppTheme.textPrimary,
            decoration:
                immeuble.archived ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (immeuble.adresse.isNotEmpty)
              Text(
                immeuble.adresse,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            if (immeuble.archived)
              const Text(
                'Archivé',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.archiveColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditDialog(immeuble);
                break;
              case 'archive':
                _toggleArchive(immeuble);
                break;
              case 'delete':
                _deleteImmeuble(immeuble);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Modifier',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(
                    immeuble.archived ? Icons.unarchive : Icons.archive,
                    color: immeuble.archived
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    immeuble.archived ? 'Désarchiver' : 'Archiver',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Text(
                    'Supprimer',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}