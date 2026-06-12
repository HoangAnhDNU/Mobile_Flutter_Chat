import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

/// Màn hình Thêm mới / Chỉnh sửa người dùng (dùng chung).
/// - Nếu [user] == null: chế độ thêm mới.
/// - Nếu [user] != null: chế độ chỉnh sửa.
class AdminUserFormScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const AdminUserFormScreen({super.key, this.user});

  bool get isEdit => user != null;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _emailC;
  final _passC = TextEditingController();
  String _role = 'user';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.user?['display_name']?.toString() ?? '');
    _emailC = TextEditingController(text: widget.user?['email']?.toString() ?? '');
    _role = widget.user?['role']?.toString() ?? 'user';
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    bool ok;
    String errorMsg = 'Thao tác thất bại';
    if (widget.isEdit) {
      ok = await ApiService.adminUpdateUser(
        widget.user!['id'].toString(),
        displayName: _nameC.text.trim(),
        email: _emailC.text.trim(),
        role: _role,
      );
    } else {
      final res = await ApiService.adminCreateUser(
        email: _emailC.text.trim(),
        password: _passC.text,
        displayName: _nameC.text.trim(),
        role: _role,
      );
      ok = res['ok'] == true;
      if (!ok) errorMsg = res['error']?.toString() ?? errorMsg;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _showSnack(widget.isEdit ? 'Đã cập nhật người dùng' : 'Đã tạo người dùng');
      Navigator.pop(context, true);
    } else {
      _showSnack(errorMsg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Chỉnh sửa người dùng' : 'Thêm người dùng mới',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameC,
              decoration: _dec('Tên hiển thị', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên hiển thị' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 14),
            if (!widget.isEdit) ...[
              TextFormField(
                controller: _passC,
                obscureText: true,
                decoration: _dec('Mật khẩu (tối thiểu 6 ký tự)', Icons.lock_outline),
                validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải từ 6 ký tự' : null,
              ),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Text('Vai trò', style: TextStyle(color: AppColors.textPrimary)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _role,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('Người dùng')),
                      DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'user'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(widget.isEdit ? Icons.save : Icons.person_add),
                label: Text(widget.isEdit ? 'Lưu thay đổi' : 'Tạo người dùng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    );
  }
}
