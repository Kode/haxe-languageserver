package features;

import vscode.BasicTypes;
import vscode.ProtocolTypes;
import jsonrpc.Protocol;
import jsonrpc.ErrorCodes.internalError;

import HaxeDisplayTypes;

class HoverFeature extends Feature {
    override function init() {
        context.protocol.onHover = onHover;
    }

    function onHover(params:TextDocumentPositionParams, token:RequestToken, resolve:Hover->Void, reject:RejectHandler) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@type'];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:{range:Range, type:TypeInfo} = try haxe.Json.parse(data) catch (_:Dynamic) return reject(internalError("Invalid JSON data: " + data));

            var result:Hover = {contents: TypePrinter.printType(data.type)};
            if (data.range != null) {
                inline function bytePosToCharPos(p) {
                    var line = doc.lineAt(p.line);
                    return {line: p.line, character: HaxePosition.byteOffsetToCharacterOffset(line, p.character)};
                }
                result.range = {
                    start: bytePosToCharPos(data.range.start),
                    end: bytePosToCharPos(data.range.end),
                };
            }

            resolve(result);
        });
    }
}
