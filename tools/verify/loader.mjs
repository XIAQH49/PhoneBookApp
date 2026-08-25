// Node ESM 解析钩子（同步，适配 registerHooks）：为无扩展名的相对导入自动补 .ts。
// ArkTS 工程内保持无扩展名导入（工具链要求），Node 侧由本钩子兼容解析；
// 已有扩展名的（如 vendored .js）原样透传。
export function resolve(specifier, context, nextResolve) {
  if ((specifier.startsWith('./') || specifier.startsWith('../')) &&
    !/\.[a-zA-Z0-9]+$/.test(specifier)) {
    return nextResolve(specifier + '.ts', context);
  }
  return nextResolve(specifier, context);
}
