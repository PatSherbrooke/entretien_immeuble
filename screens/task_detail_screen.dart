// lib/screens/task_detail_screen.dart
// ============================================
// ÉCRAN DÉTAIL D'UNE TÂCHE
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/local_db_service.dart';
import '../utils/theme.dart';
import 'task_form_screen.dart';
import 'task_history_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final bool showHistory;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.showHistory = false,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TaskModel _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _refreshTask();
    if (widget.showHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskHistoryScreen(taskId: _task.id),
          ),
        );
      });
    }
  }

  Future<void> _refreshTask() async {
    final localTask = await LocalDbService().getTaskById(_task.id);
    if (localTask != null && mounted) {
      setState(() => _task = localTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tâche ${_task.displayNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(task: _task),
                ),
              ).then((_) => _refreshTask());
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskHistoryScreen(taskId: _task.id),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _task.done
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _task.done
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
                child: Text(
                  _task.statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _task.done
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Informations principales
            _buildInfoCard('Immeuble', _task.immeuble, Icons.apartment),
            if (_task.etage.isNotEmpty)
              _buildInfoCard('Étage', _task.etage, Icons.layers),
            if (_task.chambre.isNotEmpty)
              _buildInfoCard('Chambre', _task.chambre, Icons.door_front_door),
            _buildInfoCard('Description', _task.description, Icons.description),
            _buildInfoCard(
              'Date de création',
              DateFormat('dd/MM/yyyy à HH:mm').format(_task.createdAt),
              Icons.date_range,
            ),
            if (_task.createdBy.isNotEmpty)
              _buildInfoCard(
                'Créée par',
                _task.createdBy,
                Icons.person_add,
              ),

            if (_task.plannedDate != null)
              _buildInfoCard(
                'Date planifiée',
                DateFormat('dd/MM/yyyy').format(_task.plannedDate!),
                Icons.calendar_today,
              ),

            if (_task.done) ...[
              const Divider(height: 32),
              const Text(
                'Exécution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_task.doneDate != null)
                _buildInfoCard(
                  'Date de terminaison',
                  DateFormat('dd/MM/yyyy').format(_task.doneDate!),
                  Icons.event_available,
                ),
              if (_task.doneBy.isNotEmpty)
                _buildInfoCard('Exécutant', _task.doneBy, Icons.person),
              if (_task.executionNote.isNotEmpty)
                _buildInfoCard(
                  'Note d\'exécution',
                  _task.executionNote,
                  Icons.note,
                ),
            ],

            // Photo
            if (_task.photoUrl.isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _task.photoUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 60, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}