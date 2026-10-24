using System;
using System.Collections.Generic;
using System.IO;
using System.Web.Script.Serialization;

internal static class UpdaterHarness
{
    private static int Main(string[] args)
    {
        try
        {
            var json=new JavaScriptSerializer();
            if (args[0]=="versions")
            {
                Console.WriteLine(DistributionUpdater.CompareVersions(args[1],args[2]));
            }
            else if (args[0]=="install" || args[0]=="installfail")
            {
                if (args[0]=="installfail") DistributionUpdater.BeforePublish=delegate { throw new IOException("synthetic publish failure"); };
                var descriptor=DistributionUpdater.Descriptor(File.ReadAllBytes(args[2]),args[4]);
                DistributionUpdater.Install(args[1],descriptor,File.ReadAllBytes(args[3]));
                Console.WriteLine("installed");
            }
            else if (args[0]=="try")
            {
                var map=(Dictionary<string,object>)json.DeserializeObject(File.ReadAllText(args[3]));
                var requested=new List<string>();
                DistributionUpdater.Fetch=delegate(string url) {
                    requested.Add(url);
                    if (!map.ContainsKey(url)) throw new IOException("synthetic offline");
                    return File.ReadAllBytes((string)map[url]);
                };
                bool changed=DistributionUpdater.TryUpdate(args[1],args[2]);
                Console.WriteLine(json.Serialize(new Dictionary<string,object> {{"changed",changed},{"requested",requested}}));
            }
            else throw new ArgumentException("unknown harness command");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.GetType().Name+": "+error.Message);
            return 2;
        }
    }
}
