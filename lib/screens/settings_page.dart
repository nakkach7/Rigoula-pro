import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/threshold_config.dart';

class SettingsPage extends StatefulWidget {
  /// The Firebase key for this greenhouse (e.g. "tomate", "tomate_cerise")
  final String serreId;
  final ThresholdConfig currentConfig;
  final Function(ThresholdConfig) onConfigSaved;

  const SettingsPage({
    super.key,
    required this.serreId,
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

  String get _serreLabel =>
      widget.serreId == SerreId.tomate ? 'Tomate 🍅' : 'Tomate Cerise 🍒';

  @override
  void initState() {
    super.initState();
    _tempMinController =
        TextEditingController(text: widget.currentConfig.tempMin.toStringAsFixed(1));
    _tempMaxController =
        TextEditingController(text: widget.currentConfig.tempMax.toStringAsFixed(1));
    _humMinController =
        TextEditingController(text: widget.currentConfig.humMin.toStringAsFixed(1));
    _humMaxController =
        TextEditingController(text: widget.currentConfig.humMax.toStringAsFixed(1));
    _soilMinController = TextEditingController(text: '30.0');
    _soilMaxController = TextEditingController(text: '70.0');

    _loadFromFirebase();
  }

  Future<void> _loadFromFirebase() async {
    final config = await FirebaseService.loadConfig(widget.serreId);
    if (config != null && mounted) {
      setState(() {
        _tempMinController.text = config['temp_min']!.toStringAsFixed(1);
        _tempMaxController.text = config['temp_max']!.toStringAsFixed(1);
        _humMinController.text = config['hum_min']!.toStringAsFixed(1);
        _humMaxController.text = config['hum_max']!.toStringAsFixed(1);
        if (config['soil_min'] != null)
          _soilMinController.text = config['soil_min']!.toStringAsFixed(1);
        if (config['soil_max'] != null)
          _soilMaxController.text = config['soil_max']!.toStringAsFixed(1);
      });
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
          Text(title,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
          Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: minController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
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
                      decimal: true, signed: true),
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

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final tempMin = double.parse(_tempMinController.text);
    final tempMax = double.parse(_tempMaxController.text);
    final humMin = double.parse(_humMinController.text);
    final humMax = double.parse(_humMaxController.text);
    final soilMin = double.parse(_soilMinController.text);
    final soilMax = double.parse(_soilMaxController.text);

    // Save to /serres/<serreId>/config — isolated per serre
    await FirebaseService.saveConfig(widget.serreId, {
      'temp_min': tempMin,
      'temp_max': tempMax,
      'hum_min': humMin,
      'hum_max': humMax,
      'soil_min': soilMin,
      'soil_max': soilMax,
    });

    widget.onConfigSaved(ThresholdConfig(
      tempMin: tempMin,
      tempMax: tempMax,
      humMin: humMin,
      humMax: humMax,
    ));

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Paramètres $_serreLabel sauvegardés'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _tempMinController.text = '15.0';
      _tempMaxController.text = '35.0';
      _humMinController.text = '30.0';
      _humMaxController.text = '80.0';
      _soilMinController.text = '30.0';
      _soilMaxController.text = '70.0';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('🔄 Valeurs par défaut restaurées'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres — $_serreLabel'),
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
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ces seuils s\'appliquent UNIQUEMENT à la serre $_serreLabel. '
                        'Ils sont sauvegardés dans Firebase sous /serres/${widget.serreId}/config.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Température', Icons.thermostat, Colors.orange.shade700),
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
              child: Text('Plage capteur DHT11: 0°C - 50°C',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ),

            _buildSectionTitle('Humidité de l\'air', Icons.water_drop, Colors.blue.shade700),
            _buildRangeInput(
              label: 'Plage d\'humidité',
              minController: _humMinController,
              maxController: _humMaxController,
              unit: '%',
              color: Colors.blue,
              minLimit: 20.0,
              maxLimit: 80.0,
            ),

            _buildSectionTitle('Humidité du sol', Icons.grass, Colors.brown.shade700),
            _buildRangeInput(
              label: 'Plage d\'humidité du sol',
              minController: _soilMinController,
              maxController: _soilMaxController,
              unit: '%',
              color: Colors.brown,
              minLimit: 0.0,
              maxLimit: 100.0,
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey.shade700),
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
          ],
        ),
      ),
    );
  }
}