// Node 启动注册文件：`node --import ./tools/verify/register.mjs tools/verify/verify.ts`
import { registerHooks } from 'node:module';
import { resolve } from './loader.mjs';

registerHooks({ resolve });
