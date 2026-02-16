// lib/screens/task_form_screen.dart
// ============================================
// ÉCRAN FORMULAIRE DE CRÉATION/MODIFICATION DE TÂCHE
// ============================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/task_history_model.dart';
import '../models/immeuble_model.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/app_text_field.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskModel? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  late TextEditingController _etageController;
  late TextEditingController _chambreController;
  late TextEditingController _descriptionController;
  late TextEditingController _doneByController;
  late TextEditingController _executionNoteController;

  // Liste des immeubles
  List<ImmeubleModel> _immeubles = [];
  String? _selectedImmeuble;

  bool _done = false;
  DateTime? _doneDate;
  DateTime? _plannedDate;
  String? _photoLocalPath;
  String? _photoUrl;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  bool get _hasPhoto {
    return (_photoLocalPath != null && _photoLocalPath!.isNotEmpty) ||
        (_photoUrl != null && _photoUrl!.isNotEmpty);
  }

  // ============================================
  // CYCLE DE VIE
  // ============================================

  @override
  void initState() {
    super.initState();
    _etageController =
        TextEditingController(text: widget.task?.etage ?? '');
    _chambreController =
        TextEditingController(text: widget.task?.chambre ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _doneByController =
        TextEditingController(text: widget.task?.doneBy ?? '');
    _executionNoteController =
        TextEditingController(text: widget.task?.executionNote ?? '');

    _selectedImmeuble =
        widget.task?.immeuble.isNotEmpty == true
            ? widget.task!.immeuble
            : null;
    _done = widget.task?.done ?? false;
    _doneDate = widget.task?.doneDate;
    _plannedDate = widget.task?.plannedDate;
    _photoUrl = widget.task?.photoUrl;
    _photoLocalPath = widget.task?.photoLocalPath;

    _loadImmeubles();
  }

  @override
  void dispose() {
    _etageController.dispose();
    _chambreController.dispose();
    _descriptionController.dispose();
    _doneByController.dispose();
    _executionNoteController.dispose();
    super.dispose();
  }

  // ============================================
  // CHARGEMENT DES IMMEUBLES
  // ============================================

  Future<void> _loadImmeubles() async {
    final immeubles = await _localDb.getActiveImmeubles();
    if (mounted) {
      setState(() {
        _immeubles = immeubles;
        // Si l'immeuble de la tâche n'est pas dans la liste, l'ajouter
        if (_selectedImmeuble != null &&
            !_immeubles.any((i) => i.nom == _selectedImmeuble)) {
          _immeubles.add(ImmeubleModel(
            id: 'temp',
            nom: _selectedImmeuble!,
          ));
        }
      });
    }
  }

  // ============================================
  // AJOUTER UN IMMEUBLE (ADMIN UNIQUEMENT)
  // ============================================

  void _showAddImmeubleDialog() {
    if (!_auth.isAdmin) {
      _showSnackBar(
        '❌ Seul un administrateur peut ajouter un immeuble',
        isError: true,
      );
      return;
    }

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un immeuble'),
        content: AppTextField(
          controller: controller,
          labelText: 'Nom de l\'immeuble',
          prefixIcon: const Icon(Icons.apartment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nom = controller.text.trim();
              if (nom.isNotEmpty) {
                await _localDb.insertImmeubleIfNotExists(nom);

                if (await SyncService().hasConnection()) {
                  try {
                    await _supabase.insertImmeubleIfNotExists(nom);
                  } catch (_) {
                    // Sera synchronisé plus tard
                  }
                }

                await _loadImmeubles();

                if (mounted) {
                  setState(() {
                    _selectedImmeuble = nom;
                  });
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // GESTION DES PHOTOS
  // ============================================

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choisir une source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: AppTheme.primaryColor),
                title: const Text('Prendre une photo'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: AppTheme.secondaryColor),
                title: const Text('Galerie photos'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );

    if (source == null || !mounted) return;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _photoLocalPath = pickedFile.path;
        });
        _showSnackBar('✅ Photo ajoutée avec succès');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Erreur: $e', isError: true);
      }
    }
  }

  void _removePhoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content:
            const Text('Voulez-vous vraiment supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () {
              setState(() {
                _photoLocalPath = null;
                _photoUrl = null;
              });
              Navigator.pop(context);
              _showSnackBar('🗑️ Photo supprimée', isError: true);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SÉLECTION DE DATE
  // ============================================

  Future<void> _selectDate(bool isPlannedDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPlannedDate
          ? (_plannedDate ?? DateTime.now())
          : (_doneDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isPlannedDate) {
          _plannedDate = picked;
        } else {
          _doneDate = picked;
        }
      });
    }
  }

  // ============================================
  // SAUVEGARDE — Validation
  // ============================================

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;
    if (_selectedImmeuble == null || _selectedImmeuble!.isEmpty) {
      _showSnackBar('❌ Veuillez sélectionner un immeuble', isError: true);
      return false;
    }
    return true;
  }

  // ============================================
  // SAUVEGARDE — Upload photo
  // ============================================

  Future<String> _uploadPhotoIfNeeded(String taskId) async {
    // Si photo supprimée
    if (_photoLocalPath == null && _photoUrl == null) return '';

    // Si nouvelle photo locale
    if (_photoLocalPath != null &&
        _photoLocalPath!.isNotEmpty &&
        _photoLocalPath != widget.task?.photoLocalPath) {
      try {
        if (await SyncService().hasConnection()) {
          return await _supabase.uploadPhoto(_photoLocalPath!, taskId);
        }
      } catch (_) {
        // On garde le chemin local, sera synchronisé plus tard
      }
    }

    return _photoUrl ?? '';
  }

  // ============================================
  // SAUVEGARDE — Construction du modèle
  // ============================================

  Future<TaskModel> _buildTaskModel(String photoUrl) async {
    final currentUser = _auth.currentUser;
    final taskId = widget.task?.id ?? const Uuid().v4();
    int? taskNumber = widget.task?.taskNumber;

    if (!_isEditing) {
      taskNumber = await _localDb.getNextTaskNumber();
    }

    return TaskModel(
      id: taskId,
      taskNumber: taskNumber,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      immeuble: _selectedImmeuble!,
      etage: _etageController.text.trim(),
      chambre: _chambreController.text.trim(),
      description: _descriptionController.text.trim(),
      done: _done,
      doneDate: _done ? (_doneDate ?? DateTime.now()) : null,
      doneBy: _doneByController.text.trim(),
      executionNote: _executionNoteController.text.trim(),
      lastModifiedBy: currentUser?.id ?? '',
      createdBy: _isEditing
          ? (widget.task?.createdBy ?? '')
          : (currentUser?.nomComplet ?? ''),
      photoUrl: photoUrl,
      photoLocalPath: _photoLocalPath ?? '',
      plannedDate: _plannedDate,
      syncStatus: _isEditing ? 'pending_update' : 'pending_create',
    );
  }

  // ============================================
  // SAUVEGARDE — Créer une nouvelle tâche
  // ============================================

  Future<void> _createNewTask(TaskModel task) async {
    final currentUser = _auth.currentUser;
    await _localDb.insertTask(task);
    await _localDb.insertHistory(TaskHistoryModel(
      taskId: task.id,
      champModifie: 'creation',
      ancienneValeur: '',
      nouvelleValeur: 'Tâche créée',
      modifiedBy: currentUser?.id ?? '',
      modifiedByName: currentUser?.nomComplet ?? '',
      syncStatus: 'pending_create',
    ));
  }

  // ============================================
  // SAUVEGARDE — Mettre à jour une tâche existante
  // ============================================

  Future<void> _updateExistingTask(TaskModel task) async {
    final currentUser = _auth.currentUser;
    await _recordChanges(
      widget.task!,
      task,
      currentUser?.id ?? '',
      currentUser?.nomComplet ?? '',
    );
    await _localDb.updateTask(task);
  }

  // ============================================
  // SAUVEGARDE — Notifications
  // ============================================

  Future<void> _sendNotificationsIfNeeded(TaskModel task) async {
    if (_done && !(widget.task?.done ?? false)) {
      final users = await _localDb.getAllUsers();
      for (var user in users) {
        if (user.isAdmin && !user.archived) {
          await NotificationService().notifyTaskDone(
            user.id,
            task.description,
            _doneByController.text.trim(),
          );
        }
      }
    }
  }

  // ============================================
  // SAUVEGARDE — Méthode principale
  // ============================================

  Future<void> _saveTask() async {
    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    try {
      final taskId = widget.task?.id ?? const Uuid().v4();
      final photoUrl = await _uploadPhotoIfNeeded(taskId);
      final task = await _buildTaskModel(photoUrl);

      if (_isEditing) {
        await _updateExistingTask(task);
      } else {
        await _createNewTask(task);
      }

      await _sendNotificationsIfNeeded(task);

      if (mounted) {
        _showSnackBar(
          _isEditing
              ? '✅ Tâche modifiée'
              : '✅ Tâche #${task.taskNumber} créée',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================
  // HISTORIQUE DES MODIFICATIONS
  // ============================================

  Future<void> _recordChanges(
    TaskModel oldTask,
    TaskModel newTask,
    String modifiedBy,
    String modifiedByName,
  ) async {
    final changes = <MapEntry<String, List<String>>>[];

    if (oldTask.immeuble != newTask.immeuble) {
      changes.add(MapEntry(
          'immeuble', [oldTask.immeuble, newTask.immeuble]));
    }
    if (oldTask.etage != newTask.etage) {
      changes
          .add(MapEntry('etage', [oldTask.etage, newTask.etage]));
    }
    if (oldTask.chambre != newTask.chambre) {
      changes.add(
          MapEntry('chambre', [oldTask.chambre, newTask.chambre]));
    }
    if (oldTask.description != newTask.description) {
      changes.add(MapEntry(
          'description', [oldTask.description, newTask.description]));
    }
    if (oldTask.done != newTask.done) {
      changes.add(MapEntry(
          'done', [oldTask.done.toString(), newTask.done.toString()]));
    }
    if (oldTask.doneBy != newTask.doneBy) {
      changes.add(
          MapEntry('done_by', [oldTask.doneBy, newTask.doneBy]));
    }
    if (oldTask.executionNote != newTask.executionNote) {
      changes.add(MapEntry(
          'execution_note', [oldTask.executionNote, newTask.executionNote]));
    }
    if (oldTask.photoUrl != newTask.photoUrl) {
      changes.add(MapEntry('photo_url', [
        oldTask.photoUrl.isNotEmpty ? 'Photo existante' : '',
        newTask.photoUrl.isNotEmpty
            ? 'Nouvelle photo'
            : 'Photo supprimée',
      ]));
    }
    if (oldTask.plannedDate != newTask.plannedDate) {
      changes.add(MapEntry('planned_date', [
        oldTask.plannedDate != null
            ? DateFormat('dd/MM/yyyy').format(oldTask.plannedDate!)
            : 'Non définie',
        newTask.plannedDate != null
            ? DateFormat('dd/MM/yyyy').format(newTask.plannedDate!)
            : 'Non définie',
      ]));
    }

    for (var change in changes) {
      await _localDb.insertHistory(TaskHistoryModel(
        taskId: oldTask.id,
        champModifie: change.key,
        ancienneValeur: change.value[0],
        nouvelleValeur: change.value[1],
        modifiedBy: modifiedBy,
        modifiedByName: modifiedByName,
        syncStatus: 'pending_create',
      ));
    }
  }

  // ============================================
  // UTILITAIRES UI
  // ============================================

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // WIDGET — Aperçu photo (factorisé)
  // ============================================

  Widget _buildPhotoPreview() {
    final Widget imageWidget;

    if (_photoLocalPath != null && _photoLocalPath!.isNotEmpty) {
      imageWidget = Image.file(
        File(_photoLocalPath!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageWidget = Image.network(
        _photoUrl!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 200,
          child: Center(
            child: Icon(Icons.broken_image,
                size: 60, color: AppTheme.textSecondary),
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageWidget,
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _buildDeletePhotoButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletePhotoButton() {
    return GestureDetector(
      onTap: _removePhoto,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // ============================================
  // BUILD PRINCIPAL
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing && widget.task!.taskNumber != null
              ? 'Modifier la tâche #${widget.task!.taskNumber}'
              : _isEditing
                  ? 'Modifier la tâche'
                  : 'Ajouter une tâche',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================
              // IMMEUBLE — Liste déroulante
              // ============================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedImmeuble,
                      decoration: const InputDecoration(
                        labelText: 'Immeuble *',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      isExpanded: true,
                      hint: const Text('Sélectionner un immeuble'),
                      items: _immeubles.map((immeuble) {
                        return DropdownMenuItem<String>(
                          value: immeuble.nom,
                          child: Text(immeuble.nom),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedImmeuble = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner un immeuble';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_auth.isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        onPressed: _showAddImmeubleDialog,
                        icon: const Icon(Icons.add_circle,
                            color: AppTheme.secondaryColor, size: 32),
                        tooltip: 'Ajouter un immeuble',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ============================================
              // ÉTAGE ET CHAMBRE
              // ============================================
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _etageController,
                      labelText: 'Étage',
                      prefixIcon: const Icon(Icons.layers),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _chambreController,
                      labelText: 'Chambre',
                      prefixIcon: const Icon(Icons.door_front_door),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ============================================
              // DESCRIPTION
              // ============================================
              AppTextField(
                controller: _descriptionController,
                maxLines: 4,
                labelText: 'Description de la tâche *',
                prefixIcon: const Icon(Icons.description),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer une description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ============================================
              // DATE PLANIFIÉE
              // ============================================
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today,
                      color: AppTheme.warningColor),
                  title: const Text('Date planifiée'),
                  subtitle: Text(
                    _plannedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_plannedDate!)
                        : 'Non définie',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        onPressed: () => _selectDate(true),
                      ),
                      if (_plannedDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppTheme.errorColor),
                          onPressed: () {
                            setState(() => _plannedDate = null);
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ============================================
              // STATUT FAIT / PAS FAIT
              // ============================================
              Card(
                child: SwitchListTile(
                  secondary: Icon(
                    _done ? Icons.check_circle : Icons.pending,
                    color: _done
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    size: 32,
                  ),
                  title: Text(
                    _done ? 'Tâche terminée' : 'Tâche en cours',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _done,
                  onChanged: (value) {
                    setState(() {
                      _done = value;
                      if (value) {
                        _doneDate = DateTime.now();
                        _doneByController.text =
                            _auth.currentUser?.nomComplet ?? '';
                      } else {
                        _doneDate = null;
                      }
                    });
                  },
                ),
              ),

              // ============================================
              // SI FAIT : DATE, EXÉCUTANT, PHOTO
              // ============================================
              if (_done) ...[
                const SizedBox(height: 12),

                // Date d'exécution
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available,
                        color: AppTheme.successColor),
                    title: const Text('Date d\'exécution'),
                    subtitle: Text(
                      _doneDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(_doneDate!)
                          : 'Aujourd\'hui',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => _selectDate(false),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Exécutant
                AppTextField(
                  controller: _doneByController,
                  labelText: 'Exécutant',
                  prefixIcon: const Icon(Icons.person),
                ),

                const SizedBox(height: 12),

                // Note d'exécution
                AppTextField(
                  controller: _executionNoteController,
                  labelText: 'Note d\'exécution',
                  prefixIcon: const Icon(Icons.note),
                  maxLines: 3,
                ),

                const SizedBox(height: 12),

                // Photo
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt,
                            color: AppTheme.primaryColor),
                        title: const Text('Photo du travail'),
                        subtitle: Text(
                            _hasPhoto ? 'Photo ajoutée' : 'Optionnel'),
                        trailing: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(
                            _hasPhoto
                                ? Icons.change_circle
                                : Icons.add_a_photo,
                            size: 18,
                          ),
                          label: Text(
                              _hasPhoto ? 'Changer' : 'Ajouter'),
                        ),
                      ),
                      _buildPhotoPreview(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ============================================
              // BOUTON SAUVEGARDER
              // ============================================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTask,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'Enregistrement...'
                        : _isEditing
                            ? 'Modifier la tâche'
                            : 'Créer la tâche',
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}