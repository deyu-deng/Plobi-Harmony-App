import { AgendaEvent, Anchor, PlanItem, ConflictPair, DayPayload } from '../model/AgendaEvent';
import { EventCard } from '../components/EventCard';
import { fetchAgenda, fetchPending, fetchDay, postDecide, ApiResult, DecideResponse } from '../service/AgendaApi';
import { ApiFailure } from '../service/ApiError';
import { getStringSync, putString, putNumber } from '../service/Cache';
import {
  PREF_KEY_BASE_URL,
  PREF_KEY_CACHED_EVENTS,
  PREF_KEY_CACHED_PENDING,
  PREF_KEY_CACHED_DAY,
  PREF_KEY_LAST_SYNC,
  PREF_KEY_TOKEN,
  PREF_KEY_API_VERSION,
} from '../model/AppConfig';
import { ensureNotificationEnabled, rescheduleReminders, ScheduledReminder } from '../service/ReminderService';
import { todayLocalIso, tomorrowLocalIso } from '../utils/LocalDate';
import { formatTimeRange, formatLocalNowHHmm } from '../utils/TimeFormat';
import { parseDayPayload } from '../service/DayParser';
import { TimelineRow, buildTimeline, markNow, kindLabel, mergeDay } from '../service/Timeline';
import {
  WeekColumn as WeekColumnData,
  buildWeekColumns,
  weekDaysFromMonday,
  mondayOfLocalDay,
  DAYS_PER_WEEK,
} from '../service/WeekView';
import { WeekColumn } from '../components/WeekColumn';

@Entry
@Component
struct Index {
  @State todayEvents: AgendaEvent[] = [];
  @State tomorrowEvents: AgendaEvent[] = [];
  @State pendingEvents: AgendaEvent[] = [];
  @State anchors: Anchor[] = [];
  @State planItems: PlanItem[] = [];
  @State conflicts: ConflictPair[] = [];
  @State todayRows: TimelineRow[] = [];
  @State tomorrowRows: TimelineRow[] = [];
  @State lastSyncText: string = '从未同步';
  @State reminderNotice: string = '';
  @State permissionWarning: string = '';
  @State isRefreshing: boolean = false;
  @State topError: string = '';
  @State topHint: string = '';
  @State versionNotice: string = '';
  @State versionHint: string = '';
  @State weekColumns: WeekColumnData[] = [];
  @State weekLayers: WeekDayLayer[] = [];
  @State selectedDay: string = '';
  @State selectedRows: TimelineRow[] = [];
  @State selectedConflicts: ConflictPair[] = [];
  @State selectedDegrade: string = '';
  @State selectedPendingCount: number = 0;

  private scheduledReminders: ScheduledReminder[] = [];
  /** 本周区间（周一→周日）拉回的已确认事件；周桶与提醒重排的数据源。 */
  private weekConfirmedEvents: AgendaEvent[] = [];

  aboutToAppear(): void {
    this.loadFromCache();
  }

  private loadFromCache(): void {
    const today: string = todayLocalIso();
    const tomorrow: string = tomorrowLocalIso();
    const eventsJson: string | undefined = getStringSync(PREF_KEY_CACHED_EVENTS);
    if (eventsJson !== undefined) {
      const all: AgendaEvent[] = parseEventsJson(eventsJson);
      this.weekConfirmedEvents = all;
      this.todayEvents = filterByDate(all, today);
      this.tomorrowEvents = filterByDate(all, tomorrow);
    }
    const pendingJson: string | undefined = getStringSync(PREF_KEY_CACHED_PENDING);
    if (pendingJson !== undefined) {
      this.pendingEvents = parsePendingJson(pendingJson);
    }
    const dayJson: string | undefined = getStringSync(PREF_KEY_CACHED_DAY);
    if (dayJson !== undefined) {
      const day: DayPayload = parseDayPayload(dayJson);
      this.anchors = day.anchors;
      this.planItems = day.plan_items;
      this.conflicts = day.conflicts;
    }
    const last: string | undefined = getStringSync(PREF_KEY_LAST_SYNC);
    if (last !== undefined) {
      this.lastSyncText = '上次同步 ' + last;
    }
    this.rebuildWeekColumns();
    this.initWeekLayers();
    this.rebuildTimeline();
  }

  /** 周桶 = 本周已确认事件 + 全量待确认（本地按日期过滤，前提 2 允许），一次构建，T4 不新增缓存键。 */
  private rebuildWeekColumns(): void {
    const combined: AgendaEvent[] = this.weekConfirmedEvents.concat(this.pendingEvents);
    const bucket = buildWeekColumns(combined, todayLocalIso());
    this.weekColumns = bucket.columns;
    if (this.selectedDay.length > 0) {
      this.rebuildSelectedDetail();
    }
  }

  /** 冲突/避让层：先全部置空，今日层用现有缓存数据（若有），刷新时按 D1 渐进替换。 */
  private initWeekLayers(): void {
    const layers: WeekDayLayer[] = [];
    for (let i: number = 0; i < DAYS_PER_WEEK; i++) {
      layers.push(emptyWeekDayLayer());
    }
    const todayIdx: number = this.indexOfWeekDay(todayLocalIso());
    if (todayIdx >= 0) {
      const todayLayer: WeekDayLayer = {
        'anchors': this.anchors,
        'plans': this.planItems,
        'conflicts': this.conflicts,
        'degrade': '',
      };
      layers[todayIdx] = todayLayer;
    }
    this.weekLayers = layers;
  }

  private indexOfWeekDay(dayIso: string): number {
    for (let i: number = 0; i < this.weekColumns.length; i++) {
      if (this.weekColumns[i].dateIso === dayIso) {
        return i;
      }
    }
    return -1;
  }

  private layerConflictsCount(idx: number): number {
    if (idx >= 0 && idx < this.weekLayers.length) {
      return this.weekLayers[idx].conflicts.length;
    }
    return 0;
  }

  private layerDegradeText(idx: number): string {
    if (idx >= 0 && idx < this.weekLayers.length) {
      return this.weekLayers[idx].degrade;
    }
    return '';
  }

  /** 点某天进当日详情（复用现有渲染，任务书 §T2）；再点同一天 = 回到本周总览。 */
  private selectDay(dateIso: string): void {
    if (this.selectedDay === dateIso) {
      this.clearSelectedDay();
      return;
    }
    this.selectedDay = dateIso;
    this.rebuildSelectedDetail();
  }

  private clearSelectedDay(): void {
    this.selectedDay = '';
    this.selectedRows = [];
    this.selectedConflicts = [];
    this.selectedDegrade = '';
    this.selectedPendingCount = 0;
  }

  private rebuildSelectedDetail(): void {
    if (this.selectedDay.length === 0) {
      return;
    }
    const idx: number = this.indexOfWeekDay(this.selectedDay);
    if (idx < 0) {
      this.clearSelectedDay();
      return;
    }
    const col: WeekColumnData = this.weekColumns[idx];
    const layer: WeekDayLayer = idx < this.weekLayers.length ? this.weekLayers[idx] : emptyWeekDayLayer();
    const rows: TimelineRow[] = mergeDay(col.events, layer.anchors, layer.plans);
    this.selectedRows = markNow(rows, Date.now());
    this.selectedConflicts = layer.conflicts;
    this.selectedDegrade = layer.degrade;
    this.selectedPendingCount = col.pending.length;
  }

  private selectedDayTitle(): string {
    const idx: number = this.indexOfWeekDay(this.selectedDay);
    if (idx < 0) {
      return this.selectedDay;
    }
    const di: number = this.weekColumns[idx].dayIndex;
    const wd: string = di >= 0 && di < WEEKDAY_TITLE_LABELS.length ? WEEKDAY_TITLE_LABELS[di] : '';
    return this.selectedDay + ' · ' + wd;
  }

  private rebuildTimeline(): void {
    const tl = buildTimeline({
      'todayEvents': this.todayEvents,
      'anchors': this.anchors,
      'planItems': this.planItems,
      'tomorrowEvents': this.tomorrowEvents,
    });
    this.todayRows = markNow(tl.today, Date.now());
    this.tomorrowRows = tl.tomorrow;
  }

  build(): void {
    Column() {
      this.headerBar();
      this.versionBanner();
      this.errorBanner();
      this.bodyScroll();
      this.footerBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
  }

  @Builder
  headerBar(): void {
    Row() {
      Text('Plobi')
        .fontSize(20)
        .fontWeight(FontWeight.Bold);
      Blank();
      Button('问总秘书')
        .type(ButtonType.Capsule)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
        });
      Button('刷新')
        .type(ButtonType.Capsule)
        .height(32)
        .padding({ left: 14, right: 14 })
        .margin({ left: 8 })
        .enabled(!this.isRefreshing)
        .onClick((): void => {
          void this.refresh();
        });
      Button('设置')
        .type(ButtonType.Capsule)
        .height(32)
        .padding({ left: 14, right: 14 })
        .margin({ left: 8 })
        .onClick((): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
        });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.ohos_id_color_background'));
  }

  @Builder
  errorBanner(): void {
    if (this.topError.length > 0) {
      Column() {
        Row() {
          Text(this.topError)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .layoutWeight(1);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 });
        if (this.topHint.length > 0) {
          Row() {
            Text(this.topHint)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .layoutWeight(1);
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 0, bottom: 8 });
        }
      }
      .width('100%')
      .backgroundColor('#A33A2A');
    }
  }

  @Builder
  versionBanner(): void {
    if (this.versionNotice.length > 0) {
      Column() {
        Row() {
          Text(this.versionNotice)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .layoutWeight(1);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 });
        if (this.versionHint.length > 0) {
          Row() {
            Text(this.versionHint)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .layoutWeight(1);
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 0, bottom: 8 });
        }
      }
      .width('100%')
      .backgroundColor('#7A5A18');
    }
  }

  @Builder
  bodyScroll(): void {
    Scroll() {
      Column() {
        this.weekStrip();

        if (this.selectedDay.length > 0) {
          this.dayDetail();
        } else {
          if (this.conflicts.length > 0) {
            this.conflictChip('今日有 ' + String(this.conflicts.length) + ' 段时间冲突，详见桌面');
          }

          this.sectionTitle('今日');
          if (this.todayRows.length === 0) {
            this.emptyHint('今日没有安排');
          } else {
            ForEach(this.todayRows, (item: TimelineRow): void => {
              this.timelineRow(item);
            }, (item: TimelineRow): string => item.id);
          }

          this.sectionTitle('明日');
          if (this.tomorrowRows.length === 0) {
            this.emptyHint('明日没有安排');
          } else {
            ForEach(this.tomorrowRows, (item: TimelineRow): void => {
              this.timelineRow(item);
            }, (item: TimelineRow): string => 'tomorrow-' + item.id);
          }
        }

        this.sectionTitle('待确认');
        if (this.pendingEvents.length === 0) {
          this.emptyHint('没有待确认的条目');
        } else {
          ForEach(this.pendingEvents, (item: AgendaEvent): void => {
            EventCard({
              event: item,
              confirmAction: (): void => { void this.decide(item, 'confirm'); },
              dismissAction: (): void => { void this.decide(item, 'dismiss'); },
            });
          }, (item: AgendaEvent): string => 'pending-' + item.id);
        }

        Column().height(24);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 });
    }
    .layoutWeight(1)
    .width('100%');
  }

  /** 周条：横向 7 天（D2 = 本周、周一起），冲突层按 D1 渐进补，单列降级不整屏红（C2）。 */
  @Builder
  weekStrip(): void {
    if (this.weekColumns.length > 0) {
      Column() {
        this.sectionTitle('本周');
        Scroll() {
          Row() {
            ForEach(this.weekColumns, (col: WeekColumnData, idx: number): void => {
              WeekColumn({
                column: col,
                conflictsCount: this.layerConflictsCount(idx),
                degradeText: this.layerDegradeText(idx),
                isSelected: this.selectedDay === col.dateIso,
                onDayTap: (d: string): void => {
                  this.selectDay(d);
                },
              });
            }, (col: WeekColumnData): string => col.dateIso);
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%');
      }
      .width('100%');
    }
  }

  /** 选中日详情：返回行 + 该日冲突/降级提示 + 该日时间轴（复用 timelineRow 渲染）。 */
  @Builder
  dayDetail(): void {
    Column() {
      Row() {
        Text('← 回到本周')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .onClick((): void => {
            this.clearSelectedDay();
          });
        Blank();
        Text(this.selectedDayTitle())
          .fontSize(14)
          .fontWeight(FontWeight.Medium);
      }
      .width('100%')
      .margin({ top: 8, bottom: 4 });

      if (this.selectedDegrade.length > 0) {
        Row() {
          Text('该日冲突与避让取不到：' + this.selectedDegrade)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .layoutWeight(1);
        }
        .width('100%')
        .padding(10)
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .margin({ bottom: 8 });
      } else if (this.selectedConflicts.length > 0) {
        this.conflictChip('该日有 ' + String(this.selectedConflicts.length) + ' 段时间冲突，详见桌面');
      }

      if (this.selectedPendingCount > 0) {
        Row() {
          Text('该日待确认 ' + String(this.selectedPendingCount) + ' 条，见下方待确认区')
            .fontSize(12)
            .fontColor('#7A5A18')
            .layoutWeight(1);
        }
        .width('100%')
        .margin({ bottom: 8 });
      }

      if (this.selectedRows.length === 0) {
        this.emptyHint('这天没有安排');
      } else {
        ForEach(this.selectedRows, (item: TimelineRow): void => {
          this.timelineRow(item);
        }, (item: TimelineRow): string => 'detail-' + item.id);
      }
    }
    .width('100%');
  }

  @Builder
  conflictChip(text: string): void {
    Row() {
      Text(text)
        .fontSize(12)
        .fontColor('#7A5A18')
        .layoutWeight(1);
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor('#FBEFD0')
    .margin({ top: 8, bottom: 4 });
  }

  @Builder
  timelineRow(row: TimelineRow): void {
    Row() {
      Column() {
        Row() {
          Text(row.title.length > 0 ? row.title : '（无标题）')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          if (row.isNow) {
            Text('现在')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .backgroundColor('#1A8C4A')
              .margin({ left: 8 });
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
        Text(formatTimeRange(row.start_at, row.end_at))
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 4 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text(kindLabel(row))
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .borderWidth(row.isNow ? 1 : 0)
    .borderColor(row.isNow ? '#1A8C4A' : Color.Transparent)
    .margin({ bottom: 8 });
  }

  @Builder
  sectionTitle(label: string): void {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .margin({ top: 16, bottom: 8 });
  }

  @Builder
  emptyHint(text: string): void {
    Text(text)
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .width('100%')
      .padding(12)
      .borderRadius(8)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .margin({ bottom: 8 });
  }

  @Builder
  footerBar(): void {
    Column() {
      if (this.reminderNotice.length > 0) {
        Text(this.reminderNotice)
          .fontSize(12)
          .fontColor('#7A5A18')
          .width('100%');
      }
      if (this.permissionWarning.length > 0) {
        Text(this.permissionWarning)
          .fontSize(12)
          .fontColor('#7A5A18')
          .width('100%')
          .margin({ top: 4 });
      }
      Text(this.lastSyncText)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .margin({ top: 4 });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.ohos_id_color_background'));
  }

  /**
   * 刷新 = 1× fetchAgenda（周一→周日）+ 1× fetchPending + 7× fetchDay，共 9 个请求并发发出（D1/C1）。
   * 首屏只等前两个：分桶 + 三段列表先渲染；7 个单日快照逐个回来逐列补冲突/避让层，
   * 单日失败只降级那一列（C2），整屏不红。
   */
  private async refresh(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.topError = '';
    this.topHint = '';
    this.versionNotice = '';
    this.versionHint = '';
    const baseUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    const token: string | undefined = getStringSync(PREF_KEY_TOKEN);
    if (baseUrl === undefined || token === undefined || baseUrl.length === 0 || token.length === 0) {
      this.topError = '请先在「设置」里配对';
      this.isRefreshing = false;
      return;
    }
    const today: string = todayLocalIso();
    const tomorrow: string = tomorrowLocalIso();
    const monday: string = mondayOfLocalDay(today);
    const weekDays: string[] = weekDaysFromMonday(monday);
    if (weekDays.length !== DAYS_PER_WEEK) {
      this.topError = '刷新失败：算不出本周';
      this.isRefreshing = false;
      return;
    }
    const eventsPromise: Promise<ApiResult<AgendaEvent[]>> = fetchAgenda(baseUrl, token, monday, weekDays[DAYS_PER_WEEK - 1]);
    const pendingPromise: Promise<ApiResult<AgendaEvent[]>> = fetchPending(baseUrl, token);
    const dayPromises: Array<Promise<ApiResult<DayPayload>>> = [];
    for (let i: number = 0; i < weekDays.length; i++) {
      dayPromises.push(fetchDay(baseUrl, token, weekDays[i]));
    }
    const eventsRes: ApiResult<AgendaEvent[]> = await eventsPromise;
    if (!eventsRes.ok) {
      this.applyApiFailure('拉取清单', eventsRes);
      this.isRefreshing = false;
      return;
    }
    const pendingRes: ApiResult<AgendaEvent[]> = await pendingPromise;
    if (!pendingRes.ok) {
      this.applyApiFailure('拉取待确认', pendingRes);
      this.isRefreshing = false;
      return;
    }
    const all: AgendaEvent[] = eventsRes.data ?? [];
    const todayList: AgendaEvent[] = filterByDate(all, today);
    const tomorrowList: AgendaEvent[] = filterByDate(all, tomorrow);
    this.weekConfirmedEvents = all;
    this.todayEvents = todayList;
    this.tomorrowEvents = tomorrowList;
    this.pendingEvents = pendingRes.data ?? [];
    this.rebuildWeekColumns();
    this.initWeekLayers();
    this.rebuildTimeline();
    const now: string = formatLocalNowHHmm();
    this.lastSyncText = '上次同步 ' + now;
    await putString(PREF_KEY_CACHED_EVENTS, JSON.stringify(all));
    await putString(PREF_KEY_CACHED_PENDING, JSON.stringify(this.pendingEvents));
    await putString(PREF_KEY_LAST_SYNC, now);
    await putNumber(PREF_KEY_API_VERSION, eventsRes.apiVersion ?? 0);
    if (eventsRes.versionNotice !== undefined) {
      this.versionNotice = eventsRes.versionNotice.short;
      this.versionHint = eventsRes.versionNotice.hint;
    }
    for (let i: number = 0; i < dayPromises.length; i++) {
      const dayRes: ApiResult<DayPayload> = await dayPromises[i];
      const layer: WeekDayLayer = emptyWeekDayLayer();
      if (dayRes.ok && dayRes.data !== undefined) {
        layer.anchors = dayRes.data.anchors;
        layer.plans = dayRes.data.plan_items;
        layer.conflicts = dayRes.data.conflicts;
      } else if (dayRes.failure !== undefined) {
        layer.degrade = dayRes.failure.short;
      } else {
        layer.degrade = 'HTTP ' + String(dayRes.status);
      }
      const nextLayers: WeekDayLayer[] = this.weekLayers.slice();
      nextLayers[i] = layer;
      this.weekLayers = nextLayers;
      if (weekDays[i] === today) {
        this.anchors = layer.anchors;
        this.planItems = layer.plans;
        this.conflicts = layer.conflicts;
        this.rebuildTimeline();
        if (layer.degrade.length === 0 && dayRes.data !== undefined) {
          await putString(PREF_KEY_CACHED_DAY, JSON.stringify(dayRes.data));
        } else {
          await putString(PREF_KEY_CACHED_DAY, '');
        }
      }
      if (this.selectedDay === weekDays[i]) {
        this.rebuildSelectedDetail();
      }
    }
    this.isRefreshing = false;
    void this.reschedule(all);
    void this.checkNotificationPermission();
  }

  private applyApiFailure<T>(prefix: string, res: ApiResult<T>): void {
    if (res.failure === undefined) {
      this.topError = prefix + ' 失败：HTTP ' + String(res.status);
      return;
    }
    this.topError = prefix + ' 失败：' + res.failure.short;
    this.topHint = res.failure.hint;
  }

  private async decide(item: AgendaEvent, action: 'confirm' | 'dismiss'): Promise<void> {
    const baseUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    const token: string | undefined = getStringSync(PREF_KEY_TOKEN);
    if (baseUrl === undefined || token === undefined) {
      this.topError = '请先在「设置」里配对';
      return;
    }
    const res: ApiResult<DecideResponse> = await postDecide(baseUrl, token, item.id, action);
    if (!res.ok) {
      this.applyApiFailure('批待确认', res);
      return;
    }
    this.topError = '';
    this.pendingEvents = this.pendingEvents.filter((e: AgendaEvent): boolean => e.id !== item.id);
    await putString(PREF_KEY_CACHED_PENDING, JSON.stringify(this.pendingEvents));
    this.rebuildWeekColumns();
  }

  private async reschedule(all: AgendaEvent[]): Promise<void> {
    const granted: boolean = await ensureNotificationEnabled();
    if (!granted) {
      this.permissionWarning = '课前提醒需要通知权限';
      return;
    }
    this.permissionWarning = '';
    const outcome = await rescheduleReminders(all, this.scheduledReminders, Math.floor(Date.now() / 1000));
    this.scheduledReminders = outcome.scheduled;
    if (outcome.truncated && outcome.reason !== undefined) {
      this.reminderNotice = outcome.reason;
    } else {
      this.reminderNotice = '';
    }
  }

  private async checkNotificationPermission(): Promise<void> {
    const granted: boolean = await ensureNotificationEnabled();
    if (!granted) {
      this.permissionWarning = '课前提醒需要通知权限';
    }
  }
}

/** 一天的冲突/避让层（D1：来自该日 fetchDay 单日快照；degrade 非空 = 该日取不到，C2 单列降级）。 */
interface WeekDayLayer {
  anchors: Anchor[];
  plans: PlanItem[];
  conflicts: ConflictPair[];
  degrade: string;
}

function emptyWeekDayLayer(): WeekDayLayer {
  const layer: WeekDayLayer = {
    'anchors': [],
    'plans': [],
    'conflicts': [],
    'degrade': '',
  };
  return layer;
}

/** 选中日详情的周几标题（dayIndex 0=周一 … 6=周日，与 WeekView 口径一致）。 */
const WEEKDAY_TITLE_LABELS: ReadonlyArray<string> = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

function parseEventsJson(raw: string): AgendaEvent[] {
  try {
    const obj: Object = JSON.parse(raw) as Object;
    if (!Array.isArray(obj)) {
      return [];
    }
    return obj as AgendaEvent[];
  } catch (e) {
    return [];
  }
}

function parsePendingJson(raw: string): AgendaEvent[] {
  try {
    const obj: Object = JSON.parse(raw) as Object;
    if (!Array.isArray(obj)) {
      return [];
    }
    return obj as AgendaEvent[];
  } catch (e) {
    return [];
  }
}

function filterByDate(events: ReadonlyArray<AgendaEvent>, dayIso: string): AgendaEvent[] {
  const out: AgendaEvent[] = [];
  for (let i: number = 0; i < events.length; i++) {
    const e: AgendaEvent = events[i];
    if (e.start_at.slice(0, 10) === dayIso) {
      out.push(e);
    }
  }
  out.sort((a: AgendaEvent, b: AgendaEvent): number => {
    return a.start_at.localeCompare(b.start_at);
  });
  return out;
}