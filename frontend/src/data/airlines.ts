import sichuanAirlineIcon from "@/assets/airline-sichuan.svg";
import easternAirlineIcon from "@/assets/airline-eastern.svg";
import chinaAirlineIcon from "@/assets/airline-china.svg";
import ruiliAirlineIcon from "@/assets/airline-ruili.svg";
import southernAirlineIcon from "@/assets/airline-southern.svg";
import franceAirlineIcon from "@/assets/airline-france.svg";
import juneyaoAirlineIcon from "@/assets/airline-juneyao.svg";
import xiamenAirlineIcon from "@/assets/airline-xiamen.svg";
import springAirlineIcon from "@/assets/airline-spring.svg";
import koreanAirlineIcon from "@/assets/airline-korean.svg";
import shandongAirlineIcon from "@/assets/airline-shandong.svg";

/** 承运航司数据（mock 阶段静态数据，后续接入接口后替换）。 */
export interface Airline {
  name: string;
  icon: string;
}

export const AIRLINES: Airline[] = [
  { name: "四川航空", icon: sichuanAirlineIcon },
  { name: "东方航空", icon: easternAirlineIcon },
  { name: "中国航空", icon: chinaAirlineIcon },
  { name: "瑞丽航空", icon: ruiliAirlineIcon },
  { name: "南方航空", icon: southernAirlineIcon },
  { name: "法国航空", icon: franceAirlineIcon },
  { name: "厦门航空", icon: xiamenAirlineIcon },
  { name: "春秋航空", icon: springAirlineIcon },
  { name: "吉祥航空", icon: juneyaoAirlineIcon },
  { name: "大韩航空", icon: koreanAirlineIcon },
  { name: "山东航空", icon: shandongAirlineIcon },
];
