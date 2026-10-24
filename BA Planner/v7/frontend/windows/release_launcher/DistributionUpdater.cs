using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

// Kept outside app/: no Python/Flutter process is needed while app/ is swapped.
internal static class DistributionUpdater
{
    internal const string LauncherVersion = "1.0.0";
    internal static Func<string, byte[]> Fetch = Download;
    internal static Action BeforePublish = delegate { };
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 16777216 };

    internal static string Sha(byte[] bytes)
    {
        using (var hash = SHA256.Create())
            return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant();
    }

    private static byte[] Download(string address)
    {
        var uri = SecureUri(address);
        var request = (HttpWebRequest)WebRequest.Create(uri);
        request.Timeout = 15000;
        request.ReadWriteTimeout = 15000;
        request.UserAgent = "BA-Planner-v7-Launcher/" + LauncherVersion;
        using (var response = (HttpWebResponse)request.GetResponse())
        {
            SecureUri(response.ResponseUri.AbsoluteUri);
            if (response.ContentLength > 1073741824) throw new InvalidDataException("update too large");
            using (var input = response.GetResponseStream())
            using (var output = new MemoryStream())
            {
                var buffer = new byte[65536];
                int count;
                while ((count = input.Read(buffer, 0, buffer.Length)) > 0)
                {
                    if (output.Length + count > 1073741824) throw new InvalidDataException("update too large");
                    output.Write(buffer, 0, count);
                }
                return output.ToArray();
            }
        }
    }

    private static Uri SecureUri(string text)
    {
        Uri uri;
        if (!Uri.TryCreate(text, UriKind.Absolute, out uri) || uri.Scheme != "https" ||
            !String.IsNullOrEmpty(uri.UserInfo) || !String.IsNullOrEmpty(uri.Fragment))
            throw new InvalidDataException("HTTPS update URL required");
        return uri;
    }

    private static Dictionary<string, object> Object(object value)
    {
        var result = value as Dictionary<string, object>;
        if (result == null) throw new InvalidDataException("object required");
        return result;
    }

    private static Dictionary<string, object> ReadJson(byte[] raw)
    {
        if (raw.Length > 16777216) throw new InvalidDataException("JSON too large");
        return Object(Json.DeserializeObject(new UTF8Encoding(false, true).GetString(raw)));
    }

    private static void Keys(Dictionary<string, object> value, string[] required, string[] optional)
    {
        if (required.Any(key => !value.ContainsKey(key)) ||
            value.Keys.Any(key => !required.Contains(key) && !optional.Contains(key)))
            throw new InvalidDataException("unexpected fields");
    }

    private static string Text(Dictionary<string, object> value, string key)
    {
        object result;
        if (!value.TryGetValue(key, out result) || !(result is string)) throw new InvalidDataException("string required");
        return (string)result;
    }

    private static long Integer(object value)
    {
        if (!(value is int) && !(value is long)) throw new InvalidDataException("integer required");
        long result = Convert.ToInt64(value);
        if (result < 0) throw new InvalidDataException("nonnegative integer required");
        return result;
    }

    private static void Hex(string value)
    {
        if (!Regex.IsMatch(value, "^[a-f0-9]{64}$")) throw new InvalidDataException("SHA256 required");
    }

    private static void VersionSyntax(string value)
    {
        if (!Regex.IsMatch(value, @"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$"))
            throw new InvalidDataException("version required");
    }

    private static int NumberCompare(string a, string b)
    {
        a = a.TrimStart('0'); b = b.TrimStart('0');
        return a.Length != b.Length ? a.Length.CompareTo(b.Length) : String.CompareOrdinal(a, b);
    }

    internal static int CompareVersions(string a, string b)
    {
        VersionSyntax(a); VersionSyntax(b);
        var left = a.Split(new[] {'-'}, 2); var right = b.Split(new[] {'-'}, 2);
        var l = left[0].Split('.'); var r = right[0].Split('.');
        for (int i = 0; i < 3; i++) { int cmp = NumberCompare(l[i], r[i]); if (cmp != 0) return cmp; }
        if (left.Length == 1 || right.Length == 1) return right.Length.CompareTo(left.Length);
        l = left[1].Split('.'); r = right[1].Split('.');
        for (int i = 0; i < Math.Min(l.Length, r.Length); i++)
        {
            bool ln = Regex.IsMatch(l[i], "^[0-9]+$"); bool rn = Regex.IsMatch(r[i], "^[0-9]+$");
            int cmp = ln && rn ? NumberCompare(l[i], r[i]) : ln != rn ? (ln ? -1 : 1) : String.CompareOrdinal(l[i], r[i]);
            if (cmp != 0) return cmp;
        }
        return l.Length.CompareTo(r.Length);
    }

    internal static Dictionary<string, object> Descriptor(byte[] raw, string kind)
    {
        if (kind != "app" && kind != "data") throw new InvalidDataException("unknown update kind");
        var value = ReadJson(raw);
        Keys(value, new[] {"schemaVersion","releaseType","appVersion","dataVersionId","dataSnapshotSha256","zipUrl","sha256","notes","minLauncher"}, new string[0]);
        if (Integer(value["schemaVersion"]) != 1 || Text(value,"releaseType") != kind) throw new InvalidDataException("descriptor version/type");
        VersionSyntax(Text(value,"appVersion")); VersionSyntax(Text(value,"minLauncher"));
        if (CompareVersions(Text(value,"minLauncher"), LauncherVersion) > 0) throw new InvalidDataException("launcher too old");
        if (!Regex.IsMatch(Text(value,"dataVersionId"), "^(jp|steam)-[a-z0-9][a-z0-9._-]*$")) throw new InvalidDataException("data version");
        Hex(Text(value,"sha256")); Hex(Text(value,"dataSnapshotSha256")); SecureUri(Text(value,"zipUrl"));
        if (Text(value,"notes").Length < 1 || Text(value,"notes").Length > 8192) throw new InvalidDataException("notes length");
        return value;
    }

    internal static string Portable(string name)
    {
        if (String.IsNullOrEmpty(name) || name.StartsWith("/") || name.IndexOfAny(new[] {'\\',':','\0'}) >= 0 || name.Any(Char.IsControl))
            throw new InvalidDataException("unsafe archive name");
        foreach (string part in name.Split('/'))
        {
            string stem = part.Split('.')[0];
            if (part.Length == 0 || part == "." || part == ".." || part.EndsWith(".") || part.EndsWith(" ") ||
                part.IndexOfAny(new[] {'<','>','"','|','?','*'}) >= 0 ||
                Regex.IsMatch(stem, "^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$", RegexOptions.IgnoreCase))
                throw new InvalidDataException("unsafe archive component");
        }
        return name;
    }

    private static string Inside(string root, string relative)
    {
        Portable(relative);
        string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string target = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("path escape");
        return target;
    }

    private static bool DataMember(string name)
    {
        return name.StartsWith("app/backend/data/", StringComparison.Ordinal) ||
            name == "app/.ba_planner_data_snapshot.json" || name == "app/CHANGELOG-data.md";
    }

    private static void NoLinks(string root)
    {
        if ((File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0) throw new InvalidDataException("linked directory");
        foreach (string file in Directory.GetFileSystemEntries(root))
        {
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) throw new InvalidDataException("linked member");
            if (Directory.Exists(file)) NoLinks(file);
        }
    }

    private static void CopyTree(string source, string target)
    {
        NoLinks(source);
        Directory.CreateDirectory(target);
        foreach (string file in Directory.GetFiles(source)) File.Copy(file, Path.Combine(target, Path.GetFileName(file)));
        foreach (string directory in Directory.GetDirectories(source)) CopyTree(directory, Path.Combine(target, Path.GetFileName(directory)));
    }

    private static void DeleteOwnedTree(string root, string name)
    {
        if (name != "app-staging" && name != "app-previous") throw new InvalidDataException("not updater-owned");
        string path = Inside(root, name);
        if (!Directory.Exists(path)) return;
        NoLinks(path);
        Directory.Delete(path, true);
    }

    private static void ValidateSnapshot(string app, string expected)
    {
        var raw = File.ReadAllBytes(Path.Combine(app,".ba_planner_data_snapshot.json"));
        if (Sha(raw) != expected) throw new InvalidDataException("snapshot SHA mismatch");
        var snapshot = ReadJson(raw);
        if (Integer(snapshot["schemaVersion"]) != 1) throw new InvalidDataException("snapshot version");
        Keys(snapshot,new[] {"schemaVersion","dataVersionId","lockSha256","pins","extracts","provenanceScope","files"},new string[0]);
        Hex(Text(snapshot,"lockSha256"));
        if (!Regex.IsMatch(Text(snapshot,"dataVersionId"),"^(jp|steam)-[a-z0-9][a-z0-9._-]*$") ||
            Text(snapshot,"provenanceScope")!="lock-records-only; shipped-files-hashed-separately; manual-fields-retained")
            throw new InvalidDataException("snapshot identity/provenance");
        var files = snapshot["files"] as object[];
        if (files==null || files.Length==0) throw new InvalidDataException("snapshot files");
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (object rawPin in files)
        {
            var pin=Object(rawPin); Keys(pin,new[] {"path","bytes","sha256"},new string[0]);
            string relative = Portable(Text(pin,"path"));
            if (!relative.StartsWith("backend/data/", StringComparison.Ordinal) || !seen.Add(relative)) throw new InvalidDataException("snapshot scope");
            Hex(Text(pin,"sha256"));
            byte[] bytes = File.ReadAllBytes(Inside(app,relative));
            if (bytes.LongLength != Integer(pin["bytes"]) || Sha(bytes) != Text(pin,"sha256")) throw new InvalidDataException("snapshot file differs");
        }
        string data = Path.Combine(app,"backend","data");
        if (!Directory.Exists(data)) throw new InvalidDataException("data missing");
        NoLinks(data);
        foreach (string file in Directory.GetFiles(data,"*",SearchOption.AllDirectories))
        {
            string relative = file.Substring(app.TrimEnd(Path.DirectorySeparatorChar).Length + 1).Replace('\\','/');
            if (!seen.Contains(relative)) throw new InvalidDataException("unlisted data file");
        }
    }

    internal static void Install(string root, Dictionary<string, object> descriptor, byte[] zipBytes)
    {
        descriptor=Descriptor(Encoding.UTF8.GetBytes(Json.Serialize(descriptor)),Text(descriptor,"releaseType"));
        root = Path.GetFullPath(root);
        string app = Inside(root,"app"), staging = Inside(root,"app-staging"), previous = Inside(root,"app-previous");
        if (Directory.Exists(staging) || Directory.Exists(previous)) throw new InvalidDataException("unfinished update needs recovery");
        NoLinks(root);
        if (Sha(zipBytes) != Text(descriptor,"sha256")) throw new InvalidDataException("ZIP SHA mismatch");
        string kind = Text(descriptor,"releaseType");
        var installed=Installed(root);
        if (kind=="data" && Text(descriptor,"appVersion")!=Text(installed,"appVersion") ||
            kind=="app" && CompareVersions(Text(descriptor,"appVersion"),Text(installed,"appVersion"))<0)
            throw new InvalidDataException("incompatible app version or downgrade");
        bool moved = false;
        try
        {
            using (var memory = new MemoryStream(zipBytes, false))
            using (var zip = new ZipArchive(memory,ZipArchiveMode.Read))
            {
                var members = new Dictionary<string,ZipArchiveEntry>(StringComparer.OrdinalIgnoreCase);
                long totalBytes=0;
                foreach (var entry in zip.Entries)
                {
                    if (entry.Length>1073741824 || totalBytes>4294967296L-entry.Length) throw new InvalidDataException("archive expansion limit");
                    totalBytes+=entry.Length;
                    string name = Portable(entry.FullName);
                    int mode = (entry.ExternalAttributes >> 16) & 0xF000;
                    if (mode == 0xA000 || mode == 0x4000 || !members.TryAddCompat(name,entry)) throw new InvalidDataException("linked/directory/duplicate ZIP member");
                }
                ZipArchiveEntry manifestEntry;
                if (!members.TryGetValue("release-manifest.json",out manifestEntry)) throw new InvalidDataException("manifest missing");
                var manifest = ReadJson(ReadEntry(manifestEntry,16777216));
                Keys(manifest,new[] {"schemaVersion","releaseType","appVersion","dataVersionId","dataSnapshotSha256","files"},new[] {"bundledUiAssets"});
                if (Integer(manifest["schemaVersion"]) != 1) throw new InvalidDataException("manifest version");
                foreach (string key in new[] {"releaseType","appVersion","dataVersionId","dataSnapshotSha256"})
                    if (Text(manifest,key) != Text(descriptor,key)) throw new InvalidDataException("manifest descriptor mismatch");
                if (manifest.ContainsKey("bundledUiAssets") && (!(manifest["bundledUiAssets"] is bool) || kind == "data" && (bool)manifest["bundledUiAssets"]))
                    throw new InvalidDataException("UI policy");
                var listed = new Dictionary<string,Dictionary<string,object>>(StringComparer.OrdinalIgnoreCase);
                var files = manifest["files"] as object[];
                if (files == null || files.Length == 0) throw new InvalidDataException("file list missing");
                foreach (object raw in files)
                {
                    var pin = Object(raw); Keys(pin,new[] {"path","bytes","sha256"},new string[0]);
                    string name = Portable(Text(pin,"path")); Hex(Text(pin,"sha256")); Integer(pin["bytes"]);
                    if (name == "release-manifest.json" || !listed.TryAddCompat(name,pin) || !members.ContainsKey(name) ||
                        kind == "data" && !DataMember(name) || kind == "app" && name != "BA Planner v7.exe" && !name.StartsWith("app/",StringComparison.Ordinal))
                        throw new InvalidDataException("package membership/scope");
                }
                if (listed.Count + 1 != members.Count) throw new InvalidDataException("unlisted ZIP member");
                if (kind == "data") CopyTree(app,staging); else Directory.CreateDirectory(staging);
                foreach (var pair in listed)
                {
                    var entry = members[pair.Key];
                    byte[] bytes = ReadEntry(entry,1073741824);
                    if (bytes.LongLength != Integer(pair.Value["bytes"]) || Sha(bytes) != Text(pair.Value,"sha256")) throw new InvalidDataException("member SHA mismatch");
                    if (pair.Key == "BA Planner v7.exe") continue; // No running launcher replacement.
                    string target = Inside(staging,pair.Key.Substring(4));
                    Directory.CreateDirectory(Path.GetDirectoryName(target)); File.WriteAllBytes(target,bytes);
                }
                if (kind == "data")
                {
                    var incoming = ReadJson(File.ReadAllBytes(Path.Combine(staging,".ba_planner_data_snapshot.json")));
                    var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    var incomingFiles=incoming["files"] as object[];
                    if (incomingFiles==null) throw new InvalidDataException("snapshot inventory");
                    foreach (object rawPin in incomingFiles) allowed.Add(Portable(Text(Object(rawPin),"path")));
                    foreach (string file in Directory.GetFiles(Path.Combine(staging,"backend","data"),"*",SearchOption.AllDirectories))
                    {
                        string relative = file.Substring(staging.Length+1).Replace('\\','/');
                        if (!allowed.Contains(relative)) File.Delete(file); // Only staging/backend/data.
                    }
                }
                ValidateSnapshot(staging,Text(descriptor,"dataSnapshotSha256"));
                if (Text(ReadJson(File.ReadAllBytes(Path.Combine(staging,".ba_planner_data_snapshot.json"))),"dataVersionId")!=Text(descriptor,"dataVersionId"))
                    throw new InvalidDataException("snapshot data version differs");
                if (!File.Exists(Path.Combine(staging,"ba_planner_v7.exe"))) throw new InvalidDataException("app executable missing");
                File.WriteAllText(Path.Combine(staging,".ba_planner_install.json"),Json.Serialize(new Dictionary<string,object> {
                    {"appVersion",Text(descriptor,"appVersion")},{"dataVersionId",Text(descriptor,"dataVersionId")},
                    {"dataSnapshotSha256",Text(descriptor,"dataSnapshotSha256")}}),new UTF8Encoding(false));
            }
            File.WriteAllText(Inside(root,".update-transaction.json"),"{\"schemaVersion\":1,\"owner\":\"ba-planner-updater\"}",new UTF8Encoding(false));
            if (Directory.Exists(app)) { Directory.Move(app,previous); moved = true; }
            BeforePublish();
            Directory.Move(staging,app);
            try { DeleteOwnedTree(root,"app-previous"); File.Delete(Inside(root,".update-transaction.json")); }
            catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
        catch
        {
            if (moved && !Directory.Exists(app) && Directory.Exists(previous)) Directory.Move(previous,app);
            throw;
        }
        finally { if (Directory.Exists(staging)) DeleteOwnedTree(root,"app-staging"); }
    }

    private static byte[] ReadEntry(ZipArchiveEntry entry, long maximum)
    {
        if (entry.Length > maximum) throw new InvalidDataException("archive member too large");
        using (var source = entry.Open())
        using (var output = new MemoryStream())
        {
            byte[] buffer = new byte[65536]; int read;
            while ((read=source.Read(buffer,0,buffer.Length)) > 0)
            {
                if (output.Length+read > maximum) throw new InvalidDataException("archive expansion limit");
                output.Write(buffer,0,read);
            }
            return output.ToArray();
        }
    }

    internal static bool TryUpdate(string root, string preferencesRoot)
    {
        try
        {
            root = Path.GetFullPath(root); NoLinks(root);
            string app=Inside(root,"app"), previous=Inside(root,"app-previous"), journal=Inside(root,".update-transaction.json");
            if (File.Exists(journal))
            {
                var marker=ReadJson(File.ReadAllBytes(journal));
                Keys(marker,new[] {"schemaVersion","owner"},new string[0]);
                if (Integer(marker["schemaVersion"])!=1 || Text(marker,"owner")!="ba-planner-updater") return false;
                if (!Directory.Exists(app) && Directory.Exists(previous)) Directory.Move(previous,app);
                if (Directory.Exists(app))
                {
                    try
                    {
                        var state=Installed(root);
                        ValidateSnapshot(app,Text(state,"dataSnapshotSha256"));
                    }
                    catch
                    {
                        if (!Directory.Exists(previous)) return false;
                        var old=Installed(root,"app-previous");
                        ValidateSnapshot(previous,Text(old,"dataSnapshotSha256"));
                        string rejected=Inside(root,"app-rejected-"+Guid.NewGuid().ToString("N"));
                        Directory.Move(app,rejected);
                        try { Directory.Move(previous,app); }
                        catch { Directory.Move(rejected,app); throw; }
                    }
                    DeleteOwnedTree(root,"app-staging"); DeleteOwnedTree(root,"app-previous"); File.Delete(journal);
                }
            }
            string config=Inside(root,"update-channel.json");
            if (!File.Exists(config)) config=Inside(root,"app/update-channel.json");
            if (!File.Exists(config)) return false;
            string now=Path.Combine(preferencesRoot,"check_now.flag");
            if (File.Exists(Path.Combine(preferencesRoot,"auto_update_disabled.flag")) && !File.Exists(now)) return false;
            if (File.Exists(now)) File.Delete(now);
            var channel=ReadJson(File.ReadAllBytes(config));
            Keys(channel,new[] {"latestAppUrl","latestDataUrl"},new string[0]);
            string appUrl=Text(channel,"latestAppUrl"), dataUrl=Text(channel,"latestDataUrl");
            SecureUri(appUrl); SecureUri(dataUrl);
            var installed=Installed(root);
            var latest=Descriptor(Fetch(appUrl),"app");
            int comparison=CompareVersions(Text(latest,"appVersion"),Text(installed,"appVersion"));
            if (comparison>0) { Install(root,latest,Fetch(Text(latest,"zipUrl"))); return true; }
            if (comparison<0) return false;
            var data=Descriptor(Fetch(dataUrl),"data");
            if (Text(data,"appVersion")!=Text(installed,"appVersion") || Text(data,"dataSnapshotSha256")==Text(installed,"dataSnapshotSha256")) return false;
            Install(root,data,Fetch(Text(data,"zipUrl"))); return true;
        }
        catch { return false; } // Offline/failure launches the current app silently.
    }

    private static Dictionary<string,object> Installed(string root)
    {
        return Installed(root,"app");
    }

    private static Dictionary<string,object> Installed(string root,string directory)
    {
        if (directory!="app" && directory!="app-previous") throw new InvalidDataException("install directory");
        string state=Inside(root,directory+"/.ba_planner_install.json");
        var value=ReadJson(File.ReadAllBytes(File.Exists(state)?state:Inside(root,"release-manifest.json")));
        VersionSyntax(Text(value,"appVersion")); Hex(Text(value,"dataSnapshotSha256"));
        return value;
    }

    private static bool TryAddCompat<T>(this Dictionary<string,T> target,string key,T value)
    {
        if (target.ContainsKey(key)) return false;
        target.Add(key,value); return true;
    }
}
