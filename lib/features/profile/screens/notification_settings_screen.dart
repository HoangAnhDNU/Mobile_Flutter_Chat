import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  
  // Settings
  String _messageSound = 'default';
  String _callSound = 'default';
  bool _isMessageVibration = true;
  bool _isCallVibration = true;
  bool _isMessagePreview = true;
  
  // Available sounds
  List<Map<String, dynamic>> _messageSounds = [];
  List<Map<String, dynamic>> _callSounds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getNotificationSettings();
    if (mounted) {
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        setState(() {
          _messageSound = settings['message_sound'] ?? 'default';
          _callSound = settings['call_sound'] ?? 'default';
          _isMessageVibration = settings['is_message_vibration'] ?? true;
          _isCallVibration = settings['is_call_vibration'] ?? true;
          _isMessagePreview = settings['is_message_preview'] ?? true;
        });
      }
      
      // Load available sounds
      final msgSounds = data['available_message_sounds'] as List?;
      final callSoundList = data['available_call_sounds'] as List?;
      if (msgSounds != null) {
        _messageSounds = msgSounds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (callSoundList != null) {
        _callSounds = callSoundList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      
      setState(() => _loading = false);
    }
  }

  Future<void> _saveMessageSound(String sound) async {
    setState(() => _messageSound = sound);
    await ApiService.updateNotificationSettings(messageSound: sound);
  }

  Future<void> _saveCallSound(String sound) async {
    setState(() => _callSound = sound);
    await ApiService.updateNotificationSettings(callSound: sound);
  }

  Future<void> _toggleMessageVibration(bool value) async {
    setState(() => _isMessageVibration = value);
    await ApiService.updateNotificationSettings(isMessageVibration: value);
  }

  Future<void> _toggleCallVibration(bool value) async {
    setState(() => _isCallVibration = value);
    await ApiService.updateNotificationSettings(isCallVibration: value);
  }

  Future<void> _toggleMessagePreview(bool value) async {
    setState(() => _isMessagePreview = value);
    await ApiService.updateNotificationSettings(isMessagePreview: value);
  }

  String _getSoundName(String soundId, List<Map<String, dynamic>> sounds) {
    for (final sound in sounds) {
      if (sound['id'] == soundId) {
        return sound['name'] ?? soundId;
      }
    }
    return soundId;
  }

  void _showSoundPicker(String type, String currentSound, List<Map<String, dynamic>> sounds, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    type == 'message' ? Icons.chat_bubble_outline : Icons.phone_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    type == 'message' ? 'Âm thanh tin nhắn' : 'Âm thanh cuộc gọi',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sounds.length,
                itemBuilder: (context, index) {
                  final sound = sounds[index];
                  final id = sound['id'] as String;
                  final name = sound['name'] as String;
                  final isSelected = id == currentSound;
                  
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt thông báo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('Âm thanh thông báo'),
                
                // Message Sound
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Âm thanh tin nhắn'),
                  subtitle: Text(
                    _getSoundName(_messageSound, _messageSounds),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSoundPicker(
                    'message',
                    _messageSound,
                    _messageSounds,
                    _saveMessageSound,
                  ),
                ),
                
                // Call Sound
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                  title: const Text('Âm thanh cuộc gọi'),
                  subtitle: Text(
                    _getSoundName(_callSound, _callSounds),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSoundPicker(
                    'call',
                    _callSound,
                    _callSounds,
                    _saveCallSound,
                  ),
                ),
                
                const Divider(),
                _sectionTitle('Rung'),
                
                // Message Vibration
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: AppColors.primary),
                  title: const Text('Rung khi có tin nhắn'),
                  value: _isMessageVibration,
                  onChanged: _toggleMessageVibration,
                  activeTrackColor: AppColors.primary,
                ),
                
                // Call Vibration
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: AppColors.primary),
                  title: const Text('Rung khi có cuộc gọi'),
                  value: _isCallVibration,
                  onChanged: _toggleCallVibration,
                  activeTrackColor: AppColors.primary,
                ),
                
                const Divider(),
                _sectionTitle('Nội dung thông báo'),
                
                // Message Preview
                SwitchListTile(
                  secondary: const Icon(Icons.text_fields, color: AppColors.primary),
                  title: const Text('Xem trước tin nhắn'),
                  subtitle: const Text('Hiển thị nội dung tin nhắn trong thông báo'),
                  value: _isMessagePreview,
                  onChanged: _toggleMessagePreview,
                  activeTrackColor: AppColors.primary,
                ),
                
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Một số âm thanh có thể yêu cầu tải thêm từ máy chủ.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
