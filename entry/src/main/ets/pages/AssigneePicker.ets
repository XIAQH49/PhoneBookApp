import { CallListDao } from '../database/CallListDao';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';
import { ThemeSpec } from '../common/ThemeSpec';
import { IconButton } from '../components/IconButton';

/**
 * 责任人选择页（FR-3 / R-6；v0.7 UI 重构，docs/14 4.4）：
 * 搜索胶囊 + 卡片列表行（当前项主色对勾）；行点击 → 写配置 → pop 返回
 * （宿主 Index 经 onPop 回调自动重载，链路与旧版一致）。
 *
 * M2-2：router → Navigation 迁移。本页为 NavDestination；
 * 返回统一 pop(带结果) 并拦截系统返回，保证宿主 Index 的 onPop 回调触发。
 */
@Component
export struct AssigneePicker {
  @State list: string[] = [];
  @State keyword: string = '';
  @State current: string = '';
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
        // 顶部栏：40vp 圆形返回 + 居中标题 + 右侧占位（保持对称）
        Row() {
          IconButton({
            icon: '←',
            onTap: (): void => {
              this.popBack();
            }
          })
          Blank()
          Text($r('app.string.assignee_picker_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row()
            .width($r('app.float.icon_btn_size'))
            .height($r('app.float.icon_btn_size'))
        }
        .width('100%')
        .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 8, bottom: 8 })

        // 搜索胶囊（全圆）
        Row() {
          Text('🔍')
            .fontSize(16)
            .margin({ left: 14 })
          TextInput({ placeholder: $r('app.string.search_assignee_hint'), text: this.keyword })
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .height(44)
            .layoutWeight(1)
            .margin({ left: 8, right: 12 })
            .onChange((v: string) => {
              this.keyword = v;
            })
        }
        .height(44)
        .backgroundColor($r('app.color.card'))
        .borderRadius($r('app.float.radius_pill'))
        .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_between') })

        List() {
          ForEach(this.filteredList(), (a: string) => {
            ListItem() {
              Row() {
                Text(a === Constants.UNASSIGNED ? '未分配' : a)
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                if (a === this.current) {
                  Text('✓')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.primary'))
                }
              }
              .width('100%')
              .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner'), top: 16, bottom: 16 })
              .borderRadius($r('app.float.radius_item'))
              .backgroundColor($r('app.color.card'))
              .shadow({
                radius: ThemeSpec.SHADOW_CARD_RADIUS,
                color: ThemeSpec.SHADOW_CARD_COLOR,
                offsetX: 0,
                offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
              })
              .onClick(() => {
                ConfigDao.setLastAssignee(a).then(() => {
                  this.popBack();
                });
              })
            }
            .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 6, bottom: 6 })
          }, (a: string) => a)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg'))
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
