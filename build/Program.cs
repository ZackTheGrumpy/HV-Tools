using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("HV Bypass Tool")]
[assembly: AssemblyDescription("HV Bypass Tool v4.0.2 Modernized Edition")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("Onennabe")]
[assembly: AssemblyProduct("HV Bypass Tool")]
[assembly: AssemblyCopyright("Copyright © Onennabe 2026")]
[assembly: AssemblyTrademark("Onennabe")]
[assembly: AssemblyCulture("")]
[assembly: AssemblyVersion("4.0.2.0")]
[assembly: AssemblyFileVersion("4.0.2.0")]

namespace ToolsV4
{
    class Program
    {
        [DllImport("kernel32.dll")]
        static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        const int SW_HIDE = 0;
        const int SW_SHOW = 5;

        static bool IsAdministrator()
        {
            using (var identity = WindowsIdentity.GetCurrent())
            {
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
        }

        static string Quote(string arg)
        {
            if (string.IsNullOrEmpty(arg)) return "\"\"";
            if (arg.Contains(" ") || arg.Contains("\""))
            {
                return "\"" + arg.Replace("\"", "\\\"") + "\"";
            }
            return arg;
        }

        [STAThread]
        static int Main(string[] args)
        {
            IntPtr consoleHwnd = GetConsoleWindow();

            bool isCli = false;
            foreach (var a in args)
            {
                if (string.Equals(a, "-cli", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(a, "/cli", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(a, "-CliOnly", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(a, "--cli", StringComparison.OrdinalIgnoreCase))
                {
                    isCli = true;
                    break;
                }
            }

            // In GUI mode, immediately hide console to prevent black window flicker
            if (!isCli && consoleHwnd != IntPtr.Zero)
            {
                ShowWindow(consoleHwnd, SW_HIDE);
            }

            // Self-elevation check
            if (!IsAdministrator())
            {
                var elevatePsi = new ProcessStartInfo();
                elevatePsi.FileName = Process.GetCurrentProcess().MainModule.FileName;
                elevatePsi.Arguments = string.Join(" ", args.Select(Quote));
                elevatePsi.Verb = "runas";
                elevatePsi.UseShellExecute = true;

                try
                {
                    using (var p = Process.Start(elevatePsi))
                    {
                        p.WaitForExit();
                        return p.ExitCode;
                    }
                }
                catch (Exception)
                {
                    // User declined UAC prompt
                    if (isCli)
                    {
                        Console.WriteLine("[ERROR] Administrator privileges are required to run this tool.");
                    }
                    else
                    {
                        MessageBox.Show("Administrator privileges are required to run this tool.", "HV Bypass Tool v4.0.2", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    }
                    return 1;
                }
            }

            // Extract embedded script
            string scriptContent = null;
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream("ToolsV4.ps1"))
            {
                if (stream != null)
                {
                    using (var reader = new StreamReader(stream, Encoding.UTF8))
                    {
                        scriptContent = reader.ReadToEnd();
                    }
                }
            }

            if (string.IsNullOrEmpty(scriptContent))
            {
                string msg = "Failed to extract embedded payload.";
                if (isCli) Console.WriteLine("[ERROR] " + msg);
                else MessageBox.Show(msg, "HV Bypass Tool v4.0.2", MessageBoxButtons.OK, MessageBoxIcon.Hand);
                return 1;
            }

            string tempFile = Path.Combine(Path.GetTempPath(), "HV_Tools_v402.ps1");
            try
            {
                File.WriteAllText(tempFile, scriptContent, new UTF8Encoding(false));
            }
            catch (Exception ex)
            {
                string msg = "Failed to write temporary script: " + ex.Message;
                if (isCli) Console.WriteLine("[ERROR] " + msg);
                else MessageBox.Show(msg, "HV Bypass Tool v4.0.2", MessageBoxButtons.OK, MessageBoxIcon.Hand);
                return 1;
            }

            string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            string exePath = Process.GetCurrentProcess().MainModule.FileName;

            var psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.WorkingDirectory = baseDir;
            psi.EnvironmentVariables["TOOL_DIR"] = baseDir;
            psi.EnvironmentVariables["TOOL_EXE"] = exePath;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = false;

            if (isCli)
            {
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + tempFile + "\" -CliOnly";
            }
            else
            {
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + tempFile + "\"";
            }

            int exitCode = 0;
            try
            {
                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit();
                    exitCode = proc.ExitCode;
                }
            }
            catch (Exception ex)
            {
                string msg = "Error starting tool: " + ex.Message;
                if (isCli) Console.WriteLine("[ERROR] " + msg);
                else MessageBox.Show(msg, "HV Bypass Tool v4.0.2", MessageBoxButtons.OK, MessageBoxIcon.Hand);
                exitCode = 1;
            }
            finally
            {
                if (File.Exists(tempFile))
                {
                    try { File.Delete(tempFile); } catch {}
                }
            }

            return exitCode;
        }
    }
}
