import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/threshold_config.dart';

class SettingsPage extends StatefulWidget {
  final ThresholdConfig currentConfig;
  final Function(ThresholdConfig) onConfigSaved;

  const SettingsPage({
    super.key,
    required this.currentConfig,
    required this.onConfigSaved,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _tempMinController;
  late TextEditingController _tempMaxController;
  late TextEditingController _humMinController;
  late TextEditingController _humMaxController;
  late TextEditingController _soilMinController;
  late TextEditingController _soilMaxController;

  @override
  void initState() {
    super.initState();
    _tempMinController = TextEditingController(
      text: widget.currentConfig.tempMin.toStringAsFixed(1),
    );
    _tempMaxController = TextEditingController(
      text: widget.currentConfig.tempMax.toStringAsFixed(1),
    );
    _humMinController = TextEditingController(
      text: widget.currentConfig.humMin.toStringAsFixed(1),
    );
    _humMaxController = TextEditingController(
      text: widget.currentConfig.humMax.toStringAsFixed(1),
    );
    _soilMinController = TextEditingController(text: '30.0');
    _soilMaxController = TextEditingController(text: '70.0');

    // ✅ Charger les valeurs depuis Firebase au démarrage
    _loadFromFirebase();
  }

  // ✅ NOUVEAU : Charger les seuils depuis Firebase /config
  Future<void> _loadFromFirebase() async {
    try {
      final ref = FirebaseDatabase.instance.ref("config");
      final snapshot = await ref.get();
      if (snapshot.exists && mounted) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        setState(() {
          if (data['temp_min'] != null)
            _tempMinController.text =
                (data['temp_min'] as num).toDouble().toStringAsFixed(1);
          if (data['temp_max'] != null)
            _tempMaxController.text =
                (data['temp_max'] as num).toDouble().toStringAsFixed(1);
          if (data['hum_min'] != null)
            _humMinController.text =
                (data['hum_min'] as num).toDouble().toStringAsFixed(1);
          if (data['hum_max'] != null)
            _humMaxController.text =
                (data['hum_max'] as num).toDouble().toStringAsFixed(1);
          if (data['soil_min'] != null)
            _soilMinController.text =
                (data['soil_min'] as num).toDouble().toStringAsFixed(1);
          if (data['soil_max'] != null)
            _soilMaxController.text =
                (data['soil_max'] as num).toDouble().toStringAsFixed(1);
        });
        debugPrint('✅ Config chargée depuis Firebase');
      }
    } catch (e) {
      debugPrint('⚠️ Impossible de charger config Firebase: $e');
    }
  }

  @override
  void dispose() {
    _tempMinController.dispose();
    _tempMaxController.dispose();
    _humMinController.dispose();
    _humMaxController.dispose();
    _soilMinController.dispose();
    _soilMaxController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeInput({
    required String label,
    required TextEditingController minController,
    required TextEditingController maxController,
    required String unit,
    required Color color,
    required double minLimit,
    required double maxLimit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: minController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Minimum',
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final num = double.tryParse(value);
                    if (num == null) return 'Nombre invalide';
                    if (num < minLimit || num > maxLimit)
                      return 'Entre $minLimit et $maxLimit';
                    final max = double.tryParse(maxController.text);
                    if (max != null && num >= max) return 'Min < Max';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: maxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Maximum',
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final num = double.tryParse(value);
                    if (num == null) return 'Nombre invalide';
                    if (num < minLimit || num > maxLimit)
                      return 'Entre $minLimit et $maxLimit';
                    final min = double.tryParse(minController.text);
                    if (min != null && num <= min) return 'Max > Min';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ CORRECTION PRINCIPALE : sauvegarde dans Firebase /config ET localement
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final tempMin = double.parse(_tempMinController.text);
    final tempMax = double.parse(_tempMaxController.text);
    final humMin = double.parse(_humMinController.text);
    final humMax = double.parse(_humMaxController.text);
    final soilMin = double.parse(_soilMinController.text);
    final soilMax = double.parse(_soilMaxController.text);

    // ✅ Sauvegarder dans Firebase /config (pour le backend Python)
    try {
      await FirebaseDatabase.instance.ref("config").set({
        'temp_min': tempMin,
        'temp_max': tempMax,
        'hum_min': humMin,
        'hum_max': humMax,
        'soil_min': soilMin,
        'soil_max': soilMax,
      });
      debugPrint('✅ Config sauvegardée dans Firebase /config');
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde Firebase config: $e');
    }

    // Mettre à jour localement dans l'appli
    final newConfig = ThresholdConfig(
      tempMin: tempMin,
      tempMax: tempMax,
      humMin: humMin,
      humMax: humMax,
    );
    widget.onConfigSaved(newConfig);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Paramètres sauvegardés (Firebase + local)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _tempMinController.text = '15.0';
      _tempMaxController.text = '25.0';
      _humMinController.text = '35.0';
      _humMaxController.text = '60.0';
      _soilMinController.text = '40.0';
      _soilMaxController.text = '80.0';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Valeurs par défaut restaurées'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration des Seuils'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Réinitialiser',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // En-tête info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Les seuils sont synchronisés avec Firebase et utilisés par le backend Python pour les alertes push.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section Température
            _buildSectionTitle(
                'Température', Icons.thermostat, Colors.orange.shade700),
            _buildRangeInput(
              label: 'Plage de température',
              minController: _tempMinController,
              maxController: _tempMaxController,
              unit: '°C',
              color: Colors.orange,
              minLimit: 0.0,
              maxLimit: 50.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Text(
                'Plage capteur DHT11: 0°C - 50°C',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ),

            // Section Humidité air
            _buildSectionTitle(
                'Humidité de l\'air', Icons.water_drop, Colors.blue.shade700),
            _buildRangeInput(
              label: 'Plage d\'humidité',
              minController: _humMinController,
              maxController: _humMaxController,
              unit: '%',
              color: Colors.blue,
              minLimit: 20.0,
              maxLimit: 80.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Text(
                'Plage capteur DHT11: 20% - 80%',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ),

            // Section Sol
            _buildSectionTitle(
                'Humidité du sol', Icons.grass, Colors.brown.shade700),
            _buildRangeInput(
              label: 'Plage d\'humidité du sol',
              minController: _soilMinController,
              maxController: _soilMaxController,
              unit: '%',
              color: Colors.brown,
              minLimit: 0.0,
              maxLimit: 100.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Text(
                'Plage recommandée: 40% - 80%',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ),

            const SizedBox(height: 32),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Sauvegarde...' : 'Sauvegarder'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text('Conseils',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Les seuils sont sauvegardés dans Firebase\n'
                      '• Le backend Python les lit pour envoyer des alertes push\n'
                      '• Appuyez sur 🔄 pour restaurer les valeurs par défaut',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}