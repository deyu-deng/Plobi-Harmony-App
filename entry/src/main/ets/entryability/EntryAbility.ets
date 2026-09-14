import UIAbility from '@ohos.app.ability.UIAbility';
import { AbilityConstant, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initCache } from '../service/Cache';
import { ensureNotificationEnabled } from '../service/ReminderService';

const TAG: string = 'VaelisEntry';
const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err: Error): void => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: ' + err.message);
        return;
      }
      hilog.info(DOMAIN, TAG, 'loadContent ok');
    });

    initCache(this.context).then((): void => {
      hilog.info(DOMAIN, TAG, 'cache initialised');
    }).catch((err: Error): void => {
      hilog.warn(DOMAIN, TAG, 'cache init failed: ' + err.message);
    });

    ensureNotificationEnabled().then((ok: boolean): void => {
      hilog.info(DOMAIN, TAG, 'notification enabled=' + String(ok));
    });
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
