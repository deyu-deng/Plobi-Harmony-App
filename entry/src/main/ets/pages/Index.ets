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
import { TimelineRow, buildTimeline, markNow, kindLabel } from '../service/Timeline';

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

  private scheduledReminders: ScheduledReminder[] = [];

  aboutToAppear(): void {
    this.loadFromCache();
  }

  private loadFromCache(): void {
    const eventsJson: string | undefined = getStringSync(PREF_KEY_CACHED_EVENTS);
    if (eventsJson !== undefined) {
      const parsed: ParsedEvents = parseEventsJson(eventsJson);
      this.todayEvents = parsed.today;
      this.tomorrowEvents = parsed.tomorrow;
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
    this.rebuildTimeline();
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
        if (this.conflicts.length > 0) {
          this.conflictChip();
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

  @Builder
  conflictChip(): void {
    Row() {
      Text('今日有 ' + String(this.conflicts.length) + ' 段时间冲突，详见桌面')
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
    const eventsPromise: Promise<ApiResult<AgendaEvent[]>> = fetchAgenda(baseUrl, token, today, tomorrow);
    const pendingPromise: Promise<ApiResult<AgendaEvent[]>> = fetchPending(baseUrl, token);
    const dayPromise: Promise<ApiResult<DayPayload>> = fetchDay(baseUrl, token, today);
    const eventsRes: ApiResult<AgendaEvent[]> = await eventsPromise;
    const pendingRes: ApiResult<AgendaEvent[]> = await pendingPromise;
    const dayRes: ApiResult<DayPayload> = await dayPromise;
    if (!eventsRes.ok) {
      this.applyApiFailure('拉取清单', eventsRes);
      this.isRefreshing = false;
      return;
    }
    if (!pendingRes.ok) {
      this.applyApiFailure('拉取待确认', pendingRes);
      this.isRefreshing = false;
      return;
    }
    const all: AgendaEvent[] = eventsRes.data ?? [];
    const todayList: AgendaEvent[] = filterByDate(all, today);
    const tomorrowList: AgendaEvent[] = filterByDate(all, tomorrow);
    this.todayEvents = todayList;
    this.tomorrowEvents = tomorrowList;
    this.pendingEvents = pendingRes.data ?? [];
    if (dayRes.ok && dayRes.data !== undefined) {
      this.anchors = dayRes.data.anchors;
      this.planItems = dayRes.data.plan_items;
      this.conflicts = dayRes.data.conflicts;
      await putString(PREF_KEY_CACHED_DAY, JSON.stringify(dayRes.data));
    } else {
      this.anchors = [];
      this.planItems = [];
      this.conflicts = [];
      await putString(PREF_KEY_CACHED_DAY, '');
    }
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
    this.isRefreshing = false;
    void this.reschedule(todayList.concat(tomorrowList));
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

interface ParsedEvents {
  today: AgendaEvent[];
  tomorrow: AgendaEvent[];
}

function parseEventsJson(raw: string): ParsedEvents {
  try {
    const obj: Object = JSON.parse(raw) as Object;
    if (!Array.isArray(obj)) {
      return { today: [], tomorrow: [] };
    }
    const arr: Object[] = obj as Object[];
    const today: string = todayLocalIso();
    const tomorrow: string = tomorrowLocalIso();
    const todayList: AgendaEvent[] = [];
    const tomorrowList: AgendaEvent[] = [];
    for (let i: number = 0; i < arr.length; i++) {
      const e: AgendaEvent = arr[i] as AgendaEvent;
      const d: string = e.start_at.slice(0, 10);
      if (d === today) {
        todayList.push(e);
      } else if (d === tomorrow) {
        tomorrowList.push(e);
      }
    }
    return { today: todayList, tomorrow: tomorrowList };
  } catch (e) {
    return { today: [], tomorrow: [] };
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