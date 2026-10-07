import { getStringSync, putString } from '../service/Cache';
import {
  PREF_KEY_BASE_URL,
  PREF_KEY_TOKEN,
  PREF_KEY_DEVICE_ID,
  PREF_KEY_DEVICE_NAME,
  DEFAULT_DEVICE_NAME,
} from '../model/AppConfig';
import {
  redeemPairCode,
  fetchServerStatus,
  isSixDigitCode,
  resolveDeviceName,
  isValidDeviceName,
  PairResult,
} from '../service/PairingApi';
import { ApiResult } from '../service/HttpKit';
import { ApiFailure } from '../service/ApiError';

/**
 * 配对设置页：未配对态用 6 位配对码换设备令牌；已配对态可测试连接、解除配对。
 * 纪律：设备令牌与配对码不写日志；配对锁定（429）期间不做自动重试。
 */
@Entry
@Component
struct SettingsPage {
  @State baseUrl: string = '';
  @State pairCode: string = '';
  @State deviceName: string = '';
  @State isPairing: boolean = false;
  @State isPaired: boolean = false;
  @State pairedDeviceName: string = DEFAULT_DEVICE_NAME;
  @State pairHint: string = '';
  @State testHint: string = '';

  aboutToAppear(): void {
    const savedUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    if (savedUrl !== undefined) {
      this.baseUrl = savedUrl;
    }
    const savedDeviceName: string | undefined = getStringSync(PREF_KEY_DEVICE_NAME);
    if (savedDeviceName !== undefined) {
      this.deviceName = savedDeviceName;
    }
    this.isPaired = getStringSync(PREF_KEY_TOKEN) !== undefined;
    this.pairedDeviceName = savedDeviceName !== undefined ? savedDeviceName : DEFAULT_DEVICE_NAME;
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
          if (this.isPaired) {
            this.pairedView();
          } else {
            this.pairingForm();
          }

          if (this.pairHint.length > 0) {
            Text(this.pairHint)
              .fontSize(13)
              .fontColor('#7A5A18')
              .width('100%')
              .margin({ top: 12 });
          }
          if (this.testHint.length > 0) {
            Text(this.testHint)
              .fontSize(13)
              .fontColor('#7A5A18')
              .width('100%')
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
          Text('· 在桌面 PAIRING 页点「新码」获得 6 位配对码，5 分钟内有效且只能用一次。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 4 });
          Text('· 配对码连错太多次会被暂时锁定，锁定期间不会自动重试。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 4 });
          Text('· 配对成功后设备令牌自动保存，下次冷启动无需重新配对。')
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

  @Builder
  pairingForm(): void {
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

      Text('配对码')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ top: 16, bottom: 6 });
      TextInput({ placeholder: '桌面 PAIRING 页「新码」给出的 6 位数字', text: this.pairCode })
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .type(InputType.Number)
        .onChange((value: string): void => {
          this.pairCode = value;
        });

      Text('设备名（可选）')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ top: 16, bottom: 6 });
      TextInput({ placeholder: '默认「' + DEFAULT_DEVICE_NAME + '」', text: this.deviceName })
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .onChange((value: string): void => {
          this.deviceName = value;
        });

      Row() {
        Button('配对')
          .type(ButtonType.Capsule)
          .height(36)
          .padding({ left: 18, right: 18 })
          .backgroundColor('#1A8C4A')
          .fontColor('#FFFFFF')
          .enabled(!this.isPairing)
          .onClick((): void => {
            void this.doPair();
          });
        Button('测试连接')
          .type(ButtonType.Capsule)
          .height(36)
          .padding({ left: 18, right: 18 })
          .margin({ left: 12 })
          .onClick((): void => {
            void this.doTestConnection();
          });
      }
      .margin({ top: 20 })
      .justifyContent(FlexAlign.Start);
    }
    .width('100%');
  }

  @Builder
  pairedView(): void {
    Column() {
      Text('已配对 · ' + this.pairedDeviceName)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A8C4A')
        .width('100%')
        .margin({ top: 20 });
      Row() {
        Button('测试连接')
          .type(ButtonType.Capsule)
          .height(36)
          .padding({ left: 18, right: 18 })
          .onClick((): void => {
            void this.doTestConnection();
          });
        Button('解除配对')
          .type(ButtonType.Capsule)
          .height(36)
          .padding({ left: 18, right: 18 })
          .margin({ left: 12 })
          .backgroundColor('#A33A2A')
          .fontColor('#FFFFFF')
          .onClick((): void => {
            void this.doUnpair();
          });
      }
      .margin({ top: 16 })
      .justifyContent(FlexAlign.Start);
    }
    .width('100%');
  }

  private async doPair(): Promise<void> {
    if (this.isPairing) {
      return;
    }
    const url: string = this.baseUrl.trim();
    if (url.length === 0) {
      this.pairHint = '桌面地址不能为空';
      return;
    }
    await putString(PREF_KEY_BASE_URL, url);
    const code: string = this.pairCode.trim();
    if (!isSixDigitCode(code)) {
      this.pairHint = '配对码是 6 位数字';
      return;
    }
    if (!isValidDeviceName(this.deviceName)) {
      this.pairHint = '设备名最长 64 字';
      return;
    }
    const name: string = resolveDeviceName(this.deviceName);
    this.isPairing = true;
    const res: PairResult = await redeemPairCode(url, code, name);
    this.isPairing = false;
    if (res.ok && res.token !== undefined && res.deviceId !== undefined) {
      await putString(PREF_KEY_TOKEN, res.token);
      await putString(PREF_KEY_DEVICE_ID, res.deviceId);
      await putString(PREF_KEY_DEVICE_NAME, name);
      this.isPaired = true;
      this.pairedDeviceName = name;
      this.pairCode = '';
      this.pairHint = '';
      return;
    }
    if (res.failure !== undefined) {
      const f: ApiFailure = res.failure;
      this.pairHint = f.short + ' · ' + f.hint;
      return;
    }
    this.pairHint = '配对失败 · 请稍后重试';
  }

  private async doTestConnection(): Promise<void> {
    const url: string = this.baseUrl.trim();
    if (url.length === 0) {
      this.testHint = '先填桌面地址';
      return;
    }
    await putString(PREF_KEY_BASE_URL, url);
    const res: ApiResult<Object> = await fetchServerStatus(url);
    if (res.ok) {
      this.testHint = '桌面在线';
      return;
    }
    if (res.failure !== undefined) {
      const f: ApiFailure = res.failure;
      this.testHint = f.short + ' · ' + f.hint;
      return;
    }
    this.testHint = '连接失败 · HTTP ' + String(res.status);
  }

  private async doUnpair(): Promise<void> {
    await putString(PREF_KEY_TOKEN, '');
    await putString(PREF_KEY_DEVICE_ID, '');
    await putString(PREF_KEY_DEVICE_NAME, '');
    this.isPaired = false;
    this.pairedDeviceName = DEFAULT_DEVICE_NAME;
    this.deviceName = '';
    this.pairCode = '';
    this.pairHint = '已解除配对';
  }
}
