export function ResourceTipCard() {
  return (
    <div className="relative mx-4 mt-3 p-4 border border-gray-200 rounded-[10px] bg-white overflow-hidden">
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            "linear-gradient(135deg, rgba(91, 206, 250, 0.22) 0%, rgba(245, 169, 184, 0.14) 35%, rgba(255, 255, 255, 0) 60%)",
        }}
      />
      <p className="relative text-sm text-gray-600 leading-relaxed">
        Porten 医疗资源来自跨儿组织和志愿者，均为跨儿们就医的医院。但因地区和个人情况不同，因此请根据个人情况选择所在城市或外地医院。
      </p>
    </div>
  );
}
