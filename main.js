const { app, BrowserWindow, powerSaveBlocker } = require('electron');
const path = require('path');
const { autoUpdater } = require("electron-updater");

// 1. Update Configuration
autoUpdater.autoDownload = true;
autoUpdater.on('update-downloaded', () => {
    // Reboots the player to the new version automatically
    autoUpdater.quitAndInstall(); 
});

autoUpdater.on('error', (err) => {
    console.log('Update Error: ' + err);
});

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

    win.once('ready-to-show', () => {
        autoUpdater.checkForUpdatesAndNotify();
    });
}

// 2. Prevent sleep and launch
app.whenReady().then(() => {
    powerSaveBlocker.start('prevent-display-sleep');
    createWindow();
});

// 3. Periodic update check (Every 60 minutes)
setInterval(() => {
    autoUpdater.checkForUpdatesAndNotify();
}, 3600000);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});