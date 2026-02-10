import 'package:flutter/material.dart';
import '../models/rest_area.dart';
import 'map_view.dart';

class RestAreaListPage extends StatefulWidget {
  final List<RestArea> restAreas;

  const RestAreaListPage({
    super.key,
    required this.restAreas,
  });

  @override
  State<RestAreaListPage> createState() => _RestAreaListPageState();
}

class _RestAreaListPageState extends State<RestAreaListPage> {
  String? _selectedRestAreaId;

  @override
  void initState() {
    super.initState();
    // 첫 번째 휴게소를 기본 선택
    if (widget.restAreas.isNotEmpty) {
      _selectedRestAreaId = widget.restAreas.first.id;
    }
  }

  @override
  void didUpdateWidget(RestAreaListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 데이터가 업데이트되거나 선택된 항목이 없을 때 첫 번째 항목 선택
    if (widget.restAreas.isNotEmpty) {
      if (_selectedRestAreaId == null ||
          !widget.restAreas.any((r) => r.id == _selectedRestAreaId)) {
        _selectedRestAreaId = widget.restAreas.first.id;
      }
    } else {
      _selectedRestAreaId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 휴게소가 없는 경우
    if (widget.restAreas.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.only(left: 80, right: 80, top: 32, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Text(
                  '등록된 휴게소가 없습니다.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 휴게소 선택 버튼들 (가로 스크롤 없이 Wrap 사용)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: widget.restAreas.map((restArea) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRestAreaId = restArea.id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedRestAreaId == restArea.id
                        ? Colors.orange
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _selectedRestAreaId == restArea.id
                          ? Colors.orange
                          : Colors.grey[300]!,
                      width: _selectedRestAreaId == restArea.id ? 2 : 1,
                    ),
                    boxShadow: _selectedRestAreaId == restArea.id
                        ? [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    restArea.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectedRestAreaId == restArea.id
                          ? Colors.white
                          : Colors.blue[900],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // 선택된 휴게소만 표시
          if (_selectedRestAreaId != null)
            Builder(
              builder: (context) {
                final matchingRestAreas = widget.restAreas
                    .where((r) => r.id == _selectedRestAreaId)
                    .toList();

                if (matchingRestAreas.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: const Center(
                      child: Text('휴게소를 찾을 수 없습니다.'),
                    ),
                  );
                }

                final selectedRestArea = matchingRestAreas.first;

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _RestAreaCard(
                      restArea: selectedRestArea,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RestAreaCard extends StatelessWidget {
  final RestArea restArea;

  const _RestAreaCard({
    required this.restArea,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 및 제목 영역
          if (restArea.imageUrl != null && restArea.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                restArea.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.image, size: 64, color: Colors.grey),
                  );
                },
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 64, color: Colors.grey),
              ),
            ),
          // 제목과 설명
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restArea.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                if (restArea.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    restArea.description!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 탭 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RestAreaDetailTabs(restArea: restArea),
          ),
        ],
      ),
    );
  }
}

class RestAreaDetailTabs extends StatefulWidget {
  final RestArea restArea;

  const RestAreaDetailTabs({
    super.key,
    required this.restArea,
  });

  @override
  State<RestAreaDetailTabs> createState() => _RestAreaDetailTabsState();
}

class _RestAreaDetailTabsState extends State<RestAreaDetailTabs> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final categories = RestAreaCategory.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 탭 버튼들 (가로 스크롤 없이 Wrap 사용)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final isSelected = _selectedTabIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 선택된 탭의 내용만 표시 (내부 스크롤 없음)
        _buildTabContent(),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _IntroTab(detail: widget.restArea.detail);
      case 1:
        return _StoresTab(stores: widget.restArea.detail.stores);
      case 2:
        return _FoodsTab(foods: widget.restArea.detail.foods);
      case 3:
        return _FacilitiesTab(facilities: widget.restArea.detail.facilities);
      case 4:
        return _StatusTab(detail: widget.restArea.detail);
      case 5:
        return _AwardsTab(awards: widget.restArea.detail.awards);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _IntroTab extends StatefulWidget {
  final RestAreaDetail detail;

  const _IntroTab({required this.detail});

  @override
  State<_IntroTab> createState() => _IntroTabState();
}

class _IntroTabState extends State<_IntroTab> {
  bool _isMapExpanded = false;

  // 확장성을 위한 섹션 빌더 - 나중에 어드민에서 선택한 항목들을 순차적으로 표시
  List<Widget> _buildAdditionalSections() {
    final sections = <Widget>[];

    // 현황 섹션 추가 (additionalItems를 현황으로 표시)
    if (widget.detail.additionalItems.isNotEmpty) {
      sections.add(_buildStatusSectionFromItems(widget.detail.additionalItems));
    }

    // 수상내역 섹션 추가
    if (widget.detail.awards.isNotEmpty) {
      sections.add(_buildAwardsSection(widget.detail.awards));
    }

    return sections;
  }

  // 아이콘 이름을 IconData로 변환
  IconData _getIconData(String iconName) {
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
      case 'smoke_free':
        return Icons.smoke_free;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  // 현황 섹션 빌드 (additionalItems를 현황으로 표시)
  Widget _buildStatusSectionFromItems(List<AdditionalItemInfo> items) {
    final sortedItems = List<AdditionalItemInfo>.from(items)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          '현황',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        ...sortedItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _StatusItemCard(
            icon: _getIconData(item.iconName),
            title: item.title,
            content: item.content,
            imageUrl: item.imageUrl,
          ),
        )),
      ],
    );
  }


  Widget _buildAwardsSection(List<AwardInfo> awards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          '수상내역',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          children: awards.map((award) {
            return _AwardCard(
              title: award.title,
              description: award.description,
              imageUrl: award.imageUrl,
              year: award.year,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.detail.intro.isNotEmpty)
          Text(
            widget.detail.intro,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.8,
            ),
          ),
        if (widget.detail.mapAddress != null && widget.detail.mapAddress!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _isMapExpanded
              ? // 확대된 지도 (전체 너비, 16:9)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 (제목 + 버튼)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '휴게소 위치',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen_exit),
                              tooltip: '축소',
                              onPressed: () {
                                setState(() {
                                  _isMapExpanded = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      // 지도
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: MapView(address: widget.detail.mapAddress!),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : // 작은 지도 (300x300, 좌측)
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 헤더 (제목 + 버튼)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '휴게소 위치',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: '확대',
                              onPressed: () {
                                setState(() {
                                  _isMapExpanded = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      // 지도
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: MapView(address: widget.detail.mapAddress!),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
        // 확장 가능한 추가 섹션들 (현황, 수상내역 등)
        ..._buildAdditionalSections(),
      ],
    );
  }
}

class _StoresTab extends StatelessWidget {
  final List<StoreInfo> stores;

  const _StoresTab({required this.stores});

  int _getCrossAxisCount(double width) {
    if (width < 600) {
      return 2; // 작은 화면: 2개
    } else if (width < 900) {
      return 3; // 중간 화면: 3개
    } else if (width < 1200) {
      return 4; // 큰 화면: 4개
    } else {
      return 5; // 매우 큰 화면: 5개
    }
  }

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return const Center(
        child: Text('등록된 매장이 없습니다.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final spacing = 16.0;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 0.75, // 높이를 너비보다 약간 크게
            ),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return _StoreGridItem(
                name: store.name,
                imageUrl: store.imageUrl,
              );
            },
          ),
        );
      },
    );
  }
}

class _StoreGridItem extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _StoreGridItem({
    required this.name,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 이미지 영역
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child:
                                Icon(Icons.store, size: 48, color: Colors.grey),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.store, size: 48, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          // 명칭 영역
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodsTab extends StatelessWidget {
  final List<FoodInfo> foods;

  const _FoodsTab({required this.foods});

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return const Center(
        child: Text('등록된 먹거리가 없습니다.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: foods.map((food) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _InfoCard(
              title: food.name,
              description: food.description,
              imageUrl: food.imageUrl,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FacilitiesTab extends StatelessWidget {
  final List<FacilityInfo> facilities;

  const _FacilitiesTab({required this.facilities});

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) {
      return const Center(
        child: Text('등록된 편의시설이 없습니다.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: facilities.map((facility) {
          return _FacilityChip(
            name: facility.name,
            description: facility.description,
            iconName: facility.iconName,
          );
        }).toList(),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? imageUrl;

  const _InfoCard({
    required this.title,
    this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 32),
                  );
                },
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, size: 32),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  final String name;
  final String? description;
  final String? iconName;

  const _FacilityChip({
    required this.name,
    this.description,
    this.iconName,
  });

  IconData _getIcon() {
    switch (iconName) {
      case 'restroom':
        return Icons.wc;
      case 'parking':
        return Icons.local_parking;
      case 'gas':
        return Icons.local_gas_station;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), color: Colors.blue[900], size: 20),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final RestAreaDetail detail;

  const _StatusTab({required this.detail});

  IconData _getIconData(String iconName) {
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
      case 'smoke_free':
        return Icons.smoke_free;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (detail.additionalItems.isEmpty) {
      return const Center(
        child: Text('등록된 현황 정보가 없습니다.'),
      );
    }

    final sortedItems = List<AdditionalItemInfo>.from(detail.additionalItems)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sortedItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _StatusItemCard(
              icon: _getIconData(item.iconName),
              title: item.title,
              content: item.content,
              imageUrl: item.imageUrl,
            ),
          )),
        ],
      ),
    );
  }
}


// 현황 항목 카드 (additionalItems용)
class _StatusItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? content;
  final String? imageUrl;

  const _StatusItemCard({
    required this.icon,
    required this.title,
    this.content,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 제목 (아이콘 포함)
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue[900],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          // 하단: 내용 영역 (좌측 이미지, 우측 텍스트)
          if (content != null && content!.isNotEmpty || imageUrl != null && imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좌측: 이미지
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error_outline, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                if (imageUrl != null && imageUrl!.isNotEmpty && content != null && content!.isNotEmpty)
                  const SizedBox(width: 16),
                // 우측: 텍스트
                if (content != null && content!.isNotEmpty)
                  Expanded(
                    child: Text(
                      content!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AwardsTab extends StatelessWidget {
  final List<AwardInfo> awards;

  const _AwardsTab({required this.awards});

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) {
      return const Center(
        child: Text('등록된 수상내역이 없습니다.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: awards.map((award) {
          return _AwardCard(
            title: award.title,
            description: award.description,
            imageUrl: award.imageUrl,
            year: award.year,
          );
        }).toList(),
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? imageUrl;
  final String? year;

  const _AwardCard({
    required this.title,
    this.description,
    this.imageUrl,
    this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 이미지 영역
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.emoji_events,
                              size: 48, color: Colors.grey),
                        ),
                      );
                    },
                  )
                : Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.emoji_events,
                          size: 48, color: Colors.grey),
                    ),
                  ),
          ),
          // 텍스트 영역
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (year != null && year!.isNotEmpty) ...[
                  Text(
                    year!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
