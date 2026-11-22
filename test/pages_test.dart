import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/app.dart';
import 'package:glimpse/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _bootstrap() async {
  SharedPreferences.setMockInitialValues({});
  prefs = await SharedPreferences.getInstance();
}

void main() {
  setUp(_bootstrap);

  testWidgets('六个页面都能构建且无异常', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: GlimpseApp()));
    await tester.pump(const Duration(milliseconds: 300));

    // 仪表盘
    expect(find.text('仪表盘'), findsWidgets);

    // 依次点击底部导航
    for (final label in ['代理', '连接', '规则', '日志', '设置']) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '页面 $label 构建抛异常');
    }

    // 回到仪表盘，确认数据类页面没有崩溃
    await tester.tap(find.text('仪表盘').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 销毁，让轮询定时器走完最后一轮再结束
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  });
}
