import { processNodes } from "@/data/resourceMock";
import { ProcessNodeItem } from "./ProcessNodeItem";

export function ProcessTimeline() {
  return (
    <div className="py-4">
      {processNodes.map((node, index) => (
        <ProcessNodeItem
          key={node.id}
          node={node}
          index={index}
          isLast={index === processNodes.length - 1}
          defaultExpanded={index === 0}
        />
      ))}
    </div>
  );
}
