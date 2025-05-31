// lib/widgets/battery_status_widget.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/battery_optimization_service.dart';

class BatteryStatusWidget extends StatefulWidget {
  final bool showInCard;
  final bool autoCheck;

  const BatteryStatusWidget({
    super.key,
    this.showInCard = true,
    this.autoCheck = true,
  });

  @override
  State<BatteryStatusWidget> createState() => _BatteryStatusWidgetState();
}

class _BatteryStatusWidgetState extends State<BatteryStatusWidget> {
  final Logger _logger = Logger();
  final BatteryOptimizationService _batteryService =
      BatteryOptimizationService();

  Map<String, dynamic> _batteryStatus = {};
  bool _isLoading = true;
  bool _hasCheckedOnStartup = false;

  @override
  void initState() {
    super.initState();
    _loadBatteryStatus();

    // Auto-check and prompt on startup if enabled
    if (widget.autoCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoCheckBatteryOptimization();
      });
    }
  }

  Future<void> _loadBatteryStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _batteryService.getBatteryOptimizationStatus();
      setState(() {
        _batteryStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading battery status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoCheckBatteryOptimization() async {
    if (_hasCheckedOnStartup) return;
    _hasCheckedOnStartup = true;

    try {
      // Wait a bit for the UI to settle
      await Future.delayed(Duration(seconds: 2));

      final bool isOptimized = _batteryStatus['isOptimized'] ?? true;

      if (isOptimized && mounted) {
        _logger.i('🔋 Auto-prompting battery optimization dialog');
        await _batteryService.checkAndPromptBatteryOptimization(context);

        // Refresh status after dialog
        await _loadBatteryStatus();
      }
    } catch (e) {
      _logger.e('Error in auto battery check: $e');
    }
  }

  Future<void> _manualBatteryCheck() async {
    await _batteryService.checkAndPromptBatteryOptimization(
      context,
      force: true,
    );
    await _loadBatteryStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.showInCard
          ? Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child:
                (_batteryStatus.isEmpty)
                    ? SizedBox.shrink()
                    : Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 16),
                          Text('Vérification de l\'optimisation batterie...'),
                        ],
                      ),
                    ),
          )
          : SizedBox.shrink();
    }

    if (_batteryStatus.isEmpty) {
      return SizedBox.shrink();
    }

    final bool isOptimized = _batteryStatus['isOptimized'] ?? true;
    final String status = _batteryStatus['status'] ?? 'Inconnu';
    final Color statusColor = _batteryStatus['statusColor'] ?? Colors.grey;
    final String recommendation = _batteryStatus['recommendation'] ?? '';

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isOptimized ? Icons.battery_alert : Icons.battery_full,
              color: statusColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimisation Batterie',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Statut: $status',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadBatteryStatus,
              icon: Icon(Icons.refresh, color: Colors.blue),
              tooltip: 'Actualiser',
            ),
          ],
        ),
        SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOptimized ? Colors.orange.shade50 : Colors.green.shade50,
            border: Border.all(
              color:
                  isOptimized ? Colors.orange.shade200 : Colors.green.shade200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isOptimized ? Icons.warning : Icons.check_circle,
                    color: statusColor,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            statusColor == Colors.green
                                ? Colors.green[800]
                                : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),

              if (isOptimized) ...[
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _manualBatteryCheck,
                    icon: Icon(Icons.battery_0_bar, size: 18),
                    label: Text('Configurer maintenant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (!isOptimized) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vos alarmes fonctionneront de manière fiable, même avec l\'écran éteint.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return widget.showInCard
        ? Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: isOptimized ? 4 : 2,
          color: isOptimized ? Colors.orange.shade50 : null,
          child: Padding(padding: EdgeInsets.all(16), child: content),
        )
        : Padding(padding: EdgeInsets.all(16), child: content);
  }
}
