import { CallListDao } from '../database/CallListDao';
import { ConfigDao } from '../database/ConfigDao';
import { CountResult } from '../model/CallRecord';
import { Constants } from '../common/Constants';
import { ThemeSpec } from '../common/ThemeSpec';
import { IconButton } from '../components/IconButton';

/**
 * 责任人选择页（FR-3 / R-6；docs/15 3.4）：
 * 搜索胶囊 + 列表行带任务统计（「张三 20 条任务 · 12 条已打」）；
 * 选中：primary_soft 底 + 左 8vp 蓝色指示条（selection 语义）；
 * 行点击 → 写配置 → pop 返回（宿主 Index 经 onPop 回调自动重载，链路与旧版一致）。
 * 沉浸（docs/16 6.2）：系统栏底色由 EntryAbility 融合为页面同色；内容层保持系统安全区避让。
 *
 * M2-2：router → Navigation 迁移。本页为 NavDestination；
 * 返回统一 pop(带结果) 并拦截系统返回，保证宿主 Index 的 onPop 回调触发。
 */
@Component
export struct AssigneePicker {
  @State list: string[] = [];
  @State keyword: string = '';
  @State current: string = '';
  @State statsMap: Record<string, CountResult> = {};
  private stack: NavPathStack | undefined = undefined;

  /** NavDestination 就绪回调：记录栈引用 */
  private handleReady(ctx: NavDestinationContext): void {
    this.stack = ctx.pathStack;
  }

  /** 返回上一页：pop 携带结果，触发宿主 onPop 回调 */
  private popBack(): void {
    const result: Record<string, boolean> = { 'back': true };
    if (this.stack !== undefined) {
      this.stack.pop(result);
    }
  }

  async aboutToAppear(): Promise<void> {
    this.list = await CallListDao.getAssigneeList();
    this.current = await ConfigDao.getLastAssignee();
    await this.loadStats();
  }

  /** 每个责任人的任务/已打统计（行内展示用，只读） */
  async loadStats(): Promise<void> {
    const map: Record<string, CountResult> = {};
    for (const a of this.list) {
      map[a] = await CallListDao.countByStatus(a);
    }
    this.statsMap = map;
  }

  private rowStats(a: string): string {
    const r: CountResult | undefined = this.statsMap[a];
    if (r === undefined) {
      return '';
    }
    return r.total + ' 条任务 · ' + r.called + ' 条已打';
  }

  filteredList(): string[] {
    const kw: string = this.keyword.trim();
    if (kw === '') {
      return this.list;
    }
    return this.list.filter((a: string): boolean => {
      const display: string = a === Constants.UNASSIGNED ? '未分配' : a;
      return display.indexOf(kw) >= 0;
    });
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：50vp 圆形返回 + 居中标题 + 右侧占位（保持对称）
        Row() {
          IconButton({
            icon: '←',
            onTap: (): void => {
              this.popBack();
            }
          })
          Blank()
          Text($r('app.string.assignee_picker_title'))
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row()
            .width($r('app.float.icon_btn_size'))
            .height($r('app.float.icon_btn_size'))
        }
          .width('100%')
          .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
          .height($r('app.float.header_height'))
          .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page') })
          .margin({ top: 8 })

          // 搜索胶囊（radius_search 22vp）
          Row() {
            Text('🔍')
              .fontSize(16)
              .margin({ left: 16 })
            TextInput({ placeholder: $r('app.string.search_assignee_hint'), text: this.keyword })
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .height($r('app.float.search_height'))
              .layoutWeight(1)
              .margin({ left: 8, right: 14 })
              .onChange((v: string) => {
                this.keyword = v;
              })
          }
          .height($r('app.float.search_height'))
          .width('100%')
          .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius($r('app.float.radius_search'))
          .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_between') })

          List() {
            ForEach(this.filteredList(), (a: string) => {
              ListItem() {
                Row() {
                  // 选中指示条（selection 语义：左 8vp 蓝色指示条）
                  // 注意（真机实测坑位）：height('60%') 在 ListItem 父高度未确定时解析为
                  // List 可用空间的 60%（选中行被撑成 4.8 倍高）→ 固定 24vp + 行内垂直居中
                  if (a === this.current) {
                    Row()
                      .width(8)
                      .height(24)
                      .borderRadius(4)
                      .backgroundColor($r('app.color.primary'))
                      .margin({ right: 12 })
                  }
                  Column() {
                    Text(a === Constants.UNASSIGNED ? '未分配' : a)
                      .fontSize($r('app.float.font_body'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                    Text(this.rowStats(a))
                      .fontSize($r('app.float.font_overline'))
                      .fontColor($r('app.color.text_tertiary'))
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (a === this.current) {
                    Text('✓')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.primary'))
                  }
                }
                .width('100%')
                .padding({
                  left: $r('app.float.space_card_inner'),
                  right: $r('app.float.space_card_inner'),
                  top: 16,
                  bottom: 16
                })
                .alignItems(VerticalAlign.Center)
                .borderRadius($r('app.float.radius_item'))
                .backgroundColor(a === this.current ? $r('app.color.primary_soft') : $r('app.color.surface_card'))
                .border({
                  width: a === this.current ? 1 : 0,
                  color: $r('app.color.selection_border')
                })
                .onClick(() => {
                  ConfigDao.setLastAssignee(a).then(() => {
                    this.popBack();
                  });
                })
              }
              .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 6, bottom: 6 })
              .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
            }, (a: string) => a)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.handleReady(ctx);
    })
    .onBackPressed((): boolean => {
      this.popBack();
      return true;
    })
  }
}
