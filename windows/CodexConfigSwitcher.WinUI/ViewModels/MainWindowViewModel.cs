using System.Collections.ObjectModel;
using CodexConfigSwitcher.WinUI.Helpers;
using CodexConfigSwitcher.WinUI.Models;
using CodexConfigSwitcher.WinUI.Services;

namespace CodexConfigSwitcher.WinUI;

public sealed class MainWindowViewModel : ObservableObject
{
    private readonly LocalStateRepository repository;
    private readonly CliBridgeService cliBridgeService;

    private CodexPresetRecord? selectedPreset;
    private string liveSummaryLine = "当前尚未读取 live 配置。";
    private string pathsSummaryLine = "config/auth 路径将会在首次刷新后显示。";
    private string targetSummaryLine = "目标应用状态待刷新。";
    private string cliBridgeLine = "CLI 桥接待刷新。";
    private string lastAppliedLine = "最近应用：暂无";
    private string targetPathDraft = string.Empty;
    private string statusMessage = "准备就绪。";
    private string errorMessage = string.Empty;
    private bool isBusy;

    public MainWindowViewModel()
        : this(new LocalStateRepository(), new CliBridgeService())
    {
    }

    public MainWindowViewModel(LocalStateRepository repository, CliBridgeService cliBridgeService)
    {
        this.repository = repository;
        this.cliBridgeService = cliBridgeService;
        TargetPathDraft = repository.Paths.DefaultTargetPath;
        CliBridgeLine = $"CLI 桥：{cliBridgeService.ResolutionHint}";
    }

    public ObservableCollection<CodexPresetRecord> Presets { get; } = [];

    public CodexPresetRecord? SelectedPreset
    {
        get => selectedPreset;
        set
        {
            if (SetProperty(ref selectedPreset, value))
            {
                OnPropertyChanged(nameof(SelectedPresetNameLine));
                OnPropertyChanged(nameof(SelectedPresetModelLine));
                OnPropertyChanged(nameof(SelectedPresetReviewModelLine));
                OnPropertyChanged(nameof(SelectedPresetAuthLine));
                OnPropertyChanged(nameof(SelectedPresetProviderLine));
                OnPropertyChanged(nameof(SelectedPresetBaseUrlLine));
                OnPropertyChanged(nameof(SelectedPresetEnvironmentLine));
            }
        }
    }

    public string LiveSummaryLine
    {
        get => liveSummaryLine;
        private set => SetProperty(ref liveSummaryLine, value);
    }

    public string PathsSummaryLine
    {
        get => pathsSummaryLine;
        private set => SetProperty(ref pathsSummaryLine, value);
    }

    public string TargetSummaryLine
    {
        get => targetSummaryLine;
        private set => SetProperty(ref targetSummaryLine, value);
    }

    public string CliBridgeLine
    {
        get => cliBridgeLine;
        private set => SetProperty(ref cliBridgeLine, value);
    }

    public string LastAppliedLine
    {
        get => lastAppliedLine;
        private set => SetProperty(ref lastAppliedLine, value);
    }

    public string TargetPathDraft
    {
        get => targetPathDraft;
        set => SetProperty(ref targetPathDraft, value);
    }

    public string StatusMessage
    {
        get => statusMessage;
        private set => SetProperty(ref statusMessage, value);
    }

    public string ErrorMessage
    {
        get => errorMessage;
        private set => SetProperty(ref errorMessage, value);
    }

    public bool IsBusy
    {
        get => isBusy;
        private set => SetProperty(ref isBusy, value);
    }

    public string PresetCountLine => $"本地已保存 {Presets.Count} 个预设";

    public string SelectedPresetNameLine => SelectedPreset?.Name ?? "请先从左侧选择一个预设";

    public string SelectedPresetModelLine => SelectedPreset is null
        ? "模型：-"
        : $"主模型：{SelectedPreset.Model}";

    public string SelectedPresetReviewModelLine => SelectedPreset is null
        ? "评审模型：-"
        : $"Review Model：{SelectedPreset.ReviewModel}";

    public string SelectedPresetAuthLine => SelectedPreset is null
        ? "鉴权：-"
        : $"鉴权模式：{SelectedPreset.AuthMode}";

    public string SelectedPresetProviderLine => SelectedPreset is null
        ? "Provider：-"
        : $"Provider：{SelectedPreset.ProviderName}";

    public string SelectedPresetBaseUrlLine => SelectedPreset is null
        ? "Base URL：-"
        : $"Base URL：{SelectedPreset.BaseUrl}";

    public string SelectedPresetEnvironmentLine => SelectedPreset is null
        ? "环境：-"
        : $"环境：{SelectedPreset.EnvironmentTitle}";

    public async Task LoadAsync()
    {
        await ReloadStateAsync(bypassBusyGuard: false);
    }

    private async Task ReloadStateAsync(bool bypassBusyGuard)
    {
        if (IsBusy && !bypassBusyGuard)
        {
            return;
        }

        var shouldManageBusyState = !IsBusy;
        if (shouldManageBusyState)
        {
            IsBusy = true;
        }

        ErrorMessage = string.Empty;
        StatusMessage = "正在刷新 Windows 工作台...";

        try
        {
            var presets = await repository.LoadPresetsAsync();
            var settings = await repository.LoadSettingsAsync();

            SyncPresets(presets);
            SelectPreset(settings.SelectedPresetId);
            ApplySettingsFallback(settings);

            try
            {
                var status = await cliBridgeService.GetStatusAsync();
                ApplyCliStatus(status);
                StatusMessage = "已刷新 live 状态和目标应用信息。";
            }
            catch (Exception ex)
            {
                CliBridgeLine = $"CLI 桥不可用：{cliBridgeService.ResolutionHint}";
                ErrorMessage = $"CLI 桥接失败：{ex.Message}";
                StatusMessage = "已刷新本地预设，但 live 状态未更新。";
            }
        }
        finally
        {
            if (shouldManageBusyState)
            {
                IsBusy = false;
            }
        }
    }

    public async Task ApplySelectedAsync(bool restartTargetApp)
    {
        if (SelectedPreset is null || IsBusy)
        {
            return;
        }

        await RunActionAsync(
            restartTargetApp ? "正在应用预设并准备重启目标应用..." : "正在应用预设...",
            async () =>
            {
                await cliBridgeService.ApplyPresetAsync(SelectedPreset.Name, restartTargetApp);
                await ReloadStateAsync(bypassBusyGuard: true);
                StatusMessage = restartTargetApp
                    ? "已应用预设，并请求重启目标应用。"
                    : "已应用预设。";
            }
        );
    }

    public async Task SaveTargetPathAsync()
    {
        if (IsBusy)
        {
            return;
        }

        await RunActionAsync(
            "正在更新目标应用路径...",
            async () =>
            {
                await cliBridgeService.SetTargetPathAsync(TargetPathDraft);
                await ReloadStateAsync(bypassBusyGuard: true);
                StatusMessage = "已更新目标应用路径。";
            }
        );
    }

    public async Task ResetTargetAppAsync()
    {
        if (IsBusy)
        {
            return;
        }

        await RunActionAsync(
            "正在恢复默认目标应用...",
            async () =>
            {
                await cliBridgeService.ResetTargetAppAsync();
                await ReloadStateAsync(bypassBusyGuard: true);
                StatusMessage = "已恢复默认目标应用。";
            }
        );
    }

    public async Task RestartTargetAppAsync()
    {
        if (IsBusy)
        {
            return;
        }

        await RunActionAsync(
            "正在重启目标应用...",
            async () =>
            {
                await cliBridgeService.RestartTargetAppAsync();
                await ReloadStateAsync(bypassBusyGuard: true);
                StatusMessage = "已请求重启目标应用。";
            }
        );
    }

    private void SyncPresets(IReadOnlyList<CodexPresetRecord> presets)
    {
        Presets.Clear();
        foreach (var preset in presets.OrderBy(preset => preset.Name, StringComparer.OrdinalIgnoreCase))
        {
            Presets.Add(preset);
        }

        OnPropertyChanged(nameof(PresetCountLine));
    }

    private void SelectPreset(Guid? selectedPresetId)
    {
        SelectedPreset = selectedPresetId is null
            ? Presets.FirstOrDefault()
            : Presets.FirstOrDefault(preset => preset.Id == selectedPresetId) ?? Presets.FirstOrDefault();
    }

    private void ApplySettingsFallback(AppSettingsRecord settings)
    {
        TargetPathDraft = settings.TargetApp.AppPath;
        TargetSummaryLine = $"目标应用：{settings.TargetApp.DisplayName} · 路径：{settings.TargetApp.AppPath}";
        LastAppliedLine = settings.LastAppliedAt is null
            ? "最近应用：暂无"
            : $"最近应用：{settings.LastAppliedAt:yyyy-MM-dd HH:mm:ss}";
        CliBridgeLine = $"CLI 桥：{cliBridgeService.ResolutionHint}";
    }

    private void ApplyCliStatus(CliStatusPayload status)
    {
        LiveSummaryLine =
            $"当前 live：{status.LivePreset.EnvironmentTitle} / {status.LivePreset.Model} / {status.LivePreset.BaseUrl}";
        PathsSummaryLine = $"config：{status.ConfigPath} | auth：{status.AuthPath}";
        TargetSummaryLine =
            $"目标应用：{status.TargetApp.DisplayName} · {status.TargetAvailabilityTitle} · {status.TargetApp.AppPath}";
        TargetPathDraft = status.TargetApp.AppPath;
        LastAppliedLine = status.LastAppliedAt is null
            ? "最近应用：暂无"
            : $"最近应用：{status.LastAppliedAt:yyyy-MM-dd HH:mm:ss}";
        CliBridgeLine = $"CLI 桥：{cliBridgeService.ResolutionHint} · 目标状态：{status.TargetAvailabilityTitle}";
    }

    private async Task RunActionAsync(string pendingMessage, Func<Task> action)
    {
        IsBusy = true;
        ErrorMessage = string.Empty;
        StatusMessage = pendingMessage;

        try
        {
            await action();
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
            StatusMessage = "操作未完成。";
        }
        finally
        {
            IsBusy = false;
        }
    }
}
