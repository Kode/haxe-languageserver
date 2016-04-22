package features;

import haxe.extern.EitherType;
import vscode.BasicTypes;
import vscode.ProtocolTypes;
import jsonrpc.Protocol;
import jsonrpc.ErrorCodes.internalError;
import HaxeDisplayTypes;

class GotoDefinitionFeature extends Feature {
    override function init() {
        context.protocol.onGotoDefinition = onGotoDefinition;
    }

    function onGotoDefinition(params:TextDocumentPositionParams, token:RequestToken, resolve:EitherType<Location,Array<Location>>->Void, reject:RejectHandler) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@position'];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:Array<Pos> = try haxe.Json.parse(data) catch (_:Dynamic) return reject(internalError("Invalid JSON data: " + data));

            var results = [];
            for (pos in data) {
                var location = HaxePosition.parseJson(pos, doc, null); // no cache because this right now only returns one position
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
