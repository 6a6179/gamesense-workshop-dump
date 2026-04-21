#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const ROOT_DIR = path.resolve(__dirname, "..", "..");
const SEARCH_DIRS = [".", "libraries"];

function main() {
    const argumentsList = process.argv.slice(2);
    const jsonMode = argumentsList.includes("--json");
    const fileArguments = argumentsList.filter((argument) => argument !== "--json");
    const files = fileArguments.length > 0 ? fileArguments.map((file) => path.resolve(process.cwd(), file)) : listLuaFiles(ROOT_DIR);
    const report = [];

    for (const filePath of files) {
        const source = fs.readFileSync(filePath, "utf8");

        if (!/\bslot\d+\b/.test(source)) {
            continue;
        }

        const ast = luaparse.parse(source, {
            locations: true,
            ranges: true,
            scope: true,
            luaVersion: "5.1"
        });
        const suggestions = collectTopLevelSuggestions(ast, filePath);

        if (suggestions.length > 0) {
            report.push({
                file: path.relative(ROOT_DIR, filePath),
                suggestions
            });
        }
    }

    if (jsonMode) {
        console.log(JSON.stringify(report, null, 2));
        return;
    }

    for (const entry of report) {
        console.log(entry.file);

        for (const suggestion of entry.suggestions) {
            console.log(`  L${suggestion.line}: ${suggestion.original} -> ${suggestion.suggested} (${suggestion.reason})`);
        }
    }
}

function listLuaFiles(rootDir) {
    const files = [];

    for (const relativeDir of SEARCH_DIRS) {
        const directoryPath = path.join(rootDir, relativeDir);

        for (const entry of fs.readdirSync(directoryPath, { withFileTypes: true })) {
            if (entry.isFile() && entry.name.toLowerCase().endsWith(".lua")) {
                files.push(path.join(directoryPath, entry.name));
            }
        }
    }

    return files.sort();
}

function collectTopLevelSuggestions(ast, filePath) {
    const suggestions = [];
    const fileSlug = sanitizeIdentifier(path.basename(filePath, ".lua")).replace(/^3d_/, "");

    for (const statement of ast.body) {
        if (statement.type === "AssignmentStatement") {
            for (let index = 0; index < statement.variables.length; index += 1) {
                const variable = statement.variables[index];
                const initNode = index < statement.init.length ? statement.init[index] : statement.init[statement.init.length - 1];

                if (variable.type === "Identifier" && isPseudoSlotName(variable.name)) {
                    const suggestion = inferTopLevelName(initNode, fileSlug);

                    if (suggestion) {
                        suggestions.push({
                            original: variable.name,
                            suggested: suggestion.name,
                            reason: suggestion.reason,
                            line: variable.loc.start.line
                        });
                    }
                }
            }
        } else if (statement.type === "FunctionDeclaration" && statement.identifier && statement.identifier.type === "Identifier" && isPseudoSlotName(statement.identifier.name)) {
            suggestions.push({
                original: statement.identifier.name,
                suggested: inferFunctionName(statement, fileSlug),
                reason: "function body heuristic",
                line: statement.identifier.loc.start.line
            });
        }
    }

    return suggestions;
}

function inferTopLevelName(node, fileSlug) {
    if (!node) {
        return null;
    }

    if (node.type === "CallExpression") {
        const callPath = getCallPath(node);

        if (callPath === "require") {
            const moduleName = readStringLiteral(node.arguments[0]);

            if (moduleName) {
                return {
                    name: sanitizeIdentifier(moduleName.split("/").pop()),
                    reason: "require target"
                };
            }
        }

        if (node.base.type === "CallExpression" && getCallPath(node.base) === "require") {
            const moduleName = readStringLiteral(node.base.arguments[0]);

            if (moduleName) {
                return {
                    name: sanitizeIdentifier(moduleName.split("/").pop()),
                    reason: "required module call result"
                };
            }
        }

        if (/^ui\.(new_|reference)/.test(callPath || "")) {
            const label = readStringLiteral(node.arguments[2] || node.arguments[0]);
            const controlKind = (callPath || "").replace(/^ui\.new_/, "").replace(/^ui\./, "");
            const baseName = sanitizeIdentifier(label || fileSlug);

            return {
                name: appendSuffix(baseName, controlKind === "reference" ? "reference" : controlKind),
                reason: "ui control label"
            };
        }

        if (callPath === "client.create_interface") {
            const interfaceName = readStringLiteral(node.arguments[1]);

            if (interfaceName) {
                return {
                    name: `${sanitizeIdentifier(interfaceName)}_interface`,
                    reason: "interface name"
                };
            }
        }

        return {
            name: `${sanitizeIdentifier((callPath || fileSlug).replace(/\./g, "_"))}_result`,
            reason: "call expression"
        };
    }

    if (node.type === "MemberExpression") {
        return {
            name: sanitizeIdentifier(getExpressionPath(node).replace(/\./g, "_")),
            reason: "member alias"
        };
    }

    if (node.type === "TableConstructorExpression") {
        const fields = node.fields
            .map((field) => {
                if (!field.key) {
                    return null;
                }

                if (field.key.type === "Identifier") {
                    return field.key.name;
                }

                if (field.key.type === "StringLiteral") {
                    return readStringLiteral(field.key);
                }

                return null;
            })
            .filter(Boolean);

        return {
            name: fields.length > 0 ? `${sanitizeIdentifier(fields.slice(0, 3).join("_"))}_table` : `${fileSlug}_table`,
            reason: "table keys"
        };
    }

    if (node.type === "StringLiteral") {
        return {
            name: `${sanitizeIdentifier(readStringLiteral(node) || fileSlug)}_text`,
            reason: "string literal"
        };
    }

    return null;
}

function inferFunctionName(functionNode, fileSlug) {
    if (usesCallPath(functionNode.body, "renderer.text") || usesCallPath(functionNode.body, "renderer.circle_outline")) {
        return `draw_${fileSlug}`;
    }

    if (usesCallPath(functionNode.body, "client.set_event_callback") || usesCallPath(functionNode.body, "client.unset_event_callback") || usesCallPath(functionNode.body, "ui.set_visible")) {
        return "update_menu_state";
    }

    if (usesCallPath(functionNode.body, "pairs") || usesCallPath(functionNode.body, "ipairs")) {
        return "iterate_values";
    }

    if (usesCallPath(functionNode.body, "math.atan")) {
        return "calculate_value";
    }

    return `helper_${fileSlug}`;
}

function usesCallPath(body, targetPath) {
    const stack = [...body];

    while (stack.length > 0) {
        const node = stack.pop();

        if (!node || typeof node !== "object") {
            continue;
        }

        if (node.type === "CallExpression" && getCallPath(node) === targetPath) {
            return true;
        }

        for (const child of extractChildNodes(node)) {
            stack.push(child);
        }
    }

    return false;
}

function getCallPath(node) {
    return node && node.type === "CallExpression" ? getExpressionPath(node.base) : null;
}

function getExpressionPath(node) {
    if (!node) {
        return null;
    }

    if (node.type === "Identifier") {
        return node.name;
    }

    if (node.type === "MemberExpression") {
        const basePath = getExpressionPath(node.base);
        return basePath ? `${basePath}.${node.identifier.name}` : node.identifier.name;
    }

    return null;
}

function extractChildNodes(node) {
    const children = [];

    for (const value of Object.values(node)) {
        if (!value) {
            continue;
        }

        if (Array.isArray(value)) {
            for (const child of value) {
                if (child && typeof child === "object" && child.type) {
                    children.push(child);
                }
            }
        } else if (typeof value === "object" && value.type) {
            children.push(value);
        }
    }

    return children;
}

function readStringLiteral(node) {
    if (!node || node.type !== "StringLiteral" || typeof node.raw !== "string") {
        return null;
    }

    return node.raw.replace(/^["']|["']$/g, "");
}

function appendSuffix(baseName, suffix) {
    const cleanSuffix = sanitizeIdentifier(suffix || "value");
    return baseName.endsWith(`_${cleanSuffix}`) ? baseName : `${baseName}_${cleanSuffix}`;
}

function sanitizeIdentifier(rawValue) {
    const value = String(rawValue || "")
        .replace(/\\n/g, " ")
        .replace(/[^\w]+/g, " ")
        .trim()
        .toLowerCase();
    const words = value.split(/\s+/).filter(Boolean);
    let identifier = words.join("_").replace(/_+/g, "_").replace(/^_+|_+$/g, "");

    if (!identifier) {
        identifier = "value";
    }

    if (/^\d/.test(identifier)) {
        identifier = `value_${identifier}`;
    }

    return identifier;
}

function isPseudoSlotName(name) {
    return /^slot\d+$/.test(name);
}

main();
