using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

internal sealed class DevToolsLauncherForm : Form
{
    private static readonly Regex UrlPattern = new Regex(
        @"https?://[^\s]+",
        RegexOptions.Compiled | RegexOptions.IgnoreCase
    );

    private readonly bool profileMode;
    private readonly Label statusLabel;
    private readonly TextBox outputBox;
    private readonly Button openDevToolsButton;
    private readonly Button hotReloadButton;
    private readonly Button hotRestartButton;
    private readonly Button stopButton;
    private Process flutterProcess;
    private string devToolsUrl;
    private bool nextUrlIsDevTools;
    private bool stopping;

    internal DevToolsLauncherForm(bool useProfileMode)
    {
        profileMode = useProfileMode;
        string modeLabel = profileMode ? "Profile" : "Debug";

        Text = "BA Planner v7 DevTools - " + modeLabel;
        Width = 760;
        Height = 520;
        MinimumSize = new Size(620, 360);
        StartPosition = FormStartPosition.CenterScreen;

        statusLabel = new Label
        {
            AutoSize = false,
            Dock = DockStyle.Top,
            Height = 48,
            Padding = new Padding(14, 15, 14, 0),
            Text = modeLabel + " 모드로 Flutter 앱을 시작하고 있습니다...",
        };

        outputBox = new TextBox
        {
            Dock = DockStyle.Fill,
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Both,
            WordWrap = false,
            Font = new Font(FontFamily.GenericMonospace, 9.0f),
            BackColor = Color.FromArgb(28, 30, 34),
            ForeColor = Color.Gainsboro,
        };

        openDevToolsButton = new Button
        {
            Text = "DevTools 열기",
            AutoSize = true,
            Enabled = false,
        };
        openDevToolsButton.Click += delegate { OpenDevTools(); };

        hotReloadButton = new Button
        {
            Text = "Hot Reload",
            AutoSize = true,
            Enabled = false,
        };
        hotReloadButton.Click += delegate { SendFlutterCommand("r"); };

        hotRestartButton = new Button
        {
            Text = "Hot Restart",
            AutoSize = true,
            Enabled = false,
        };
        hotRestartButton.Click += delegate { SendFlutterCommand("R"); };

        stopButton = new Button
        {
            Text = "앱 종료",
            AutoSize = true,
            Enabled = false,
        };
        stopButton.Click += delegate { Close(); };

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 52,
            Padding = new Padding(10, 9, 10, 8),
            FlowDirection = FlowDirection.LeftToRight,
        };
        buttonPanel.Controls.Add(openDevToolsButton);
        buttonPanel.Controls.Add(hotReloadButton);
        buttonPanel.Controls.Add(hotRestartButton);
        buttonPanel.Controls.Add(stopButton);

        Controls.Add(outputBox);
        Controls.Add(buttonPanel);
        Controls.Add(statusLabel);
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        BeginInvoke(new Action(StartFlutter));
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        StopFlutter();
        base.OnFormClosing(e);
    }

    private void StartFlutter()
    {
        string rootDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string frontendDirectory = Path.Combine(rootDirectory, "frontend");
        if (!File.Exists(Path.Combine(frontendDirectory, "pubspec.yaml")))
        {
            Fail("frontend\\pubspec.yaml을 찾지 못했습니다. 런처를 v7 최상위 폴더에서 실행해 주세요.");
            return;
        }

        string flutterCommand = ResolveFlutterCommand();
        if (flutterCommand == null)
        {
            Fail("Flutter SDK를 찾지 못했습니다. Flutter를 PATH에 추가하거나 FLUTTER_ROOT를 설정해 주세요.");
            return;
        }

        string flutterArguments = "run -d windows" + (profileMode ? " --profile" : "");
        string commandArguments = "/d /c \"\"" + flutterCommand + "\" " + flutterArguments + "\"";
        AppendOutput("> flutter " + flutterArguments + Environment.NewLine);

        var startInfo = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = commandArguments,
            WorkingDirectory = frontendDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
        };

        try
        {
            flutterProcess = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
            flutterProcess.OutputDataReceived += OnFlutterOutput;
            flutterProcess.ErrorDataReceived += OnFlutterOutput;
            flutterProcess.Exited += OnFlutterExited;
            flutterProcess.Start();
            flutterProcess.BeginOutputReadLine();
            flutterProcess.BeginErrorReadLine();
            stopButton.Enabled = true;
            hotReloadButton.Enabled = !profileMode;
            hotRestartButton.Enabled = !profileMode;
        }
        catch (Exception exception)
        {
            Fail("Flutter를 시작하지 못했습니다." + Environment.NewLine + exception.Message);
        }
    }

    private void OnFlutterOutput(object sender, DataReceivedEventArgs e)
    {
        if (e.Data == null)
        {
            return;
        }

        string line = StripAnsi(e.Data);
        AppendOutput(line + Environment.NewLine);

        if (line.IndexOf("DevTools debugger and profiler", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            nextUrlIsDevTools = true;
        }

        Match match = UrlPattern.Match(line);
        if (!match.Success)
        {
            return;
        }

        string candidate = match.Value.TrimEnd('.', ',', ')', ']');
        if (candidate.IndexOf("?uri=", StringComparison.OrdinalIgnoreCase) >= 0 || nextUrlIsDevTools)
        {
            nextUrlIsDevTools = false;
            SetDevToolsUrl(candidate);
        }
    }

    private void SetDevToolsUrl(string url)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(SetDevToolsUrl), url);
            return;
        }

        if (devToolsUrl != null)
        {
            return;
        }

        devToolsUrl = url;
        openDevToolsButton.Enabled = true;
        statusLabel.Text = "앱이 실행 중입니다. DevTools가 기본 브라우저에서 열립니다.";
        OpenDevTools();
    }

    private void OpenDevTools()
    {
        if (string.IsNullOrWhiteSpace(devToolsUrl))
        {
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = devToolsUrl,
                UseShellExecute = true,
            });
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                "DevTools 브라우저를 열지 못했습니다.\n\n" + exception.Message,
                Text,
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            );
        }
    }

    private void SendFlutterCommand(string command)
    {
        try
        {
            if (flutterProcess != null && !flutterProcess.HasExited)
            {
                flutterProcess.StandardInput.WriteLine(command);
                flutterProcess.StandardInput.Flush();
            }
        }
        catch (Exception exception)
        {
            AppendOutput("명령을 보내지 못했습니다: " + exception.Message + Environment.NewLine);
        }
    }

    private void OnFlutterExited(object sender, EventArgs e)
    {
        if (IsDisposed || stopping)
        {
            return;
        }

        BeginInvoke(new Action(delegate
        {
            int exitCode = flutterProcess == null ? -1 : flutterProcess.ExitCode;
            statusLabel.Text = "Flutter 프로세스가 종료되었습니다. 종료 코드: " + exitCode;
            openDevToolsButton.Enabled = false;
            hotReloadButton.Enabled = false;
            hotRestartButton.Enabled = false;
            stopButton.Text = "창 닫기";
        }));
    }

    private void StopFlutter()
    {
        if (stopping)
        {
            return;
        }

        stopping = true;
        try
        {
            if (flutterProcess == null || flutterProcess.HasExited)
            {
                return;
            }

            try
            {
                flutterProcess.StandardInput.WriteLine("q");
                flutterProcess.StandardInput.Flush();
                if (flutterProcess.WaitForExit(2500))
                {
                    return;
                }
            }
            catch
            {
                // Fall through to terminating only the process tree created by this launcher.
            }

            using (var taskKill = Process.Start(new ProcessStartInfo
            {
                FileName = "taskkill.exe",
                Arguments = "/PID " + flutterProcess.Id + " /T /F",
                UseShellExecute = false,
                CreateNoWindow = true,
            }))
            {
                if (taskKill != null)
                {
                    taskKill.WaitForExit(3000);
                }
            }
        }
        catch
        {
            // The child may already have exited while the window was closing.
        }
    }

    private void AppendOutput(string text)
    {
        if (IsDisposed)
        {
            return;
        }

        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(AppendOutput), text);
            return;
        }

        outputBox.AppendText(text);
    }

    private void Fail(string message)
    {
        statusLabel.Text = "실행하지 못했습니다.";
        AppendOutput(message + Environment.NewLine);
        stopButton.Text = "창 닫기";
        stopButton.Enabled = true;
        MessageBox.Show(message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    private static string ResolveFlutterCommand()
    {
        string flutterRoot = Environment.GetEnvironmentVariable("FLUTTER_ROOT");
        if (!string.IsNullOrWhiteSpace(flutterRoot))
        {
            string fromRoot = Path.Combine(flutterRoot, "bin", "flutter.bat");
            if (File.Exists(fromRoot))
            {
                return Path.GetFullPath(fromRoot);
            }
        }

        string pathValue = Environment.GetEnvironmentVariable("PATH") ?? "";
        foreach (string pathEntry in pathValue.Split(Path.PathSeparator))
        {
            string cleanEntry = pathEntry.Trim().Trim('"');
            if (cleanEntry.Length == 0)
            {
                continue;
            }

            string candidate = Path.Combine(cleanEntry, "flutter.bat");
            if (File.Exists(candidate))
            {
                return Path.GetFullPath(candidate);
            }
        }

        const string commonFlutterPath = @"C:\src\flutter\bin\flutter.bat";
        return File.Exists(commonFlutterPath) ? commonFlutterPath : null;
    }

    private static string StripAnsi(string value)
    {
        return Regex.Replace(value, "\\x1B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~])", "");
    }
}

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        string executableName = Path.GetFileNameWithoutExtension(Application.ExecutablePath);
        bool profileMode = executableName.IndexOf("Profile", StringComparison.OrdinalIgnoreCase) >= 0;
        string mutexName = profileMode
            ? "Local\\BAPlannerV7DevToolsProfileLauncher"
            : "Local\\BAPlannerV7DevToolsDebugLauncher";

        bool ownsMutex;
        using (var launcherMutex = new Mutex(true, mutexName, out ownsMutex))
        {
            if (!ownsMutex)
            {
                MessageBox.Show(
                    "같은 모드의 BA Planner v7 DevTools 런처가 이미 실행 중입니다.",
                    "BA Planner v7 DevTools",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new DevToolsLauncherForm(profileMode));
        }
    }
}
