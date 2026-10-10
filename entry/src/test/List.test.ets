import apiErrorTest from './ApiError.test';
import chatSessionTest from './ChatSession.test';
import dayParserTest from './DayParser.test';
import httpKitTest from './HttpKit.test';
import localDateTest from './LocalDate.test';
import pairingApiTest from './PairingApi.test';
import reminderCalculatorTest from './ReminderCalculator.test';
import timeFormatTest from './TimeFormat.test';
import timelineTest from './Timeline.test';
import weekViewTest from './WeekView.test';
import wsUrlTest from './WsUrl.test';

/**
 * 本地单测聚合入口（hypium 装载点）。
 * 此前 entry/src/test/ 下每个 .test.ets 都只写了 export default function xxxTest()，
 * 却没有这份聚合文件 —— 等于十个套件一次都不会被执行。新增套件必须在这里挂进来。
 */
export default function testsuite(): void {
  apiErrorTest();
  chatSessionTest();
  dayParserTest();
  httpKitTest();
  localDateTest();
  pairingApiTest();
  reminderCalculatorTest();
  timeFormatTest();
  timelineTest();
  weekViewTest();
  wsUrlTest();
}
