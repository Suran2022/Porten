import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import type { Components } from "react-markdown";

interface MarkdownProps {
  content: string;
}

/**
 * 排版良好的 Markdown 渲染器。
 * 不依赖 @tailwindcss/typography 插件，自带移动端友好的层级、表格、引用样式。
 */
const components: Components = {
  h1: ({ children, ...props }) => (
    <h1
      className="text-[22px] font-semibold text-gray-900 leading-snug mt-7 mb-3 pb-2 border-b border-gray-100"
      {...props}
    >
      {children}
    </h1>
  ),
  h2: ({ children, ...props }) => (
    <h2
      className="text-[19px] font-semibold text-gray-900 leading-snug mt-7 mb-3 pb-2 border-b border-gray-100"
      {...props}
    >
      {children}
    </h2>
  ),
  h3: ({ children, ...props }) => (
    <h3
      className="text-[17px] font-semibold text-gray-900 leading-snug mt-5 mb-2"
      {...props}
    >
      {children}
    </h3>
  ),
  h4: ({ children, ...props }) => (
    <h4
      className="text-[15px] font-semibold text-gray-900 mt-4 mb-2"
      {...props}
    >
      {children}
    </h4>
  ),
  p: ({ children, ...props }) => (
    <p className="text-[15px] text-gray-800 leading-[1.85] my-2.5" {...props}>
      {children}
    </p>
  ),
  ul: ({ children, ...props }) => (
    <ul
      className="my-3 pl-6 list-disc text-[15px] text-gray-800 leading-[1.85] space-y-1.5"
      {...props}
    >
      {children}
    </ul>
  ),
  ol: ({ children, ...props }) => (
    <ol
      className="my-3 pl-6 list-decimal text-[15px] text-gray-800 leading-[1.85] space-y-1.5"
      {...props}
    >
      {children}
    </ol>
  ),
  li: ({ children, ...props }) => (
    <li className="pl-1" {...props}>
      {children}
    </li>
  ),
  blockquote: ({ children, ...props }) => (
    <blockquote
      className="my-4 px-4 py-3 bg-gray-50 border-l-4 border-gray-300 text-gray-700 rounded-r-md leading-[1.8]"
      {...props}
    >
      {children}
    </blockquote>
  ),
  table: ({ children, ...props }) => (
    <div className="my-5 w-full overflow-x-auto rounded-lg border border-gray-200">
      <table
        className="w-full border-collapse text-[14px] text-gray-800"
        {...props}
      >
        {children}
      </table>
    </div>
  ),
  thead: ({ children, ...props }) => (
    <thead className="bg-gray-50" {...props}>
      {children}
    </thead>
  ),
  th: ({ children, ...props }) => (
    <th
      className="px-3.5 py-2.5 text-left font-semibold text-gray-700 border-b border-gray-200 whitespace-nowrap"
      {...props}
    >
      {children}
    </th>
  ),
  td: ({ children, ...props }) => (
    <td
      className="px-3.5 py-2.5 text-gray-800 border-b border-gray-100 align-top"
      {...props}
    >
      {children}
    </td>
  ),
  tr: ({ children, ...props }) => (
    <tr
      className="even:bg-gray-50/50 last:border-b-0"
      {...props}
    >
      {children}
    </tr>
  ),
  code: ({ children, className, ...props }) => {
    const isBlock = className?.startsWith("language-");
    if (isBlock) {
      return (
        <code
          className="block bg-gray-900 text-gray-100 p-4 rounded-md text-[13px] font-mono leading-relaxed overflow-x-auto my-3"
          {...props}
        >
          {children}
        </code>
      );
    }
    return (
      <code
        className="bg-gray-100 text-pink-600 px-1.5 py-0.5 rounded text-[13px] font-mono"
        {...props}
      >
        {children}
      </code>
    );
  },
  pre: ({ children, ...props }) => (
    <pre
      className="my-4"
      {...props}
    >
      {children}
    </pre>
  ),
  a: ({ children, ...props }) => (
    <a
      className="text-pink-600 underline underline-offset-2 break-all"
      target="_blank"
      rel="noreferrer"
      {...props}
    >
      {children}
    </a>
  ),
  hr: ({ ...props }) => (
    <hr className="my-6 border-t border-gray-200" {...props} />
  ),
  strong: ({ children, ...props }) => (
    <strong className="font-semibold text-gray-900" {...props}>
      {children}
    </strong>
  ),
  em: ({ children, ...props }) => (
    <em className="italic text-gray-700" {...props}>
      {children}
    </em>
  ),
  img: ({ ...props }) => (
    <img
      className="max-w-full h-auto rounded-md my-3"
      {...props}
    />
  ),
};

export function Markdown({ content }: MarkdownProps) {
  return (
    <div className="text-[15px] text-gray-800">
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
        {content}
      </ReactMarkdown>
    </div>
  );
}
