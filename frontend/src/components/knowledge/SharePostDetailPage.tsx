import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type UIEvent,
} from "react";
import { BackIcon } from "@/components/common/BackIcon";
import { ShareCommentItem, SharePost } from "@/types/knowledge";
import { useToastStore } from "@/store/toastStore";
import { useAuthStore } from "@/store/authStore";
import { cn } from "@/lib/utils";

interface SharePostDetailPageProps {
  visible: boolean;
  post: SharePost | null;
  onClose: () => void;
}

/** 转场与回弹统一曲线：快速启动 + 柔和落定，与项目页面切换手感一致 */
const SLIDE_TRANSITION = "transform 320ms cubic-bezier(0.25, 0.1, 0.25, 1)";
/** 滑出动画等待：略长于转场时长，保证动画播完再卸载 */
const EXIT_MS = 360;
/** 手势门槛：横向位移超过该值才可能接管（防轻微抖动误触发） */
const GRAB_DX = 24;
/** 方向系数：横向位移需大于纵向位移 × 该系数才认定为右滑退出 */
const DIRECTION_RATIO = 1.5;
/** 松手退出判定：位移超过屏宽该比例，或快速轻扫 */
const COMMIT_RATIO = 0.3;
const FLICK_VELOCITY = 600;
const FLICK_MIN_OFFSET = 40;
/** 交流列表按需加载：默认展示条数 / 每次触底最多增载条数 / 增载动画时长（ms） */
const COMMENT_INITIAL_COUNT = 5;
const COMMENT_LOAD_STEP = 3;
const COMMENT_LOAD_DELAY = 600;

/** 发布时间统一以「年月日」展示，如 2026年9月28日 */
function formatYearMonthDay(value?: string): string {
  if (!value) return "";
  const m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(value.trim());
  if (!m) return value;
  return `${m[1]}年${Number(m[2])}月${Number(m[3])}日`;
}

/**
 * 交流发布时间展示：
 * 1 分钟内 → 现在；1 小时内 → N分钟前；24 小时内 → N小时前；
 * 7 天内 → N天前；超过 7 天 → 年月日（如 2026年9月28日）
 */
function formatCommentTime(value: string): string {
  const t = new Date(value).getTime();
  if (Number.isNaN(t)) return value;
  const diff = Date.now() - t;
  if (diff < 60_000) return "现在";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}分钟前`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}小时前`;
  if (diff < 7 * 86_400_000) return `${Math.floor(diff / 86_400_000)}天前`;
  return formatYearMonthDay(value.slice(0, 10)) || value;
}

/** 由最近采样点估算松手瞬时速度（px/s） */
function velocityOf(hist: [number, number][]): number {
  if (hist.length < 2) return 0;
  const [t0, o0] = hist[0];
  const [t1, o1] = hist[hist.length - 1];
  return ((o1 - o0) / Math.max(1, t1 - t0)) * 1000;
}

/** 分享图标（顶部栏右对齐） */
function ShareIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M831.061333 53.76c23.936-4.352 47.232-5.888 68.693334 2.218667 31.445333 11.946667 56.32 36.778667 68.266666 68.224 8.106667 21.504 6.570667 44.757333 2.133334 68.693333-4.394667 24.192-12.928 54.528-23.466667 92.16l-122.154667 436.266667c-16.725333 59.776-29.866667 106.624-42.453333 140.544-11.946667 32.085333-26.368 61.653333-51.114667 76.757333a117.333333 117.333333 0 0 1-112.426666 5.290667c-26.026667-12.672-43.264-40.789333-58.154667-71.594667-15.744-32.597333-33.152-78.037333-55.466667-135.936l-8.021333-20.906667-8.192-21.333333a32 32 0 0 1 59.733333-22.997333l8.192 21.333333 8.021334 20.906667c22.741333 59.093333 39.082667 101.461333 53.376 131.072 15.146667 31.317333 24.32 39.850667 28.501333 41.898666 16.341333 7.978667 35.626667 7.04 51.114667-2.389333 3.968-2.432 12.288-11.776 24.448-44.373333 11.434667-30.848 23.722667-74.581333 40.832-135.509334l122.154666-436.309333c10.88-38.826667 18.346667-65.792 22.186667-86.4 3.797333-20.778667 2.645333-29.781333 0.853333-34.517333a53.418667 53.418667 0 0 0-31.018666-30.976c-4.693333-1.792-13.738667-2.986667-34.474667 0.853333-20.608 3.797333-47.616 11.306667-86.442667 22.186667L319.914667 261.077333c-60.970667 17.066667-104.704 29.312-135.509334 40.789334-32.597333 12.117333-41.941333 20.48-44.373333 24.448a53.418667 53.418667 0 0 0-2.432 51.157333c2.048 4.138667 10.581333 13.354667 41.941333 28.501333 29.568 14.293333 71.978667 30.634667 131.029334 53.333334l87.424 33.664c32.213333 12.373333 41.088 15.274667 49.066666 15.445333 8.234667 0.170667 16.384-1.536 23.850667-5.034667 7.210667-3.413333 14.08-9.685333 38.528-34.133333l65.28-65.194667a32 32 0 0 1 45.226667 45.226667L554.666667 514.56c-20.949333 20.949333-36.821333 37.418667-56.533334 46.72-16.384 7.68-34.346667 11.52-52.48 11.093333-21.76-0.426667-42.965333-9.045333-70.613333-19.712l-87.466667-33.621333c-57.941333-22.272-103.338667-39.68-135.936-55.466667-30.805333-14.890667-58.88-32.085333-71.552-58.112A117.333333 117.333333 0 0 1 85.333333 293.034667c15.061333-24.746667 44.672-39.210667 76.714667-51.114667 33.92-12.629333 80.768-25.728 140.544-42.453333L738.986667 77.226667c37.589333-10.496 67.968-19.029333 92.16-23.466667z" />
    </svg>
  );
}

/** 编辑图标（仅自己发布的文章显示，位于分享图标左侧） */
function EditIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M430.848 877.056H295.0144a139.5712 139.5712 0 0 1-139.4176-139.4176v-494.592a108.3392 108.3392 0 0 1 108.1856-108.1856h440.9856a139.5712 139.5712 0 0 1 139.4176 139.4176v98.7648a25.6 25.6 0 1 0 51.2 0V274.2784a190.8224 190.8224 0 0 0-190.6176-190.6176H263.7824a159.5392 159.5392 0 0 0-159.3856 159.3856v494.592a190.8224 190.8224 0 0 0 190.6176 190.6176h135.8336a25.6 25.6 0 1 0 0-51.2z" />
      <path d="M340.6848 509.5424a25.6 25.6 0 0 0 0 51.2h239.5136a25.6 25.6 0 0 0 0-51.2zM684.6464 323.7376a25.6 25.6 0 0 0-25.6-25.6H340.6848a25.6 25.6 0 0 0 0 51.2h318.3616a25.6 25.6 0 0 0 25.6-25.6zM939.5712 530.3296l-37.12-36.1472a82.2272 82.2272 0 0 0-115.712 1.0752l-43.0592 44.0832-156.7744 158.3104a118.6816 118.6816 0 0 0-29.3376 49.8688l-30.208 103.8336a55.7568 55.7568 0 0 0 73.3184 67.8912l93.0816-35.1232a118.3744 118.3744 0 0 0 42.8544-28.0064L898.1504 691.2l27.8016-29.0304 15.36-15.36a81.92 81.92 0 0 0-1.4848-116.1216z m-239.6672 289.9968a66.9184 66.9184 0 0 1-24.2688 15.9232l-93.0816 35.1232a4.1472 4.1472 0 0 1-4.8128-0.9728 4.5056 4.5056 0 0 1-1.28-4.7104l30.2592-103.7824a67.328 67.328 0 0 1 16.5888-28.2624l149.3504-150.8352 83.3024 78.0288z m204.4928-209.6128l-12.9536 13.2096-82.9952-77.7728 14.7456-14.8992a30.72 30.72 0 0 1 43.52-0.4096l37.12 36.1472a30.72 30.72 0 0 1 0.5632 43.7248z" />
    </svg>
  );
}

/** 交流区块标题图标（对话气泡） */
function ChatIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M725.333333 352a288 288 0 0 1 261.461334 408.917333c-13.056 28.16-17.706667 38.869333-13.226667 54.485334 1.194667 4.053333 3.029333 7.637333 7.082667 16.597333 3.285333 7.253333 8.234667 18.688 9.301333 31.872a57.6 57.6 0 0 1-66.858667 61.525333c-22.613333-3.754667-42.069333-15.573333-50.730666-19.712-9.386667-4.437333-15.402667-6.058667-25.173334-3.754666l-2.005333 0.597333a283.733333 283.733333 0 0 0-6.741333 2.261333c-5.802667 2.005333-13.909333 4.949333-24.96 8.874667A257.28 257.28 0 0 1 725.333333 928a288 288 0 0 1-249.472-432.042667 32 32 0 0 1 55.466667 32.085334A224 224 0 0 0 725.333333 864c25.941333 0 47.232-3.669333 66.56-10.581333 20.437333-7.296 34.090667-12.245333 40.618667-13.781334 29.098667-6.826667 50.602667 0.298667 67.328 8.234667 10.752 5.12 16.981333 8.618667 22.656 11.050667l-0.213333-0.597334c-2.261333-5.034667-7.424-15.36-10.282667-25.258666-12.16-42.368 5.802667-75.648 16.64-99.072a224 224 0 0 0-278.058667-305.237334 32 32 0 0 1-21.290666-60.330666A287.573333 287.573333 0 0 1 725.333333 352z m-277.333333-298.666667a394.453333 394.453333 0 0 1 334.890667 185.728 32 32 0 0 1-54.314667 33.877334 330.666667 330.666667 0 1 0-580.778667 313.813333c15.829333 34.218667 38.528 76.629333 22.869334 131.114667-3.669333 12.8-10.325333 26.026667-13.909334 33.962666-4.352 9.642667-6.229333 15.36-6.570666 19.669334a4.266667 4.266667 0 0 0 4.949333 4.565333c17.834667-2.986667 28.373333-10.624 51.328-21.504 22.186667-10.538667 49.365333-19.498667 86.613333-10.752 8.234667 1.92 26.453333 8.490667 56.064 19.072 12.672 4.522667 25.813333 8.106667 39.722667 10.666667a32 32 0 1 1-11.690667 62.976 321.706667 321.706667 0 0 1-49.621333-13.397334c-15.616-5.546667-27.093333-9.685333-35.413333-12.586666a455.68 455.68 0 0 0-12.672-4.181334l-0.810667-0.213333-0.256-0.042667c-17.834667-4.224-29.568-0.853333-44.458667 6.229334-14.08 6.698667-38.698667 21.888-68.266666 26.837333a68.266667 68.266667 0 0 1-79.317334-72.917333c1.365333-16.213333 7.466667-30.634667 12.074667-40.789334 5.333333-11.861333 8.704-18.346667 10.666667-25.258666 7.978667-27.733333-1.365333-47.616-19.370667-86.528A394.666667 394.666667 0 0 1 448 53.333333z" />
    </svg>
  );
}

/** 点亮太阳图标（点亮后为橙色） */
function SunIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M512 821.333333a32 32 0 0 1 32 32v85.333334a32 32 0 0 1-64 0v-85.333334a32 32 0 0 1 32-32z m-278.613333-75.946666a32 32 0 0 1 45.226666 45.226666l-64 64a32 32 0 1 1-45.226666-45.226666l64-64z m512-0.042667a32 32 0 0 1 45.226666 0l64 64a32 32 0 0 1-45.226666 45.226667l-64-64a32 32 0 0 1 0-45.226667zM512 266.666667a32 32 0 0 1 0 64 181.333333 181.333333 0 1 0 145.066667 72.533333 32 32 0 0 1 51.2-38.442667A245.333333 245.333333 0 1 1 512 266.666667z m-341.333333 213.333333a32 32 0 0 1 0 64H85.333333a32 32 0 0 1 0-64h85.333334z m768 0a32 32 0 0 1 0 64h-85.333334a32 32 0 0 1 0-64h85.333334z m-129.28-310.613333a32 32 0 0 1 45.226666 45.226666l-64 64a32 32 0 0 1-45.226666-45.226666l64-64z m-640-0.042667a32 32 0 0 1 45.226666 0l64 64a32 32 0 0 1-45.226666 45.226667L169.386667 214.613333a32.042667 32.042667 0 0 1 0-45.269333zM512 53.333333a32 32 0 0 1 32 32v85.333334a32 32 0 0 1-64 0V85.333333a32 32 0 0 1 32-32z" />
    </svg>
  );
}

/** 举报图标 */
function ReportIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M420.906667 80.853333a245.461333 245.461333 0 0 1 182.229333 0c36.522667 14.592 66.730667 42.325333 96.128 80.256 29.354667 37.845333 60.032 88.661333 96.554667 152.704a32 32 0 0 1-55.594667 31.701334c-36.565333-64.128-65.28-111.36-91.52-145.194667-26.197333-33.706667-47.914667-51.498667-69.333333-60.074667a181.376 181.376 0 0 0-134.698667 0c-26.069333 10.453333-52.138667 34.261333-85.930667 82.858667-33.706667 48.384-71.893333 116.48-124.245333 210.005333-50.346667 89.941333-87.04 155.392-109.824 207.445334-22.826667 52.138667-29.44 85.76-25.130667 113.066666a181.418667 181.418667 0 0 0 66.901334 114.176c21.717333 17.066667 54.314667 27.776 110.933333 33.322667 56.576 5.546667 131.541333 5.546667 234.666667 5.546667 103.082667 0 178.048 0 234.624-5.546667 56.618667-5.546667 89.216-16.213333 110.933333-33.322667a181.418667 181.418667 0 0 0 66.858667-114.176c3.456-21.845333-0.085333-48.042667-13.653334-84.906666-13.738667-37.12-36.522667-82.261333-68.821333-141.397334a32 32 0 1 1 56.106667-30.634666c32.341333 59.178667 57.216 107.946667 72.704 149.845333 15.573333 42.112 22.784 80.128 16.938666 117.12a245.418667 245.418667 0 0 1-90.538666 154.410667c-36.352 28.586667-84.053333 40.832-144.341334 46.72-60.373333 5.930667-139.093333 5.888-240.810666 5.888-101.76 0-180.48 0-240.853334-5.888-60.245333-5.888-107.946667-18.048-144.341333-46.677334a245.418667 245.418667 0 0 1-90.453333-154.453333c-7.253333-45.738667 5.376-93.312 29.653333-148.778667 24.362667-55.594667 62.890667-124.202667 112.597333-212.992 51.712-92.373333 91.648-163.797333 127.573334-215.381333 35.712-51.370667 70.741333-88.064 114.688-105.642667zM512 640a42.666667 42.666667 0 1 1-0.085333 85.376A42.666667 42.666667 0 0 1 512.042667 640z m0-288a32 32 0 0 1 32 32v170.666667a32 32 0 0 1-64 0V384a32 32 0 0 1 32-32z" />
    </svg>
  );
}

/** 顶部栏举报图标（盾形 + 对勾） */
function ReportShieldIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M793.6 546.3552V310.6304a76.8 76.8 0 0 0-56.9856-74.24l-178.4832-47.616a179.2 179.2 0 0 0-92.2624 0l-178.4832 47.616A76.8 76.8 0 0 0 230.4 310.6304v237.1072c0 15.872 4.864 30.976 13.9264 43.2128 26.112 35.072 75.8272 99.1744 129.3824 154.2656 26.7776 27.5968 53.9136 52.224 79.0016 69.8368 25.9584 18.2272 45.9776 26.1632 59.2896 26.1632 10.6496 0 28.9792-7.3216 54.6816-25.8048 24.5248-17.5616 51.6096-42.24 78.6944-69.7856 54.016-55.04 105.6768-119.0912 133.1712-154.4704 9.7792-12.5952 15.0528-28.3136 15.0528-44.8z m51.2 0c0 27.3408-8.7552 54.272-25.856 76.288-27.904 35.84-80.9472 101.7344-137.1136 158.8736-28.0064 28.5184-57.344 55.5008-85.248 75.52-26.624 19.1488-56.576 35.3792-84.5824 35.3792-29.7984 0-60.7744-15.872-88.6784-35.3792-28.8256-20.224-58.4704-47.4624-86.3744-76.1856-55.808-57.4976-107.1104-123.648-133.632-159.3344a123.2896 123.2896 0 0 1-24.1152-73.728V310.5792A128 128 0 0 1 274.176 186.88l178.4832-47.5648a230.4 230.4 0 0 1 118.6816 0l178.4832 47.5648A128 128 0 0 1 844.8 310.6304v235.7248z" />
      <path d="M647.0656 388.352a25.6 25.6 0 0 1 37.0688 35.328l-158.208 166.5024a76.8 76.8 0 0 1-110.2336 1.1264l-75.4688-76.288a25.6 25.6 0 0 1 36.352-35.9936l75.52 76.2368a25.6 25.6 0 0 0 36.7616-0.3584l158.208-166.5536z" />
    </svg>
  );
}

/** 删除图标（仅自己发布的交流显示，红色） */
function DeleteIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" fill="currentColor" aria-hidden>
      <path d="M566.186667 53.333333c23.808 0 44.501333-0.512 62.805333 6.656 14.933333 5.888 28.16 15.445333 38.485333 27.733334 12.629333 15.104 18.688 34.944 26.24 57.514666l12.032 36.096H938.666667a32 32 0 0 1 0 64H204.629333l25.557334 434.432c2.688 45.738667 4.565333 78.165333 8.106666 103.509334 3.456 24.96 8.234667 40.490667 15.104 52.736a138.666667 138.666667 0 0 0 60.117334 56.618666c12.629333 6.144 28.330667 9.984 53.461333 11.989334 25.514667 2.048 58.026667 2.048 103.808 2.048h82.432c45.824 0 78.293333 0 103.808-2.048 25.173333-2.005333 40.832-5.845333 53.461333-11.989334a138.666667 138.666667 0 0 0 60.117334-56.618666c6.912-12.245333 11.648-27.733333 15.104-52.736 3.541333-25.344 5.418667-57.770667 8.106666-103.509334l17.493334-297.642666a32 32 0 0 1 63.957333 3.754666l-17.493333 297.642667c-2.645333 44.714667-4.693333 80.128-8.704 108.586667-4.010667 28.842667-10.24 53.205333-22.698667 75.264a202.709333 202.709333 0 0 1-87.808 82.773333c-22.784 11.093333-47.402667 15.957333-76.416 18.261333-28.672 2.304-64.128 2.261333-108.928 2.261334h-82.432c-44.8 0-80.256 0-108.928-2.261334-29.013333-2.304-53.632-7.168-76.373333-18.218666a202.709333 202.709333 0 0 1-87.893334-82.773334c-12.373333-22.101333-18.645333-46.464-22.656-75.306666-3.968-28.458667-6.058667-63.872-8.704-108.629334L140.501333 245.333333H85.333333a32 32 0 0 1 0-64h232.917334l12.032-36.096c7.552-22.570667 13.610667-42.410667 26.197333-57.472a96 96 0 0 1 38.528-27.733333c18.304-7.253333 38.997333-6.698667 62.805333-6.698667h108.373334z m-139.52 341.333334a32 32 0 0 1 32 32v298.666666a32 32 0 0 1-64 0v-298.666666a32 32 0 0 1 32-32z m170.666666 0a32 32 0 0 1 32 32v170.666666a32 32 0 0 1-64 0v-170.666666a32 32 0 0 1 32-32z m-139.52-277.333334c-29.269333 0-35.114667 0.512-39.381333 2.218667a32.042667 32.042667 0 0 0-12.842667 9.258667c-2.986667 3.498667-5.333333 8.874667-14.592 36.650666l-5.290666 15.872h252.586666l-5.290666-15.872c-9.258667-27.733333-11.648-33.152-14.592-36.693333a32.042667 32.042667 0 0 0-12.8-9.216c-4.266667-1.706667-10.154667-2.218667-39.424-2.218667h-108.373334z" />
    </svg>
  );
}

interface CommentCardProps {
  comment: ShareCommentItem;
  onToggleLit: (id: string) => void;
  onReport: (comment: ShareCommentItem) => void;
  onDelete: (id: string) => void;
}

/**
 * 交流卡片：第一行小头像 + 昵称（昵称后带冒号）；正文与昵称首字左对齐；
 * 正文下方左侧为发布时间（相对时间/年月日），右侧为点亮太阳、举报，
 * 自己发布的交流额外显示红色删除。平铺展示，不支持回复。
 */
function CommentCard({
  comment,
  onToggleLit,
  onReport,
  onDelete,
}: CommentCardProps) {
  const [imgError, setImgError] = useState(false);

  return (
    <div className="rounded-xl bg-gray-50 px-3.5 py-3">
      <div className="flex items-center gap-2">
        <div className="flex-shrink-0 w-6 h-6 rounded-full bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8] flex items-center justify-center overflow-hidden">
          {comment.avatar && !imgError ? (
            <img
              src={comment.avatar}
              alt={comment.author}
              className="w-full h-full object-cover"
              onError={() => setImgError(true)}
            />
          ) : (
            <span className="text-[11px] font-medium text-white">
              {comment.author.slice(0, 1)}
            </span>
          )}
        </div>
        <span className="text-sm font-medium text-gray-900 leading-tight">
          {comment.author}：
        </span>
      </div>

      <p className="mt-1.5 pl-8 text-sm text-gray-700 leading-relaxed break-words">
        {comment.content}
      </p>

      <div className="mt-1.5 pl-8 flex items-center justify-between">
        <span className="text-xs text-gray-400">
          {formatCommentTime(comment.publishedAt)}
        </span>
        <div className="flex items-center -mr-1.5">
          <button
            type="button"
            aria-label={comment.lit ? "取消点亮" : "点亮"}
            onClick={() => onToggleLit(comment.id)}
            className={cn(
              "w-8 h-8 flex items-center justify-center rounded-full active:bg-black/5 transition-colors",
              comment.lit ? "text-[#f97316]" : "text-gray-400"
            )}
          >
            <SunIcon className="w-4 h-4" />
          </button>
          <button
            type="button"
            aria-label="举报"
            onClick={() => onReport(comment)}
            className="w-8 h-8 flex items-center justify-center rounded-full text-gray-400 active:bg-black/5 transition-colors"
          >
            <ReportIcon className="w-4 h-4" />
          </button>
          {comment.isOwn ? (
            <button
              type="button"
              aria-label="删除"
              onClick={() => onDelete(comment.id)}
              className="w-8 h-8 flex items-center justify-center rounded-full text-red-500 active:bg-black/5 transition-colors"
            >
              <DeleteIcon className="w-4 h-4" />
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

interface ComposerPanelProps {
  open: boolean;
  onClose: () => void;
  onSend: (content: string) => void;
}

/**
 * 独立交流输入面板：白色面板（左上/右上圆角）从底部滑入，
 * 其余区域覆盖浅黑色透明遮罩，输入框下方右对齐浅粉色胶囊发送按钮。
 * 面板常驻挂载，open 驱动显隐与动画；打开时在用户点击的事件栈内
 * 同步聚焦输入框（useLayoutEffect），以满足移动端弹键盘的手势要求。
 */
function ComposerPanel({ open, onClose, onSend }: ComposerPanelProps) {
  const [entered, setEntered] = useState(false);
  const [draft, setDraft] = useState("");
  const inputRef = useRef<HTMLTextAreaElement | null>(null);

  // 滑入/滑出动画状态
  useEffect(() => {
    if (open) {
      let raf2 = 0;
      const raf1 = requestAnimationFrame(() => {
        raf2 = requestAnimationFrame(() => setEntered(true));
      });
      return () => {
        cancelAnimationFrame(raf1);
        cancelAnimationFrame(raf2);
      };
    }
    setEntered(false);
  }, [open]);

  // 关键：open 变化的同一 commit 内同步聚焦（仍处于用户点击调用栈内，
  // 移动端浏览器只认可手势栈内的 focus 才会弹起键盘），并在动画结束后兜底补聚焦
  useLayoutEffect(() => {
    if (open) {
      inputRef.current?.focus();
      const t = setTimeout(() => inputRef.current?.focus(), 350);
      return () => clearTimeout(t);
    }
    inputRef.current?.blur();
    return undefined;
  }, [open]);

  // 关闭后延迟清空草稿（等滑出动画结束，避免视觉闪变）
  useEffect(() => {
    if (open) return undefined;
    const t = setTimeout(() => setDraft(""), 300);
    return () => clearTimeout(t);
  }, [open]);

  const canSend = draft.trim().length > 0;

  return (
    <div
      aria-hidden={!open}
      className={cn("fixed inset-0 z-[90]", !open && "pointer-events-none")}
    >
      {/* 浅黑色透明遮罩：点击关闭 */}
      <div
        aria-hidden
        onClick={onClose}
        className={cn(
          "absolute inset-0 bg-black/40 transition-opacity duration-300",
          entered ? "opacity-100" : "opacity-0"
        )}
      />
      <div
        className={cn(
          "absolute inset-x-0 bottom-0 bg-white rounded-t-2xl px-4 pt-4 pb-[max(1rem,env(safe-area-inset-bottom))] transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          entered ? "translate-y-0" : "translate-y-full"
        )}
      >
        <textarea
          ref={inputRef}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          rows={3}
          maxLength={500}
          placeholder="与同伴一起同行，会走的更远哦！"
          className="w-full resize-none rounded-xl bg-white px-3.5 py-3 text-sm text-gray-800 placeholder:text-gray-400 outline-none"
        />
        <div className="mt-3 flex items-center justify-end">
          <button
            type="button"
            disabled={!canSend}
            onClick={() => {
              const content = draft.trim();
              if (!content) return;
              onSend(content);
            }}
            className={cn(
              "min-w-[5.5rem] h-9 px-6 rounded-full text-sm font-medium text-white transition-all duration-200",
              canSend
                ? "bg-[#F5A9B8] active:bg-[#ec97a6]"
                : "bg-[#F5A9B8]/40 cursor-not-allowed"
            )}
          >
            发送
          </button>
        </div>
      </div>
    </div>
  );
}

interface Grip {
  pointerId: number;
  x0: number;
  y0: number;
  /** 已锁定为右滑退出手势，开始跟手 */
  active: boolean;
  /** 已判定为非右滑（纵向滚动/向左），本次手势不再接管 */
  abandoned: boolean;
  /** 最近采样 [timeStamp, offset]，用于估算松手速度 */
  hist: [number, number][];
}

/**
 * 分享内容详情页（独立全屏页，不含底部菜单与知识顶部栏）。
 *
 * 转场：从右侧平移进入，退出向右侧平移滑出（统一 cubic-bezier 曲线）。
 * 手势：右滑跟手退出——横向位移超过门槛且纵向主导时才接管，接管瞬间从 0 位移
 * 起步（抵消门槛差），全程 transform 直写不触发 React 渲染，松手按位移/速度
 * 判定完成退出或回弹，无闪动、无卡顿、不误触。
 */
export function SharePostDetailPage({
  visible,
  post,
  onClose,
}: SharePostDetailPageProps) {
  const [mounted, setMounted] = useState(visible);
  const [imgError, setImgError] = useState(false);
  // 交流列表：进入页面时从帖子数据初始化，点亮/删除在本地维护
  const [comments, setComments] = useState<ShareCommentItem[]>([]);
  // 独立输入面板开关
  const [composerOpen, setComposerOpen] = useState(false);
  // 当前用户（底部交流框头像、发布交流的署名）
  const user = useAuthStore((state) => state.user);
  const [userImgError, setUserImgError] = useState(false);
  // 交流内容滚动容器（发送后滚动到最新）
  const scrollElRef = useRef<HTMLDivElement | null>(null);
  const composerOpenRef = useRef(composerOpen);
  // 交流列表按需加载：默认展示 5 条，触底每次最多增载 3 条
  const [visibleCount, setVisibleCount] = useState(COMMENT_INITIAL_COUNT);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const loadMoreTimerRef = useRef<number | null>(null);

  useEffect(() => {
    composerOpenRef.current = composerOpen;
  }, [composerOpen]);
  const rootRef = useRef<HTMLDivElement | null>(null);
  const gripRef = useRef<Grip | null>(null);
  const exitTimerRef = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined
  );
  const mountedRef = useRef(mounted);
  const visibleRef = useRef(visible);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  /** transform/transition 直写 DOM（合成层属性），是全程流畅的关键 */
  const applyX = useCallback((px: number, animate: boolean) => {
    const el = rootRef.current;
    if (!el) return;
    el.style.transition = animate ? SLIDE_TRANSITION : "none";
    el.style.transform = `translateX(${px}px)`;
  }, []);

  /** 进入动画编排：首帧定位于屏幕外（避免闪现），随后平滑滑入 */
  useLayoutEffect(() => {
    if (!mounted) return undefined;
    const el = rootRef.current;
    if (!el) return undefined;
    el.style.transition = "none";
    el.style.transform = `translateX(${window.innerWidth}px)`;
    let raf2 = 0;
    const raf1 = requestAnimationFrame(() => {
      raf2 = requestAnimationFrame(() => applyX(0, true));
    });
    return () => {
      cancelAnimationFrame(raf1);
      cancelAnimationFrame(raf2);
    };
  }, [mounted, applyX]);

  useEffect(() => {
    visibleRef.current = visible;
    if (visible) {
      if (mountedRef.current) return;
      mountedRef.current = true;
      setMounted(true);
      setImgError(false);
      return;
    }
    // 关闭（返回按钮 / 父级关闭）：滑出动画结束后再卸载
    if (!mountedRef.current) return;
    applyX(window.innerWidth, true);
    exitTimerRef.current = setTimeout(() => {
      exitTimerRef.current = undefined;
      mountedRef.current = false;
      setMounted(false);
    }, EXIT_MS);
  }, [visible, applyX]);

  // 卸载兜底清理
  useEffect(
    () => () => {
      if (exitTimerRef.current) clearTimeout(exitTimerRef.current);
    },
    []
  );

  // Escape 键退出（桌面预览友好）
  useEffect(() => {
    if (!mounted) return undefined;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onCloseRef.current();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mounted]);

  useEffect(() => {
    if (!mounted) return undefined;
    const root = rootRef.current;
    if (!root) return undefined;

    const onPointerDown = (e: PointerEvent) => {
      if (!visibleRef.current || e.button !== 0) return;
      if (composerOpenRef.current) return; // 输入面板打开时不做右滑退出
      if (exitTimerRef.current) return; // 退出动画中不重新起手势
      // 按钮/链接等交互元素上的按下不作为手势起点
      if (
        e.target instanceof Element &&
        e.target.closest("button, a, input, textarea, select")
      )
        return;
      gripRef.current = {
        pointerId: e.pointerId,
        x0: e.clientX,
        y0: e.clientY,
        active: false,
        abandoned: false,
        hist: [],
      };
      try {
        root.setPointerCapture(e.pointerId);
      } catch {
        /* noop */
      }
    };

    const onPointerMove = (e: PointerEvent) => {
      const g = gripRef.current;
      if (!g || g.pointerId !== e.pointerId || g.abandoned) return;
      const dx = e.clientX - g.x0;
      const dy = e.clientY - g.y0;
      if (!g.active) {
        if (dx >= GRAB_DX && Math.abs(dx) > Math.abs(dy) * DIRECTION_RATIO) {
          // 锁定为右滑手势：抵消门槛差，从 0 位移起步跟手，无跳变
          g.active = true;
        } else if (
          dx < -GRAB_DX ||
          (Math.abs(dy) > Math.abs(dx) * DIRECTION_RATIO &&
            Math.abs(dy) > GRAB_DX)
        ) {
          // 向左滑或纵向滚动：交给浏览器，本次手势不再接管
          g.abandoned = true;
          return;
        } else {
          return;
        }
      }
      const width = window.innerWidth;
      const offset = Math.min(width, Math.max(0, dx - GRAB_DX));
      g.hist.push([e.timeStamp, offset]);
      if (g.hist.length > 4) g.hist.shift();
      applyX(offset, false);
    };

    const finish = (e: PointerEvent, cancelled: boolean) => {
      const g = gripRef.current;
      if (!g || g.pointerId !== e.pointerId) return;
      gripRef.current = null;
      try {
        root.releasePointerCapture(e.pointerId);
      } catch {
        /* noop */
      }
      if (!g.active) return;
      if (cancelled) {
        // 手势被打断（如来电/切后台）：原地回弹
        applyX(0, true);
        return;
      }
      const width = window.innerWidth;
      const offset = Math.min(width, Math.max(0, e.clientX - g.x0 - GRAB_DX));
      const v = velocityOf(g.hist);
      const commit =
        offset > width * COMMIT_RATIO ||
        (v > FLICK_VELOCITY && offset > FLICK_MIN_OFFSET);
      if (commit) {
        // 跟手滑出至屏幕外，动画结束后卸载并通知父级
        applyX(width, true);
        exitTimerRef.current = setTimeout(() => {
          exitTimerRef.current = undefined;
          mountedRef.current = false;
          setMounted(false);
          onCloseRef.current();
        }, EXIT_MS);
      } else {
        applyX(0, true);
      }
    };

    const onPointerUp = (e: PointerEvent) => finish(e, false);
    const onPointerCancel = (e: PointerEvent) => finish(e, true);

    root.addEventListener("pointerdown", onPointerDown);
    root.addEventListener("pointermove", onPointerMove);
    root.addEventListener("pointerup", onPointerUp);
    root.addEventListener("pointercancel", onPointerCancel);
    return () => {
      root.removeEventListener("pointerdown", onPointerDown);
      root.removeEventListener("pointermove", onPointerMove);
      root.removeEventListener("pointerup", onPointerUp);
      root.removeEventListener("pointercancel", onPointerCancel);
    };
  }, [mounted, applyX]);

  useEffect(() => {
    // 切换帖子时重置交流列表与分页
    setComments(post?.commentList ? post.commentList.map((c) => ({ ...c })) : []);
    setVisibleCount(COMMENT_INITIAL_COUNT);
  }, [post]);

  // 卸载时清理触底增载定时器
  useEffect(() => {
    return () => {
      if (loadMoreTimerRef.current !== null)
        window.clearTimeout(loadMoreTimerRef.current);
    };
  }, []);

  const handleToggleLit = useCallback(
    (id: string) => {
      const target = comments.find((c) => c.id === id);
      if (!target) return;
      const lit = !target.lit;
      setComments((prev) => prev.map((c) => (c.id === id ? { ...c, lit } : c)));
      useToastStore
        .getState()
        .show(
          lit ? "点亮成功，谢谢你的光！" : "缘分到此我还会记得你！",
          "success",
          "center"
        );
    },
    [comments]
  );

  const handleReportComment = useCallback(() => {
    useToastStore.getState().show("已提交举报，感谢反馈", "success", "center");
  }, []);

  /** 举报当前帖子（顶部栏入口） */
  const handleReportPost = useCallback(() => {
    useToastStore.getState().show("已提交举报，感谢反馈", "success", "center");
  }, []);

  const handleDeleteComment = useCallback((id: string) => {
    setComments((prev) => prev.filter((c) => c.id !== id));
    useToastStore.getState().show("删除成功", "success", "center");
  }, []);

  /** 发布交流：以当前用户署名插入列表最前（最新在最上），滚动到顶部 */
  const handleSendComment = useCallback((content: string) => {
    const currentUser = useAuthStore.getState().user;
    const item: ShareCommentItem = {
      id: `local-${Date.now()}`,
      author: currentUser?.nickname || "我",
      avatar: currentUser?.avatar || "https://i.pravatar.cc/150?u=me",
      content,
      publishedAt: new Date().toISOString(),
      isOwn: true,
    };
    setComments((prev) => [item, ...prev]);
    setComposerOpen(false);
    useToastStore.getState().show("发布成功", "success", "center");
    setTimeout(() => {
      const el = scrollElRef.current;
      if (el) el.scrollTo({ top: 0, behavior: "smooth" });
    }, 60);
  }, []);

  // 交流按发布时间倒序（最新在最上），再按已展示条数分页
  const sortedComments = useMemo(
    () =>
      [...comments].sort(
        (a, b) =>
          new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
      ),
    [comments]
  );
  const visibleComments = useMemo(
    () => sortedComments.slice(0, visibleCount),
    [sortedComments, visibleCount]
  );
  const hasMoreComments = visibleCount < sortedComments.length;

  /** 列表滚动触底：按需增载（每次最多 3 条），加载动画期间不重复触发 */
  const handleListScroll = useCallback(
    (e: UIEvent<HTMLDivElement>) => {
      if (loadingMoreRef.current || !hasMoreComments) return;
      const el = e.currentTarget;
      if (el.scrollTop + el.clientHeight < el.scrollHeight - 48) return;
      loadingMoreRef.current = true;
      setLoadingMore(true);
      loadMoreTimerRef.current = window.setTimeout(() => {
        setVisibleCount((v) =>
          Math.min(v + COMMENT_LOAD_STEP, sortedComments.length)
        );
        setLoadingMore(false);
        loadingMoreRef.current = false;
      }, COMMENT_LOAD_DELAY);
    },
    [hasMoreComments, sortedComments.length]
  );

  const handleBack = useCallback(() => {
    if (exitTimerRef.current) return;
    onCloseRef.current();
  }, []);

  if (!mounted) return null;

  return (
    <div
      ref={rootRef}
      role="dialog"
      aria-label="分享详情"
      style={{ willChange: "transform", touchAction: "pan-y" }}
      className="fixed inset-0 z-[80] bg-white flex flex-col"
    >
      {/* 顶部栏：左返回；右侧依次为举报、分享（自己发布的文章额外显示编辑），无分割线 */}
      <header className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white">
        <button
          type="button"
          aria-label="返回"
          onClick={handleBack}
          className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors"
        >
          <BackIcon className="w-7 h-7" />
        </button>
        <div className="flex items-center gap-1">
          <button
            type="button"
            aria-label="举报"
            onClick={handleReportPost}
            className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors text-gray-900"
          >
            {/* 盾形图形在 1024 viewBox 内留白较大，放大一档使视觉尺寸与相邻 w-5 图标一致 */}
            <ReportShieldIcon className="w-6 h-6" />
          </button>
          {post?.isOwn ? (
            <button
              type="button"
              aria-label="编辑"
              className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors text-[#474747]"
            >
              <EditIcon className="w-5 h-5" />
            </button>
          ) : null}
          <button
            type="button"
            aria-label="分享"
            className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors text-gray-900"
          >
            <ShareIcon className="w-5 h-5" />
          </button>
        </div>
      </header>

      {/* 主内容：分享人头像昵称 → 发布时间（年月日） → 正文 → 交流区 */}
      {post ? (
        <div
          ref={scrollElRef}
          onScroll={handleListScroll}
          className="flex-1 overflow-y-auto overscroll-contain px-4 pt-5 pb-28"
        >
          <div className="flex items-center gap-3">
            <div className="flex-shrink-0 w-11 h-11 rounded-full bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8] flex items-center justify-center overflow-hidden">
              {post.author.avatar && !imgError ? (
                <img
                  src={post.author.avatar}
                  alt={post.author.nickname}
                  className="w-full h-full object-cover"
                  onError={() => setImgError(true)}
                />
              ) : (
                <span className="text-sm font-medium text-white">
                  {post.author.nickname.slice(0, 1)}
                </span>
              )}
            </div>
            <span className="text-base font-semibold text-gray-900 leading-tight">
              {post.author.nickname}
            </span>
          </div>

          <p className="mt-2.5 text-xs text-gray-400">
            {formatYearMonthDay(post.publishedDate ?? post.publishedAt)}
          </p>

          <div className="mt-4 text-[15px] text-gray-800 leading-[1.8] whitespace-pre-wrap break-words">
            {post.content}
          </div>

          {/* 交流区：标题行图标与文本等大，卡片平铺、不支持回复 */}
          <div className="mt-8">
            <div className="flex items-center gap-1.5">
              <ChatIcon className="w-4 h-4 text-gray-900" />
              <span className="text-base font-semibold text-gray-900 leading-none">
                交流
              </span>
            </div>

            {comments.length > 0 ? (
              <div className="mt-3 space-y-3">
                {visibleComments.map((comment) => (
                  <CommentCard
                    key={comment.id}
                    comment={comment}
                    onToggleLit={handleToggleLit}
                    onReport={handleReportComment}
                    onDelete={handleDeleteComment}
                  />
                ))}
              </div>
            ) : (
              <p className="mt-3 text-sm text-gray-400">
                还没有交流，来说点什么吧
              </p>
            )}

            {/* 触底按需加载中：复用下拉刷新的三圆点轮转动效，图标与文本水平居中 */}
            {loadingMore ? (
              <div className="mt-4 flex items-center justify-center gap-2">
                <span className="ptr-loader" aria-hidden />
                <span className="select-none text-sm leading-5 text-gray-400">
                  加载中
                </span>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {/* 底部固定交流框：高斯模糊半透明悬浮层（内容从其后滚过被虚化），灰色胶囊，左侧当前用户头像 + 竖线分割 + 提示文本（点击打开输入面板，不直接聚焦） */}
      <div className="absolute inset-x-0 bottom-0 z-10 border-t border-gray-200/60 bg-white/70 backdrop-blur-xl backdrop-saturate-150 px-4 pt-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
        <div
          role="button"
          tabIndex={-1}
          aria-label="写交流"
          onClick={() => setComposerOpen(true)}
          className="flex items-center gap-3 rounded-full bg-gray-100 pl-1.5 pr-4 py-1.5 cursor-pointer active:bg-gray-200/70 transition-colors"
        >
          <div className="flex-shrink-0 w-8 h-8 rounded-full bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8] flex items-center justify-center overflow-hidden">
            {user?.avatar && !userImgError ? (
              <img
                src={user.avatar}
                alt={user.nickname}
                className="w-full h-full object-cover"
                onError={() => setUserImgError(true)}
              />
            ) : (
              <span className="text-xs font-medium text-white">
                {(user?.nickname || "我").slice(0, 1)}
              </span>
            )}
          </div>
          <span aria-hidden className="flex-shrink-0 w-px h-5 bg-gray-300/80" />
          <span className="flex-1 min-w-0 truncate text-sm text-gray-400">
            与同伴一起同行，会走的更远哦！
          </span>
        </div>
      </div>

      {/* 独立输入面板 */}
      <ComposerPanel
        open={composerOpen}
        onClose={() => setComposerOpen(false)}
        onSend={handleSendComment}
      />
    </div>
  );
}
