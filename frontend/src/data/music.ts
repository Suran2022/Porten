export interface MusicTrack {
  id: string;
  title: string;
  subtitle?: string;
  artist: string;
  duration: number; // seconds
  currentTime: number; // seconds
  quality: string;
  likes: string;
  comments: string;
  bgGradient: string;
  vinylColor: string;
  coverLabel: string;
  lrcSrc?: string; // 歌词文件路径，相对 public 根
  audioSrc?: string; // 音频文件路径，相对 public 根，无则不可播放
}

export const MUSIC_TRACKS: MusicTrack[] = [
  {
    id: "1",
    title: "眉间雪",
    subtitle: "Cover 晴愔",
    artist: "锦零",
    duration: 269,
    currentTime: 109,
    quality: "极高音质",
    likes: "14w+",
    comments: "999+",
    bgGradient:
      "linear-gradient(180deg, #3d2817 0%, #2f1f12 30%, #231710 60%, #1a1108 85%, #1a1108 100%)",
    vinylColor: "#1a1a1a",
    coverLabel: "bmb",
    lrcSrc: "/musice-back1.lrc",
    audioSrc: "/musice-back1.mp3",
  },
  {
    id: "2",
    title: "深海",
    subtitle: "Original Mix",
    artist: "蓝调",
    duration: 225,
    currentTime: 80,
    quality: "无损",
    likes: "8.5w",
    comments: "420",
    bgGradient:
      "linear-gradient(180deg, #2c3e50 0%, #243340 30%, #1a2733 60%, #0f1820 85%, #0f1820 100%)",
    vinylColor: "#0e1116",
    coverLabel: "ocn",
  },
  {
    id: "3",
    title: "黄昏的车站",
    subtitle: "Acoustic",
    artist: "云雀",
    duration: 312,
    currentTime: 145,
    quality: "极高音质",
    likes: "5.2w",
    comments: "186",
    bgGradient:
      "linear-gradient(180deg, #4a3528 0%, #3d2c20 30%, #322318 60%, #1f1410 85%, #1f1410 100%)",
    vinylColor: "#181410",
    coverLabel: "stn",
  },
  {
    id: "4",
    title: "雨后",
    subtitle: "Piano Ver.",
    artist: "小屿",
    duration: 198,
    currentTime: 60,
    quality: "标准",
    likes: "2.3w",
    comments: "92",
    bgGradient:
      "linear-gradient(180deg, #3a3530 0%, #312c29 30%, #252220 60%, #161413 85%, #161413 100%)",
    vinylColor: "#131312",
    coverLabel: "rn",
  },
];
