using Microsoft.UI.Xaml;

namespace CodexConfigSwitcher.WinUI;

public sealed partial class MainWindow : Window
{
    public MainWindowViewModel ViewModel { get; }

    public MainWindow()
    {
        InitializeComponent();
        ViewModel = new MainWindowViewModel();
        RootLayout.DataContext = ViewModel;
        Activated += MainWindow_Activated;
    }

    private async void MainWindow_Activated(object sender, WindowActivatedEventArgs args)
    {
        Activated -= MainWindow_Activated;
        await ViewModel.LoadAsync();
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.LoadAsync();
    }

    private async void ApplyButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.ApplySelectedAsync(restartTargetApp: false);
    }

    private async void ApplyAndRestartButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.ApplySelectedAsync(restartTargetApp: true);
    }

    private async void SaveTargetPathButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.SaveTargetPathAsync();
    }

    private async void ResetTargetPathButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.ResetTargetAppAsync();
    }

    private async void RestartTargetButton_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.RestartTargetAppAsync();
    }
}
