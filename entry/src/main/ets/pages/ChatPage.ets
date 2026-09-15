import { ChatMessage, L1Info } from '../model/ChatMessage';
import { fetchAgents, ApiResultAgents } from '../service/AgentApi';
import { pickL1Row } from '../service/ChatSession';
import { sendPromptOverWs, ChatSendOutcome } from '../service/WsChat';
import { buildWsUrl } from '../service/WsUrl';
import { getStringSync, putString } from '../service/Cache';
import {
  PREF_KEY_BASE_URL,
  PREF_KEY_TOKEN,
  PREF_KEY_L1_INFO,
  PREF_KEY_CHAT_HISTORY,
} from '../model/AppConfig';

const HEADER_TOKEN: string = 'X-Vaelis-Session-Token';
const MAX_HISTORY: number = 100;

@Entry
@Component
struct ChatPage {
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State isSending: boolean = false;
  @State topError: string = '';
  @State topHint: string = '';
  @State l1Name: string = '总秘书';
  @State l1MissingText: string = '';

  private l1Info: L1Info | undefined = undefined;

  aboutToAppear(): void {
    this.loadFromCache();
    void this.resolveL1();
  }

  build(): void {
    Column() {
      this.headerBar();
      this.statusBanner();
      this.messageList();
      this.composerBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
  }

  @Builder
  headerBar(): void {
    Row() {
      Button('返回')
        .type(ButtonType.Capsule)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.getUIContext().getRouter().back();
        });
      Blank();
      Text('问' + this.l1Name)
        .fontSize(18)
        .fontWeight(FontWeight.Medium);
      Blank();
      Column().width(60);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.ohos_id_color_background'));
  }

  @Builder
  statusBanner(): void {
    if (this.l1MissingText.length > 0) {
      Row() {
        Text(this.l1MissingText)
          .fontSize(13)
          .fontColor('#7A5A18')
          .layoutWeight(1);
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#FBEFD0');
    }
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
  messageList(): void {
    Scroll() {
      Column() {
        if (this.messages.length === 0) {
          this.emptyHint('向' + this.l1Name + '说一句话，比如「明天的安排」');
        }
        ForEach(this.messages, (item: ChatMessage): void => {
          this.bubble(item);
        }, (item: ChatMessage): string => item.id);
        Column().height(24);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 });
    }
    .layoutWeight(1)
    .width('100%');
  }

  @Builder
  emptyHint(text: string): void {
    Text(text)
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .width('100%')
      .padding(16)
      .borderRadius(8)
      .backgroundColor($r('sys.color.ohos_id_color_card_background'))
      .margin({ top: 8, bottom: 8 });
  }

  @Builder
  bubble(item: ChatMessage): void {
    Row() {
      Column() {
        Text(item.text)
          .fontSize(15)
          .fontColor(item.role === 'user' ? '#FFFFFF' : $r('sys.color.ohos_id_color_text_primary'))
          .padding(12)
          .borderRadius(12)
          .backgroundColor(item.role === 'user' ? '#1A8C4A' : $r('sys.color.ohos_id_color_card_background'))
          .maxLines(500)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(item.role === 'user' ? '我' : this.l1Name + ' · ' + formatLocalTime(item.createdAtIso))
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .margin({ top: 4 });
      }
      .layoutWeight(1)
      .alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start);

      Blank().width(0);
    }
    .width('100%')
    .justifyContent(item.role === 'user' ? FlexAlign.End : FlexAlign.Start)
    .margin({ top: 6, bottom: 6 });
  }

  @Builder
  composerBar(): void {
    Row() {
      TextInput({ placeholder: '输入后点发送', text: this.input })
        .layoutWeight(1)
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(20)
        .backgroundColor($r('sys.color.ohos_id_color_card_background'))
        .enabled(!this.isSending)
        .onChange((value: string): void => {
          this.input = value;
        });
      Button('发送')
        .type(ButtonType.Capsule)
        .height(40)
        .padding({ left: 16, right: 16 })
        .margin({ left: 8 })
        .enabled(!this.isSending && this.input.trim().length > 0)
        .onClick((): void => {
          void this.sendCurrent();
        });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .alignItems(VerticalAlign.Center);
  }

  private loadFromCache(): void {
    const l1Json: string | undefined = getStringSync(PREF_KEY_L1_INFO);
    if (l1Json !== undefined) {
      this.l1Info = parseL1Info(l1Json);
      if (this.l1Info !== undefined) {
        this.l1Name = this.l1Info.agentName;
      }
    }
    const historyJson: string | undefined = getStringSync(PREF_KEY_CHAT_HISTORY);
    if (historyJson !== undefined) {
      this.messages = parseChatHistory(historyJson);
    }
  }

  private async resolveL1(): Promise<void> {
    const baseUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    const token: string | undefined = getStringSync(PREF_KEY_TOKEN);
    if (baseUrl === undefined || token === undefined || baseUrl.length === 0 || token.length === 0) {
      this.l1MissingText = '请先在「设置」配对';
      return;
    }
    const res: ApiResultAgents = await fetchAgents(baseUrl, token);
    if (!res.ok || res.data === undefined) {
      this.l1MissingText = '拉取总秘书列表失败，请检查桌面';
      return;
    }
    const rawJson: string = JSON.stringify(res.data);
    const l1: L1Info | undefined = pickL1Row(rawJson);
    if (l1 === undefined) {
      this.l1MissingText = '电脑端还没打开平板对话通道（找不到 L1 / sessionId）';
      return;
    }
    this.l1Info = l1;
    this.l1Name = l1.agentName;
    this.l1MissingText = '';
    await putString(PREF_KEY_L1_INFO, JSON.stringify(l1));
  }

  private async sendCurrent(): Promise<void> {
    const text: string = this.input.trim();
    if (text.length === 0 || this.isSending) {
      return;
    }
    const baseUrl: string | undefined = getStringSync(PREF_KEY_BASE_URL);
    const token: string | undefined = getStringSync(PREF_KEY_TOKEN);
    if (baseUrl === undefined || token === undefined || baseUrl.length === 0 || token.length === 0) {
      this.topError = '请先在「设置」配对';
      return;
    }
    if (this.l1Info === undefined) {
      await this.resolveL1();
    }
    if (this.l1Info === undefined) {
      this.topError = this.l1MissingText.length > 0 ? this.l1MissingText : '总秘书未就绪';
      return;
    }
    const userMsg: ChatMessage = {
      'id': makeId('u'),
      'role': 'user',
      'text': text,
      'createdAtIso': new Date().toISOString(),
    };
    const placeholderId: string = makeId('a');
    this.messages = this.messages.concat([userMsg, {
      'id': placeholderId,
      'role': 'assistant',
      'text': '正在询问…',
      'createdAtIso': new Date().toISOString(),
    }]);
    this.input = '';
    this.isSending = true;
    this.topError = '';
    this.topHint = '';
    void this.persistHistory();

    const outcome: ChatSendOutcome = await sendPromptOverWs(baseUrl, token, {
      'session_id': this.l1Info.sessionId,
      'text': text,
    });
    this.isSending = false;
    if (outcome.ok) {
      this.messages = this.messages.map((m: ChatMessage): ChatMessage => {
        if (m.id === placeholderId) {
          const updated: ChatMessage = {
            'id': placeholderId,
            'role': 'assistant',
            'text': outcome.fullText,
            'createdAtIso': m.createdAtIso,
          };
          return updated;
        }
        return m;
      });
      this.topError = '';
      this.topHint = '';
    } else {
      this.messages = this.messages.map((m: ChatMessage): ChatMessage => {
        if (m.id === placeholderId) {
          const updated: ChatMessage = {
            'id': placeholderId,
            'role': 'assistant',
            'text': '(失败)' + (outcome.failure?.short ?? '未知错误'),
            'createdAtIso': m.createdAtIso,
          };
          return updated;
        }
        return m;
      });
      if (outcome.failure !== undefined) {
        this.topError = outcome.failure.short;
        this.topHint = outcome.failure.hint;
      } else {
        this.topError = outcome.reason ?? '未知错误';
      }
    }
    void this.persistHistory();
  }

  private async persistHistory(): Promise<void> {
    const trimmed: ChatMessage[] = this.messages.length > MAX_HISTORY ?
      this.messages.slice(this.messages.length - MAX_HISTORY) : this.messages;
    await putString(PREF_KEY_CHAT_HISTORY, JSON.stringify(trimmed));
  }
}

function makeId(prefix: string): string {
  return prefix + '-' + String(Math.floor(Math.random() * 1e9));
}

function formatLocalTime(iso: string): string {
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return '--:--';
  }
  const pad: (n: number) => string = (n: number): string => {
    return n < 10 ? '0' + n.toString() : n.toString();
  };
  return pad(d.getHours()) + ':' + pad(d.getMinutes());
}

interface L1InfoStored {
  agentId: string;
  agentName: string;
  role: string;
  sessionId: string;
}

function parseL1Info(raw: string): L1Info | undefined {
  let obj: Object;
  try {
    obj = JSON.parse(raw) as Object;
  } catch (e) {
    return undefined;
  }
  if (typeof obj !== 'object' || obj === null) {
    return undefined;
  }
  const rec: Record<string, Object> = obj as Record<string, Object>;
  const id: string = typeof rec['agentId'] === 'string' ? (rec['agentId'] as string) : '';
  const name: string = typeof rec['agentName'] === 'string' ? (rec['agentName'] as string) : '';
  const role: string = typeof rec['role'] === 'string' ? (rec['role'] as string) : '';
  const sid: string = typeof rec['sessionId'] === 'string' ? (rec['sessionId'] as string) : '';
  if (id.length === 0 || sid.length === 0) {
    return undefined;
  }
  return {
    'agentId': id,
    'agentName': name.length > 0 ? name : id,
    'role': role.length > 0 ? role : 'l1_secretary',
    'sessionId': sid,
  };
}

function parseChatHistory(raw: string): ChatMessage[] {
  let obj: Object;
  try {
    obj = JSON.parse(raw) as Object;
  } catch (e) {
    return [];
  }
  if (!Array.isArray(obj)) {
    return [];
  }
  const arr: Object[] = obj as Object[];
  const out: ChatMessage[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    const e: Object | null = arr[i] as Object;
    if (e === null || typeof e !== 'object') {
      continue;
    }
    const rec: Record<string, Object> = e as Record<string, Object>;
    const id: string = typeof rec['id'] === 'string' ? (rec['id'] as string) : '';
    const role: string = typeof rec['role'] === 'string' ? (rec['role'] as string) : '';
    const text: string = typeof rec['text'] === 'string' ? (rec['text'] as string) : '';
    const ts: string = typeof rec['createdAtIso'] === 'string' ? (rec['createdAtIso'] as string) : '';
    if (id.length === 0 || text.length === 0) {
      continue;
    }
    const roleNorm: 'user' | 'assistant' = role === 'user' ? 'user' : 'assistant';
    out.push({
      'id': id,
      'role': roleNorm,
      'text': text,
      'createdAtIso': ts,
    });
  }
  return out;
}