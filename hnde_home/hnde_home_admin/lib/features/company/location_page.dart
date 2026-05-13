import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/company_provider.dart';
import '../../models/location_info.dart';

class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _mapAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _busInfoController = TextEditingController();
  final _subwayInfoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    _mapAddressController.dispose();
    _phoneController.dispose();
    _busInfoController.dispose();
    _subwayInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final asyncValue = ref.read(locationProvider);
    asyncValue.whenData((location) {
      if (location != null) {
        _addressController.text = location.address;
        _mapAddressController.text = location.mapAddress;
        _phoneController.text = location.phone;
        _busInfoController.text = location.busInfo;
        _subwayInfoController.text = location.subwayInfo;
        setState(() {});
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final location = LocationInfo(
        id: 'main',
        address: _addressController.text.trim(),
        mapAddress: _mapAddressController.text.trim(),
        phone: _phoneController.text.trim(),
        busInfo: _busInfoController.text.trim(),
        subwayInfo: _subwayInfoController.text.trim(),
      );
      await ref.read(locationControllerProvider).save(location);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncLocation = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('찾아오시는 길 관리')),
      body: asyncLocation.when(
        data: (location) {
          if (location != null && _addressController.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '주소 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '주소를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mapAddressController,
                    decoration: const InputDecoration(
                      labelText: '지도 주소 *',
                      border: OutlineInputBorder(),
                      helperText: '네이버 지도에 표시할 주소 또는 좌표',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '지도 주소를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: '문의 전화 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '전화번호를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _busInfoController,
                    decoration: const InputDecoration(
                      labelText: '버스 정보 *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '버스 정보를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subwayInfoController,
                    decoration: const InputDecoration(
                      labelText: '지하철 정보 *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '지하철 정보를 입력하세요' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }
}

