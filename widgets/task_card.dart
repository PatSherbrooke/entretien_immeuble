// lib/widgets/task_card.dart
// ============================================
// WIDGET CARTE DE TÂCHE
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../utils/theme.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : numéro + statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Numéro de tâche + indicateur de synchronisation
                  Row(
                    children: [
                      Text(
                        task.displayNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (task.syncStatus != 'synced') ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: AppTheme.warningColor.withValues(alpha: 178),
                        ),
                      ],
                    ],
                  ),
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: 8),

              // Immeuble
              Row(
                children: [
                  const Icon(Icons.apartment,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.immeuble,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Étage et chambre
              if (task.etage.isNotEmpty || task.chambre.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.layers,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    if (task.etage.isNotEmpty) Text('Étage ${task.etage}'),
                    if (task.etage.isNotEmpty && task.chambre.isNotEmpty)
                      const Text(' — '),
                    if (task.chambre.isNotEmpty) Text('Ch. ${task.chambre}'),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              // A faire: description (une ligne, "..." si débordement)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 18,
                    color: AppTheme.primaryColor.withValues(alpha: 178),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A faire: ${task.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Créée le: date à gauche, créateur justifié à droite
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Créée le: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(task.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (task.createdBy.isNotEmpty)
                    Expanded(
                      child: Text(
                        task.createdBy,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),

              // Planifiée le: date (si existe)
              if (task.plannedDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Planifiée le: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(task.plannedDate!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],

              // Terminée le: date + exécutant (si existe)
              if (task.done && task.doneDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Terminée le: ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(task.doneDate!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Exécutant aligné à droite, même couleur
                    if (task.doneBy.isNotEmpty)
                      Flexible(
                        child: Text(
                          task.doneBy,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (task.archived) {
      bgColor = AppTheme.archiveColor.withValues(alpha: 51);
      textColor = AppTheme.archiveColor;
      label = 'Archivée';
      icon = Icons.archive;
    } else if (task.done) {
      bgColor = AppTheme.successColor.withValues(alpha: 51);
      textColor = AppTheme.successColor;
      label = 'Terminée';
      icon = Icons.check_circle;
    } else {
      bgColor = AppTheme.warningColor.withValues(alpha: 51);
      textColor = AppTheme.warningColor;
      label = 'En cours';
      icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}