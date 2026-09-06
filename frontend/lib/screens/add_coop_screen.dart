import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/coop.dart';
import '../services/vaccination_service.dart';

/// Form thêm chuồng mới.
/// Chọn giống là bước quan trọng nhất: giống quyết định phác đồ tiêm gồm
/// những mũi nào và bao nhiêu ngày thì tới lứa xuất chuồng.
class AddCoopScreen extends StatefulWidget {
  const AddCoopScreen({super.key});

  @override
  State<AddCoopScreen> createState() => _AddCoopScreenState();
}

class _AddCoopScreenState extends State<AddCoopScreen> {
  final VaccinationService _service = VaccinationService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();

  late Future<List<Breed>> _breedsFuture;
  Breed? _selectedBreed;
  DateTime _startDate = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _breedsFuture = _service.fetchBreeds();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Ngày xuất chuồng dự kiến, hiện ngay khi chọn giống để người nuôi
  /// biết trước lứa này rơi vào lúc nào.
  DateTime? get _harvestDate => _selectedBreed == null
      ? null
      : _startDate.add(Duration(days: _selectedBreed!.harvestDays));

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Chọn ngày vào đàn',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBreed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn giống gà trước.')),
      );
      return;
    }

    // Lấy messenger TRƯỚC khi pop: sau khi pop, context của màn này đã bị huỷ,
    // gọi ScaffoldMessenger.of(context) lúc đó là tra cứu trên widget đã chết.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      final message = await _service.createCoop(
        name: _nameController.text,
        breedId: _selectedBreed!.idGiong,
        quantity: int.parse(_quantityController.text.trim()),
        flockStartDate: _startDate,
      );
      if (!mounted) return;
      // Trả true để màn danh sách biết cần tải lại.
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AgriTechColors.primary),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Thêm chuồng mới',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Breed>>(
        future: _breedsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBox(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {
                _breedsFuture = _service.fetchBreeds();
              }),
            );
          }

          final breeds = snapshot.data ?? const [];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Label('Tên chuồng'),
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
                  decoration: _inputDecoration(
                      colorScheme, 'Ví dụ: Chuồng Tam Hoàng 02'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Hãy nhập tên chuồng'
                      : null,
                ),
                const SizedBox(height: 18),

                _Label('Giống gà'),
                DropdownButtonFormField<Breed>(
                  initialValue: _selectedBreed,
                  isExpanded: true,
                  decoration: _inputDecoration(colorScheme, 'Chọn giống'),
                  items: breeds
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b.tenGiong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _selectedBreed = value),
                  validator: (value) => value == null ? 'Hãy chọn giống gà' : null,
                ),
                if (_selectedBreed != null) ...[
                  const SizedBox(height: 10),
                  _BreedSummary(breed: _selectedBreed!, harvestDate: _harvestDate!),
                ],
                const SizedBox(height: 18),

                _Label('Số lượng con giống'),
                TextFormField(
                  controller: _quantityController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(colorScheme, 'Ví dụ: 2000'),
                  validator: (value) {
                    final n = int.tryParse((value ?? '').trim());
                    if (n == null) return 'Hãy nhập số hợp lệ';
                    if (n <= 0) return 'Số lượng phải lớn hơn 0';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _Label('Ngày vào đàn'),
                InkWell(
                  onTap: _submitting ? null : _pickStartDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(_startDate),
                          style: TextStyle(
                              fontSize: 15, color: colorScheme.onSurface),
                        ),
                        const Spacer(),
                        Icon(Icons.edit,
                            size: 16, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AgriTechColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_home_work),
                  label: Text(_submitting ? 'Đang tạo...' : 'Tạo chuồng'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme colorScheme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgriTechColors.primary, width: 1.5),
      ),
    );
  }
}

/// Tóm tắt giống vừa chọn: bao nhiêu mũi tiêm, bao lâu thì xuất chuồng.
class _BreedSummary extends StatelessWidget {
  final Breed breed;
  final DateTime harvestDate;

  const _BreedSummary({required this.breed, required this.harvestDate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AgriTechColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriTechColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breed.mucDichNuoi != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                breed.mucDichNuoi!,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.vaccines,
                text: '${breed.soMuiVaccine} mũi tiêm',
              ),
              _Chip(
                icon: Icons.event_available,
                text: 'Nuôi ${breed.harvestDays} ngày',
              ),
              if (breed.trongLuongKg != null)
                _Chip(
                  icon: Icons.scale,
                  text: '~${breed.trongLuongKg}kg/con',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.flag, size: 15, color: AgriTechColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dự kiến xuất chuồng: ${_formatDate(harvestDate)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AgriTechColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AgriTechColors.primary),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Không tải được danh mục giống.\n$message',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AgriTechColors.primary),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
