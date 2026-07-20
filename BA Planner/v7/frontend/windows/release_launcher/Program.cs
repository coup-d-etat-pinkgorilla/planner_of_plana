using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows.Forms;

internal sealed class SyncResult
{
    internal int ExitCode;
    internal string Output = "";
    internal string Error = "";
}

internal sealed class SyncProgressForm : Form
{
    private readonly string syncScript;
    internal SyncResult Result { get; private set; }

    internal SyncProgressForm(string syncScriptPath)
    {
        syncScript = syncScriptPath;
        Result = new SyncResult { ExitCode = -1 };

        Text = "BA Planner v7";
        Width = 430;
        Height = 132;
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ControlBox = false;

        var label = new Label
        {
            AutoSize = false,
            Dock = DockStyle.Top,
            Height = 52,
            Padding = new Padding(18, 18, 18, 0),
            Text = "최신 변경 사항을 확인하고 있습니다...",
        };
        var progress = new ProgressBar
        {
            Dock = DockStyle.Top,
            Height = 18,
            Margin = new Padding(18),
            Style = ProgressBarStyle.Marquee,
            MarqueeAnimationSpeed = 24,
        };

        Controls.Add(progress);
        Controls.Add(label);
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);

        var worker = new BackgroundWorker();
        worker.DoWork += delegate(object sender, DoWorkEventArgs args)
        {
            args.Result = Program.RunSync(syncScript);
        };
        worker.RunWorkerCompleted += delegate(object sender, RunWorkerCompletedEventArgs args)
        {
            if (args.Error != null)
            {
                Result = new SyncResult
                {
                    ExitCode = -1,
                    Error = args.Error.ToString(),
                };
            }
            else
            {
                Result = (SyncResult)args.Result;
            }
            Close();
        };
        worker.RunWorkerAsync();
    }
}

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        bool ownsMutex;
        using (var launcherMutex = new Mutex(true, "Local\\BAPlannerV7ReleaseLauncher", out ownsMutex))
        {
            if (!ownsMutex)
            {
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string rootDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string syncScript = Path.Combine(
                rootDirectory,
                "frontend",
                "tool",
                "sync_windows_release.ps1"
            );
            string executablePath = Path.Combine(
                rootDirectory,
                "release",
                "ba_planner_v7.exe"
            );

            if (File.Exists(syncScript))
            {
                SyncResult result;
                using (var progressForm = new SyncProgressForm(syncScript))
                {
                    Application.Run(progressForm);
                    result = progressForm.Result;
                }

                if (result.ExitCode != 0)
                {
                    string details = string.IsNullOrWhiteSpace(result.Error)
                        ? result.Output
                        : result.Error;
                    DialogResult choice = MessageBox.Show(
                        "최신 Release 빌드를 만들지 못했습니다.\n\n"
                            + details.Trim()
                            + "\n\n기존 빌드를 실행하시겠습니까?",
                        "BA Planner v7",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Warning
                    );
                    if (choice != DialogResult.Yes)
                    {
                        return;
                    }
                }
            }

            if (!File.Exists(executablePath))
            {
                MessageBox.Show(
                    "실행에 필요한 release 폴더가 없습니다.\n"
                        + "frontend\\tool\\build_windows_release.ps1을 실행해 주세요.",
                    "BA Planner v7",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            Process.Start(
                new ProcessStartInfo
                {
                    FileName = executablePath,
                    WorkingDirectory = Path.GetDirectoryName(executablePath),
                    UseShellExecute = true,
                }
            );
        }
    }

    internal static SyncResult RunSync(string syncScript)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + syncScript + "\"",
            WorkingDirectory = Path.GetDirectoryName(syncScript),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

        using (Process process = Process.Start(startInfo))
        {
            string output = process.StandardOutput.ReadToEnd();
            string error = process.StandardError.ReadToEnd();
            process.WaitForExit();
            return new SyncResult
            {
                ExitCode = process.ExitCode,
                Output = output,
                Error = error,
            };
        }
    }
}
