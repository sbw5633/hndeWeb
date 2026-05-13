import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/file_upload_service.dart';
import '../../models/rest_area.dart';

class RestAreaDetailEditTab extends StatefulWidget {
  final RestAreaDetail detail;
  final Function(RestAreaDetail) onDetailChanged;

  const RestAreaDetailEditTab({
    super.key,
    required this.detail,
    required this.onDetailChanged,
  });

  @override
  State<RestAreaDetailEditTab> createState() => _RestAreaDetailEditTabState();
}

class _RestAreaDetailEditTabState extends State<RestAreaDetailEditTab> {
  late RestAreaDetail _detail;
  final _introController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _introController.text = _detail.intro;
    _addressController.text = _detail.address ?? '';
    _mapAddressController.text = _detail.mapAddress ?? '';
  }

  @override
  void dispose() {
    _introController.dispose();
    _addressController.dispose();
    _mapAddressController.dispose();
    super.dispose();
  }

  void _updateDetail() {
    _detail = RestAreaDetail(
      intro: _introController.text,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      mapAddress: _mapAddressController.text.trim().isEmpty ? null : _mapAddressController.text.trim(),
      status: _detail.status,
      awards: _detail.awards,
      stores: _detail.stores,
      foods: _detail.foods,
      facilities: _detail.facilities,
      additionalItems: _detail.additionalItems,
    );
    widget.onDetailChanged(_detail);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '소개'),
              Tab(text: '매장'),
              Tab(text: '먹거리'),
              Tab(text: '편의시설'),
              Tab(text: '현황'),
              Tab(text: '수상내역'),
            ],
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              children: [
                _buildIntroTab(),
                _buildStoresTab(),
                _buildFoodsTab(),
                _buildFacilitiesTab(),
                _buildStatusTab(),
                _buildAwardsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 추가 항목 관리 UI (소개 탭 하단에 표시)
  Widget _buildAdditionalItemsSection() {
    final items = List<AdditionalItemInfo>.from(_detail.additionalItems)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '현황 (최대 5개)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (items.length < 5)
              TextButton.icon(
                onPressed: _addAdditionalItem,
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            setState(() {
              final item = items.removeAt(oldIndex);
              items.insert(newIndex, item);
              // 순서 업데이트
              for (int i = 0; i < items.length; i++) {
                items[i] = AdditionalItemInfo(
                  id: items[i].id,
                  iconName: items[i].iconName,
                  title: items[i].title,
                  content: items[i].content,
                  imageUrl: items[i].imageUrl,
                  order: i,
                );
              }
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores,
                foods: _detail.foods,
                facilities: _detail.facilities,
                additionalItems: items,
              );
              widget.onDetailChanged(_detail);
            });
          },
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 6,
              color: Colors.transparent,
              shadowColor: Colors.black54,
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final item = items[index];
            return _AdditionalItemCard(
              key: ValueKey(item.id),
              item: item,
              onChanged: (updatedItem) {
                setState(() {
                  final itemIndex = _detail.additionalItems.indexWhere((i) => i.id == item.id);
                  if (itemIndex != -1) {
                    final updatedItems = List<AdditionalItemInfo>.from(_detail.additionalItems);
                    updatedItems[itemIndex] = updatedItem;
                    _detail = RestAreaDetail(
                      intro: _detail.intro,
                      address: _detail.address,
                      mapAddress: _detail.mapAddress,
                      status: _detail.status,
                      awards: _detail.awards,
                      stores: _detail.stores,
                      foods: _detail.foods,
                      facilities: _detail.facilities,
                      additionalItems: updatedItems,
                    );
                    widget.onDetailChanged(_detail);
                  }
                });
              },
              onDelete: () {
                setState(() {
                  final updatedItems = _detail.additionalItems.where((i) => i.id != item.id).toList();
                  _detail = RestAreaDetail(
                    intro: _detail.intro,
                    address: _detail.address,
                    mapAddress: _detail.mapAddress,
                    status: _detail.status,
                    awards: _detail.awards,
                    stores: _detail.stores,
                    foods: _detail.foods,
                    facilities: _detail.facilities,
                    additionalItems: updatedItems,
                  );
                  widget.onDetailChanged(_detail);
                });
              },
            );
          },
        ),
      ],
    );
  }

  void _addAdditionalItem() {
    final newItem = AdditionalItemInfo(
      id: const Uuid().v4(),
      iconName: 'info',
      title: '',
      content: '',
      imageUrl: null,
      order: _detail.additionalItems.length,
    );
    setState(() {
      _detail = RestAreaDetail(
        intro: _detail.intro,
        address: _detail.address,
        mapAddress: _detail.mapAddress,
        status: _detail.status,
        awards: _detail.awards,
        stores: _detail.stores,
        foods: _detail.foods,
        facilities: _detail.facilities,
        additionalItems: [..._detail.additionalItems, newItem],
      );
      widget.onDetailChanged(_detail);
    });
  }

  Widget _buildIntroTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _introController,
            decoration: const InputDecoration(
              labelText: '소개 내용',
              border: OutlineInputBorder(),
            ),
            maxLines: 10,
            onChanged: (_) => _updateDetail(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '주소',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _updateDetail(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mapAddressController,
            decoration: const InputDecoration(
              labelText: '지도 주소 (지도 표시용)',
              border: OutlineInputBorder(),
              helperText: '지도에서 검색할 주소를 입력하세요',
            ),
            onChanged: (_) => _updateDetail(),
          ),
          if (_mapAddressController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  '지도 미리보기\n(주소: ${_mapAddressController.text})',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _buildAdditionalItemsSection(),
        ],
      ),
    );
  }

  Widget _buildStoresTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('매장 목록', style: TextStyle(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('추가'),
                onPressed: () => _showStoreDialog(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _detail.stores.length,
            itemBuilder: (context, index) {
              final store = _detail.stores[index];
              return ListTile(
                leading: store.imageUrl != null
                    ? Image.network(store.imageUrl!,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.store),
                title: Text(store.name),
                subtitle: Text(store.description ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showStoreDialog(store),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _detail = RestAreaDetail(
                            intro: _detail.intro,
                            address: _detail.address,
                            mapAddress: _detail.mapAddress,
                            status: _detail.status,
                            awards: _detail.awards,
                            stores: _detail.stores
                                .where((s) => s.id != store.id)
                                .toList(),
                            foods: _detail.foods,
                            facilities: _detail.facilities,
                            additionalItems: _detail.additionalItems,
                          );
                          _updateDetail();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFoodsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('먹거리 목록', style: TextStyle(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('추가'),
                onPressed: () => _showFoodDialog(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _detail.foods.length,
            itemBuilder: (context, index) {
              final food = _detail.foods[index];
              return ListTile(
                leading: food.imageUrl != null
                    ? Image.network(food.imageUrl!,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.restaurant),
                title: Text(food.name),
                subtitle: Text(food.description ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showFoodDialog(food),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _detail = RestAreaDetail(
                            intro: _detail.intro,
                            address: _detail.address,
                            mapAddress: _detail.mapAddress,
                            status: _detail.status,
                            awards: _detail.awards,
                            stores: _detail.stores,
                            foods: _detail.foods
                                .where((f) => f.id != food.id)
                                .toList(),
                            facilities: _detail.facilities,
                            additionalItems: _detail.additionalItems,
                          );
                          _updateDetail();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacilitiesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('편의시설 목록', style: TextStyle(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('추가'),
                onPressed: () => _showFacilityDialog(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _detail.facilities.length,
            itemBuilder: (context, index) {
              final facility = _detail.facilities[index];
              return ListTile(
                leading: facility.imageUrl != null
                    ? Image.network(facility.imageUrl!,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.local_offer),
                title: Text(facility.name),
                subtitle: Text(facility.description ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showFacilityDialog(facility),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _detail = RestAreaDetail(
                            intro: _detail.intro,
                            address: _detail.address,
                            mapAddress: _detail.mapAddress,
                            status: _detail.status,
                            awards: _detail.awards,
                            stores: _detail.stores,
                            foods: _detail.foods,
                            facilities: _detail.facilities
                                .where((f) => f.id != facility.id)
                                .toList(),
                            additionalItems: _detail.additionalItems,
                          );
                          _updateDetail();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showStoreDialog(StoreInfo? store) async {
    final nameController = TextEditingController(text: store?.name ?? '');
    final descController =
        TextEditingController(text: store?.description ?? '');
    String? imageUrl = store?.imageUrl;

    await showDialog(
      context: context,
      builder: (_) => _StoreDialog(
        nameController: nameController,
        descController: descController,
        imageUrl: imageUrl,
        onImageChanged: (url) => imageUrl = url,
        onSave: () {
          final newStore = StoreInfo(
            id: store?.id ?? const Uuid().v4(),
            name: nameController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            imageUrl: imageUrl,
          );
          setState(() {
            if (store == null) {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: [..._detail.stores, newStore],
                foods: _detail.foods,
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            } else {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores
                    .map((s) => s.id == store.id ? newStore : s)
                    .toList(),
                foods: _detail.foods,
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            }
            _updateDetail();
          });
        },
      ),
    );
  }

  Future<void> _showFoodDialog(FoodInfo? food) async {
    final nameController = TextEditingController(text: food?.name ?? '');
    final descController = TextEditingController(text: food?.description ?? '');
    String? imageUrl = food?.imageUrl;

    await showDialog(
      context: context,
      builder: (_) => _FoodDialog(
        nameController: nameController,
        descController: descController,
        imageUrl: imageUrl,
        onImageChanged: (url) => imageUrl = url,
        onSave: () {
          final newFood = FoodInfo(
            id: food?.id ?? const Uuid().v4(),
            name: nameController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            imageUrl: imageUrl,
          );
          setState(() {
            if (food == null) {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores,
                foods: [..._detail.foods, newFood],
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            } else {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores,
                foods: _detail.foods
                    .map((f) => f.id == food.id ? newFood : f)
                    .toList(),
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            }
            _updateDetail();
          });
        },
      ),
    );
  }

  Future<void> _showFacilityDialog(FacilityInfo? facility) async {
    final nameController = TextEditingController(text: facility?.name ?? '');
    final descController =
        TextEditingController(text: facility?.description ?? '');
    String? imageUrl = facility?.imageUrl;

    await showDialog(
      context: context,
      builder: (_) => _FacilityDialog(
        nameController: nameController,
        descController: descController,
        imageUrl: imageUrl,
        onImageChanged: (url) => imageUrl = url,
        onSave: () {
          final newFacility = FacilityInfo(
            id: facility?.id ?? const Uuid().v4(),
            name: nameController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            iconName: facility?.iconName,
            imageUrl: imageUrl,
          );
          setState(() {
            if (facility == null) {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores,
                foods: _detail.foods,
                facilities: [..._detail.facilities, newFacility],
                additionalItems: _detail.additionalItems,
              );
            } else {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards,
                stores: _detail.stores,
                foods: _detail.foods,
                facilities: _detail.facilities
                    .map((f) => f.id == facility.id ? newFacility : f)
                    .toList(),
                additionalItems: _detail.additionalItems,
              );
            }
            _updateDetail();
          });
        },
      ),
    );
  }

  Widget _buildStatusTab() {
    final status = _detail.status ?? RestAreaStatus();
    final buildingController = TextEditingController(text: status.buildingStatus ?? '');
    final parkingController = TextEditingController(text: status.parkingStatus ?? '');
    final restroomController = TextEditingController(text: status.restroomStatus ?? '');
    final convenienceController = TextEditingController(text: status.convenienceStatus ?? '');
    final gasStationController = TextEditingController(text: status.gasStationStatus ?? '');
    bool hasGasStation = status.hasGasStation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: buildingController,
            decoration: const InputDecoration(
              labelText: '건물현황',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (_) {
              setState(() {
                _detail = RestAreaDetail(
                  intro: _detail.intro,
                  address: _detail.address,
                  mapAddress: _detail.mapAddress,
                  status: RestAreaStatus(
                    buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                    parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                    restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                    convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                    hasGasStation: hasGasStation,
                    gasStationStatus: hasGasStation && gasStationController.text.trim().isNotEmpty ? gasStationController.text.trim() : null,
                  ),
                  awards: _detail.awards,
                  stores: _detail.stores,
                  foods: _detail.foods,
                  facilities: _detail.facilities,
                  additionalItems: _detail.additionalItems,
                );
                _updateDetail();
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: parkingController,
            decoration: const InputDecoration(
              labelText: '주차장 현황',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (_) {
              setState(() {
                _detail = RestAreaDetail(
                  intro: _detail.intro,
                  address: _detail.address,
                  mapAddress: _detail.mapAddress,
                  status: RestAreaStatus(
                    buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                    parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                    restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                    convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                    hasGasStation: hasGasStation,
                    gasStationStatus: hasGasStation && gasStationController.text.trim().isNotEmpty ? gasStationController.text.trim() : null,
                  ),
                  awards: _detail.awards,
                  stores: _detail.stores,
                  foods: _detail.foods,
                  facilities: _detail.facilities,
                  additionalItems: _detail.additionalItems,
                );
                _updateDetail();
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: restroomController,
            decoration: const InputDecoration(
              labelText: '화장실 현황',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (_) {
              setState(() {
                _detail = RestAreaDetail(
                  intro: _detail.intro,
                  address: _detail.address,
                  mapAddress: _detail.mapAddress,
                  status: RestAreaStatus(
                    buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                    parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                    restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                    convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                    hasGasStation: hasGasStation,
                    gasStationStatus: hasGasStation && gasStationController.text.trim().isNotEmpty ? gasStationController.text.trim() : null,
                  ),
                  awards: _detail.awards,
                  stores: _detail.stores,
                  foods: _detail.foods,
                  facilities: _detail.facilities,
                  additionalItems: _detail.additionalItems,
                );
                _updateDetail();
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: convenienceController,
            decoration: const InputDecoration(
              labelText: '편의시설 현황',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (_) {
              setState(() {
                _detail = RestAreaDetail(
                  intro: _detail.intro,
                  address: _detail.address,
                  mapAddress: _detail.mapAddress,
                  status: RestAreaStatus(
                    buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                    parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                    restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                    convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                    hasGasStation: hasGasStation,
                    gasStationStatus: hasGasStation && gasStationController.text.trim().isNotEmpty ? gasStationController.text.trim() : null,
                  ),
                  awards: _detail.awards,
                  stores: _detail.stores,
                  foods: _detail.foods,
                  facilities: _detail.facilities,
                  additionalItems: _detail.additionalItems,
                );
                _updateDetail();
              });
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('주유소 있음'),
            value: hasGasStation,
            onChanged: (value) {
              setState(() {
                hasGasStation = value ?? false;
                _detail = RestAreaDetail(
                  intro: _detail.intro,
                  address: _detail.address,
                  mapAddress: _detail.mapAddress,
                  status: RestAreaStatus(
                    buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                    parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                    restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                    convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                    hasGasStation: hasGasStation,
                    gasStationStatus: hasGasStation && gasStationController.text.trim().isNotEmpty ? gasStationController.text.trim() : null,
                  ),
                  awards: _detail.awards,
                  stores: _detail.stores,
                  foods: _detail.foods,
                  facilities: _detail.facilities,
                  additionalItems: _detail.additionalItems,
                );
                _updateDetail();
              });
            },
          ),
          if (hasGasStation) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: gasStationController,
              decoration: const InputDecoration(
                labelText: '주유소 현황',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (_) {
                setState(() {
                  _detail = RestAreaDetail(
                    intro: _detail.intro,
                    address: _detail.address,
                    mapAddress: _detail.mapAddress,
                    status: RestAreaStatus(
                      buildingStatus: buildingController.text.trim().isEmpty ? null : buildingController.text.trim(),
                      parkingStatus: parkingController.text.trim().isEmpty ? null : parkingController.text.trim(),
                      restroomStatus: restroomController.text.trim().isEmpty ? null : restroomController.text.trim(),
                      convenienceStatus: convenienceController.text.trim().isEmpty ? null : convenienceController.text.trim(),
                      hasGasStation: hasGasStation,
                      gasStationStatus: gasStationController.text.trim().isEmpty ? null : gasStationController.text.trim(),
                    ),
                    awards: _detail.awards,
                    stores: _detail.stores,
                    foods: _detail.foods,
                    facilities: _detail.facilities,
                    additionalItems: _detail.additionalItems,
                  );
                  _updateDetail();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAwardsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('수상내역 목록', style: TextStyle(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('추가'),
                onPressed: () => _showAwardDialog(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _detail.awards.length,
            itemBuilder: (context, index) {
              final award = _detail.awards[index];
              return ListTile(
                leading: award.imageUrl != null
                    ? Image.network(award.imageUrl!,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.emoji_events),
                title: Text(award.title),
                subtitle: Text(award.description ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAwardDialog(award),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _detail = RestAreaDetail(
                            intro: _detail.intro,
                            address: _detail.address,
                            mapAddress: _detail.mapAddress,
                            status: _detail.status,
                            awards: _detail.awards
                                .where((a) => a.id != award.id)
                                .toList(),
                            stores: _detail.stores,
                            foods: _detail.foods,
                            facilities: _detail.facilities,
                            additionalItems: _detail.additionalItems,
                          );
                          _updateDetail();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAwardDialog(AwardInfo? award) async {
    final titleController = TextEditingController(text: award?.title ?? '');
    final descController = TextEditingController(text: award?.description ?? '');
    final yearController = TextEditingController(text: award?.year ?? '');
    String? imageUrl = award?.imageUrl;

    await showDialog(
      context: context,
      builder: (_) => _AwardDialog(
        titleController: titleController,
        descController: descController,
        yearController: yearController,
        imageUrl: imageUrl,
        onImageChanged: (url) => imageUrl = url,
        onSave: () {
          final newAward = AwardInfo(
            id: award?.id ?? const Uuid().v4(),
            title: titleController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            imageUrl: imageUrl,
            year: yearController.text.trim().isEmpty
                ? null
                : yearController.text.trim(),
          );
          setState(() {
            if (award == null) {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: [..._detail.awards, newAward],
                stores: _detail.stores,
                foods: _detail.foods,
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            } else {
              _detail = RestAreaDetail(
                intro: _detail.intro,
                address: _detail.address,
                mapAddress: _detail.mapAddress,
                status: _detail.status,
                awards: _detail.awards
                    .map((a) => a.id == award.id ? newAward : a)
                    .toList(),
                stores: _detail.stores,
                foods: _detail.foods,
                facilities: _detail.facilities,
                additionalItems: _detail.additionalItems,
              );
            }
            _updateDetail();
          });
        },
      ),
    );
  }
}

class _StoreDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  String? imageUrl;
  final Function(String?) onImageChanged;
  final VoidCallback onSave;

  _StoreDialog({
    required this.nameController,
    required this.descController,
    required this.imageUrl,
    required this.onImageChanged,
    required this.onSave,
  });

  @override
  State<_StoreDialog> createState() => __StoreDialogState();
}

class __StoreDialogState extends State<_StoreDialog> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          widget.imageUrl = uploadService.getViewUrl(result['view_url']);
          widget.onImageChanged(widget.imageUrl);
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('매장 추가/수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                  labelText: '매장명 *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.descController,
              decoration: const InputDecoration(
                  labelText: '설명', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: widget.imageUrl != null
                    ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.add_photo_alternate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _FoodDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  String? imageUrl;
  final Function(String?) onImageChanged;
  final VoidCallback onSave;

  _FoodDialog({
    required this.nameController,
    required this.descController,
    required this.imageUrl,
    required this.onImageChanged,
    required this.onSave,
  });

  @override
  State<_FoodDialog> createState() => __FoodDialogState();
}

class __FoodDialogState extends State<_FoodDialog> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          widget.imageUrl = uploadService.getViewUrl(result['view_url']);
          widget.onImageChanged(widget.imageUrl);
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('먹거리 추가/수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                  labelText: '먹거리명 *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.descController,
              decoration: const InputDecoration(
                  labelText: '설명', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: widget.imageUrl != null
                    ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.add_photo_alternate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _FacilityDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  String? imageUrl;
  final Function(String?) onImageChanged;
  final VoidCallback onSave;

  _FacilityDialog({
    required this.nameController,
    required this.descController,
    required this.imageUrl,
    required this.onImageChanged,
    required this.onSave,
  });

  @override
  State<_FacilityDialog> createState() => __FacilityDialogState();
}

class __FacilityDialogState extends State<_FacilityDialog> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          widget.imageUrl = uploadService.getViewUrl(result['view_url']);
          widget.onImageChanged(widget.imageUrl);
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('편의시설 추가/수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                  labelText: '편의시설명 *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.descController,
              decoration: const InputDecoration(
                  labelText: '설명', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: widget.imageUrl != null
                    ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.add_photo_alternate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _AwardDialog extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController yearController;
  String? imageUrl;
  final Function(String?) onImageChanged;
  final VoidCallback onSave;

  _AwardDialog({
    required this.titleController,
    required this.descController,
    required this.yearController,
    required this.imageUrl,
    required this.onImageChanged,
    required this.onSave,
  });

  @override
  State<_AwardDialog> createState() => __AwardDialogState();
}

class __AwardDialogState extends State<_AwardDialog> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          widget.imageUrl = uploadService.getViewUrl(result['view_url']);
          widget.onImageChanged(widget.imageUrl);
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('수상내역 추가/수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.titleController,
              decoration: const InputDecoration(
                  labelText: '수상명 *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.yearController,
              decoration: const InputDecoration(
                  labelText: '연도', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.descController,
              decoration: const InputDecoration(
                  labelText: '설명', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: widget.imageUrl != null
                    ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.add_photo_alternate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// 추가 항목 카드 위젯
class _AdditionalItemCard extends StatefulWidget {
  final AdditionalItemInfo item;
  final Function(AdditionalItemInfo) onChanged;
  final VoidCallback onDelete;

  const _AdditionalItemCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_AdditionalItemCard> createState() => _AdditionalItemCardState();
}

class _AdditionalItemCardState extends State<_AdditionalItemCard> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedIcon;
  String? _imageUrl;
  bool _isUploading = false;

  // 일반적인 Material Icons 목록 (한글 이름)
  final Map<String, String> _iconOptions = {
    'info': '정보',
    'star': '별',
    'location_on': '위치',
    'phone': '전화',
    'email': '이메일',
    'schedule': '시간',
    'directions_car': '주차',
    'restaurant': '식당',
    'local_parking': '주차장',
    'wc': '화장실',
    'local_gas_station': '주유소',
    'shopping_cart': '쇼핑',
    'hotel': '숙박',
    'wifi': '와이파이',
    'accessibility': '장애인',
    'child_care': '유아',
    'pets': '반려동물',
    'smoking_rooms': '흡연실',
    'no_smoking': '금연',
    'check_circle': '확인',
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _contentController = TextEditingController(text: widget.item.content);
    _selectedIcon = widget.item.iconName;
    _imageUrl = widget.item.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    // Material Icons 매핑
    switch (iconName) {
      case 'info':
        return Icons.info;
      case 'star':
        return Icons.star;
      case 'location_on':
        return Icons.location_on;
      case 'phone':
        return Icons.phone;
      case 'email':
        return Icons.email;
      case 'schedule':
        return Icons.schedule;
      case 'directions_car':
        return Icons.directions_car;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_parking':
        return Icons.local_parking;
      case 'wc':
        return Icons.wc;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'hotel':
        return Icons.hotel;
      case 'wifi':
        return Icons.wifi;
      case 'accessibility':
        return Icons.accessibility;
      case 'child_care':
        return Icons.child_care;
      case 'pets':
        return Icons.pets;
      case 'smoking_rooms':
        return Icons.smoking_rooms;
      case 'no_smoking':
        return Icons.smoke_free;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _imageUrl = uploadService.getViewUrl(result['view_url']);
          _updateItem();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _updateItem() {
    widget.onChanged(AdditionalItemInfo(
      id: widget.item.id,
      iconName: _selectedIcon,
      title: _titleController.text,
      content: _contentController.text,
      imageUrl: _imageUrl,
      order: widget.item.order,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들 (햄버거 아이콘) - ReorderableDragStartListener로 감싸서 드래그 가능하게
            ReorderableDragStartListener(
              index: widget.item.order,
              child: Icon(
                Icons.drag_handle,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            // 아이콘 선택
            PopupMenuButton<String>(
              icon: Icon(_getIconData(_selectedIcon)),
              onSelected: (icon) {
                setState(() {
                  _selectedIcon = icon;
                  _updateItem();
                });
              },
              itemBuilder: (context) => _iconOptions.entries.map((entry) {
                return PopupMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(_getIconData(entry.key)),
                      const SizedBox(width: 8),
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            // 제목과 내용 입력 필드
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateItem(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                    onChanged: (_) => _updateItem(),
                  ),
                  const SizedBox(height: 8),
                  // 이미지 업로드
                  GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _isUploading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _imageUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _imageUrl!,
                                        width: double.infinity,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.error),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _imageUrl = null;
                                              _updateItem();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 24),
                                      SizedBox(height: 4),
                                      Text(
                                        '이미지 추가',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 삭제 버튼 (가운데 정렬)
            Center(
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

