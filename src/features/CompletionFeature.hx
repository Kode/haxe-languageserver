package features;

import vscode.BasicTypes;
import vscode.ProtocolTypes;
import jsonrpc.Protocol;
import jsonrpc.ErrorCodes.internalError;

import SignatureHelper.prepareSignature;
import HaxeDisplayTypes;

class CompletionFeature extends Feature {
    override function init() {
        context.protocol.onCompletion = onCompletion;
        showHaxeErrorMessages = false;
    }

    function onCompletion(params:TextDocumentPositionParams, token:RequestToken, resolve:Array<CompletionItem>->Void, reject:RejectHandler) {
        var doc = context.documents.get(params.textDocument.uri);
        var r = calculateCompletionPosition(doc.content, doc.offsetAt(params.position));
        var bytePos = doc.offsetToByteOffset(r.pos);
        var args = ["--display", '${doc.fsPath}@$bytePos' + (if (r.toplevel) "@toplevel" else "")];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var items =
                if (r.toplevel) {
                    var data:Array<ToplevelCompletionItem> = try haxe.Json.parse(data) catch (_:Dynamic) return reject(internalError("Invalid JSON data: " + data));
                    parseToplevelCompletion(data);
                } else {
                    var xml = try Xml.parse(data).firstElement() catch (_:Dynamic) null;
                    if (xml == null) return reject(internalError("Invalid xml data: " + data));
                    parseFieldCompletion(xml);
                };

            resolve(items);
        });
    }

    static var reFieldPart = ~/\.(\w*)$/;
    static function calculateCompletionPosition(text:String, index:Int):CompletionPosition {
        text = text.substring(0, index);
        if (reFieldPart.match(text))
            return {
                pos: index - reFieldPart.matched(1).length,
                toplevel: false,
            };
        else
            return {
                pos: index,
                toplevel: true,
            };
    }

    static function parseToplevelCompletion(completion:Array<ToplevelCompletionItem>):Array<CompletionItem> {
        var result = [];
        for (el in completion) {
            var kind:CompletionItemKind, name, fullName = null, type = null;
            switch (el.kind) {
                case Local:
                    kind = Variable;
                    name = el.name;
                    type = el.type;
                case Member | Static:
                    kind = Field;
                    name = el.name;
                    type = el.type;
                case Enum:
                    kind = Enum;
                    name = el.name;
                    type = el.type;
                case Global:
                    kind = Variable;
                    name = el.name;
                    type = el.type;
                    fullName = TypePrinter.printTypePath(el.parent) + "." + el.name;
                case Type:
                    kind = Class;
                    name = el.path.name;
                    fullName = TypePrinter.printTypePath(el.path);
                case Package:
                    kind = Module;
                    name = el.name;
            }

            if (fullName == name)
                fullName = null;

            var item:CompletionItem = {
                label: name,
                kind: kind,
            }

            if (type != null || fullName != null) {
                var parts = [];
                if (fullName != null)
                    parts.push('($fullName)');
                if (type != null)
                    parts.push(TypePrinter.printTypeInner(type));
                item.detail = parts.join(" ");
            }

            result.push(item);
        }
        return result;
    }

    static function parseFieldCompletion(x:Xml):Array<CompletionItem> {
        var result = [];
        for (el in x.elements()) {
            var kind = fieldKindToCompletionItemKind(el.get("k"));
            var type = null, doc = null;
            for (child in el.elements()) {
                switch (child.nodeName) {
                    case "t": type = child.firstChild().nodeValue;
                    case "d": doc = child.firstChild().nodeValue;
                }
            }
            var name = el.get("n");
            var item:CompletionItem = {label: name};
            if (doc != null) item.documentation = doc;
            if (kind != null) item.kind = kind;
            if (type != null) item.detail = formatType(type, name, kind);
            result.push(item);
        }
        return result;
    }

    static function formatType(type:String, name:String, kind:CompletionItemKind):String {
        return switch (kind) {
            case Method: name + prepareSignature(type);
            default: type;
        }
    }

    static function fieldKindToCompletionItemKind(kind:String):CompletionItemKind {
        return switch (kind) {
            case "var": Field;
            case "method": Method;
            case "type": Class;
            case "package": Module;
            default: trace("unknown field item kind: " + kind); null;
        }
    }
}

private typedef CompletionPosition = {
    var pos:Int;
    var toplevel:Bool;
}
