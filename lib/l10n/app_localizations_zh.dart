// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get backgroundColor => '背景颜色';

  @override
  String get pageTurnMode => '翻页模式';

  @override
  String get pageTurnSlide => '平移';

  @override
  String get pageTurnNone => '无动画';

  @override
  String get chapterEndHint => '本章完，点击进入下一章';

  @override
  String get contents => '目录';

  @override
  String totalChapters(int count) {
    return '共${count}话';
  }

  @override
  String get commentShort => '章评';

  @override
  String get indentMode => '缩进模式';

  @override
  String get indentNone => '无';

  @override
  String get indentOne => '1格';

  @override
  String get indentTwo => '2格';

  @override
  String get addToBookshelf => '加入书架';

  @override
  String get inBookshelf => '已在书架';

  @override
  String get exitAppHint => '再滑一次退出应用';

  @override
  String get gridView => '宫格视图';

  @override
  String get listView => '列表视图';

  @override
  String unreadChapters(int count) {
    return '${count}话未读';
  }

  @override
  String get home => '发现';

  @override
  String get favorites => '收藏';

  @override
  String get settings => '设置';

  @override
  String get more => '我的';

  @override
  String get showWindow => '显示窗口';

  @override
  String get hideWindow => '隐藏窗口';

  @override
  String get exit => '退出';

  @override
  String get login => '登录';

  @override
  String get mobilePhoneLoginTip => '请在网页中登录，登录成功后点击右上角按钮关闭当前页面';

  @override
  String get desktopLoginTip => '点击下面按钮将打开本地安装的 Chrome 或 Chromium 浏览器，请手动输入帐号密码进行登录，本软件在检测到登录成功后会自动关闭浏览器';

  @override
  String get chromePath => 'Chrome 或 Chromium 安装位置:';

  @override
  String get chromeNotFound => '未检测到 Chrome 或 Chromium 浏览器';

  @override
  String get author => '作者';

  @override
  String get translator => '翻译';

  @override
  String get status => '状态';

  @override
  String get originalBook => '原作';

  @override
  String get lastUpdated => '最近更新';

  @override
  String get brief => '简介';

  @override
  String get errorTip => '出错啦~';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get menu => '菜单';

  @override
  String get detail => '详情';

  @override
  String get noContentMessage => '- 空空如也 -';

  @override
  String get noMoreContentTip => '没有更多啦~';

  @override
  String levelLimitMessage(Object level) {
    return '等级 $level 以上用户才能访问';
  }

  @override
  String levelLimitAndCostMessage(Object cost, Object level) {
    return '等级 $level 以上用户才能访问，将消耗 ${cost}G';
  }

  @override
  String get easyRefreshDragText => '下拉刷新';

  @override
  String get easyRefreshArmedText => '松开刷新';

  @override
  String get easyRefreshReadyText => '刷新中...';

  @override
  String get easyRefreshProcessingText => '刷新中...';

  @override
  String get easyRefreshProcessedText => '刷新成功';

  @override
  String get easyRefreshNoMoreText => '没有更多了';

  @override
  String get easyRefreshFailedText => '刷新失败';

  @override
  String get easyRefreshMessageText => '上次刷新时间: %T';

  @override
  String get easyRefreshFooterDragText => '上拉加载更多';

  @override
  String get easyRefreshFooterArmedText => '松开加载更多';

  @override
  String get easyRefreshFooterReadyText => '加载中...';

  @override
  String get easyRefreshFooterProcessingText => '加载中...';

  @override
  String get easyRefreshFooterProcessedText => '加载成功';

  @override
  String get easyRefreshFooterNoMoreText => '没有更多了';

  @override
  String get easyRefreshFooterFailedText => '加载失败';

  @override
  String get easyRefreshFooterMessageText => '上次加载时间: %T';

  @override
  String get startReading => '开始阅读';

  @override
  String costMessage(Object cost) {
    return '购买当前章节将消耗 ${cost}G';
  }

  @override
  String get pay => '支付';

  @override
  String get isPaying => '支付中...';

  @override
  String get coin => '金币';

  @override
  String get fan => '粉丝';

  @override
  String get id => 'ID';

  @override
  String get signIn => '签到';

  @override
  String get hasSignedIn => '已签到';

  @override
  String get license => '开源协议';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get themeMode => '主题模式';

  @override
  String get lightMode => '日间模式';

  @override
  String get dartMode => '夜间模式';

  @override
  String get systemMode => '跟随系统';

  @override
  String get themeColor => '主题颜色';

  @override
  String get primaryColor => '主色调';

  @override
  String get wheelColor => '自定义';

  @override
  String get reset => '重置';

  @override
  String get collapse => '折叠';

  @override
  String get expand => '展开';

  @override
  String get logout => '登出';

  @override
  String get logoutPrompt => '将清除本地存储的数据，包括但不限于登录信息和历史记录，确定要退出登录吗?';

  @override
  String get about => '关于';

  @override
  String get currentVersion => '当前版本';

  @override
  String get projectHomepage => '项目主页';

  @override
  String get websiteHomepage => '网站主页';

  @override
  String get copied => '已复制';

  @override
  String get fontSize => '字体大小';

  @override
  String get switchAccounts => '切换账号';

  @override
  String get addAnAccount => '添加账号';

  @override
  String get novelComments => '小说评论';

  @override
  String get chapterComments => '章节评论';

  @override
  String get reply => '回复';

  @override
  String viewMoreReplies(Object count) {
    return '查看更多回复 ($count)';
  }

  @override
  String get jumpTo => '跳转到';

  @override
  String get sortMode => '排序方式';

  @override
  String get sortDefault => '默认';

  @override
  String get recentlyRead => '最近阅读';

  @override
  String get sortByName => '名称';

  @override
  String get sortByWordCount => '字数';

  @override
  String get sortAscending => '正序';

  @override
  String get sortDescending => '倒序';

  @override
  String get manualSort => '调整排序';

  @override
  String get wallet => '钱包';

  @override
  String get moreActions => '更多';

  @override
  String get batchManagement => '批量管理';

  @override
  String get removeFromFavorites => '移除收藏';

  @override
  String get selectAll => '全选';

  @override
  String get shrinkEmptyLines => '空行缩小';
}

/// The translations for Chinese, as used in Hong Kong, using the Han script (`zh_Hant_HK`).
class AppLocalizationsZhHantHk extends AppLocalizationsZh {
  AppLocalizationsZhHantHk(): super('zh_Hant_HK');

  @override
  String get backgroundColor => '背景顏色';

  @override
  String get pageTurnMode => '翻頁模式';

  @override
  String get pageTurnSlide => '平移';

  @override
  String get pageTurnNone => '無動畫';

  @override
  String get chapterEndHint => '本章完，點擊進入下一章';

  @override
  String get contents => '目錄';

  @override
  String totalChapters(int count) {
    return '共${count}話';
  }

  @override
  String get commentShort => '章評';

  @override
  String get indentMode => '縮進模式';

  @override
  String get indentNone => '無';

  @override
  String get indentOne => '1格';

  @override
  String get indentTwo => '2格';

  @override
  String get addToBookshelf => '加入書架';

  @override
  String get inBookshelf => '已在書架';

  @override
  String get exitAppHint => '再滑一次退出應用';

  @override
  String get gridView => '宮格視圖';

  @override
  String get listView => '列表視圖';

  @override
  String unreadChapters(int count) {
    return '${count}話未讀';
  }

  @override
  String get home => '发现';

  @override
  String get favorites => '收藏';

  @override
  String get settings => '设置';

  @override
  String get more => '我的';

  @override
  String get showWindow => '显示窗口';

  @override
  String get hideWindow => '隐藏窗口';

  @override
  String get exit => '退出';

  @override
  String get login => '登录';

  @override
  String get mobilePhoneLoginTip => '请在网页中登录，登录成功后点击右上角按钮关闭当前页面';

  @override
  String get desktopLoginTip => '点击下面按钮将打开本地安装的 Chrome 或 Chromium 浏览器，请手动输入帐号密码进行登录，本软件在检测到登录成功后会自动关闭浏览器';

  @override
  String get chromePath => 'Chrome 或 Chromium 安装位置:';

  @override
  String get chromeNotFound => '未检测到 Chrome 或 Chromium 浏览器';

  @override
  String get author => '作者';

  @override
  String get translator => '翻译';

  @override
  String get status => '状态';

  @override
  String get originalBook => '原作';

  @override
  String get lastUpdated => '最近更新';

  @override
  String get brief => '简介';

  @override
  String get errorTip => '出错啦~';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get menu => '菜单';

  @override
  String get detail => '详情';

  @override
  String get noContentMessage => '- 空空如也 -';

  @override
  String get noMoreContentTip => '没有更多啦~';

  @override
  String levelLimitMessage(Object level) {
    return '等级 $level 以上用户才能访问';
  }

  @override
  String levelLimitAndCostMessage(Object cost, Object level) {
    return '等级 $level 以上用户才能访问，将消耗 ${cost}G';
  }

  @override
  String get easyRefreshDragText => '下拉刷新';

  @override
  String get easyRefreshArmedText => '松开刷新';

  @override
  String get easyRefreshReadyText => '刷新中...';

  @override
  String get easyRefreshProcessingText => '刷新中...';

  @override
  String get easyRefreshProcessedText => '刷新成功';

  @override
  String get easyRefreshNoMoreText => '没有更多了';

  @override
  String get easyRefreshFailedText => '刷新失败';

  @override
  String get easyRefreshMessageText => '上次刷新时间: %T';

  @override
  String get easyRefreshFooterDragText => '上拉加载更多';

  @override
  String get easyRefreshFooterArmedText => '松开加载更多';

  @override
  String get easyRefreshFooterReadyText => '加载中...';

  @override
  String get easyRefreshFooterProcessingText => '加载中...';

  @override
  String get easyRefreshFooterProcessedText => '加载成功';

  @override
  String get easyRefreshFooterNoMoreText => '没有更多了';

  @override
  String get easyRefreshFooterFailedText => '加载失败';

  @override
  String get easyRefreshFooterMessageText => '上次加载时间: %T';

  @override
  String get startReading => '开始阅读';

  @override
  String costMessage(Object cost) {
    return '购买当前章节将消耗 ${cost}G';
  }

  @override
  String get pay => '支付';

  @override
  String get isPaying => '支付中...';

  @override
  String get coin => '金币';

  @override
  String get fan => '粉丝';

  @override
  String get id => 'ID';

  @override
  String get signIn => '签到';

  @override
  String get hasSignedIn => '已签到';

  @override
  String get license => '开源协议';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get themeMode => '主题模式';

  @override
  String get lightMode => '日间模式';

  @override
  String get dartMode => '夜间模式';

  @override
  String get systemMode => '跟随系统';

  @override
  String get themeColor => '主题颜色';

  @override
  String get primaryColor => '主色调';

  @override
  String get wheelColor => '自定义';

  @override
  String get reset => '重置';

  @override
  String get collapse => '折叠';

  @override
  String get expand => '展开';

  @override
  String get logout => '登出';

  @override
  String get logoutPrompt => '将清除本地存储的数据，包括但不限于登录信息和历史记录，确定要退出登录吗?';

  @override
  String get about => '关于';

  @override
  String get currentVersion => '当前版本';

  @override
  String get projectHomepage => '项目主页';

  @override
  String get websiteHomepage => '网站主页';

  @override
  String get copied => '已复制';

  @override
  String get fontSize => '字体大小';

  @override
  String get switchAccounts => '切换账号';

  @override
  String get addAnAccount => '添加账号';

  @override
  String get novelComments => '小说评论';

  @override
  String get chapterComments => '章节评论';

  @override
  String get reply => '回复';

  @override
  String viewMoreReplies(Object count) {
    return '查看更多回复 ($count)';
  }

  @override
  String get jumpTo => '跳转到';

  @override
  String get sortMode => '排序方式';

  @override
  String get sortDefault => '默认';

  @override
  String get recentlyRead => '最近阅读';

  @override
  String get sortByName => '名称';

  @override
  String get sortByWordCount => '字数';

  @override
  String get sortAscending => '正序';

  @override
  String get sortDescending => '倒序';

  @override
  String get manualSort => '调整排序';

  @override
  String get wallet => '錢包';

  @override
  String get selectAll => '全選';

  @override
  String get shrinkEmptyLines => '空行縮小';
}

/// The translations for Chinese, as used in Taiwan, using the Han script (`zh_Hant_TW`).
class AppLocalizationsZhHantTw extends AppLocalizationsZh {
  AppLocalizationsZhHantTw(): super('zh_Hant_TW');

  @override
  String get backgroundColor => '背景顏色';

  @override
  String get pageTurnMode => '翻頁模式';

  @override
  String get pageTurnSlide => '平移';

  @override
  String get pageTurnNone => '無動畫';

  @override
  String get chapterEndHint => '本章完，點擊進入下一章';

  @override
  String get contents => '目錄';

  @override
  String totalChapters(int count) {
    return '共${count}話';
  }

  @override
  String get commentShort => '章評';

  @override
  String get indentMode => '縮進模式';

  @override
  String get indentNone => '無';

  @override
  String get indentOne => '1格';

  @override
  String get indentTwo => '2格';

  @override
  String get addToBookshelf => '加入書架';

  @override
  String get inBookshelf => '已在書架';

  @override
  String get exitAppHint => '再滑一次退出應用';

  @override
  String get gridView => '宮格視圖';

  @override
  String get listView => '列表視圖';

  @override
  String unreadChapters(int count) {
    return '${count}話未讀';
  }

  @override
  String get home => '发现';

  @override
  String get favorites => '收藏';

  @override
  String get settings => '设置';

  @override
  String get more => '我的';

  @override
  String get showWindow => '显示窗口';

  @override
  String get hideWindow => '隐藏窗口';

  @override
  String get exit => '退出';

  @override
  String get login => '登录';

  @override
  String get mobilePhoneLoginTip => '请在网页中登录，登录成功后点击右上角按钮关闭当前页面';

  @override
  String get desktopLoginTip => '点击下面按钮将打开本地安装的 Chrome 或 Chromium 浏览器，请手动输入帐号密码进行登录，本软件在检测到登录成功后会自动关闭浏览器';

  @override
  String get chromePath => 'Chrome 或 Chromium 安装位置:';

  @override
  String get chromeNotFound => '未检测到 Chrome 或 Chromium 浏览器';

  @override
  String get author => '作者';

  @override
  String get translator => '翻译';

  @override
  String get status => '状态';

  @override
  String get originalBook => '原作';

  @override
  String get lastUpdated => '最近更新';

  @override
  String get brief => '简介';

  @override
  String get errorTip => '出错啦~';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get menu => '菜单';

  @override
  String get detail => '详情';

  @override
  String get noContentMessage => '- 空空如也 -';

  @override
  String get noMoreContentTip => '没有更多啦~';

  @override
  String levelLimitMessage(Object level) {
    return '等级 $level 以上用户才能访问';
  }

  @override
  String levelLimitAndCostMessage(Object cost, Object level) {
    return '等级 $level 以上用户才能访问，将消耗 ${cost}G';
  }

  @override
  String get easyRefreshDragText => '下拉刷新';

  @override
  String get easyRefreshArmedText => '松开刷新';

  @override
  String get easyRefreshReadyText => '刷新中...';

  @override
  String get easyRefreshProcessingText => '刷新中...';

  @override
  String get easyRefreshProcessedText => '刷新成功';

  @override
  String get easyRefreshNoMoreText => '没有更多了';

  @override
  String get easyRefreshFailedText => '刷新失败';

  @override
  String get easyRefreshMessageText => '上次刷新时间: %T';

  @override
  String get easyRefreshFooterDragText => '上拉加载更多';

  @override
  String get easyRefreshFooterArmedText => '松开加载更多';

  @override
  String get easyRefreshFooterReadyText => '加载中...';

  @override
  String get easyRefreshFooterProcessingText => '加载中...';

  @override
  String get easyRefreshFooterProcessedText => '加载成功';

  @override
  String get easyRefreshFooterNoMoreText => '没有更多了';

  @override
  String get easyRefreshFooterFailedText => '加载失败';

  @override
  String get easyRefreshFooterMessageText => '上次加载时间: %T';

  @override
  String get startReading => '开始阅读';

  @override
  String costMessage(Object cost) {
    return '购买当前章节将消耗 ${cost}G';
  }

  @override
  String get pay => '支付';

  @override
  String get isPaying => '支付中...';

  @override
  String get coin => '金币';

  @override
  String get fan => '粉丝';

  @override
  String get id => 'ID';

  @override
  String get signIn => '签到';

  @override
  String get hasSignedIn => '已签到';

  @override
  String get license => '开源协议';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get themeMode => '主题模式';

  @override
  String get lightMode => '日间模式';

  @override
  String get dartMode => '夜间模式';

  @override
  String get systemMode => '跟随系统';

  @override
  String get themeColor => '主题颜色';

  @override
  String get primaryColor => '主色调';

  @override
  String get wheelColor => '自定义';

  @override
  String get reset => '重置';

  @override
  String get collapse => '折叠';

  @override
  String get expand => '展开';

  @override
  String get logout => '登出';

  @override
  String get logoutPrompt => '将清除本地存储的数据，包括但不限于登录信息和历史记录，确定要退出登录吗?';

  @override
  String get about => '关于';

  @override
  String get currentVersion => '当前版本';

  @override
  String get projectHomepage => '项目主页';

  @override
  String get websiteHomepage => '网站主页';

  @override
  String get copied => '已复制';

  @override
  String get fontSize => '字体大小';

  @override
  String get switchAccounts => '切换账号';

  @override
  String get addAnAccount => '添加账号';

  @override
  String get novelComments => '小说评论';

  @override
  String get chapterComments => '章节评论';

  @override
  String get reply => '回复';

  @override
  String viewMoreReplies(Object count) {
    return '查看更多回复 ($count)';
  }

  @override
  String get jumpTo => '跳转到';

  @override
  String get sortMode => '排序方式';

  @override
  String get sortDefault => '默认';

  @override
  String get recentlyRead => '最近阅读';

  @override
  String get sortByName => '名称';

  @override
  String get sortByWordCount => '字数';

  @override
  String get sortAscending => '正序';

  @override
  String get sortDescending => '倒序';

  @override
  String get manualSort => '调整排序';

  @override
  String get wallet => '錢包';

  @override
  String get selectAll => '全選';

  @override
  String get shrinkEmptyLines => '空行縮小';
}
