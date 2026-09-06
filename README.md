# 菜盒日记 🍳

一款温馨小清新的 Flutter 菜谱管理与随机点餐 App，帮你记录会做的菜，用盲盒模式决定今天吃什么。

## 功能特性

### 📖 菜谱库
- 拍照或从相册选择菜品图片（自动持久化到应用目录，不怕系统清理缓存）
- 按分类管理菜品（海鲜、肉菜、蔬菜、汤品、主食、甜品等）
- 支持增删改分类，自定义分类名称和 emoji 图标
- 按菜品名称搜索，可与分类筛选叠加

### 🎲 盲盒模式
- 选择午餐或晚餐
- 勾选参与抽签的分类（可多选），自定义每个分类随机出现的菜品数量
- **避开最近吃过的菜**：可开启并选择 1/3/7 天范围，抽签时优先排除近期吃过的菜品（某分类排除后无菜可抽时自动回退，保证总有结果）
- 抽签滚动动画，不满意可重新抽签
- 确认后自动生成当日饮食记录

### 📅 饮食记录
- 顶部统计卡片：总餐数、本周餐数、平均评分、最常吃菜品 Top3
- 盲盒确认自动记录，也可点「记一餐」手动记录外出就餐（可选日期、餐次、菜品、心得）
- 按日期分组展示，每餐可进行 1-5 星评价并撰写用餐心得
- 长按可删除记录

### ⭐ 修炼模式
- 新学的菜反复迭代练习，每次上传照片、评分、记录心得
- 满意后一键升级到正式菜库（菜库已有同名菜品时自动关联，避免重复）
- 追踪修炼次数和进步轨迹

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── models/                            # 数据模型
│   ├── dish.dart                      # 菜品
│   ├── category.dart                  # 分类
│   ├── meal_record.dart               # 饮食记录
│   └── practice_record.dart           # 修炼记录
├── database/
│   └── database_helper.dart           # SQLite 本地数据库管理
├── services/
│   └── image_service.dart             # 菜品图片持久化管理
├── theme/
│   └── app_theme.dart                 # 暖棕色小清新主题
├── utils/                             # 纯逻辑（抽签算法/统计/文案）
├── widgets/                           # 复用组件（图片/评分/选择面板等）
└── screens/                           # 页面
    ├── home_screen.dart               # 底部导航主界面（IndexedStack 保活）
    ├── recipe_library_screen.dart     # 菜谱库（搜索/分类管理）
    ├── blind_box_screen.dart          # 盲盒模式（滚动抽签/避开近期吃过的菜）
    ├── meal_history_screen.dart       # 饮食记录（统计卡片）
    ├── practice_screen.dart           # 修炼模式
    ├── add_dish_screen.dart           # 添加/编辑菜品
    ├── add_meal_record_screen.dart    # 手动记一餐
    └── dish_detail_screen.dart        # 菜品详情（搭配历史）
```

更多设计细节见 [docs/开发文档.md](docs/开发文档.md)。

## 技术栈

- **Flutter** — 跨平台 UI 框架（Flutter 3.32+ / Dart 3.8+）
- **SQLite (sqflite)** — 本地数据库存储
- **image_picker** — 拍照/相册选图
- **path_provider** — 本地文件路径管理
- **intl** — 日期格式化
- **uuid** — 图片文件命名

## 开始使用

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test

# 静态分析
flutter analyze
```

## 测试

测试覆盖数据模型、抽签算法、统计计算、图片管理、数据库 CRUD（基于 sqflite_common_ffi，无需真机）与核心页面 Widget 测试，详见 [docs/测试文档.md](docs/测试文档.md)。

```bash
flutter test          # 全部 43 个测试
flutter analyze       # 期望：No issues found!
```

> 桌面端（Windows/macOS/Linux）数据库会自动切换到 FFI 实现（`main.dart` 内置引导），可正常启动使用；但拍照/相册选图依赖移动端插件，桌面端点击会得到友好提示，属已知限制。Windows 发行版需将 `sqlite3.dll` 放在可执行文件同级目录。

## 预置分类

| 分类 | 图标 | 说明 |
|------|------|------|
| 海鲜 | 🦐 | 虾蟹鱼类等 |
| 肉菜 | 🥩 | 猪牛羊肉等 |
| 蔬菜 | 🥬 | 各类蔬菜 |
| 汤品 | 🍲 | 各类汤 |
| 主食 | 🍚 | 米面主食 |
| 甜品 | 🍰 | 蛋糕甜点等 |

可在 App 内自由添加、编辑、删除分类。

## 数据存储

所有数据存储在本地 SQLite 数据库；菜品图片在选图后立即复制到应用文档目录 `dish_images/` 统一管理，删除菜品/分类或更换图片时自动清理对应文件。无需联网，保护隐私。
