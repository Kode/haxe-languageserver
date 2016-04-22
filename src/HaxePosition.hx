import vscode.BasicTypes.Location;

class HaxePosition {
    static var positionRe = ~/^(.+):(\d+): (?:lines (\d+)-(\d+)|character(?:s (\d+)-| )(\d+))$/;
    static var properFileNameCaseCache:Map<String,String>;
    static var isWindows = (Sys.systemName() == "Windows");

    // TODO: extract range handling since sometimes we just need a range in the stdin file and don't
    // need the rest of the logic

    public static function parse(pos:String, doc:TextDocument, cache:Map<String,Array<String>>):Null<Location> {
        if (!positionRe.match(pos))
            return null;

        var file = getProperFileNameCase(positionRe.matched(1));
        var s = positionRe.matched(3);
        if (s != null) { // line span
            var startLine = Std.parseInt(s);
            var endLine = Std.parseInt(positionRe.matched(4));
            return {
                uri: if (file == doc.fsPath) doc.uri else Uri.fsPathToUri(file),
                range: {
                    start: {line: startLine - 1, character: 0},
                    end: {line: endLine - 1, character: 0},
                }
            };
        } else { // char span
            var line = Std.parseInt(positionRe.matched(2));
            line--;

            var lineContent, uri;
            if (file == doc.fsPath) {
                // it's a stdin file, we have its content in memory
                lineContent = doc.lineAt(line);
                uri = doc.uri;
            } else {
                // we have to read lines from a file on disk (cache if available)
                var lines;
                if (cache == null) {
                    lines = sys.io.File.getContent(file).split("\n");
                } else {
                    lines = cache[file];
                    if (lines == null)
                        lines = cache[file] = sys.io.File.getContent(file).split("\n");
                }
                lineContent = lines[line];
                uri = Uri.fsPathToUri(file);
            }

            var endByte = Std.parseInt(positionRe.matched(6));
            var endChar = byteOffsetToCharacterOffset(lineContent, endByte);

            s = positionRe.matched(5);
            var startChar;
            if (s != null) {
                var startByte = Std.parseInt(s);
                startChar = byteOffsetToCharacterOffset(lineContent, startByte);
            } else {
                startChar = endChar;
            }

            return {
                uri: uri,
                range: {
                    start: {line: line, character: startChar},
                    end: {line: line, character: endChar},
                }
            };
        }
    }

    public static function parseJson(pos:HaxeDisplayTypes.Pos, doc:TextDocument, cache:Map<String,Array<String>>):Null<Location> {
        if (pos == null)
            return null;

        var file = getProperFileNameCase(pos.file);
        var uri, getLine;
        if (file == doc.fsPath) {
            uri = doc.uri;
            getLine = doc.lineAt;
        } else {
            uri = Uri.fsPathToUri(file);
            var lines;
            if (cache == null) {
                lines = sys.io.File.getContent(file).split("\n");
            } else {
                lines = cache[file];
                if (lines == null)
                    lines = cache[file] = sys.io.File.getContent(file).split("\n");
            }
            getLine = function(n) return lines[n];
        }

        var line = getLine(pos.start.line);
        var startChar = byteOffsetToCharacterOffset(line, pos.start.character);
        if (pos.end.line != pos.start.line)
            line = getLine(pos.end.line);
        var endChar = byteOffsetToCharacterOffset(line, pos.end.character);

        return {
            uri: uri,
            range: {
                start: {line: pos.start.line, character: startChar},
                end: {line: pos.end.line, character: endChar},
            }
        };
    }

    public static inline function byteOffsetToCharacterOffset(string:String, byteOffset:Int):Int {
        var buf = new js.node.Buffer(string, "utf-8");
        return buf.toString("utf-8", 0, byteOffset).length;
    }

    static function getProperFileNameCase(normalizedPath:String):String {
        if (!isWindows) return normalizedPath;
        if (properFileNameCaseCache == null) {
            properFileNameCaseCache = new Map();
        } else {
            var cached = properFileNameCaseCache[normalizedPath];
            if (cached != null)
                return cached;
        }
        var result = normalizedPath;
        var parts = normalizedPath.split("\\");
        if (parts.length > 1) {
            var acc = parts[0];
            for (i in 1...parts.length) {
                var part = parts[i];
                for (realFile in sys.FileSystem.readDirectory(acc)) {
                    if (realFile.toLowerCase() == part) {
                        part = realFile;
                        break;
                    }
                }
                acc = acc + "/" + part;
            }
            result = acc;
        }
        return properFileNameCaseCache[normalizedPath] = result;
    }
}
