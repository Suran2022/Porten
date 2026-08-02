/**
 * 资料页通用骨架屏。
 * 模拟资料页布局：背景占位 + 头像/昵称/账号/统计/日记/分享卡的灰色呼吸占位块。
 * loading 期间不渲染任何真实 img，避免弱网下"加载文字 + 破损图片"混合堆叠。
 */
export function ProfileSkeleton() {
  return (
    <>
      {/* 背景区域占位：灰色渐变替代真实 img，避免弱网图片错误 */}
      <div className="absolute inset-x-0 top-0 h-[380px] sm:h-[440px] overflow-hidden bg-gradient-to-b from-gray-200 via-gray-100 to-white" />

      {/* 内容区骨架 */}
      <div className="relative z-10 px-4 pb-6 space-y-4">
        {/* ProfileCard 骨架 */}
        <div className="p-5 bg-white rounded-2xl">
          <div className="flex items-start gap-4">
            {/* 头像占位 */}
            <div className="w-20 h-20 rounded-full bg-gray-200 animate-pulse flex-shrink-0" />
            <div className="flex-1 pt-1 space-y-2">
              {/* 昵称占位 */}
              <div className="h-5 w-24 bg-gray-200 rounded animate-pulse" />
              {/* Porten 账号占位 */}
              <div className="h-3 w-32 bg-gray-200 rounded animate-pulse" />
            </div>
          </div>

          {/* 三列统计占位（同胞数 / 性别 / 跨儿时常） */}
          <div className="grid grid-cols-3 gap-3 mt-5">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="flex flex-col items-center gap-1.5">
                <div className="h-5 w-10 bg-gray-200 rounded animate-pulse" />
                <div className="h-3 w-12 bg-gray-200 rounded animate-pulse" />
              </div>
            ))}
          </div>

          {/* 最新日记占位 */}
          <div className="mt-5 space-y-2">
            <div className="h-3 w-16 bg-gray-200 rounded animate-pulse" />
            <div className="h-4 w-full bg-gray-200 rounded animate-pulse" />
          </div>
        </div>

        {/* 分享卡骨架 */}
        <div className="p-4 bg-white rounded-2xl space-y-3">
          <div className="h-4 w-20 bg-gray-200 rounded animate-pulse" />
          <div className="space-y-2">
            <div className="h-3 w-full bg-gray-200 rounded animate-pulse" />
            <div className="h-3 w-2/3 bg-gray-200 rounded animate-pulse" />
          </div>
          <div className="flex gap-4 pt-1">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="h-3 w-10 bg-gray-200 rounded animate-pulse" />
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
