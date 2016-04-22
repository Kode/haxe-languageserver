package features;

import vscode.BasicTypes;
import vscode.ProtocolTypes;
import jsonrpc.Protocol;
import jsonrpc.ErrorCodes.internalError;
import HaxeDisplayTypes;

class FindReferencesFeature extends Feature {
    override function init() {
        context.protocol.onFindReferences = onFindReferences;
    }

    function onFindReferences(params:TextDocumentPositionParams, token:RequestToken, resolve:Array<Location>->Void, reject:RejectHandler) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@usage'];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:Array<Pos> = try haxe.Json.parse(data) catch (_:Dynamic) return reject(internalError("Invalid JSON data: " + data));

            var results = [];
            var haxePosCache = new Map();
            for (pos in data) {
                var location = HaxePosition.parseJson(pos, doc, haxePosCache);
                if (location == null) {
                    trace("Got invalid position: " + pos);
                    continue;
                }
                results.push(location);
            }

            return resolve(results);
        });
    }
}
