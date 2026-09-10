import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
export function Logo() { return _jsxs("div", { className: "logo", children: [_jsx("span", { children: "D" }), _jsx("strong", { children: "DPL" })] }); }
export function SectionHeader({ eyebrow, title, description, action }) { return _jsxs("div", { className: "section-header", children: [_jsxs("div", { children: [_jsx("p", { className: "eyebrow", children: eyebrow }), _jsx("h1", { children: title }), description && _jsx("p", { className: "description", children: description })] }), action] }); }
