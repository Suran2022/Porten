/**
 * Mock 模式开关。
 *
 * 当前阶段前端默认使用本地 mock 数据运行：登录页可用任意账号直接登录，
 * 会话、消息、联系人、搜索等数据全部来自本地 mock 引擎，不依赖后端服务。
 *
 * 如需恢复真实后端联调，设置环境变量 VITE_USE_MOCK=false 即可。
 */
export const USE_MOCK: boolean =
  (import.meta.env.VITE_USE_MOCK as string | undefined) !== "false";

/** mock 环境下当前登录用户的 id。 */
export const MOCK_USER_ID = 1001;
