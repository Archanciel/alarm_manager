// lib/services/battery_optimization_service.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance = BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  final Logger _logger = Logger();
  static const MethodChannel _channel = MethodChannel('alarm_manager/battery');

  /// Check if battery optimization is disabled for the app
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      // First try using permission_handler
      final status = await Permission.ignoreBatteryOptimizations.status;
      _logger.i('🔋 Battery optimization permission status: $status');
      
      return status.isGranted;
    } catch (e) {
      _logger.e('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization
  Future<bool> requestDisableBatteryOptimization() async {
    try {
      _logger.i('🔋 Requesting battery optimization exemption...');
      
      final status = await Permission.ignoreBatteryOptimizations.request();
      _logger.i('🔋 Battery optimization request result: $status');
      
      return status.isGranted;
    } catch (e) {
      _logger.e('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Show battery optimization guidance dialog
  Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    final bool isOptimized = !(await isBatteryOptimizationDisabled());
    
    if (!isOptimized) {
      _logger.i('✅ Battery optimization already disabled');
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Optimisation de la batterie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Pour que vos alarmes fonctionnent de manière fiable, '
                        'vous devez désactiver l\'optimisation de la batterie.',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Étapes à suivre :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                _buildStep(1, 'Taper "Autoriser" ci-dessous'),
                _buildStep(2, 'Choisir "Alarm Manager" dans la liste'),
                _buildStep(3, 'Sélectionner "Non restreinte"'),
                _buildStep(4, 'Confirmer votre choix'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette autorisation est nécessaire pour que vos alarmes '
                          'se déclenchent même quand l\'écran est éteint.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logger.i('🔋 User dismissed battery optimization dialog');
              },
              child: Text('Plus tard'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openBatteryOptimizationSettings(context);
              },
              icon: Icon(Icons.battery_6_bar_rounded),
              label: Text('Autoriser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Open battery optimization settings
  Future<void> _openBatteryOptimizationSettings(BuildContext context) async {
    try {
      _logger.i('🔋 Opening battery optimization settings...');
      
      final bool granted = await requestDisableBatteryOptimization();
      
      if (granted) {
        _logger.i('✅ Battery optimization disabled successfully');
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Optimisation de la batterie désactivée ! Vos alarmes fonctionneront parfaitement.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        _logger.w('⚠️ Battery optimization not disabled');
        
        // Show guidance message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimisation non désactivée',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Paramètres → Batterie → Alarm Manager → Non restreinte'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: () => _openBatteryOptimizationSettings(context),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error opening battery settings: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture des paramètres: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check battery optimization status and show dialog if needed
  Future<void> checkAndPromptBatteryOptimization(BuildContext context, {bool force = false}) async {
    try {
      final bool isDisabled = await isBatteryOptimizationDisabled();
      
      _logger.i('🔋 Battery optimization status - Disabled: $isDisabled');
      
      if (!isDisabled || force) {
        await showBatteryOptimizationDialog(context);
      } else {
        _logger.i('✅ Battery optimization already disabled - no action needed');
      }
    } catch (e) {
      _logger.e('Error checking battery optimization: $e');
    }
  }

  /// Get battery optimization status for display
  Future<Map<String, dynamic>> getBatteryOptimizationStatus() async {
    try {
      final bool isDisabled = await isBatteryOptimizationDisabled();
      
      return {
        'isOptimized': !isDisabled,
        'isDisabled': isDisabled,
        'status': isDisabled ? 'Non restreinte' : 'Optimisée/Restreinte',
        'statusColor': isDisabled ? Colors.green : Colors.orange,
        'recommendation': isDisabled 
            ? 'Parfait ! Vos alarmes fonctionneront de manière fiable.'
            : 'Désactivez l\'optimisation pour des alarmes fiables.',
      };
    } catch (e) {
      _logger.e('Error getting battery status: $e');
      return {
        'isOptimized': true,
        'isDisabled': false,
        'status': 'Inconnu',
        'statusColor': Colors.grey,
        'recommendation': 'Impossible de vérifier le statut.',
      };
    }
  }
}