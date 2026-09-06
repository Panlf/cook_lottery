import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/database/database_helper.dart';
import 'package:cook_lottery/main.dart';
import 'package:cook_lottery/models/dish.dart';
import 'package:cook_lottery/models/meal_record.dart';

import 'helpers/test_db.dart';

/// sqflite_common_ffi 的部分内部实现依赖真实事件循环，在 flutter_test 的
/// FakeAsync 区内无法完成，因此统一用 runAsync 打开真实异步窗口完成
/// 数据库工作，再用 pumpAndSettle 收敛 UI 帧。
Future<void> pumpApp(
  WidgetTester tester, {
  Future<void> Function()? seed,
}) async {
  await tester.runAsync(() async {
    if (seed != null) await seed();
    await tester.pumpWidget(const CookLotteryApp());
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

/// 页面切换或数据操作后，等待真实异步完成并刷新界面。
Future<void> pumpAfterInteraction(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

Future<Dish> createDish(String name, int categoryId) async {
  final id = await DatabaseHelper.instance.insertDish(
    Dish(name: name, categoryId: categoryId),
  );
  return (await DatabaseHelper.instance.getDish(id))!;
}

void main() {
  setUpAll(() async {
    await initTestDatabaseFactory();
  });

  setUp(() => TestDatabase.setUp());
  tearDown(() => TestDatabase.tearDown());

  testWidgets('应用启动后显示菜谱页', (tester) async {
    await pumpApp(tester);
    expect(find.text('我的菜谱'), findsOneWidget);
    // 首次启动预置了默认分类
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('底部导航可在四个页签间切换', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('盲盒'));
    await pumpAfterInteraction(tester);
    expect(find.text('今日盲盒'), findsOneWidget);

    await tester.tap(find.text('饮食记录'));
    await pumpAfterInteraction(tester);
    expect(find.text('还没有饮食记录'), findsOneWidget);

    await tester.tap(find.text('修炼'));
    await pumpAfterInteraction(tester);
    expect(find.text('修炼模式'), findsOneWidget);

    await tester.tap(find.text('菜谱'));
    await pumpAfterInteraction(tester);
    expect(find.text('我的菜谱'), findsOneWidget);
  });

  testWidgets('饮食记录页展示统计与已有记录', (tester) async {
    await pumpApp(
      tester,
      seed: () async {
        final categories = await DatabaseHelper.instance.getAllCategories();
        final dish = await createDish('红烧肉', categories.first.id!);
        await DatabaseHelper.instance.insertMealRecord(
          MealRecord(
            date: DateTime.now(),
            mealType: 'lunch',
            dishIds: '${dish.id}',
            rating: 5,
          ),
        );
      },
    );

    await tester.tap(find.text('饮食记录'));
    await pumpAfterInteraction(tester);

    expect(find.textContaining('共 1 餐'), findsOneWidget);
    expect(find.text('红烧肉'), findsOneWidget);
    expect(find.text('☀️ 午餐'), findsOneWidget);
  });

  testWidgets('盲盒页勾选分类后可以抽签并确认', (tester) async {
    // 放大测试视口，避免页面内容被底部导航遮挡导致点击落点偏移
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      seed: () async {
        final categories = await DatabaseHelper.instance.getAllCategories();
        await createDish('可乐鸡翅', categories.first.id!);
      },
    );

    await tester.tap(find.text('盲盒'));
    await pumpAfterInteraction(tester);

    // 关闭「避开最近吃过的菜」开关（其排除算法已由 LotteryPicker/数据库
    // 单测覆盖），让抽签流程走纯本地路径，避免 FakeAsync 下的数据库等待。
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    // 勾选「海鲜」分类（首个默认分类，种子菜品归入此类）
    await tester.tap(find.text('海鲜'));
    await tester.pump();

    await tester.tap(find.text('🎲 开始抽签'));
    // 抽签滚动动画约 0.8s（FakeAsync 时间），随后结果落定
    await pumpAfterInteraction(tester);

    expect(find.text('可乐鸡翅'), findsOneWidget);
    await tester.tap(find.text('确定，就吃这些！'));
    await pumpAfterInteraction(tester);

    final records = await tester.runAsync(
      () => DatabaseHelper.instance.getAllMealRecords(),
    );
    expect(records, hasLength(1));
    expect(records!.first.mealType, 'lunch');
    // 记录里保存的菜品 ID 应能反查到「可乐鸡翅」
    final savedDish = await tester.runAsync(
      () async =>
          DatabaseHelper.instance.getDish(records.first.dishIdList.single),
    );
    expect(savedDish!.name, '可乐鸡翅');
  });
}
