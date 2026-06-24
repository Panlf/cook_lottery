# 菜盒日记 🍳

一款温馨小清新的 Flutter 菜谱管理与随机点餐 App，帮你记录会做的菜，用盲盒模式决定今天吃什么。


## 功能特性

### 📖 菜谱库
- 拍照或从相册选择菜品图片
- 按分类管理菜品（海鲜、肉菜、蔬菜、汤品、主食、甜品等）
- 支持增删改分类，自定义分类名称和 emoji 图标
- 菜品图片支持随时替换更新

### 🎲 盲盒模式
- 选择午餐或晚餐
- 勾选参与抽签的分类（可多选）
- 自定义每个分类随机出现的菜品数量
- 一键抽签，不满意可重新抽签
- 确认后自动生成当日饮食记录

### 📅 饮食记录
- 按日期分组展示所有饮食记录
- 每餐可进行 1-5 星评价
- 支持撰写用餐心得
- 长按可删除记录
- 数据可用于后期分析

### ⭐ 修炼模式
- 新学的菜反复迭代练习
- 每次上传照片、评分、记录心得
- 满意后一键升级到正式菜库
- 追踪修炼次数和进步轨迹

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── models/
│   ├── dish.dart                      # 菜品数据模型
│   ├── category.dart                  # 分类数据模型
│   ├── meal_record.dart               # 饮食记录模型
│   └── practice_record.dart           # 修炼记录模型
├── database/
│   └── database_helper.dart           # SQLite 本地数据库管理
├── theme/
│   └── app_theme.dart                 # 暖棕色小清新主题
└── screens/
    ├── home_screen.dart               # 底部导航主界面
    ├── recipe_library_screen.dart     # 菜谱库
    ├── blind_box_screen.dart          # 盲盒模式
    ├── meal_history_screen.dart       # 饮食记录
    ├── practice_screen.dart           # 修炼模式
    ├── add_dish_screen.dart           # 添加/编辑菜品
    └── dish_detail_screen.dart        # 菜品详情
```

## 技术栈

- **Flutter** — 跨平台 UI 框架
- **SQLite (sqflite)** — 本地数据库存储
- **image_picker** — 拍照/相册选图
- **path_provider** — 本地文件路径管理
- **intl** — 日期格式化

## 开始使用

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run
```

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

所有数据存储在本地 SQLite 数据库，图片保存在设备本地文件系统，无需联网，保护隐私。
