import { getStringSync, putString } from '../service/Cache';
import { PREF_KEY_BASE_URL, PREF_KEY_TOKEN } from '../model/AppConfig';
import { fetchAgenda, ApiResult } from '../service/AgendaApi';
import { AgendaEvent } from '../model/AgendaEvent';
import { ApiFailure } from '../service/ApiError';

@Entry
@Component
struct SettingsPage {
  @State baseUrl: string = '';
  @State token: string = '';
  @State savedHint: string = '';
  @State testHint: string = '';

  aboutToAppear(): void {
    const savedUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    const savedToken: string | undefined = getStringSync(PREF_KEY_TOKEN);
    if (savedUrl !== undefined) {
      this.baseUrl = savedUrl;
    }
    if (savedToken !== undefined) {
      this.token = savedToken;
    }
  }

  build(): void {
    Column() {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .height(32)
          .padding({ left: 14, right: 14 })
          .onClick((): void => {
            this.getUIContext().getRouter().back();
          });
        Blank();
        Text('配对')
          .fontSize(18)
          .fontWeight(FontWeight.Medium);
        Blank();
        Column().width(60);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('sys.color.ohos_id_color_background'));

      Scroll() {
        Column() {
          Text('桌面地址')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 16, bottom: 6 });
          TextInput({ placeholder: '如 http://192.168.1.8:8787', text: this.baseUrl })
            .width('100%')
            .height(44)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
            .onChange((value: string): void => {
              this.baseUrl = value;
            });

          Text('会话令牌')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 16, bottom: 6 });
          TextInput({ placeholder: 'X-Vaelis-Session-Token 的值', text: this.token })
            .width('100%')
            .height(44)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
            .type(InputType.Password)
            .onChange((value: string): void => {
              this.token = value;
            });

          Row() {
            Button('保存')
              .type(ButtonType.Capsule)
              .height(36)
              .padding({ left: 18, right: 18 })
              .backgroundColor('#1A8C4A')
              .fontColor('#FFFFFF')
              .onClick((): void => {
                void this.save();
              });
            Button('测试连接')
              .type(ButtonType.Capsule)
              .height(36)
              .padding({ left: 18, right: 18 })
              .margin({ left: 12 })
              .onClick((): void => {
                void this.testConnection();
              });
          }
          .margin({ top: 20 })
          .justifyContent(FlexAlign.Start);

          if (this.savedHint.length > 0) {
            Text(this.savedHint)
              .fontSize(13)
              .fontColor('#1A8C4A')
              .margin({ top: 12 });
          }
          if (this.testHint.length > 0) {
            Text(this.testHint)
              .fontSize(13)
              .fontColor('#7A5A18')
              .margin({ top: 12 });
          }

          Text('说明')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 32, bottom: 8 })
            .width('100%');
          Text('· 平板需要和 Windows 桌面在同一局域网内。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%');
          Text('· 桌面 Vaelis 启动后，监听 0.0.0.0:8787（参见 H1-API-HARDEN 任务书）。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 4 });
          Text('· 令牌可在桌面设置里复制，下次冷启动会自动填入。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 4 });

          Column().height(40);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 });
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
  }

  private async save(): Promise<void> {
    const url: string = this.baseUrl.trim();
    const tok: string = this.token.trim();
    if (url.length === 0 || tok.length === 0) {
      this.savedHint = '地址和令牌都不能为空';
      return;
    }
    await putString(PREF_KEY_BASE_URL, url);
    await putString(PREF_KEY_TOKEN, tok);
    this.savedHint = '已保存';
  }

  private async testConnection(): Promise<void> {
    const url: string = this.baseUrl.trim();
    const tok: string = this.token.trim();
    if (url.length === 0 || tok.length === 0) {
      this.testHint = '先填地址和令牌';
      return;
    }
    const res: ApiResult<AgendaEvent[]> = await fetchAgenda(url, tok, '2999-01-01', '2999-01-02');
    if (res.ok) {
      this.testHint = '连接 OK · status=' + String(res.status);
      return;
    }
    if (res.failure !== undefined) {
      const f: ApiFailure = res.failure;
      this.testHint = f.short + ' · ' + f.hint;
      return;
    }
    this.testHint = '连接失败 · HTTP ' + String(res.status);
  }
}
