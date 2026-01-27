const { app, BrowserWindow, powerSaveBlocker } = require('electron');
const path = require('path');

let autoUpdater;

// 🛡️ Strong safety guard
try {
    autoUpdater = require('electron-updater').autoUpdater;
    autoUpdater.autoDownload = true;

    autoUpdater.on('update-downloaded', () => {
        // Reboots the player to the new version automatically
        autoUpdater.quitAndInstall(); 
    });

    autoUpdater.on('error', (err) => {
        console.log('Update Error: ' + err);
    });
} catch (e) {
    console.log('electron-updater not available, skipping updates');
}

function createWindow() {
    const win = new BrowserWindow({
        fullscreen: true,
        autoHideMenuBar: true,
        backgroundColor: '#000000',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            autoplayPolicy: 'no-user-gesture-required',
            additionalArguments: [
                `--userDataPath=${app.getPath('userData')}`,
                `--appVersion=${app.getVersion()}`
            ]
        }
    });

    win.loadFile(path.join(__dirname, 'player.html'));

    // Only check for updates if autoUpdater exists
    if (autoUpdater) {
        win.once('ready-to-show', () => {
            autoUpdater.checkForUpdatesAndNotify();
        });
    }
}

// Prevent sleep and launch
app.whenReady().then(() => {
    powerSaveBlocker.start('prevent-display-sleep');
    createWindow();
});

// Periodic update check every 60 minutes (if autoUpdater exists)
if (autoUpdater) {
    setInterval(() => {
        autoUpdater.checkForUpdatesAndNotify();
    }, 3600000);
}

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});
