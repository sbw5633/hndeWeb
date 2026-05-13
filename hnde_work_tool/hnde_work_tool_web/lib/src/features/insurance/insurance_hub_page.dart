import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../common/enterprise_scaffold.dart';
import 'daily_worker_page.dart';
import 'insurance_search_page.dart';
import 'insurance_status_page.dart';

/// 프로토타입: 가입 이력(명부/검색) + 일용직 탭
class InsuranceHubPage extends StatefulWidget {
  const InsuranceHubPage({super.key});

  @override
  State<InsuranceHubPage> createState() => _InsuranceHubPageState();
}

class _InsuranceHubPageState extends State<InsuranceHubPage>
    with TickerProviderStateMixin {
  late TabController _mainTab;
  late TabController _subTab;

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
    _subTab = TabController(length: 2, vsync: this);
    _subTab.addListener(_onSubTabChanged);
  }

  void _onSubTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subTab.removeListener(_onSubTabChanged);
    _mainTab.dispose();
    _subTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeNotifier>(
      builder: (BuildContext context, AppThemeNotifier notifier, _) {
        final Color primaryColor = notifier.theme.primary;
        return EnterpriseScaffold(
          title: '4대보험 관리',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: TabBar(
                  controller: _mainTab,
                  labelColor: primaryColor,
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  tabs: const <Tab>[
                    Tab(text: '가입 이력'),
                    Tab(text: '일용직 관리'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _mainTab,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: SegmentedButton<int>(
                                  segments: const <ButtonSegment<int>>[
                                    ButtonSegment<int>(
                                      value: 0,
                                      label: Text('가입자 명부'),
                                      icon: Icon(Icons.list_alt_rounded, size: 18),
                                    ),
                                    ButtonSegment<int>(
                                      value: 1,
                                      label: Text('직원 통합 검색'),
                                      icon: Icon(Icons.search_rounded, size: 18),
                                    ),
                                  ],
                                  selected: <int>{_subTab.index},
                                  onSelectionChanged: (Set<int> v) {
                                    if (v.isNotEmpty) {
                                      _subTab.animateTo(v.first);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _subTab,
                            children: const <Widget>[
                              InsuranceStatusPage(),
                              InsuranceSearchPage(),
                            ],
                          ),
                        ),
                      ],
                    ),
                const DailyWorkerPage(),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
