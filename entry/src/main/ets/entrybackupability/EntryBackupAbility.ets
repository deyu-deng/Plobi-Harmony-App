import { BackupExtensionAbility } from '@kit.CoreFileKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    // No-op: Vaelis 缓存（Preferences）依赖桌面同步，不参与系统级备份
  }

  async onRestore(): Promise<void> {
    // No-op
  }
}
