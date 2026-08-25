import { router } from '@kit.ArkUI';
import { CallListDao } from '../database/CallListDao';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';

/**
 * 责任人选择页（FR-3 / R-6）：搜索、切换、记住上次选择。
 * 列表仅展示责任人名字，选中后写配置并返回（Index.onPageShow 自动重载）。
 */
@Entry
@Component
struct AssigneePicker {
  @State list: string[] = [];
  @State keyword: string = '';
  @State current: string = '';

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
    Column() {
      Row() {
        Text('← 返回')
          .fontSize(16)
          .onClick(() => {
            router.back();
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
                router.back();
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
}
