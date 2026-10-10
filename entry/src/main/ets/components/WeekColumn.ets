import { AgendaEvent, kindLabelOf } from '../model/AgendaEvent';
import { formatHHmm } from '../utils/TimeFormat';
import { WeekColumn as WeekColumnData } from '../service/WeekView';

/**
 * 周视图的单列（WP-APP-CALENDAR T2）。
 *
 * 数据来自 service/WeekView 的分桶（T1 纯函数，已有单测）；
 * 冲突数与降级文案来自页面按 D1（7× fetchDay）渐进填充的层。
 * 只读显示：点击整列回调 onDayTap，由 Index 复用现有那屏进当日详情（任务书 §T2）。
 */

/** 列内实际渲染的事件摘要条数（渲染层裁切；数据层不截断，见 WeekView.MAX_EVENTS_PER_DAY 注释）。 */
const SHOWN_EVENTS_PER_COLUMN: number = 6;

/** 列头周几短字（dayIndex 0=周一 … 6=周日，与 WeekView 口径一致）。 */
const WEEKDAY_SHORT_LABELS: ReadonlyArray<string> = ['一', '二', '三', '四', '五', '六', '日'];

@Component
export struct WeekColumn {
  @Prop column: WeekColumnData;
  /** 该日冲突对数（来自桌面单日快照 conflicts；App 不算冲突，specs/handset-app.md §3.1）。 */
  @Prop conflictsCount: number = 0;
  /** 非空 = 该日 fetchDay 失败（C2 单列降级），值为 ApiFailure.short；点击该天可在详情里看全文。 */
  @Prop degradeText: string = '';
  @Prop isSelected: boolean = false;
  onDayTap: (dateIso: string) => void = (_dateIso: string): void => {};

  private dayNumber(): string {
    if (this.column.dateIso.length !== 10) {
      return this.column.dateIso;
    }
    const d: string = this.column.dateIso.substring(8, 10);
    return d.startsWith('0') ? d.substring(1) : d;
  }

  private weekdayShort(): string {
    const di: number = this.column.dayIndex;
    if (di >= 0 && di < WEEKDAY_SHORT_LABELS.length) {
      return WEEKDAY_SHORT_LABELS[di];
    }
    return '';
  }

  private shownEvents(): AgendaEvent[] {
    const total: number = this.column.events.length;
    const n: number = total > SHOWN_EVENTS_PER_COLUMN ? SHOWN_EVENTS_PER_COLUMN : total;
    return this.column.events.slice(0, n);
  }

  private remainingCount(): number {
    const total: number = this.column.events.length;
    return total > SHOWN_EVENTS_PER_COLUMN ? total - SHOWN_EVENTS_PER_COLUMN : 0;
  }

  build(): void {
    Column() {
      Column() {
        Text(this.weekdayShort())
          .fontSize(11)
          .fontColor(this.column.isToday ? $r('sys.color.ohos_id_color_text_secondary') : $r('sys.color.ohos_id_color_text_tertiary'));
        Text(this.dayNumber())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.column.isToday ? '#FFFFFF' : $r('sys.color.ohos_id_color_text_primary'))
          .textAlign(TextAlign.Center)
          .width(28)
          .height(28)
          .borderRadius(14)
          .backgroundColor(this.column.isToday ? '#1A8C4A' : Color.Transparent)
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%');

      if (this.degradeText.length > 0) {
        Text('取不到')
          .fontSize(10)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .margin({ top: 4 });
      } else if (this.conflictsCount > 0) {
        Text('冲突 ' + String(this.conflictsCount))
          .fontSize(10)
          .fontColor('#7A5A18')
          .margin({ top: 4 });
      }

      ForEach(this.shownEvents(), (e: AgendaEvent): void => {
        Row() {
          Text(formatHHmm(e.start_at))
            .fontSize(10)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'));
          Text(e.title.length > 0 ? e.title : '（无标题）')
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 4, right: 4 });
          Text(kindLabelOf(e.kind))
            .fontSize(9)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'));
        }
        .width('100%')
        .margin({ top: 3 });
      }, (e: AgendaEvent): string => e.id)

      if (this.column.pending.length > 0) {
        Text('待确认 ' + String(this.column.pending.length))
          .fontSize(10)
          .fontColor('#7A5A18')
          .margin({ top: 3 });
      }

      if (this.remainingCount() > 0) {
        Text('还有 ' + String(this.remainingCount()) + ' 条')
          .fontSize(10)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .margin({ top: 3 });
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width(112)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor(this.isSelected ? $r('sys.color.ohos_id_color_sub_background') : $r('sys.color.ohos_id_color_card_bg'))
    .opacity(this.column.isPast ? 0.45 : 1)
    .margin({ right: 6 })
    .onClick((): void => {
      this.onDayTap(this.column.dateIso);
    });
  }
}
