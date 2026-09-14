import { AgendaEvent } from '../model/AgendaEvent';
import { formatEventLine, formatHHmm } from '../utils/TimeFormat';

@Component
export struct EventCard {
  @Prop event: AgendaEvent;
  @State isExpanded: boolean = false;
  confirmAction: () => void = (): void => {};
  dismissAction: () => void = (): void => {};

  build(): void {
    Column() {
      Row() {
        Column() {
          Text(this.event.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(formatEventLine('', this.event.start_at, this.event.end_at))
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(this.event.kind)
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.isExpanded) {
        Row() {
          Text('开始 ' + formatHHmm(this.event.start_at))
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
          Text('  ·  状态 ' + this.event.status)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
        }
        .margin({ top: 8 });

        Row() {
          Button('确认')
            .type(ButtonType.Capsule)
            .backgroundColor('#1A8C4A')
            .fontColor('#FFFFFF')
            .height(36)
            .padding({ left: 16, right: 16 })
            .onClick((): void => {
              this.confirmAction();
            });
          Button('忽略')
            .type(ButtonType.Capsule)
            .backgroundColor('#A33A2A')
            .fontColor('#FFFFFF')
            .height(36)
            .padding({ left: 16, right: 16 })
            .margin({ left: 12 })
            .onClick((): void => {
              this.dismissAction();
            });
        }
        .margin({ top: 12 })
        .justifyContent(FlexAlign.Start);
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor($r('sys.color.ohos_id_color_card_background'))
    .margin({ bottom: 8 })
    .onClick((): void => {
      this.isExpanded = !this.isExpanded;
    });
  }
}
