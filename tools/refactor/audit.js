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
        const slotCount = countMatches(source, /\bslot\d+\b/g);
        const uvCount = countMatches(source, /\buv\d+\b/g);

        if (slotCount === 0 && uvCount === 0) {
            continue;
        }

        let parseError = null;
        let unresolvedSlots = [];

        try {
            const ast = luaparse.parse(source, {
                locations: true,
                ranges: true,
                scope: true,
                luaVersion: "5.1"
            });

            unresolvedSlots = collectUnresolvedSlots(ast);
        } catch (error) {
            parseError = error.message;
        }

        report.push({
            file: path.relative(ROOT_DIR, filePath),
            slotCount,
            uvCount,
            unresolvedSlots,
            parseError
        });
    }

    if (jsonMode) {
        console.log(JSON.stringify(report, null, 2));
        return;
    }

    for (const entry of report) {
        console.log(`${entry.file}: slot=${entry.slotCount}, uv=${entry.uvCount}, unresolved_slot_refs=${entry.unresolvedSlots.length}`);

        if (entry.parseError) {
            console.log(`  parse_error: ${entry.parseError}`);
            continue;
        }

        for (const unresolved of entry.unresolvedSlots.slice(0, 8)) {
            console.log(`  L${unresolved.line}: ${unresolved.name}`);
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

function collectUnresolvedSlots(ast) {
    const unresolved = [];
    const rootScope = createScope(null);

    walkStatements(ast.body, rootScope, unresolved);

    return unresolved;
}

function walkStatements(statements, scope, unresolved) {
    for (const statement of statements) {
        walkStatement(statement, scope, unresolved);
    }
}

function walkStatement(statement, scope, unresolved) {
    switch (statement.type) {
        case "AssignmentStatement":
            for (const variable of statement.variables) {
                if (variable.type === "Identifier" && isPseudoSlotName(variable.name)) {
                    declare(scope, variable.name);
                }
            }

            for (const initNode of statement.init) {
                walkNode(initNode, scope, unresolved, new Set());
            }
            break;
        case "FunctionDeclaration":
            if (statement.identifier && statement.identifier.type === "Identifier" && isPseudoSlotName(statement.identifier.name)) {
                declare(scope, statement.identifier.name);
            }

            walkFunction(statement, scope, unresolved);
            break;
        case "ForNumericStatement":
            if (statement.variable.type === "Identifier" && isPseudoSlotName(statement.variable.name)) {
                declare(scope, statement.variable.name);
            }

            walkNode(statement.start, scope, unresolved, new Set());
            walkNode(statement.end, scope, unresolved, new Set());
            if (statement.step) {
                walkNode(statement.step, scope, unresolved, new Set());
            }
            walkStatements(statement.body, scope, unresolved);
            break;
        case "ForGenericStatement":
            for (const variable of statement.variables) {
                if (variable.type === "Identifier" && isPseudoSlotName(variable.name)) {
                    declare(scope, variable.name);
                }
            }

            for (const iterator of statement.iterators) {
                walkNode(iterator, scope, unresolved, new Set());
            }
            walkStatements(statement.body, scope, unresolved);
            break;
        case "IfStatement":
            for (const clause of statement.clauses) {
                if (clause.condition) {
                    walkNode(clause.condition, scope, unresolved, new Set());
                }

                walkStatements(clause.body, scope, unresolved);
            }
            break;
        case "DoStatement":
        case "WhileStatement":
        case "RepeatStatement":
            if (statement.condition) {
                walkNode(statement.condition, scope, unresolved, new Set());
            }
            walkStatements(statement.body, scope, unresolved);
            break;
        default:
            walkNode(statement, scope, unresolved, new Set());
    }
}

function walkFunction(functionNode, parentScope, unresolved) {
    const functionScope = createScope(parentScope);

    for (const parameter of functionNode.parameters) {
        if (parameter.type === "Identifier" && isPseudoSlotName(parameter.name)) {
            declare(functionScope, parameter.name);
        }
    }

    walkStatements(functionNode.body, functionScope, unresolved);
}

function walkNode(node, scope, unresolved, declarationNodes) {
    if (!node || typeof node !== "object") {
        return;
    }

    if (node.type === "FunctionDeclaration") {
        walkFunction(node, scope, unresolved);
        return;
    }

    if (node.type === "Identifier" && isPseudoSlotName(node.name) && !declarationNodes.has(node) && !lookup(scope, node.name)) {
        unresolved.push({
            name: node.name,
            line: node.loc.start.line
        });
        return;
    }

    const nestedDeclarationNodes = new Set(declarationNodes);

    if (node.type === "AssignmentStatement") {
        for (const variable of node.variables) {
            if (variable.type === "Identifier") {
                nestedDeclarationNodes.add(variable);
            }
        }
    } else if (node.type === "FunctionDeclaration") {
        if (node.identifier && node.identifier.type === "Identifier") {
            nestedDeclarationNodes.add(node.identifier);
        }
        for (const parameter of node.parameters) {
            if (parameter.type === "Identifier") {
                nestedDeclarationNodes.add(parameter);
            }
        }
    }

    for (const child of extractChildNodes(node)) {
        walkNode(child, scope, unresolved, nestedDeclarationNodes);
    }
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

function createScope(parent) {
    return {
        parent,
        declarations: new Set()
    };
}

function declare(scope, name) {
    scope.declarations.add(name);
}

function lookup(scope, name) {
    let currentScope = scope;

    while (currentScope) {
        if (currentScope.declarations.has(name)) {
            return true;
        }

        currentScope = currentScope.parent;
    }

    return false;
}

function countMatches(text, pattern) {
    const matches = text.match(pattern);
    return matches ? matches.length : 0;
}

function isPseudoSlotName(name) {
    return /^slot\d+$/.test(name);
}

main();
