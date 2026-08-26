import { CallListDao } from '../database/CallListDao';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';

/**
 * 责任人选择页（FR-3 / R-6）：搜索、切换、记住上次选择。
 * 列表仅展示责任人名字，选中后写配置并返回（宿主 Index 经 onPop 回调自动重载）。
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
        Row() {
          Text('← 返回')
            .fontSize(16)
            .onClick(() => {
              this.popBack();
            })
          Blank()
          Text($r('app.string.assignee_picker_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('    ')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        TextInput({ placeholder: '搜索责任人', text: this.keyword })
          .height(40)
          .margin({ left: 16, right: 16, bottom: 8 })
          .onChange((v: string) => {
            this.keyword = v;
          })

        List() {
          ForEach(this.filteredList(), (a: string) => {
            ListItem() {
              Row() {
                Text(a === Constants.UNASSIGNED ? '未分配' : a)
                  .fontSize(16)
                  .layoutWeight(1)
                if (a === this.current) {
                  Text('✓')
                    .fontSize(16)
                    .fontColor('#007DFF')
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                ConfigDao.setLastAssignee(a).then(() => {
                  this.popBack();
                });
              })
            }
          }, (a: string) => a)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: '#F1F3F5' })
      }
      .width('100%')
      .height('100%')
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
